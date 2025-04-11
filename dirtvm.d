import std.array;
import std.conv;
import std.file;
import std.format;
import std.math;
import std.path;
import std.stdio;

import bytecode;

void manualStepping(DM* dm)
{
	while (dm.halt != true) {
		char cmd;
		readf("%s", cmd);
		auto res = dm.executeOne();
		if (res != Result.OK) {
			dm.halt = true;
			writeln("ERROR: ", res);
		}
		dm.dumpDm();
	}
}

int main(string[] args)
{
	DM dm;

	string fn = "out.bin";

	if (args.length > 1)
		fn = args[1].withDefaultExtension(".bin").array;

	Result res = loadFromFile(&dm, fn);
	if (res != Result.OK) {
		writefln("ERROR: Could not load file `%s`: %s", fn, res);
		return 1;
	}
	dumpDm(&dm);
	manualStepping(&dm);
	dumpDm(&dm);
    return 0;
}
