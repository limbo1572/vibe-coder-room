#!/usr/bin/env python3
"""Local HTTP server for Godot 4 HTML5 builds (SharedArrayBuffer / threads)."""

from __future__ import annotations

import http.server
import socketserver
from pathlib import Path

PORT = 8000
DIRECTORY = Path(__file__).resolve().parent


class GodotWebHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(DIRECTORY), **kwargs)

    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        super().end_headers()


def main() -> None:
    with socketserver.TCPServer(("", PORT), GodotWebHandler) as httpd:
        print(f"Serving {DIRECTORY}")
        print(f"Open: http://localhost:{PORT}/")
        httpd.serve_forever()


if __name__ == "__main__":
    main()
