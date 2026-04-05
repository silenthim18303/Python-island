import windows_bluetooth_watcher as wbw
import asyncio

async def get_bluetooth_devices():
    """获取蓝牙设备信息
    
    Returns:
        list: 蓝牙设备列表，每个设备包含name和status属性
    """
    try:
        listener = wbw.Listener()
        devices = await listener.get_all()
        # 只返回Status等于Connected的设备
        connected_devices = [device for device in devices if hasattr(device, 'status') and str(device.status).lower() == 'connected']
        return connected_devices
    except Exception as e:
        print(f"错误: {e}")
        print("请确保蓝牙已开启并有权限访问")
        return []

async def main():
    """主函数，用于测试"""
    devices = await get_bluetooth_devices()
    for device in devices:
        print(f"Device: {device.name}, Status: {device.status}")

if __name__ == "__main__":
    asyncio.run(main())