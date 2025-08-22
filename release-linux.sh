#!/bin/env sh

set -ex

rm -rf zig-cache zig-out
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux-gnu

ls -alh zig-out/bin
