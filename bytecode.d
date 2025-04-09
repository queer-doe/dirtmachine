import std.stdio;
import std.file;
import std.format;
import std.math;
import std.conv;
import std.string;

const dmInstCapacity = 1024;
const dmStackCapacity = 1024;
const dmCallStackCapacity = 256;

enum InstType
{
    HALT = 0,
    PUSH, POP, SWAP,
    ADD, SUB, MUL, DIV,
    DUP,
	EQ, NEQ, GT, LT,
	JMPZ_REL, JMPZ_ABS,
	CALL, RET,
}

bool takesArgument(InstType type)
{
	final switch (type) {
	case InstType.HALT:
	case InstType.POP:
	case InstType.SWAP:
	case InstType.ADD:
	case InstType.SUB:
	case InstType.MUL:
	case InstType.DIV:
	case InstType.EQ:
	case InstType.NEQ:
	case InstType.GT:
	case InstType.LT:
	case InstType.RET:
		return false;

	case InstType.PUSH:
	case InstType.DUP:
	case InstType.JMPZ_REL:
	case InstType.JMPZ_ABS:
	case InstType.CALL:
		return true;
	}
}

struct Inst
{
    InstType type;
    long operand;

	string fn;
	ulong ln;

	bool takesArgument() const
	{
		return this.type.takesArgument;
	}

    void toString(scope void delegate(const(char)[]) sink) const
	{
		final switch (this.type) {
		case InstType.HALT:
			sink("halt"); break;
		case InstType.POP:
			sink("pop"); break;
		case InstType.SWAP:
			sink("swap"); break;
		case InstType.ADD:
			sink("add"); break;
		case InstType.SUB:
			sink("sub"); break;
		case InstType.MUL:
			sink("mul"); break;
		case InstType.DIV:
			sink("div"); break;
		case InstType.EQ:
			sink("eq"); break;
		case InstType.NEQ:
			sink("neq"); break;
		case InstType.GT:
			sink("gt"); break;
		case InstType.LT:
			sink("lt"); break;
		case InstType.RET:
			sink("ret " ~ this.operand.text); break;
		case InstType.PUSH:
			sink("push " ~ this.operand.text); break;
		case InstType.DUP:
			sink("dup " ~ this.operand.text); break;
		case InstType.JMPZ_REL:
			sink("jmpz " ~ this.operand.text); break;
		case InstType.JMPZ_ABS:
			sink("jmpz@ " ~ this.operand.text); break;
		case InstType.CALL:
			sink("call " ~ this.operand.text); break;
		}
    }

	ubyte[] toByteCode() {
		ubyteLong tmp;
		tmp.l = this.operand;
		if (this.takesArgument)
			return [cast(ubyte)this.type] ~ tmp.u;
		else
			return [cast(ubyte)this.type];
		assert(0);
	}
}

union ubyteLong
{
	ubyte[8] u;
	long l;
}

enum Result
{
	OK = 0,
	STACK_OVERFLOW, STACK_UNDERFLOW,
	CALLSTACK_OVERFLOW, CALLSTACK_UNDERFLOW,
	ILLEGAL_INST_POINTER, ILLEGAL_STACK_POINTER,
	ILLEGAL_INSTRUCTION,
}

struct DM
{
	bool halt;

    Inst[dmInstCapacity] instructions;
	long instructionCount;
    long instPointer;

    long[dmStackCapacity] stack;
	long stackCount;

    long[dmCallStackCapacity] callStack;
	long callStackCount;
}

bool appendInstruction(DM* dm, Inst inst)
{
	if (dm.instructionCount >= dmInstCapacity)
		return false;

	dm.instructions[dm.instructionCount++] = inst;

	return true;
}

bool appendInstructions(DM* dm, Inst[] insts)
{
	foreach(inst; insts)
		if (!appendInstruction(dm, inst))
			return false;

	return true;
}

bool loadByteCodeV0(DM* dm, long[] byteCode)
{
	for (ulong i = 0; i < byteCode.length; i += 2) {
		if (!dm.appendInstruction(Inst(cast(InstType)byteCode[i], byteCode[i+1]))) {
			return false;}
	}
	return true;
}

bool loadFromFileV0(DM* dm, string filename)
{
	ubyte[] data;

	try
		data = cast(ubyte[])filename.read();
	catch (Exception o)
		return false;

	if (data[0..4].assumeUTF == "DBC\0")
		data = data[4..$];

	if (data.length % 16 != 0)
		return false;

	long[] byteCode;
	for (ulong i = 0; i < data.length; i += 8) {
		ubyte[8] tmp = data[i..i+8];
		byteCode ~= (cast(ubyteLong)tmp).l;
	}
	return dm.loadByteCodeV0(byteCode);
}

bool loadByteCodeV1(DM* dm, ubyte[] data)
{
	Inst[] instructions;
	bool expectingInstruction = true;

	for (ulong i = 0; i < data.length;) {
		if (expectingInstruction) {
			InstType type = cast(InstType)data[i];
			if (type.takesArgument)
				expectingInstruction = false;
			i += 1;
			instructions ~= Inst(type);
		} else {
			ubyte[8] tmp = data[i..i+8];
			instructions[$-1].operand = (cast(ubyteLong)tmp).l;
			expectingInstruction = true;
			i += 8;
		}
	}
	return dm.appendInstructions(instructions);
}

bool loadFromFileV1(DM* dm, string filename)
{
	ubyte[] data;
	try
		data = cast(ubyte[])filename.read();
	catch (Exception o)
		return false;

	if (data[0..4].assumeUTF == "DBC\1")
		data = data[4..$];
	else
		return false;

	return dm.loadByteCodeV1(data);
}

bool loadFromFile(DM* dm, string filename)
{
	ubyte[] data;
	try
		data = cast(ubyte[])filename.read(4);
	catch (Exception o)
		return false;

	if (data.length < 4)
		return false;

	switch (data[0..4].assumeUTF) {
	case "DBC\1":
		return dm.loadFromFileV1(filename);
	case "DBC\0":
		return dm.loadFromFileV0(filename);
	default:
		return dm.loadFromFileV0(filename);
	}
	return false;
}

void dumpDm(DM* dm)
{
	int pad;
	try {
		pad = to!int(log10(cast(double)dm.instructionCount)+1);
	} catch (Exception) {
		pad = 0;
	}
	writeln("\n");
	writefln("Instructions: [%s]", dm.instructionCount);
	if (dm.instructionCount > 0)
		foreach (idx; 0..dm.instructionCount) {
			if (idx == dm.instPointer)
				writefln("%*d > %s", pad, idx, dm.instructions[idx]);
			else
				writefln("%*d   %s", pad, idx, dm.instructions[idx]);
		}
	else
		writeln("  [empty]");

	writefln("Stack: [%s]", dm.stackCount);
	foreach (idx; 0..dm.stackCount) {
		writeln("  ", dm.stack[idx]);
	}
	writeln("  [top]");

	writefln("Callstack: [%s]", dm.callStackCount);
	foreach (idx; 0..dm.callStackCount) {
		writeln("  ", dm.callStack[idx]);
	}
	writeln("  [top]");
}

Result executeOne(DM* dm)
{
	if (dm.instPointer > dm.instructionCount || dm.instPointer < 0)
		return Result.ILLEGAL_INST_POINTER;
	auto instruction = dm.instructions[dm.instPointer];
	switch (instruction.type) {
	case InstType.PUSH:
		if (dm.stackCount >= dmInstCapacity)
			return Result.STACK_OVERFLOW;

		dm.stack[dm.stackCount] = instruction.operand;
		dm.stackCount++;
		break;

	case InstType.POP:
		if (dm.stackCount < 1)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stackCount--] = 0;
		break;

	case InstType.SWAP:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;

		auto temp = dm.stack[dm.stackCount - 1];
		dm.stack[dm.stackCount - 1] = dm.stack[dm.stackCount - 2];
		dm.stack[dm.stackCount - 2] = temp;
		break;

	case InstType.ADD:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stackCount - 2] += dm.stack[dm.stackCount - 1];
		dm.stack[--dm.stackCount] = 0;
		break;

	case InstType.SUB:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stackCount - 2] -= dm.stack[dm.stackCount - 1];
		dm.stack[--dm.stackCount] = 0;
		break;

	case InstType.MUL:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stackCount - 2] *= dm.stack[dm.stackCount - 1];
		dm.stack[--dm.stackCount] = 0;
		break;

	case InstType.DIV:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stackCount - 2] /= dm.stack[dm.stackCount - 1];
		dm.stack[--dm.stackCount] = 0;
		break;

	case InstType.DUP:
		if (dm.stackCount >= dmStackCapacity)
			return Result.STACK_OVERFLOW;
		if (dm.stackCount < (instruction.operand + 1))
			return Result.ILLEGAL_STACK_POINTER;
		dm.stack[dm.stackCount++] = dm.stack[dm.stackCount - instruction.operand - 2];
		break;

	case InstType.EQ:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stackCount - 1] == dm.stack[dm.stackCount - 2];
		dm.stack[dm.stackCount - 2] = res;
		dm.stackCount--;
		break;

	case InstType.NEQ:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stackCount - 1] != dm.stack[dm.stackCount - 2];
		dm.stack[dm.stackCount - 2] = res;
		dm.stackCount--;
		break;

	case InstType.GT:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stackCount - 1] > dm.stack[dm.stackCount - 2];
		dm.stack[dm.stackCount - 2] = res;
		dm.stackCount--;
		break;

	case InstType.LT:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stackCount - 1] < dm.stack[dm.stackCount - 2];
		dm.stack[dm.stackCount - 2] = res;
		dm.stackCount--;
		break;

	case InstType.JMPZ_ABS:
		if (instruction.operand > dm.instructionCount || instruction.operand < 0)
			return Result.ILLEGAL_INST_POINTER;

		if (dm.stackCount < 1)
			return Result.STACK_UNDERFLOW;

		if (dm.stack[dm.stackCount - 1] != 0)
			break;

		dm.stack[--dm.stackCount] = 0;
		dm.instPointer = instruction.operand;
		return Result.OK;

	case InstType.JMPZ_REL:
		if ((dm.instPointer + instruction.operand) > dm.instructionCount || (dm.instPointer + instruction.operand) < 0)
			return Result.ILLEGAL_INST_POINTER;

		if (dm.stackCount < 1)
			return Result.STACK_UNDERFLOW;

		if (dm.stack[dm.stackCount - 1] != 0)
			break;

		dm.stack[--dm.stackCount] = 0;
		dm.instPointer += instruction.operand;
		return Result.OK;

	case InstType.CALL:
		if (instruction.operand > dm.instructionCount || instruction.operand < 0)
			return Result.ILLEGAL_INST_POINTER;

		if (dm.callStackCount >= dmCallStackCapacity)
			return Result.CALLSTACK_OVERFLOW;

		dm.callStack[dm.callStackCount++] = dm.instPointer;
		dm.instPointer = instruction.operand;

		return Result.OK;

	case InstType.RET:
		if (dm.callStackCount < 1)
			return Result.CALLSTACK_UNDERFLOW;

		dm.instPointer = dm.callStack[--dm.callStackCount];
		dm.callStack[dm.callStackCount] = 0;

		break;

	case InstType.HALT:
		dm.halt = true;
		return Result.OK;

	default:
		return Result.ILLEGAL_INSTRUCTION;}

	dm.instPointer++;
	return Result.OK;
}
