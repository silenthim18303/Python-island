import subprocess

class BatteryChecker:
    def check_battery(self):
        """获取电池信息
        
        Returns:
            tuple: (status, level)
                status: 电池状态
                level: 电池电量百分比
        """
        charge = ""
        status = ""

        status_map = {
            1: "放电",
            2: "接通电源",
            3: "完全充电",
            4: "低",
            5: "临界",
            6: "充电",
            7: "充电过高",
            8: "未知",
        }

        try:
            try:
                import wmi

                c = wmi.WMI()
                batteries = c.Win32_Battery()
                if batteries:
                    battery = batteries[0]
                    charge = battery.EstimatedChargeRemaining
                    status_code = battery.BatteryStatus
                    status = status_map.get(status_code, "未知")
                else:
                    # 没有电池，可能是台式机
                    status = "插电"
            except ImportError:
                result = subprocess.run(
                    [
                        "wmic",
                        "path",
                        "Win32_Battery",
                        "get",
                        "EstimatedChargeRemaining,BatteryStatus",
                    ],
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                    errors="ignore",
                    creationflags=subprocess.CREATE_NO_WINDOW,
                )
                output = result.stdout

                lines = output.strip().split("\n")[1:]
                if lines and lines[0].strip():
                    parts = lines[0].strip().split()
                    if len(parts) >= 2:
                        charge = parts[0]
                        status_code = int(parts[1])
                        status = status_map.get(status_code, "未知")
                else:
                    # 没有电池信息，可能是台式机
                    status = "插电"
        except Exception:
            # 发生异常，可能是没有电池
            status = "插电"

        return status, int(charge) if charge else None