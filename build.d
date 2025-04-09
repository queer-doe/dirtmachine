#!/bin/env rdmd
import std.process;
import std.stdio;

bool cmd(string[] args)
{
    writeln("CMD: ", args);
    return spawnProcess(args).wait() == 0;
}

int main()
{
    string[] dmdAndFlags = ["dmd", "-O", "-release"];
    if (!cmd(dmdAndFlags ~ "dirtasm" ~ "bytecode.d")) return 1;
    if (!cmd(dmdAndFlags ~ "dirtdisasm" ~ "bytecode.d")) return 1;
    if (!cmd(dmdAndFlags ~ "dirtvm" ~ "bytecode.d")) return 1;
    if (!cmd(["rm"] ~ "dirtasm.o" ~ "dirtvm.o")) return 1;
    return 0;
}
