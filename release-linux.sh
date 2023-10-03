#!/bin/env sh

set -exo pipefail

rm -rf zig-cache zig-out
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux-gnu

ls -alh zig-out/bin
