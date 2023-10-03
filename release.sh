#!/bin/env sh

set -exo pipefail

rm -rf zig-cache zig-out
zig build -Doptimize=ReleaseFast

ls -alh zig-out/bin

