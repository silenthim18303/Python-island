"""后台工作线程模块

提供后台执行耗时操作的工作线程，避免阻塞主UI线程。
"""

from PySide6.QtCore import QThread, Signal


class WorkerThread(QThread):
    """后台工作线程，用于执行耗时操作。

    在后台线程中执行指定的任务函数，执行完成后通过信号返回结果或错误信息。

    Signals:
        finished_signal: 任务完成信号，携带执行结果
        error_signal: 任务错误信号，携带错误信息

    Example:
        def long_running_task(param):
            # 耗时操作
            return result

        thread = WorkerThread(long_running_task, param)
        thread.finished_signal.connect(self.on_task_finished)
        thread.error_signal.connect(self.on_task_error)
        thread.start()
    """

    finished_signal = Signal(object)
    error_signal = Signal(str)

    def __init__(self, task_func, *args, **kwargs):
        """初始化工作线程。

        Args:
            task_func: 要执行的任务函数
            *args: 任务函数的位置参数
            **kwargs: 任务函数的关键字参数
        """
        super().__init__()
        self.task_func = task_func
        self.args = args
        self.kwargs = kwargs

    def run(self):
        """执行任务函数。"""
        try:
            result = self.task_func(*self.args, **self.kwargs)
            self.finished_signal.emit(result)
        except Exception as e:
            self.error_signal.emit(str(e))
