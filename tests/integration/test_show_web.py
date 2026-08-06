#!/usr/bin/env python
"""Integration test for cl-matplotlib-show-web.

Starts the demo server (tools/show-web-demo.lisp) on a fixed port,
speaks real HTTP + websocket to it, and asserts the WebAgg-style
contract: page serves, first binary frame is a PNG, wheel produces a
different frame, home restores the first frame byte-for-byte
(render determinism is proven in the show-core FiveAM suite), and
closing the socket unblocks the server's (show :block t).

Run:  .venv/bin/python tests/integration/test_show_web.py
Needs: pip install websocket-client (into .venv)
"""

import os
import subprocess
import sys
import time
import urllib.request

import websocket  # websocket-client

PORT = int(os.environ.get("SHOW_WEB_PORT", "8977"))
BASE = f"http://127.0.0.1:{PORT}"
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"

failures = []


def check(name, ok, detail=""):
    print(f"  {'ok' if ok else 'FAIL'}  {name}" + (f"  ({detail})" if detail and not ok else ""))
    if not ok:
        failures.append(name)


def wait_for_server(timeout=120):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            urllib.request.urlopen(f"{BASE}/figure/1", timeout=2)
            return True
        except Exception:
            time.sleep(0.5)
    return False


def recv_binary(ws, timeout=30):
    """Next binary message, skipping text (coords) messages."""
    ws.settimeout(timeout)
    deadline = time.time() + timeout
    while time.time() < deadline:
        opcode, data = ws.recv_data()
        if opcode == websocket.ABNF.OPCODE_BINARY:
            return bytes(data)
    raise TimeoutError("no binary frame received")


def main():
    env = dict(os.environ, SHOW_WEB_PORT=str(PORT), SHOW_WEB_NO_BROWSER="1")
    server = subprocess.Popen(
        ["ros", "run", "--", "--load", "tools/show-web-demo.lisp"],
        cwd=REPO, env=env,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    try:
        print("waiting for server ...")
        check("server comes up", wait_for_server())
        if failures:
            return

        page = urllib.request.urlopen(f"{BASE}/figure/1", timeout=5)
        body = page.read().decode()
        check("GET /figure/1 is 200", page.status == 200)
        check("page is the client html", "app.js" in body)

        js = urllib.request.urlopen(f"{BASE}/app.js", timeout=5)
        check("GET /app.js is 200", js.status == 200)

        try:
            urllib.request.urlopen(f"{BASE}/ws?fig=999", timeout=5)
            check("unknown figure id is 404", False)
        except urllib.error.HTTPError as e:
            check("unknown figure id is 404", e.code == 404)

        ws = websocket.WebSocket()
        ws.connect(f"ws://127.0.0.1:{PORT}/ws?fig=1")

        first = recv_binary(ws)
        check("first frame is a PNG", first[:8] == PNG_MAGIC, first[:8].hex())
        check("first frame is plausibly sized", 1000 < len(first) < 500_000, str(len(first)))

        # zoom in at the figure center → new, different frame
        ws.send('{"type":"wheel","x":320,"y":240,"deltaY":-100}')
        zoomed = recv_binary(ws)
        check("wheel produces a new frame", zoomed != first)

        # pan while dragging → another frame
        ws.send('{"type":"mousedown","x":320,"y":240}')
        ws.send('{"type":"mousemove","x":360,"y":240}')
        panned = recv_binary(ws)
        ws.send('{"type":"mouseup"}')
        check("drag pan produces a new frame", panned != zoomed)

        # hover (no drag) → text coords message
        ws.send('{"type":"mousemove","x":320,"y":240}')
        ws.settimeout(30)
        opcode, data = ws.recv_data()
        while opcode == websocket.ABNF.OPCODE_BINARY:
            opcode, data = ws.recv_data()
        text = bytes(data).decode()
        check("hover sends coords", '"type":"coords"' in text and '"x":' in text, text)

        # home → byte-identical to the first frame
        ws.send('{"type":"home"}')
        home = recv_binary(ws)
        check("home restores the first frame exactly", home == first,
              f"{len(home)} vs {len(first)} bytes")

        # closing the last socket unblocks (show :block t) → server exits
        ws.close()
        try:
            server.wait(timeout=60)
            check("closing the page unblocks show :block", server.returncode == 0,
                  str(server.returncode))
        except subprocess.TimeoutExpired:
            check("closing the page unblocks show :block", False, "server still running")
    finally:
        if server.poll() is None:
            server.kill()
        out = server.stdout.read().decode(errors="replace")
        if failures:
            print("---- server output ----")
            print(out[-4000:])

    print()
    if failures:
        print(f"FAILED: {len(failures)} check(s): {', '.join(failures)}")
        sys.exit(1)
    print("all checks passed")


if __name__ == "__main__":
    main()
