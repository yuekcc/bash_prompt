#!/bin/env sh

set -exo pipefail

zig build
cp zig-out/bin/bash_prompt.exe ../../app/bin