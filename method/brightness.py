import logging

try:
    import screen_brightness_control as sbc

    brightness_available = True
except ImportError:
    brightness_available = False
    sbc = None


class BrightnessService:
    _target = None

    @staticmethod
    def _normalize(value, default: int = 50) -> int:
        if isinstance(value, (list, tuple)):
            for item in value:
                if item is None:
                    continue
                try:
                    return max(0, min(100, int(item)))
                except (TypeError, ValueError):
                    continue
            return default
        try:
            return max(0, min(100, int(value)))
        except (TypeError, ValueError):
            return default

    @classmethod
    def _scan_targets(cls) -> list[dict]:
        if not brightness_available:
            return []
        try:
            monitors = sbc.list_monitors_info()
        except Exception:
            return [{}]
        targets = []
        for index, monitor in enumerate(monitors):
            method = monitor.get("method")
            method_name = getattr(method, "__name__", "") if method is not None else ""
            method_name = method_name.lower() if method_name else None
            score = 0 if method_name == "wmi" else 1 if method_name == "vcp" else 2
            targets.append(
                {
                    "display": monitor.get("index", index),
                    "method": method_name,
                    "score": score,
                }
            )
        targets.sort(key=lambda item: (item["score"], item["display"]))
        return targets or [{}]

    @classmethod
    def _resolve_target(cls) -> dict:
        if cls._target is not None:
            return cls._target
        targets = cls._scan_targets()
        cls._target = targets[0] if targets else {}
        return cls._target

    @classmethod
    def _build_kwargs(cls, target: dict) -> dict:
        kwargs = {"verbose_error": True}
        if target.get("display") is not None:
            kwargs["display"] = target["display"]
        if target.get("method"):
            kwargs["method"] = target["method"]
        return kwargs

    @classmethod
    def get_brightness(cls) -> int:
        if not brightness_available:
            return 50
        target = cls._resolve_target()
        try:
            return cls._normalize(sbc.get_brightness(**cls._build_kwargs(target)))
        except Exception as exc:
            logging.warning("brightness: read with target failed %s", exc)
        for target in cls._scan_targets():
            try:
                cls._target = target
                return cls._normalize(sbc.get_brightness(**cls._build_kwargs(target)))
            except Exception as exc:
                logging.warning("brightness: read fallback failed %s", exc)
        try:
            return cls._normalize(sbc.get_brightness(verbose_error=True))
        except Exception as exc:
            logging.warning("brightness: read global failed %s", exc)
            return 50

    @classmethod
    def set_brightness(cls, value: int) -> bool:
        if not brightness_available:
            return False
        normalized_value = cls._normalize(value)
        target = cls._resolve_target()
        try:
            sbc.set_brightness(
                normalized_value,
                no_return=False,
                **cls._build_kwargs(target),
            )
            return True
        except Exception as exc:
            logging.warning("brightness: set with target failed %s", exc)
        for target in cls._scan_targets():
            try:
                sbc.set_brightness(
                    normalized_value,
                    no_return=False,
                    **cls._build_kwargs(target),
                )
                cls._target = target
                return True
            except Exception as exc:
                logging.warning("brightness: set fallback failed %s", exc)
        try:
            sbc.set_brightness(normalized_value, verbose_error=True, no_return=False)
            return True
        except Exception as exc:
            logging.warning("brightness: set global failed %s", exc)
            return False

    @staticmethod
    def is_available() -> bool:
        return brightness_available
