"""一个线程拥有串口读写；普通事务等待ACK时仍可发送紧急帧。"""
from __future__ import annotations
from concurrent.futures import Future
from dataclasses import dataclass
import queue
import threading
import time
from .protocol import FrameDecoder,encode_frame,parse_ack,ACK


class TransferAborted(RuntimeError):
    """用户显式中止上传；不得在随后重试中继续写资源。"""


@dataclass
class Request:
    kind:int
    payload:bytes
    timeout:float
    retries:int
    urgent:bool=False
    abort:bool=False
    future:Future=None
    sequence:int=0
    attempts:int=0
    deadline:float=0


class SerialExecutor:
    def __init__(self,port):
        self.port=port;self.commands=queue.Queue(maxsize=256);self.decoder=FrameDecoder()
        self.closed=threading.Event();self.sequence=0;self.submit_lock=threading.Lock()
        # 2ms串口等待上界避免紧急请求被旧的100ms读超时挡住。
        self.port.timeout=.002
        self.port.write_timeout=.25
        self.thread=threading.Thread(target=self._run,name='FPGA serial owner',daemon=True);self.thread.start()
    def request(self,kind,payload=b'',*,timeout=1,retries=3,urgent=False,abort=False):
        if timeout<=0 or retries<1:raise ValueError('串口超时与重试次数必须为正')
        request=Request(kind,bytes(payload),timeout,retries,urgent,abort,Future())
        with self.submit_lock:
            if self.closed.is_set():raise RuntimeError('串口执行器已关闭')
            try:self.commands.put_nowait(request)
            except queue.Full:raise RuntimeError('串口命令队列已满')
        return request.future.result()
    @staticmethod
    def _fail(request,error):
        if not request.future.done():request.future.set_exception(error)
    def _run(self):
        normal=[];urgent=[];active={};fatal=None;normal_inflight=None;urgent_inflight=None
        def transmit(request):
            raw=encode_frame(request.kind,request.sequence,request.payload)
            if self.port.write(raw)!=len(raw):raise IOError('串口帧未完整写入')
            request.attempts+=1;request.deadline=time.monotonic()+request.timeout
        try:
            while not self.closed.is_set():
                while True:
                    try:request=self.commands.get_nowait()
                    except queue.Empty:break
                    if request.abort:
                        # 同时取消旧状态查询，防止清音确认后又把清音前的快照显示为实际状态。
                        for item in list(normal):
                            normal.remove(item);self._fail(item,TransferAborted('上传或设备操作已中止'))
                        for seq,item in list(active.items()):
                            if not item.urgent:
                                self._fail(item,TransferAborted('上传或设备操作已中止'));active.pop(seq)
                                if normal_inflight==seq:normal_inflight=None
                    (urgent if request.urgent else normal).append(request)
                for pending,is_urgent in ((urgent,True),(normal,False)):
                    if pending and (urgent_inflight is None if is_urgent else normal_inflight is None and not urgent and urgent_inflight is None):
                        request=pending.pop(0);request.sequence=self.sequence;self.sequence=(self.sequence+1)&0xffff
                        while request.sequence in active:request.sequence=self.sequence;self.sequence=(self.sequence+1)&0xffff
                        transmit(request);active[request.sequence]=request
                        if is_urgent:urgent_inflight=request.sequence
                        else:normal_inflight=request.sequence
                data=self.port.read(min(4096,self.port.in_waiting) or 1)
                for response in self.decoder.feed(data):
                    request=active.get(response.sequence)
                    if request is None or response.message_type not in (ACK,0x82) or len(response.payload)<2:continue
                    original,status,_=parse_ack(response)
                    if original!=request.kind:continue
                    if response.message_type!=ACK or status:
                        self._fail(request,RuntimeError(f'FPGA rejected message type 0x{request.kind:02X}, status {status}'))
                    elif not request.future.done():request.future.set_result(response)
                    active.pop(response.sequence)
                    if request.urgent:urgent_inflight=None
                    else:normal_inflight=None
                now=time.monotonic()
                for seq,request in list(active.items()):
                    if now<request.deadline:continue
                    if request.attempts<request.retries:transmit(request)
                    else:
                        self._fail(request,TimeoutError(f'no ACK for message type 0x{request.kind:02X}'));active.pop(seq)
                        if request.urgent:urgent_inflight=None
                        else:normal_inflight=None
        except BaseException as exc:fatal=exc
        finally:
            with self.submit_lock:self.closed.set()
            error=fatal or RuntimeError('串口连接已关闭')
            for request in list(active.values())+normal+urgent:self._fail(request,error)
            while True:
                try:self._fail(self.commands.get_nowait(),error)
                except queue.Empty:break
            self.port.close()
    def close(self):
        with self.submit_lock:self.closed.set()
        self.thread.join(timeout=2)
        if self.thread.is_alive():raise RuntimeError('串口执行器未在关闭期限内退出')
