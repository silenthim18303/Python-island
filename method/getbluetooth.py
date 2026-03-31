import windows_bluetooth_watcher as wbw
import asyncio

async def main():
    try:
        listener = wbw.Listener()
        devices = await listener.get_all()
        for device in devices:
            print(f"Device: {device.name}, Status: {device.status}")
    except Exception as e:
        print(f"错误: {e}")
        print("请确保蓝牙已开启并有权限访问")

asyncio.run(main())