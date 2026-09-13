#!/usr/bin/env python
"""Integration test for cl-matplotlib-show-web.

Starts the demo server (tools/show-web-demo.lisp) on a fixed port,
speaks real HTTP + websocket to it, and asserts the multi-figure
contract: one page at / (and /figure/<id>), one multiplexed socket at
/ws that first sends a "windows" tab list and then one id-prefixed PNG
frame per window; events carry "fig"; wheel produces a different frame,
home restores the first frame byte-for-byte (render determinism is
proven in the show-core FiveAM suite); a "new" event adds a tab; a
"close" event on the blocking figure unblocks (show :block t).

Run:  .venv/bin/python tests/integration/test_show_web.py
Needs: pip install websocket-client (into .venv)
"""

import json
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
            urllib.request.urlopen(f"{BASE}/", timeout=2)
            return True
        except Exception:
            time.sleep(0.5)
    return False


class Client:
    """A websocket with a message buffer, so a frame that arrives while we
    wait for a text message (or vice versa) is kept, not dropped."""

    def __init__(self, url):
        self.ws = websocket.WebSocket()
        self.ws.connect(url)
        self.pending = []  # (opcode, bytes)

    def send(self, **obj):
        self.ws.send(json.dumps(obj))

    def close(self):
        self.ws.close()

    def _next(self, pred, timeout):
        for i, msg in enumerate(self.pending):
            if pred(msg):
                return self.pending.pop(i)
        self.ws.settimeout(timeout)
        deadline = time.time() + timeout
        while time.time() < deadline:
            opcode, data = self.ws.recv_data()
            msg = (opcode, bytes(data))
            if pred(msg):
                return msg
            self.pending.append(msg)
        raise TimeoutError("no matching message received")

    def recv_control(self, opcode, timeout=30):
        """Wait for a control frame (e.g. a ping) with OPCODE, buffering
        any data frames that arrive meanwhile. websocket-client answers a
        ping with a pong by itself."""
        self.ws.settimeout(timeout)
        deadline = time.time() + timeout
        while time.time() < deadline:
            op, frame = self.ws.recv_data(control_frame=True)
            if op == opcode:
                return True
            if op in (websocket.ABNF.OPCODE_TEXT, websocket.ABNF.OPCODE_BINARY):
                self.pending.append((op, bytes(frame)))
        return False

    def idle(self, seconds):
        """Stay quiet for SECONDS while still reading, so pings get their
        pong (a browser does this in its network stack). Data frames that
        arrive are buffered."""
        deadline = time.time() + seconds
        while time.time() < deadline:
            self.ws.settimeout(max(0.1, min(1.0, deadline - time.time())))
            try:
                op, frame = self.ws.recv_data(control_frame=True)
            except websocket.WebSocketTimeoutException:
                continue
            if op in (websocket.ABNF.OPCODE_TEXT, websocket.ABNF.OPCODE_BINARY):
                self.pending.append((op, bytes(frame)))

    def recv_frame(self, fig=None, timeout=30):
        """Next binary frame as (id, png); with FIG, the next one for that window."""
        def pred(msg):
            return (msg[0] == websocket.ABNF.OPCODE_BINARY
                    and (fig is None or int.from_bytes(msg[1][:4], "big") == fig))
        _, data = self._next(pred, timeout)
        return int.from_bytes(data[:4], "big"), data[4:]

    def recv_text(self, kind=None, match=None, timeout=30):
        """Next text message parsed as JSON; with KIND, the next of that
        type; with MATCH, the next one for which MATCH(msg) holds."""
        def pred(msg):
            if msg[0] != websocket.ABNF.OPCODE_TEXT:
                return False
            m = json.loads(msg[1].decode())
            return (kind is None or m.get("type") == kind) and (match is None or match(m))
        _, data = self._next(pred, timeout)
        return json.loads(data.decode())


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

        page = urllib.request.urlopen(f"{BASE}/", timeout=5)
        body = page.read().decode()
        check("GET / is 200", page.status == 200)
        check("page is the client html", "app.js" in body)
        page2 = urllib.request.urlopen(f"{BASE}/figure/2", timeout=5)
        check("GET /figure/<id> serves the same page", page2.status == 200 and "app.js" in page2.read().decode())

        js = urllib.request.urlopen(f"{BASE}/app.js", timeout=5)
        check("GET /app.js is 200", js.status == 200)

        try:
            urllib.request.urlopen(f"{BASE}/nope", timeout=5)
            check("unknown path is 404", False)
        except urllib.error.HTTPError as e:
            check("unknown path is 404", e.code == 404)

        ws = Client(f"ws://127.0.0.1:{PORT}/ws")

        # the tab list comes first: both demo figures, the second active
        windows = ws.recv_text("windows")
        ids = [w["id"] for w in windows["items"]]
        check("windows message lists two tabs", len(ids) == 2, json.dumps(windows))
        check("second figure is active", windows.get("active") == ids[-1], json.dumps(windows))
        check("tabs have titles", all(w.get("title") for w in windows["items"]), json.dumps(windows))
        fig1, fig2 = ids

        # then one frame per window, routed by id
        frames = {}
        for _ in range(2):
            wid, png = ws.recv_frame()
            frames[wid] = png
        check("a frame arrives for each window", set(frames) == {fig1, fig2}, str(sorted(frames)))
        first = frames.get(fig1, b"")
        check("frames are PNGs", all(p[:8] == PNG_MAGIC for p in frames.values()))
        check("frames differ between windows", frames.get(fig1) != frames.get(fig2))
        check("first frame is plausibly sized", 1000 < len(first) < 500_000, str(len(first)))

        # zoom in at figure 1's center → a new frame for figure 1 only
        ws.send(type="wheel", fig=fig1, x=320, y=240, deltaY=-100)
        wid, zoomed = ws.recv_frame()
        check("wheel produces a new frame for its window", wid == fig1 and zoomed != first)

        # pan while dragging → another frame
        ws.send(type="mousedown", fig=fig1, x=320, y=240)
        ws.send(type="mousemove", fig=fig1, x=360, y=240)
        wid, panned = ws.recv_frame(fig1)
        ws.send(type="mouseup", fig=fig1)
        check("drag pan produces a new frame", panned != zoomed)

        # hover (no drag) → coords message tagged with the window
        ws.send(type="mousemove", fig=fig1, x=320, y=240)
        coords = ws.recv_text("coords")
        check("hover sends coords with fig", coords.get("fig") == fig1 and "x" in coords, json.dumps(coords))

        # home → byte-identical to the first frame
        ws.send(type="home", fig=fig1)
        wid, home = ws.recv_frame(fig1)
        check("home restores the first frame exactly", home == first,
              f"{len(home)} vs {len(first)} bytes")

        # interaction on a non-active tab: click the y=0 line of figure 1
        # (its pixel row is known from the default 640x480 layout) → the
        # selection highlight changes the frame; Delete removes it; ctrl-z
        # restores it and the frame is the home frame again, byte for byte.
        ws.send(type="click", fig=fig1, x=320, y=243)
        wid, selected = ws.recv_frame(fig1)
        check("click selects a trace (highlight frame)", selected != home)
        ws.send(type="keydown", fig=fig1, key="c", ctrl=True)
        ws.send(type="keydown", fig=fig1, key="Delete")
        wid, deleted = ws.recv_frame(fig1)
        check("Delete removes the trace", deleted != selected and deleted != home)
        ws.send(type="keydown", fig=fig1, key="z", ctrl=True)
        wid, restored = ws.recv_frame(fig1)
        check("undo restores the home frame exactly", restored == home,
              f"{len(restored)} vs {len(home)} bytes")

        # paste the copied trace into figure 2 → figure 2's frame changes
        ws.send(type="keydown", fig=fig2, key="v", ctrl=True)
        wid, pasted = ws.recv_frame(fig2)
        check("paste across figures changes the other window", pasted != frames[fig2])

        # activating a tab makes it the active window
        ws.send(type="activate", fig=fig1)
        windows = ws.recv_text("windows", lambda m: m.get("active") == fig1)
        check("activate updates the tab list", windows.get("active") == fig1, json.dumps(windows))

        # a new figure from the page → a third tab plus its frame
        ws.send(type="new")
        windows = ws.recv_text("windows", lambda m: len(m["items"]) == 3 and m.get("active") == m["items"][-1]["id"])
        new_ids = [w["id"] for w in windows["items"]]
        check("new adds a tab and activates it", new_ids[:2] == [fig1, fig2], json.dumps(windows))
        fig3 = new_ids[-1]
        wid, png3 = ws.recv_frame(fig3)
        check("new tab gets a frame", png3[:8] == PNG_MAGIC)

        # closing a tab removes it and activates the most recent remaining one
        ws.send(type="close", fig=fig3)
        windows = ws.recv_text("windows", lambda m: len(m["items"]) == 2 and m.get("active") != fig3)
        check("close removes the tab and activates the last remaining one",
              [w["id"] for w in windows["items"]] == [fig1, fig2] and windows.get("active") == fig2,
              json.dumps(windows))

        # keepalive: an idle page (background tab) must outlive hunchentoot's
        # 20 s connection timeout (websocket-driver retries once, so a silent
        # socket dies after ~40 s) — the server pings, the client pongs
        check("server pings within 15 s", ws.recv_control(websocket.ABNF.OPCODE_PING, timeout=15))
        print("  ...  idling 45 s to check the keepalive")
        ws.idle(45)
        ws.send(type="home", fig=fig1)
        try:
            wid, again = ws.recv_frame(fig1)
            check("socket survives 45 s idle", again == home)
        except Exception as e:  # noqa: BLE001
            check("socket survives 45 s idle", False, repr(e))

        # cursor mode: the coords message carries the mode
        ws.send(type="keydown", fig=fig1, key="c")
        coords = ws.recv_text("coords")
        check("cursor mode is reported", coords.get("mode") == "cursor", json.dumps(coords))

        # closing the blocking figure's tab unblocks (show :block t) → server exits
        ws.send(type="close", fig=fig2)
        try:
            server.wait(timeout=60)
            check("closing the tab unblocks show :block", server.returncode == 0,
                  str(server.returncode))
        except subprocess.TimeoutExpired:
            check("closing the tab unblocks show :block", False, "server still running")
        ws.close()
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
