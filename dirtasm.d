import std.array;
import std.conv;
import std.file;
import std.stdio;
import std.string;

import bytecode;

bool tryGetNumArg(string[] arr, long* output)
{
	if (arr.length < 2)
		return false;

	try
		*output = to!long(arr[1]);
	catch (Exception o)
		return false;

	return true;
}

const string invArgErrFormat = "ERROR: %s:%d:0 No valid argument provided for `%s`";

int main(string[] args)
{
	if (args.length < 3) {
		writeln("ERROR: Not enough arguments");
		writeln("USAGE:");
		writefln("  %s <file.dasm> <out.bin>", args[0]);
		return 1;
	}

	string[] lines;
	try
		lines = (cast(string)args[1].read()).split("\n");
	catch (Exception o) {
		writefln("ERROR: Could not read file `%s`", args[1]);
		return 1;
	}

	long[string] labels;

	long[] byteCode;
	Inst[] instructions;
	string[] needLabels;
	bool err = false;
	long instCount = 0;

	foreach (ln, line; lines) {
		line = line.strip();
		if (line == "")
			continue;
		if (line.startsWith(";"))
			continue;

		if (line.endsWith(":")) {
			labels[line.split(":")[0]] = instCount;
			continue;
		}

		string[] inst = line.split(";")[0].split(" ");

		long arg;
		bool got = tryGetNumArg(inst, &arg);

		switch (inst[0]) {
		case "dup":
			if (!got) {
				writefln(invArgErrFormat, args[1], ln+1, inst[0]);
				err = true;
			}

			instructions ~= Inst(InstType.DUP, arg);
			break;

		case "jmpz":
			if (!got) {
				writefln(invArgErrFormat, args[1], ln+1, inst[0]);
				err = true;
			}

			instructions ~= Inst(InstType.JMPZ_REL, arg);
			break;

		case "jmpz@":
			if (!got) {
				needLabels ~= inst[1];
				// writefln(invArgErrFormat, args[1], ln+1, inst[0]);
				// err = true;
			}

			instructions ~= Inst(InstType.JMPZ_ABS, arg, args[1], ln+1);
			break;

		case "push":
			if (!got) {
				writefln(invArgErrFormat, args[1], ln+1, inst[0]);
				err = true;
			}

			instructions ~= Inst(InstType.PUSH, arg);
			break;

		case "halt":
			instructions ~= Inst(InstType.HALT, arg);
			break;

		case "pop":
			instructions ~= Inst(InstType.POP, arg);
			break;

		case "swap":
			instructions ~= Inst(InstType.SWAP, arg);
			break;

		case "add":
			instructions ~= Inst(InstType.ADD, arg);
			break;

		case "sub":
			instructions ~= Inst(InstType.SUB, arg);
			break;

		case "mul":
			instructions ~= Inst(InstType.MUL, arg);
			break;

		case "div":
			instructions ~= Inst(InstType.DIV, arg);
			break;

		case "eq":
			instructions ~= Inst(InstType.EQ, arg);
			break;

		case "neq":
			instructions ~= Inst(InstType.NEQ, arg);
			break;

		case "gt":
			instructions ~= Inst(InstType.GT, arg);
			break;

		case "lt":
			instructions ~= Inst(InstType.LT, arg);
			break;

		default:
			writefln("ERROR: %s:%d:0 Unknown instruction: %s", args[1], ln+1, inst[0]);
			return 1;
		}
		instCount++;
	}

	ulong jmpCount = 0;
	foreach (inst; instructions) {
		if (inst.type == InstType.JMPZ_ABS) {
			if (needLabels[jmpCount] in labels)
				inst.operand = labels[needLabels[jmpCount]];
			else {
				writefln("ERROR: %s:%d:0 Unknown label: `%s`", inst.fn, inst.ln, needLabels[jmpCount]);
				err = true;
			}
			jmpCount++;
		}
		byteCode ~= inst.toByteCode();
	}

	if (err) {
		return 2;
	}


	std.file.write(args[2], ""); // FIXME: proper fileheader struct
	std.file.append(args[2], byteCode);
	return 0;
}

