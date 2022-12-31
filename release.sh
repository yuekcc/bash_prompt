#!/bin/env sh

set -exo pipefail

zig build -Drelease-fast
ls -alh zig-out/bin
cp zig-out/bin/bash_prompt.exe ../../app/bin