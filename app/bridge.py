from PySide6.QtCore import QObject, Slot


class CapsuleBridge(QObject):
    def __init__(self, window):
        super().__init__()
        self.window = window

    @Slot()
    def toggleExpand(self):
        self.window.toggle_expand()

    @Slot(int, int)
    def dragStart(self, screen_x, screen_y):
        self.window.drag_start(screen_x, screen_y)

    @Slot(int, int)
    def dragMove(self, screen_x, screen_y):
        self.window.drag_move(screen_x, screen_y)

    @Slot()
    def dragEnd(self):
        self.window.drag_end()

    @Slot(result=str)
    def loadTodos(self):
        return self.window.load_todos_json()

    @Slot(str)
    def saveTodos(self, payload):
        self.window.save_todos_json(payload)

    @Slot()
    def clearTodos(self):
        self.window.clear_todos()

    @Slot(str)
    def openImageSource(self, source):
        self.window.open_image_source(source)

    @Slot(str)
    def openFileLocation(self, file_path):
        self.window.open_file_location(file_path)

    @Slot(result=str)
    def startVoiceInput(self):
        return self.window.start_voice_input()

    @Slot()
    def stopVoiceInput(self):
        self.window.stop_voice_input()
