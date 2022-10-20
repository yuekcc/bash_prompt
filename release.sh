#!/bin/env sh

set -exo pipefail

zig build -Drelease-fast
cp zig-out/bin/bash_prompt.exe ../../app/bin