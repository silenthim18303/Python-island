import sys

from PySide6.QtWidgets import QApplication

from app.window import CapsuleWindow


def main():
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)
    window = CapsuleWindow()

    screen = app.primaryScreen().availableGeometry()
    window.move(screen.width() - window.width() - 32, 36)
    window.show()
    window._notify_frontend_state()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()