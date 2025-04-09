import std.stdio;

import bytecode;

int main(string[] args)
{
	if (args.length < 2) {
		writefln("Usage: %s <input.bin>");
		return 1;
	}

	DM dm;

	if (!loadFromFile(&dm, args[1])) {
		writefln("ERROR: Could not load file `%s`", args[1]);
		return 1;
	}

	for (ulong i; i < dm.instructionCount; i++) {
		writeln(dm.instructions[i]);
	}
	return 0;
}
