#!/usr/bin/env python3
"""Talk to the USB-connected clicker using macOS serial support.

One command:   python3 scripts/clicker-usb.py s
               python3 scripts/clicker-usb.py pulse 200 3 150
Live control:  python3 scripts/clicker-usb.py console

Commands: 1=Liked, 2=Want to go, 3/h=undo, s=status, l=blue LED test, ?=help
Motor:    on | on 2000 | off (or x) | pulse 200 | pulse 200 3 150 |
          pattern 100 50 100 400 x3 | power 60 | play liked|want|error|undone |
          auto on|off | m (10 s buzz)
"""

import argparse
import fcntl
import glob
import os
import select
import struct
import sys
import termios
import time

FIRST_WORDS = {"1", "2", "3", "h", "s", "l", "m", "x", "?", "status", "help",
               "on", "off", "stop", "pulse", "pattern", "power", "play", "auto"}
MOTOR_RUNS = {"m", "on", "pulse", "pattern", "play"}
FINISHED = ("MOTOR done", "MOTOR off", "MOTOR ERROR", "Unknown USB command", "REJECTED")


def number(text):
    try:
        return int(text)
    except ValueError:
        return 0


def estimate_seconds(words):
    """Rough run time of a motor command, so the helper waits long enough."""
    if not words:
        return 0.0
    first, args = words[0].lower(), words[1:]
    if first == "m":
        return 10.0
    if first == "on":
        return number(args[0]) / 1000 if args else 0.0
    if first == "pulse" and args:
        ms = number(args[0])
        count = number(args[1]) if len(args) > 1 else 1
        gap = number(args[2]) if len(args) > 2 else ms
        return (count * ms + max(count - 1, 0) * gap) / 1000
    if first == "pattern" and args:
        repeats = 1
        if args[-1][:1] in ("x", "*"):
            repeats, args = max(number(args[-1][1:]), 1), args[:-1]
        steps = [number(a) for a in args]
        total = sum(steps) * repeats - (steps[-1] if len(steps) > 1 and len(steps) % 2 == 0 else 0)
        return total / 1000
    if first == "play":
        return 1.0
    return 0.0


def open_port(port):
    fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    try:
        # Prevent another process from opening this connection while we use it.
        fcntl.ioctl(fd, termios.TIOCEXCL)
        attrs = termios.tcgetattr(fd)
        attrs[0] = attrs[1] = attrs[3] = 0
        attrs[2] = termios.CLOCAL | termios.CREAD | termios.CS8
        attrs[4] = attrs[5] = termios.B115200
        attrs[6][termios.VMIN] = 0
        attrs[6][termios.VTIME] = 0
        termios.tcsetattr(fd, termios.TCSANOW, attrs)
        fcntl.ioctl(fd, termios.TIOCMBIS, struct.pack("I", termios.TIOCM_DTR))
    except Exception:
        os.close(fd)
        raise
    # Let the USB CDC session become ready; this is not a 1200-baud reset.
    time.sleep(0.25)
    return fd


def close_port(fd):
    try:
        fcntl.ioctl(fd, termios.TIOCMBIC, struct.pack("I", termios.TIOCM_DTR))
    finally:
        try:
            fcntl.ioctl(fd, termios.TIOCNXCL)
        finally:
            os.close(fd)


def send(fd, line):
    os.write(fd, (line + "\n").encode("ascii", errors="replace"))


def read_for(fd, seconds, stop_text=None):
    """Print what the clicker says for up to `seconds`. Returns True if stop_text was seen."""
    deadline = time.monotonic() + seconds
    seen = ""
    while time.monotonic() < deadline:
        timeout = max(0.0, min(0.2, deadline - time.monotonic()))
        readable, _, _ = select.select([fd], [], [], timeout)
        if not readable:
            continue
        try:
            data = os.read(fd, 4096)
        except BlockingIOError:
            continue
        if not data:
            continue
        text = data.decode("utf-8", errors="replace")
        sys.stdout.write(text)
        sys.stdout.flush()
        seen = (seen + text)[-400:]
        if stop_text and any(marker in seen for marker in stop_text):
            # Give the rest of that line a moment to arrive.
            time.sleep(0.05)
            return True
    return False


def run_one(fd, words, wait):
    line = " ".join(words)
    first = words[0].lower()
    run = first in MOTOR_RUNS and not (first == "on" and len(words) == 1)
    send(fd, line)
    try:
        if run:
            read_for(fd, wait, FINISHED)
        else:
            read_for(fd, wait)
    except KeyboardInterrupt:
        if first in MOTOR_RUNS:
            send(fd, "off")
            read_for(fd, 0.5)
        print("\nStopped.")


def console(fd):
    print("Connected. Type a command and press Enter, for example:")
    print("  on   off   pulse 200 3 150   pattern 100 50 100 400 x3   power 60   play want   s   ?")
    print("Type quit (or press Ctrl-C) to leave; the motor is turned off when you leave.")
    read_for(fd, 0.3)
    try:
        while True:
            readable, _, _ = select.select([fd, sys.stdin], [], [], 0.2)
            if fd in readable:
                read_for(fd, 0.05)
            if sys.stdin in readable:
                line = sys.stdin.readline()
                if not line:
                    break
                line = line.strip()
                if line.lower() in ("quit", "exit", "q"):
                    break
                if line:
                    send(fd, line)
    except KeyboardInterrupt:
        print()
    finally:
        send(fd, "off")
        read_for(fd, 0.4)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", nargs="+",
                        help="a clicker command with its numbers, e.g. pulse 200 3 150; or console")
    parser.add_argument("--port", help="USB serial device; auto-detected when exactly one is present")
    parser.add_argument("--wait", type=float,
                        help="seconds to collect replies (default: long enough for a motor command, "
                             "2 otherwise; use 16 for phone feedback)")
    args = parser.parse_args()

    words = args.command
    first = words[0].lower()
    if first != "console" and first not in FIRST_WORDS:
        parser.error(f"unknown command '{words[0]}'; run with -h for the list")
    if args.wait is None:
        args.wait = max(2.0, estimate_seconds(words) + 2.0) if first != "console" else 0
    if first != "console" and not 0.1 <= args.wait <= 610:
        parser.error("--wait must be between 0.1 and 610 seconds")

    ports = sorted(glob.glob("/dev/cu.usbmodem*"))
    port = args.port
    if not port:
        if len(ports) != 1:
            parser.error("Connect one XIAO by USB or select its device with --port")
        port = ports[0]

    fd = open_port(port)
    try:
        if first == "console":
            console(fd)
        else:
            run_one(fd, words, args.wait)
    finally:
        close_port(fd)


if __name__ == "__main__":
    try:
        main()
    except (OSError, termios.error) as error:
        sys.exit(f"USB connection failed: {error}. Close any Arduino Serial Monitor and retry.")
