import std.array;
import std.path;
import std.stdio;

import bytecode;

int main(string[] args)
{
	if (args.length < 2) {
		writefln("Usage: %s <input.bin>");
		return 1;
	}

	DM dm;

	auto res = loadFromFile(&dm, args[1].withDefaultExtension(".bin").array);
	if (res != Result.OK) {
		writefln("ERROR: Could not load file `%s`: %s", args[1], res);
		return 1;
	}

	for (ulong i; i < dm.instructions.length; i++) {
		writeln(dm.instructions[i]);
	}
	return 0;
}
