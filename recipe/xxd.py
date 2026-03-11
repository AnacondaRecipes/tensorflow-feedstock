#!/usr/bin/env python3
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
