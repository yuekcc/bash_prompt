#!/bin/env sh

set -exo pipefail

rm -rf zig-cache zig-out
zig build --release=fast

ls -alh zig-out/bin

