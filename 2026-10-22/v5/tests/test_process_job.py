import sys,tempfile,threading,time,unittest
from pathlib import Path
from host_app.process_job import run_tool


class ProcessJobTests(unittest.TestCase):
    def test_process_output_is_preserved(self):
        with tempfile.TemporaryDirectory() as folder:
            result=run_tool([sys.executable,'-c','print("artifact")'],folder,timeout=5)
            self.assertEqual(result['returncode'],0)
            self.assertIn('artifact',(Path(folder)/'process.log').read_text())

    def test_cancel_reaps_own_process(self):
        cancel=threading.Event();timer=threading.Timer(.4,cancel.set)
        with tempfile.TemporaryDirectory() as folder:
            timer.start();start=time.monotonic()
            try:
                with self.assertRaises(InterruptedError):run_tool([sys.executable,'-c','import time;print("started",flush=True);time.sleep(30)'],folder,cancel=cancel)
                self.assertLess(time.monotonic()-start,5)
                self.assertIn('started',(Path(folder)/'process.log').read_text())
            finally:timer.cancel()

if __name__=='__main__':unittest.main()
