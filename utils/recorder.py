import cv2
import numpy as np
import mss
import os
import threading
import time
from datetime import datetime
from PySide6.QtCore import QObject, Signal

class ScreenRecorder(QObject):
    recording_status = Signal(bool, str) # status, filename

    def __init__(self, output_dir="video"):
        super().__init__()
        self.output_dir = output_dir
        self.is_recording = False
        self._thread = None
        
        if not os.path.exists(self.output_dir):
            os.makedirs(self.output_dir)

    def start_recording(self):
        if not self.is_recording:
            self.is_recording = True
            filename = f"record_{datetime.now().strftime('%Y%m%d_%H%M%S')}.mp4"
            filepath = os.path.join(self.output_dir, filename)
            self._thread = threading.Thread(target=self._record, args=(filepath,))
            self._thread.start()
            self.recording_status.emit(True, filename)

    def stop_recording(self):
        if self.is_recording:
            self.is_recording = False
            if self._thread:
                self._thread.join()
            self.recording_status.emit(False, "")

    def _record(self, filepath):
        with mss.mss() as sct:
            # Use the primary monitor
            monitor = sct.monitors[1]
            width = monitor["width"]
            height = monitor["height"]
            
            # Define codec and create VideoWriter object
            fourcc = cv2.VideoWriter_fourcc(*'mp4v')
            # Assuming 20 FPS
            out = cv2.VideoWriter(filepath, fourcc, 20.0, (width, height))
            
            while self.is_recording:
                # Capture screen
                img = sct.grab(monitor)
                frame = np.array(img)
                # Convert from BGRA to BGR
                frame = cv2.cvtColor(frame, cv2.COLOR_BGRA2BGR)
                out.write(frame)
                # Control frame rate
                time.sleep(1/20)
            
            out.release()
