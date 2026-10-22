from concurrent.futures import ThreadPoolExecutor
import queue,threading,time,unittest
from host_app.protocol import FrameDecoder,encode_frame
from host_app.serial_executor import SerialExecutor,TransferAborted
from host_app.device_v2 import DeviceV2,FEATURE_EMERGENCY
from host_app.music_project import Patch


class FakeSerial:
    def __init__(self):
        self.incoming=queue.Queue();self.sent=queue.Queue();self.decoder=FrameDecoder();self.timeout=.002;self.closed=False;self.io_threads=set()
    @property
    def in_waiting(self):return self.incoming.qsize()
    def read(self,count):
        self.io_threads.add(threading.get_ident())
        try:first=self.incoming.get(timeout=self.timeout)
        except queue.Empty:return b''
        data=bytearray([first])
        while len(data)<count:
            try:data.append(self.incoming.get_nowait())
            except queue.Empty:break
        return bytes(data)
    def write(self,data):
        self.io_threads.add(threading.get_ident())
        for frame in self.decoder.feed(data):self.sent.put(frame)
        return len(data)
    def ack(self,frame,code=0):
        for b in encode_frame(0x81,frame.sequence,bytes([frame.message_type,code])):self.incoming.put(b)
    def close(self):self.closed=True


class SerialExecutorTests(unittest.TestCase):
    def setUp(self):self.port=FakeSerial();self.executor=SerialExecutor(self.port);self.callers=ThreadPoolExecutor(3)
    def tearDown(self):self.executor.close();self.callers.shutdown(wait=True)
    def test_urgent_ack_overtakes_slow_commit_without_stealing_ack(self):
        ordinary=self.callers.submit(self.executor.request,0x34,b'crc',timeout=2)
        first=self.port.sent.get(timeout=1)
        urgent=self.callers.submit(self.executor.request,0x3b,b'\x01',urgent=True)
        second=self.port.sent.get(timeout=1);self.assertEqual(second.message_type,0x3b)
        self.port.ack(second);self.assertEqual(urgent.result(timeout=1).sequence,second.sequence)
        self.assertFalse(ordinary.done());self.port.ack(first);self.assertEqual(ordinary.result(timeout=1).sequence,first.sequence)
        self.assertEqual(len(self.port.io_threads),1)
    def test_abort_cancels_commit_and_does_not_retry_it(self):
        ordinary=self.callers.submit(self.executor.request,0x34,b'crc',timeout=.05,retries=3);old=self.port.sent.get(timeout=1)
        urgent=self.callers.submit(self.executor.request,0x3b,b'\x03',urgent=True,abort=True)
        stop=self.port.sent.get(timeout=1)
        with self.assertRaises(TransferAborted):ordinary.result(timeout=1)
        self.port.ack(old);self.port.ack(stop);urgent.result(timeout=1)
        time.sleep(.1);self.assertTrue(self.port.sent.empty())
    def test_retry_uses_same_sequence_and_rejects_matching_nack(self):
        result=self.callers.submit(self.executor.request,0x30,timeout=.02,retries=2)
        first=self.port.sent.get(timeout=1);retry=self.port.sent.get(timeout=1)
        self.assertEqual(first.sequence,retry.sequence);self.port.ack(retry,7)
        with self.assertRaisesRegex(RuntimeError,'status 7'):result.result(timeout=1)
    def test_abort_discards_snapshot_taken_before_stop(self):
        old=self.callers.submit(self.executor.request,0x37,timeout=2);frame=self.port.sent.get(timeout=1)
        urgent=self.callers.submit(self.executor.request,0x3b,b'\x03',urgent=True,abort=True);stop=self.port.sent.get(timeout=1)
        self.port.ack(frame);self.port.ack(stop);urgent.result(timeout=1)
        with self.assertRaises(TransferAborted):old.result(timeout=1)
        fresh=self.callers.submit(self.executor.request,0x37);request=self.port.sent.get(timeout=1);self.port.ack(request)
        self.assertNotEqual(fresh.result(timeout=1).sequence,frame.sequence)
    def test_close_releases_waiters(self):
        result=self.callers.submit(self.executor.request,0x30,timeout=10);self.port.sent.get(timeout=1)
        self.executor.close()
        with self.assertRaisesRegex(RuntimeError,'关闭'):result.result(timeout=1)
        self.assertTrue(self.port.closed)

class UploadAbortTests(unittest.TestCase):
    def test_stop_between_chunks_prevents_commit(self):
        device=DeviceV2.__new__(DeviceV2);device.features=FEATURE_EMERGENCY;sent=[]
        device.send_and_wait_ack=lambda kind,payload=b'',**kwargs:sent.append(kind)
        with self.assertRaises(TransferAborted):
            device.upload_resource(1,0,Patch(),bytes(512),progress=lambda *_:device.emergency())
        self.assertEqual(sent,[0x32,0x33,0x3b])
    def test_legacy_device_does_not_send_unknown_emergency(self):
        device=DeviceV2.__new__(DeviceV2);device.features=3;sent=[]
        device.send_and_wait_ack=lambda *args,**kwargs:sent.append(args)
        with self.assertRaisesRegex(RuntimeError,'新版位流'):device.emergency()
        self.assertFalse(sent)

if __name__=='__main__':unittest.main()
