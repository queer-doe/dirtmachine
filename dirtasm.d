import std.array;
import std.conv;
import std.file;
import std.stdio;
import std.string;
import std.path;

import bytecode;

Result tryGetNumArg(string[] arr, Word* output)
{
	if (arr.length < 2)
		return Result.NO_ARGUMENT_PROVIDED;

	string[] parts = arr[1].split(".");

	if (parts.length == 2) {
		if (parts[0] == "")
			parts[0] = "0";

		if (parts[0] == "")
			return Result.INVALID_DECIMAL;

		try
			output.asF64 = to!double(arr[1]);
		catch (Exception o)
			return Result.INVALID_DECIMAL;
		return Result.OK;
	}

	if (parts.length == 1) {
		if (parts[0] == "")
			return Result.NO_ARGUMENT_PROVIDED;

		try
			output.asI64 = to!long(arr[1]);
		catch (Exception o)
			return Result.INVALID_INTEGER;
		return Result.OK;
	}

	return Result.INVALID_DECIMAL;
}

const string invArgErrFormat = "ERROR: %s:%d:0 Invalid or no argument provided for `%s`: %s";

int main(string[] args)
{
	if (args.length == 2 && args[1].extension.empty) {
		args[1] = args[1].setExtension(".dasm");
		args ~= args[1].setExtension(".bin");
	}
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

	ubyte[] byteCode;
	Inst[] instructions;
	string[] needLabels;
	bool err = false;
	long instCount = 0;

	for (int ln = 0; ln < lines.length; ln++) {
		string line = lines[ln];
		line = line.strip();

		if (line == "")
			continue;
		if (line.startsWith(";"))
			continue;

		if (line.startsWith("#include ")) {
			string[] newLines;
			try
				newLines = (cast(string)args[1].absolutePath.dirName.buildPath(line.split(" ")[1]).read()).split("\n");
			catch (Exception o) {
				writefln("ERROR: Could not read file `%s`", args[1]);
				return 1;
			}
			lines[ln] = "";
			lines.insertInPlace(ln, newLines);
			continue;
		}

		if (line.endsWith(":")) {
			labels[line.split(":")[0]] = instCount;
			continue;
		}

		string[] inst = line.split(";")[0].split(" ");

		Word arg;
		Result got = tryGetNumArg(inst, &arg);

		switch (inst[0]) {
		case "dup":
			if (got != Result.OK) {
				writefln(invArgErrFormat, args[1], ln+1, inst[0], got);
				err = true;
			}

			instructions ~= Inst(InstType.DUP, arg);
			break;

		case "jmpz":
			if (got != Result.OK) {
				writefln(invArgErrFormat, args[1], ln+1, inst[0], got);
				err = true;
			}

			instructions ~= Inst(InstType.JMPZ_REL, arg);
			break;

		case "jmpz@":
			if (got != Result.OK) {
				needLabels ~= inst[1];
				arg.asI64 = -1;
			}

			instructions ~= Inst(InstType.JMPZ_ABS, arg, args[1], ln+1);
			break;

		case "call":
			if (got != Result.OK) {
				needLabels ~= inst[1];
				arg.asI64 = -1;
			}

			instructions ~= Inst(InstType.CALL, arg, args[1], ln+1);
			break;

		case "ret":
			instructions ~= Inst(InstType.RET, arg, args[1], ln+1);
			break;

		case "push":
			if (got != Result.OK) {
				writefln(invArgErrFormat, args[1], ln+1, inst[0], got);
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

		case "addi":
			instructions ~= Inst(InstType.ADDI, arg);
			break;

		case "subi":
			instructions ~= Inst(InstType.SUBI, arg);
			break;

		case "muli":
			instructions ~= Inst(InstType.MULI, arg);
			break;

		case "divi":
			instructions ~= Inst(InstType.DIVI, arg);
			break;

		case "addf":
			instructions ~= Inst(InstType.ADDF, arg);
			break;

		case "subf":
			instructions ~= Inst(InstType.SUBF, arg);
			break;

		case "mulf":
			instructions ~= Inst(InstType.MULF, arg);
			break;

		case "divf":
			instructions ~= Inst(InstType.DIVF, arg);
			break;

		case "eq":
			instructions ~= Inst(InstType.EQ, arg);
			break;

		case "neq":
			instructions ~= Inst(InstType.NEQ, arg);
			break;

		case "gti":
			instructions ~= Inst(InstType.GTI, arg);
			break;

		case "lti":
			instructions ~= Inst(InstType.LTI, arg);
			break;

		case "gtu":
			instructions ~= Inst(InstType.GTU, arg);
			break;

		case "ltu":
			instructions ~= Inst(InstType.LTU, arg);
			break;

		case "gtf":
			instructions ~= Inst(InstType.GTF, arg);
			break;

		case "ltf":
			instructions ~= Inst(InstType.LTF, arg);
			break;

		default:
			writefln("ERROR: %s:%d:0 Unknown instruction: %s", args[1], ln+1, inst[0]);
			return 1;
		}
		instCount++;
	}

	ulong jmpCount = 0;
	foreach (inst; instructions) {
		if ((inst.type == InstType.JMPZ_ABS || inst.type == InstType.CALL) && inst.operand.asI64 == -1) {
			if (needLabels[jmpCount] in labels)
				inst.operand.asI64 = labels[needLabels[jmpCount]];
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


	std.file.write(args[2], "DBC\2");
	std.file.append(args[2], byteCode);
	return 0;
}

