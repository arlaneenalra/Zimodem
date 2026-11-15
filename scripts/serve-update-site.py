#!/usr/bin/env python3
"""Serve an AT&U update site (scripts/update-site.sh) over plain HTTP.

Like `python3 -m http.server`, but each response is written through a
buffer so the headers and the start of the body leave in one write.
Zimodem's updater (before 2026-11-15's fix, and stock builds) checks the
image's first byte as soon as it has read the headers; with the headers
and body sent separately, as http.server does, that byte has not arrived
yet and the update fails with ERROR (a broken pipe on this side).

usage: scripts/serve-update-site.py [-p PORT] [-d DIR]
       (defaults: port 8000, build/update-site)
"""
import argparse
import functools
import http.server
import os


class BufferedHandler(http.server.SimpleHTTPRequestHandler):
    # StreamRequestHandler: non-zero -> a buffered socket file, flushed in
    # finish(); the default 0 writes the headers on their own.
    wbufsize = 64 * 1024

    def copyfile(self, source, outputfile):
        # Chunks smaller than the buffer, so the first one joins the headers
        # (shutil.copyfileobj's larger chunks flush the headers on their own).
        while chunk := source.read(8 * 1024):
            outputfile.write(chunk)


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("-p", "--port", type=int, default=8000)
    ap.add_argument("-b", "--bind", default="")
    ap.add_argument("-d", "--directory",
                    default=os.path.join(root, "build", "update-site"))
    args = ap.parse_args()
    handler = functools.partial(BufferedHandler, directory=args.directory)
    with http.server.ThreadingHTTPServer((args.bind, args.port), handler) as srv:
        print(f"Serving {args.directory} on port {args.port}", flush=True)
        try:
            srv.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
