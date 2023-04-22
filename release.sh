#!/bin/env sh

set -exo pipefail

zig build -Doptimize=ReleaseFast
ls -alh zig-out/bin

