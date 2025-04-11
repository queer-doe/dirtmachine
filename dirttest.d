import std.array;
import std.conv;
import std.file;
import std.format;
import std.path;
import std.process;
import std.stdio;
import std.string;

import bytecode;

bool cmd(string command)
{
    writeln("CMD: ", command);
    return executeShell(command).status == 0;
}

int errorout(string error, string progname, int ret)
{
	writeln("ERROR: ", error);
	if (ret == 1) {
		writeln("USAGE:");
		writefln("  %s <compiler> <testdir>", progname);
	}
	return ret;
}

int main(string[] args)
{
	if (args.length < 2) {
		return errorout("Not enough arguments", args[0], 1);
	}

	auto progName = args[0];
	auto compiler = args[1];
	auto testDir = args[2];

	ulong tests = 0;
	ulong testsPassed = 0;

	if (!testDir.exists || !testDir.isDir)
		return errorout("Not a directory: `%s`".format(testDir), progName, 1);

	foreach (file; testDir.dirEntries("*.dasm", SpanMode.depth)) {
		string[] lines;
		try
			lines = (cast(string)file.read()).split("\n");
		catch (Exception o)
			return errorout("Could not read file `%s`".format(file), progName, 2);

		string dirtTestExpected = "";
		foreach (line; lines)
			if (line.strip().startsWith("; DIRT-TEST:")) {
				dirtTestExpected = line.strip.split(":")[1].strip;
				break;
			}

		long expectedValue;
		try
			expectedValue = to!long(dirtTestExpected);
		catch (Exception o)
			return errorout("Invalid expected value (must be an integer): `%s`".format(dirtTestExpected), progName, 2);

		if (!cmd(compiler ~ " " ~ file ~ " " ~ file.setExtension(".bin")))
			return errorout("Could not compile `%s`".format(file), progName, 2);

		DM dm;
		auto res = (&dm).loadFromFile(file.setExtension(".bin"));

		if (res != Result.OK)
			return errorout("Could not read file `%s`: %s".format(file.setExtension(".bin"), res), progName, 2);

		bool err = false;

		writefln("Running `%s`...", file);
		res = (&dm).executeUntilHalt(1_000_000); // FIXME: don't hardcode limit

		if (res != Result.OK) {
			errorout("VM crashed: `%s`".format(res), progName, 3);
			err = true;
		}

		if (dm.stackCount < 1) {
			errorout("Not enough values on the stack", progName, 3);
			err = true;
		}

		auto stackTop = dm.stack[dm.stackCount - 1];
		if (stackTop.asI64 != expectedValue) {
			errorout("Test failed: expected `%s` but got `%s`".format(expectedValue, stackTop), progName, 3);
			err = true;
		}

		if (!err)
			testsPassed++;
		tests++;
	}

	writefln("Test passed: %s/%s", testsPassed, tests);

	if (testsPassed < tests)
		return 1;
	else
		return 0;
}
