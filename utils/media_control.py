import asyncio
from winsdk.windows.media.control import GlobalSystemMediaTransportControlsSessionManager as SessionManager
from PySide6.QtCore import QObject, Signal, QThread
import threading

class MediaMonitor(QObject):
    metadata_changed = Signal(dict)
    status_changed = Signal(bool) # Playing or not

    def __init__(self):
        super().__init__()
        self._current_session = None
        self._manager = None
        self._loop = asyncio.new_event_loop()
        self._thread = threading.Thread(target=self._run_loop, daemon=True)
        self._thread.start()
        
        # Initial fetch
        asyncio.run_coroutine_threadsafe(self.initialize_manager(), self._loop)

    def _run_loop(self):
        asyncio.set_event_loop(self._loop)
        self._loop.run_forever()

    async def initialize_manager(self):
        try:
            self._manager = await SessionManager.request_async()
            self._manager.add_current_session_changed(self._on_current_session_changed)
            self._manager.add_sessions_changed(self._on_sessions_changed)
            # Periodic check for sessions (some players don't trigger events immediately)
            asyncio.run_coroutine_threadsafe(self._periodic_check(), self._loop)
            await self.update_session()
        except Exception as e:
            print(f"SMTC Init Error: {e}")
            await asyncio.sleep(2)
            asyncio.run_coroutine_threadsafe(self.initialize_manager(), self._loop)

    def _on_sessions_changed(self, manager, args):
        asyncio.run_coroutine_threadsafe(self.update_session(), self._loop)

    async def _periodic_check(self):
        while True:
            await asyncio.sleep(5) # Check every 5 seconds
            if not self._current_session:
                await self.update_session()

    async def update_session(self):
        try:
            if not self._manager:
                return
                
            session = self._manager.get_current_session()
            
            # If get_current_session is None, try to find ANY active session
            if not session:
                sessions = self._manager.get_sessions()
                if sessions and len(sessions) > 0:
                    # Prefer a playing session
                    for s in sessions:
                        info = s.get_playback_info()
                        if info.playback_status == 4: # Playing
                            session = s
                            break
                    if not session:
                        session = sessions[0]

            if session:
                # Store session and source app
                source_app = session.source_app_user_model_id
                print(f"SMTC: Found session from {source_app}")
                
                self._current_session = session
                try:
                    session.add_media_properties_changed(self._on_metadata_changed)
                    session.add_playback_info_changed(self._on_status_changed)
                except:
                    pass # Handlers might already exist
                
                await self._fetch_metadata()
            else:
                self._current_session = None
                self.metadata_changed.emit({'title': '未在播放', 'artist': '', 'album': ''})
                self.status_changed.emit(False)
        except Exception as e:
            print(f"SMTC Update Error: {e}")

    async def _fetch_metadata(self):
        if not self._current_session:
            return
        
        try:
            # Add a small delay as some apps take a moment to update properties
            await asyncio.sleep(0.1)
            
            props = await self._current_session.try_get_media_properties_async()
            if not props:
                return
                
            title = props.title if props.title else '正在获取...'
            artist = props.artist if props.artist else '未知艺术家'
            
            # If we get placeholders, we can try once more after a short delay
            if title == '正在获取...' or not props.title:
                await asyncio.sleep(0.5)
                props = await self._current_session.try_get_media_properties_async()
                title = props.title if props.title else '正在获取...'
                artist = props.artist if props.artist else '未知艺术家'

            info = {
                'title': title,
                'artist': artist,
                'album': props.album_title if props.album_title else '',
            }
            self.metadata_changed.emit(info)
            
            playback = self._current_session.get_playback_info()
            # 4 is Playing, 5 is Paused
            self.status_changed.emit(playback.playback_status == 4)
        except Exception as e:
            print(f"Fetch metadata error: {e}")

    def _on_current_session_changed(self, manager, args):
        asyncio.run_coroutine_threadsafe(self.update_session(), self._loop)

    def _on_metadata_changed(self, session, args):
        asyncio.run_coroutine_threadsafe(self._fetch_metadata(), self._loop)

    def _on_status_changed(self, session, args):
        asyncio.run_coroutine_threadsafe(self._fetch_metadata(), self._loop)

    def play_pause(self):
        if self._current_session:
            asyncio.run_coroutine_threadsafe(self._current_session.try_toggle_play_pause_async(), self._loop)

    def next(self):
        if self._current_session:
            asyncio.run_coroutine_threadsafe(self._current_session.try_skip_next_async(), self._loop)

    def previous(self):
        if self._current_session:
            asyncio.run_coroutine_threadsafe(self._current_session.try_skip_previous_async(), self._loop)
