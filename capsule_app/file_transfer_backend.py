import base64
import binascii
import json
import mimetypes
import os
import shutil
import subprocess
from pathlib import Path

from PySide6.QtCore import QObject, QMimeData, QUrl, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtWidgets import QFileDialog


PROJECT_ROOT = Path(__file__).resolve().parent.parent
TRANSFER_DIR = PROJECT_ROOT / "pyisland_fileTransfer"
MAX_SINGLE_FILE_SIZE = 50 * 1024 * 1024
MAX_SINGLE_FILE_SIZE_LABEL = "50 MB"


class FileTransferBackend(QObject):
    """文件中转后端，负责将文件落到本地中转目录。"""

    def __init__(self, parent=None):
        super().__init__(parent)
        self._dialog_parent = parent
        TRANSFER_DIR.mkdir(parents=True, exist_ok=True)

    @Slot(result=str)
    def listFiles(self):
        return json.dumps(self._list_files(), ensure_ascii=False)

    @Slot(result=str)
    def selectFiles(self):
        file_paths, _ = QFileDialog.getOpenFileNames(
            self._dialog_parent,
            "选择要中转的文件",
            str(PROJECT_ROOT),
            "所有文件 (*.*)",
        )
        if not file_paths:
            return json.dumps({"files": [], "errors": []}, ensure_ascii=False)
        imported, errors = self._import_paths([Path(file_path) for file_path in file_paths], enforce_size_limit=True)
        return json.dumps({"files": imported, "errors": errors}, ensure_ascii=False)

    @Slot(str, result=str)
    def importPaths(self, payload):
        try:
            raw_paths = json.loads(payload)
        except (ValueError, TypeError):
            return json.dumps({"files": [], "errors": ["无效的路径参数"]}, ensure_ascii=False)

        if not isinstance(raw_paths, list):
            return json.dumps({"files": [], "errors": ["无效的路径参数"]}, ensure_ascii=False)

        file_paths = [Path(str(file_path)) for file_path in raw_paths if isinstance(file_path, str) and file_path]
        imported, errors = self._import_paths(file_paths, enforce_size_limit=True)
        return json.dumps({"files": imported, "errors": errors}, ensure_ascii=False)

    @Slot(str, result=str)
    def uploadFile(self, payload):
        try:
            data = json.loads(payload)
            if not isinstance(data, dict):
                return json.dumps({"ok": False, "error": "无效的上传参数"}, ensure_ascii=False)

            file_name = Path(str(data.get("name", ""))).name
            if not file_name:
                return json.dumps({"ok": False, "error": "文件名无效"}, ensure_ascii=False)

            if str(data.get("kind", "file")) != "file":
                return json.dumps({"ok": False, "error": "不支持上传文件夹"}, ensure_ascii=False)

            data_url = str(data.get("dataUrl", ""))
            raw_base64 = data_url.split(",", 1)[1] if "," in data_url else data_url
            file_bytes = base64.b64decode(raw_base64, validate=True)
            file_size = len(file_bytes)
            if file_size > MAX_SINGLE_FILE_SIZE:
                return json.dumps(
                    {"ok": False, "error": f"单个文件不能超过 {MAX_SINGLE_FILE_SIZE_LABEL}"},
                    ensure_ascii=False,
                )

            target_path = self._allocate_target_path(file_name)
            target_path.write_bytes(file_bytes)

            mime_type = str(data.get("type", "")) or mimetypes.guess_type(target_path.name)[0] or ""
            entry = self._entry_from_path(target_path, mime_type=mime_type)
            return json.dumps({"ok": True, "file": entry}, ensure_ascii=False)
        except (ValueError, TypeError, binascii.Error):
            return json.dumps({"ok": False, "error": "文件解析失败"}, ensure_ascii=False)

    @Slot(str, result=str)
    def removeFile(self, stored_name):
        target_path = TRANSFER_DIR / Path(stored_name).name
        if not target_path.exists() or not target_path.is_file():
            return json.dumps({"ok": False, "error": "文件不存在"}, ensure_ascii=False)
        try:
            target_path.unlink()
            return json.dumps({"ok": True}, ensure_ascii=False)
        except PermissionError:
            return json.dumps(
                {"ok": False, "error": "文件正在被其他程序占用，无法删除"},
                ensure_ascii=False,
            )
        except OSError:
            return json.dumps({"ok": False, "error": "删除文件失败"}, ensure_ascii=False)

    @Slot(result=str)
    def clearFiles(self):
        errors = []
        for file_path in TRANSFER_DIR.iterdir():
            if not file_path.is_file():
                continue
            try:
                file_path.unlink()
            except PermissionError:
                errors.append(f"{file_path.name}: 文件正在被其他程序占用，无法删除")
            except OSError:
                errors.append(f"{file_path.name}: 删除失败")
        return json.dumps({"ok": len(errors) == 0, "errors": errors}, ensure_ascii=False)

    @Slot(result=str)
    def transferDirectory(self):
        return str(TRANSFER_DIR)

    @Slot(result=int)
    def maxFileSizeBytes(self):
        return MAX_SINGLE_FILE_SIZE

    @Slot(result=bool)
    def openTransferDirectory(self):
        try:
            os.startfile(str(TRANSFER_DIR))
            return True
        except Exception:
            try:
                subprocess.Popen(["explorer", str(TRANSFER_DIR)])
                return True
            except Exception:
                return False

    @Slot(str, result=bool)
    def openFileLocation(self, stored_name):
        target_path = TRANSFER_DIR / Path(stored_name).name
        if not target_path.exists():
            return False
        try:
            subprocess.Popen(["explorer", "/select,", str(target_path)])
            return True
        except Exception:
            return False

    @Slot(str, result=str)
    def copyFileToClipboard(self, stored_name):
        target_path = TRANSFER_DIR / Path(stored_name).name
        if not target_path.exists() or not target_path.is_file():
            return json.dumps({"ok": False, "error": "文件不存在"}, ensure_ascii=False)

        clipboard = QGuiApplication.clipboard()
        if clipboard is None:
            return json.dumps({"ok": False, "error": "无法访问系统剪贴板"}, ensure_ascii=False)

        mime_data = QMimeData()
        mime_data.setUrls([QUrl.fromLocalFile(str(target_path.resolve()))])
        clipboard.setMimeData(mime_data)
        return json.dumps({"ok": True}, ensure_ascii=False)

    def _list_files(self):
        entries = []
        for file_path in sorted(TRANSFER_DIR.iterdir(), key=lambda item: item.stat().st_mtime, reverse=True):
            if file_path.is_file():
                entries.append(self._entry_from_path(file_path))
        return entries

    def _import_paths(self, file_paths, enforce_size_limit=True):
        imported = []
        errors = []
        for source_path in file_paths:
            if not source_path.exists():
                continue
            if not source_path.is_file():
                errors.append(f"{source_path.name or source_path}: 不支持文件夹")
                continue
            try:
                file_size = source_path.stat().st_size
            except OSError:
                errors.append(f"{source_path.name}: 无法读取文件大小")
                continue
            if enforce_size_limit and file_size > MAX_SINGLE_FILE_SIZE:
                errors.append(f"{source_path.name}: 单个文件不能超过 {MAX_SINGLE_FILE_SIZE_LABEL}")
                continue
            try:
                target_path = self._allocate_target_path(source_path.name)
                shutil.copy2(source_path, target_path)
                imported.append(self._entry_from_path(target_path))
            except PermissionError:
                errors.append(f"{source_path.name}: 文件正在被其他程序占用，无法复制")
            except OSError:
                errors.append(f"{source_path.name}: 复制失败")
        return imported, errors

    def _allocate_target_path(self, file_name):
        safe_name = Path(file_name).name or "unnamed"
        candidate = TRANSFER_DIR / safe_name
        if not candidate.exists():
            return candidate

        stem = candidate.stem
        suffix = candidate.suffix
        index = 1
        while True:
            candidate = TRANSFER_DIR / f"{stem}_{index}{suffix}"
            if not candidate.exists():
                return candidate
            index += 1

    def _entry_from_path(self, file_path, mime_type=""):
        stat = file_path.stat()
        return {
            "id": file_path.name,
            "name": file_path.name,
            "size": stat.st_size,
            "type": mime_type or mimetypes.guess_type(file_path.name)[0] or "",
            "addedAt": int(stat.st_mtime * 1000),
            "status": "ready",
        }
