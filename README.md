# UNDER CONSTRUCTION. DO NOT USE.
# DirtMachine
[![build and test](https://github.com/queer-doe/dirtmachine/actions/workflows/d.yml/badge.svg)](https://github.com/queer-doe/dirtmachine/actions/workflows/d.yml)

DirtMachine is a simplistic application VM.


## Dependencies

+ dmd
+ rdmd


## Building

`rdmd build.d` or `./build.d`


## Running

`./dirtasm <input.dasm> <output.bin>` to assemble from dirtasm into dirtbc (dirtbytecode).

`./dirtvm <input.bin>` to run specified dirtbc file.
