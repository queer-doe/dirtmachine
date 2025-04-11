import std.algorithm;
import std.array;
import std.conv;
import std.file;
import std.format;
import std.path;
import std.process;
import std.stdio;
import std.string;
import std.typecons;

import bytecode;

int errorout(string error, string progname, int ret)
{
	writeln("ERROR: ", error);
	if (ret == 1) {
		writeln("USAGE:");
		writefln("  %s <compiler> <testdir>", progname);
	}
	return ret;
}

long[] asI64a(Word[] words)
{
	long[] o;
	foreach (word; words)
		o ~= word.asI64;
	return o;
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
				auto tmp = line.strip.split(":")[1].split(";");
				if (tmp.length >= 1)
					dirtTestExpected = tmp[0].strip;
				break;
			}

		if (dirtTestExpected == "")
			return errorout("No `; DIRT-TEST: ` provided in file `%s`".format(file), progName, 2);

		long[] expectedValues;
		foreach (ev; dirtTestExpected.split(" ")) {
			try
				expectedValues ~= to!long(ev);
			catch (Exception o) {
				if (dirtTestExpected == "[empty]")
					expectedValues = [];
				else
					return errorout("Invalid expected value (must be an integer): `%s`".format(dirtTestExpected), progName, 2);
			}
		}

		writefln("Compiling `%s`...", file);
		auto cmdRes = executeShell(compiler ~ " " ~ file ~ " " ~ file.setExtension(".bin"));
		if (cmdRes.status != 0)
			return errorout("Could not compile `%s`:\n%s".format(file, cmdRes.output), progName, 2);

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

		if (dm.stackCount != expectedValues.length) {
			errorout("Test failed: expected `%s` but got `%s`".format(expectedValues, dm.stack[0..dm.stackCount].reverse.asI64a), progName, 3);
			err = true;
		} else {
			foreach (idx, word; dm.stack[0..dm.stackCount].reverse) {
				if (word.asI64 != expectedValues[idx]) {
					errorout("Test failed: expected `%s` but got `%s`".format(expectedValues, dm.stack[0..dm.stackCount].reverse.asI64a), progName, 3);
					err = true;
				}
			}
		}

		if (!err)
			testsPassed++;
		tests++;
	}

	writefln("Tests passed: %s/%s", testsPassed, tests);

	if (testsPassed < tests)
		return 1;
	else
		return 0;
}
