"""Minimal NTCONTROL client: one TCP connection per command, like the app.

Edit HOST for your projector. The login comes from the environment
(PGRID_LOGIN, PGRID_PASSWORD) so it never lands in the repo; a projector that
isn't in protected mode needs neither.

    python ntc.py QID QVX:GMMI0     # send commands, print the replies
"""
import hashlib
import os
import re
import socket
import sys

HOST, PORT = "192.168.0.8", 1024
LOGIN = os.environ.get("PGRID_LOGIN", "")
PASSWORD = os.environ.get("PGRID_PASSWORD", "")


def _recv_line(sock):
    buf = b""
    while not buf.endswith(b"\r"):
        chunk = sock.recv(1024)
        if not chunk:
            break
        buf += chunk
    return buf.decode("ascii", "replace").strip()


def send(cmd, timeout=5.0):
    with socket.create_connection((HOST, PORT), timeout=timeout) as s:
        hello = _recv_line(s)
        prefix = "00"
        m = re.match(r"NTCONTROL 1 ([0-9a-fA-F]{8})", hello)
        if m:
            digest = hashlib.md5(f"{LOGIN}:{PASSWORD}:{m.group(1)}".encode()).hexdigest()
            prefix = digest + "00"
        s.sendall(f"{prefix}{cmd}\r".encode("ascii"))
        reply = _recv_line(s)
    return reply[2:] if reply.startswith("00") else reply


def qvx(key):
    r = send(f"QVX:{key}")
    return r.split("=", 1)[1] if "=" in r else r


# Value formats of the geometry registers (geometry_values.dart in the app).
def fmt_int(v):
    return f"{'+' if v >= 0 else '-'}{abs(int(v)):05d}"


def fmt_deg(v):
    v = round(v, 1)
    return f"{'+' if v >= 0 else '-'}{abs(v):.1f}"


def fmt_throw(v):
    return "+" + f"{round(v, 1):.1f}".rjust(4, "0")


if __name__ == "__main__":
    for c in sys.argv[1:]:
        print(c, "->", send(c))
