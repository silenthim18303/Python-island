from vosk import Model, KaldiRecognizer
import pyaudio
import json

# 加载离线模型
model = Model("vosk-model-small-cn-0.22")
# 16000采样率，中文模型通用
rec = KaldiRecognizer(model, 16000)

# 打开麦克风
p = pyaudio.PyAudio()
stream = p.open(
    format=pyaudio.paInt16,
    channels=1,
    rate=16000,
    input=True,
    frames_per_buffer=8000
)
stream.start_stream()

print("开始说话，按 Ctrl+C 退出")

try:
    while True:
        data = stream.read(4000, exception_on_overflow=False)
        if rec.AcceptWaveform(data):
            res = json.loads(rec.Result())
            print("识别结果：", res["text"])
except KeyboardInterrupt:
    print("\n结束识别")