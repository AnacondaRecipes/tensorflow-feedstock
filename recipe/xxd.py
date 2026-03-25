#!/usr/bin/env python3
"""Minimal Python shim for `xxd -i`, which is not available as a conda package.

XLA's embed_files() genrule invokes `xxd -i` to convert binary files into C
byte-array literals (see xla/util/build_defs.bzl, @xxd//:xxd). This script
emulates that behavior so the Bazel build can find an xxd on PATH.

Reference: https://github.com/openxla/xla/blob/37c3ee81054956406e4c0685c7d06a629de6fed0/xla/util/build_defs.bzl#L44
"""
import sys

args = sys.argv[1:]
if "-i" in args:
    args.remove("-i")

if not args:
    raise SystemExit("usage: xxd -i <file>")

fname = args[0]
with open(fname, "rb") as f:
    data = f.read()

varname = fname.replace("/", "_").replace("\\", "_").replace(".", "_").replace("-", "_")
print(f"unsigned char {varname}[] = {{")
for i in range(0, len(data), 12):
    chunk = data[i : i + 12]
    print("  " + ", ".join(f"0x{b:02x}" for b in chunk) + ",")
print("};")
print(f"unsigned int {varname}_len = {len(data)};")
