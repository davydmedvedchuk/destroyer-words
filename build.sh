#!/bin/sh
# Assemble calc.wat into calc.wasm. Needs wabt: npm install -g wabt  (provides wat2wasm)
set -e
cd "$(dirname "$0")"
wat2wasm calc.wat -o calc.wasm
ls -l calc.wasm
