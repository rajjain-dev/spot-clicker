#!/usr/bin/env python3
"""Send one command to the USB-connected clicker using macOS serial support."""

import argparse
import fcntl
import glob
import os
import select
import struct
import sys
import termios
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["1", "2", "3", "h", "s", "l", "m", "x", "?"],
                        help="1=Liked, 2=Want to go, 3/h=undo, s=status, l=blue LED test, m=motor test, x=stop, ?=help")
    parser.add_argument("--port", help="USB serial device; auto-detected when exactly one is present")
    parser.add_argument("--wait", type=float,
                        help="Seconds to collect replies (default 12 for motor test, 2 otherwise; use 16 for phone feedback)")
    args = parser.parse_args()
    if args.wait is None:
        args.wait = 12 if args.command == "m" else 2
    if not 0.1 <= args.wait <= 30:
        parser.error("--wait must be between 0.1 and 30 seconds")
    ports = sorted(glob.glob("/dev/cu.usbmodem*"))
    port = args.port
    if not port:
        if len(ports) != 1:
            parser.error("Connect one XIAO by USB or select its device with --port")
        port = ports[0]

    fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    try:
        # Prevent another process from opening this connection during the command.
        fcntl.ioctl(fd, termios.TIOCEXCL)
        attrs = termios.tcgetattr(fd)
        attrs[0] = attrs[1] = attrs[3] = 0
        attrs[2] = termios.CLOCAL | termios.CREAD | termios.CS8
        attrs[4] = attrs[5] = termios.B115200
        attrs[6][termios.VMIN] = 0
        attrs[6][termios.VTIME] = 0
        termios.tcsetattr(fd, termios.TCSANOW, attrs)
        fcntl.ioctl(fd, termios.TIOCMBIS, struct.pack("I", termios.TIOCM_DTR))

        # Let the USB CDC session become ready; this is not a 1200-baud reset.
        time.sleep(0.25)
        os.write(fd, (args.command + "\n").encode("ascii"))
        deadline = time.monotonic() + args.wait
        while time.monotonic() < deadline:
            timeout = max(0.0, min(0.2, deadline - time.monotonic()))
            readable, _, _ = select.select([fd], [], [], timeout)
            if readable:
                try:
                    data = os.read(fd, 4096)
                except BlockingIOError:
                    continue
                if data:
                    sys.stdout.write(data.decode("utf-8", errors="replace"))
                    sys.stdout.flush()
    finally:
        try:
            # Deassert DTR so a live motor test also stops on helper cancellation.
            fcntl.ioctl(fd, termios.TIOCMBIC, struct.pack("I", termios.TIOCM_DTR))
        finally:
            try:
                fcntl.ioctl(fd, termios.TIOCNXCL)
            finally:
                os.close(fd)


if __name__ == "__main__":
    try:
        main()
    except (OSError, termios.error) as error:
        sys.exit(f"USB connection failed: {error}. Close any Arduino Serial Monitor and retry.")
