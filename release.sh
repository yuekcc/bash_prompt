#!/bin/env sh

set -exo pipefail

zig build -Drelease-safe
cp zig-out/bin/bash_prompt.exe ../../app/bin