import windows_bluetooth_watcher as wbw
import asyncio

async def main():
    listener = wbw.Listener()
    devices = await listener.get_all()
    for device in devices:
        print(f"Device: {device.name}, Status: {device.status}")

asyncio.run(main())