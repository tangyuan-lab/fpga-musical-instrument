"""可取消的本机工具进程；只终止本次启动的进程树，保留日志及中间产物。"""
import ctypes as C
import os
from pathlib import Path
import subprocess
import time


class WindowsJob:
    def __init__(self,process,limit_bytes):
        self.handle=None
        if os.name!='nt':return
        from ctypes import wintypes as W
        class Basic(C.Structure):
            _fields_=[('ProcessTime',C.c_longlong),('JobTime',C.c_longlong),('Flags',W.DWORD),
                      ('MinWorkingSet',C.c_size_t),('MaxWorkingSet',C.c_size_t),('ActiveProcesses',W.DWORD),
                      ('Affinity',C.c_size_t),('Priority',W.DWORD),('Scheduling',W.DWORD)]
        class IO(C.Structure):_fields_=[(name,C.c_ulonglong) for name in ('ReadOps','WriteOps','OtherOps','ReadBytes','WriteBytes','OtherBytes')]
        class Extended(C.Structure):
            _fields_=[('Basic',Basic),('IO',IO),('ProcessLimit',C.c_size_t),('JobLimit',C.c_size_t),('PeakProcess',C.c_size_t),('PeakJob',C.c_size_t)]
        self.kernel=C.WinDLL('kernel32',use_last_error=True)
        create=self.kernel.CreateJobObjectW;create.argtypes=[C.c_void_p,W.LPCWSTR];create.restype=W.HANDLE
        setinfo=self.kernel.SetInformationJobObject;setinfo.argtypes=[W.HANDLE,C.c_int,C.c_void_p,W.DWORD];setinfo.restype=W.BOOL
        assign=self.kernel.AssignProcessToJobObject;assign.argtypes=[W.HANDLE,W.HANDLE];assign.restype=W.BOOL
        self.kernel.CloseHandle.argtypes=[W.HANDLE];self.kernel.CloseHandle.restype=W.BOOL
        self.handle=create(None,None)
        info=Extended();info.Basic.Flags=0x2000|0x200;info.JobLimit=limit_bytes
        if not self.handle or not setinfo(self.handle,9,C.byref(info),C.sizeof(info)) or not assign(self.handle,int(process._handle)):
            error=C.get_last_error();self.close();raise OSError(error,'无法为识谱进程建立内存/取消边界')
    def close(self):
        if self.handle:self.kernel.CloseHandle(self.handle);self.handle=None


def run_tool(command,folder,cancel=None,timeout=600,memory_mib=4096):
    """stdout/stderr直接落盘，避免大日志占满管道；Windows Job限制整棵进程树。"""
    folder=Path(folder);folder.mkdir(parents=True,exist_ok=True);log=folder/'process.log'
    if cancel is not None and cancel.is_set():raise InterruptedError('识谱已取消')
    process=None;job=None;started=time.monotonic()
    try:
        with log.open('wb') as output:
            process=subprocess.Popen(command,stdout=output,stderr=subprocess.STDOUT,
                creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
            job=WindowsJob(process,memory_mib*1024*1024)
            while process.poll() is None:
                if cancel is not None and cancel.wait(.05):raise InterruptedError('识谱已取消；中间结果已保留')
                if cancel is None:time.sleep(.05)
                if time.monotonic()-started>timeout:raise TimeoutError(f'识谱超过{timeout}秒；日志及中间结果已保留')
            if process.returncode:
                raise RuntimeError(f'识谱工具退出码{process.returncode}；'+log.read_text(encoding='utf-8',errors='replace')[-1500:])
        return dict(seconds=time.monotonic()-started,returncode=process.returncode,log=str(log))
    finally:
        if job:job.close()
        if process and process.poll() is None:
            if os.name=='nt':
                subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
            else:process.terminate()
            try:process.wait(timeout=1)
            except subprocess.TimeoutExpired:process.kill();process.wait(timeout=1)
