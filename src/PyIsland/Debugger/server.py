# Home: https://github.com/starwindv/PyIsland.git
# Author: StarWindv
# License: GPL-3.0
# All rights reserved

from PyQt5.QtCore import QThread
from flask import Flask, request, jsonify
from waitress import serve as wr_server
from rich import print as rprint
import asyncio

from ..EventBus.Bus import EventManager
from ..EventBus.EventDefine import EventCode


class _API(QThread):
    """
    Decouple the routing definition and the startup logic
    """
    def __init__(self):
        super().__init__()
        self.server = Flask("__PyIsland_Debug_Server__")
        self.bus = EventManager()

    def suicide(self):
        self.bus.publish(EventCode.SUICIDE)
        return jsonify("SUCCESS")

    def publish(self):
        data = request.get_json()
        try:
            name = data["event"]
            if not name: raise KeyError()
            self.bus.publish(EventCode.__getitem__(name))
            return jsonify("SUCCESS")
        except KeyError:
            return jsonify("Param: { event }\nMethod: POST")

    @staticmethod
    def _align_dict(
            data: dict,
            hex_color: str,
            prefix: str,
            last_line_prefix: str = None
    )->str:
        last_line_prefix = prefix if not last_line_prefix else last_line_prefix
        maximum = max((len(key) for key in data), default=0)
        result = []
        if not data:
            data ={
                "[NO DATA]": "[NO DATA]"
            }
        for idx, (name, content) in enumerate(data.items()):
            if idx == len(data) - 1 :
                result.append(f" {last_line_prefix} [bold {hex_color}]{name:<{maximum}}[/]: {content}")
            else:
                result.append(f" {prefix} [bold {hex_color}]{name:<{maximum}}[/]: {content}")
        return "\n".join(result)

    def before(self):
        rprint("\n[bold underline #ffffff][DEBUG][/] HEADERS")
        info  = {
            line.split(": ")[0]: line.split(": ")[-1]
            for line in request.headers
                .__str__()
                .strip()
                .split("\r\n")
        }
        rprint(self._align_dict(info, "#FFEB3B", "|"))
        rprint("[bold underline #ffffff][DEBUG][/] QUERY ARGS")
        rprint(
            self._align_dict(
                request.args,
                "#81C784",
                "|"
            )
        )
        rprint("[bold underline #ffffff][DEBUG][/] POST ARGS")
        rprint(
            self._align_dict(
                request.form.to_dict(),
                "#00BFFF",
                "|",
                last_line_prefix="+"
            )
        )


class Debugger(_API):
    def __init__(self):
        super().__init__()
        self.loop = asyncio.new_event_loop()
        self.register_hooks()
        self.register_routes()

    def register_hooks(self):
        self.server.before_request(self.before)

    def register_routes(self):
        self.server.add_url_rule(
            "/api/suicide",
            view_func=self.suicide,
            methods=["GET", "POST"]
        )
        self.server.add_url_rule(
            "/api/event",
            view_func=self.publish,
            methods=["POST"]
        )

    async def run_server(self):
        host = "127.0.0.1"
        port = 65534
        rprint("[bold underline #ffffff][DEBUG][/] Debug Server Start")
        rprint(f" | Host: {host}")
        rprint(f" + Port: {port}")
        wr_server(
            self.server,
            host = host,
            port = port,
            threads = 2
        )

    def run(self):
        """
        Puzzling Action!
        If I don't start an event loop and put the server into the loop
        then there will definitely be triggered QObject errors and QTimer errors
        There are some writing methods that can cause errors:
         - only thread.Thread
         - only extend QThread
         - only thread + asyncio
        we must create a new loop.
        """
        asyncio.set_event_loop(self.loop)
        self.loop.create_task(self.run_server())
        self.loop.run_forever()
