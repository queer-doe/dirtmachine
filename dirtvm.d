import std.stdio;
import std.format;
import std.file;
import std.conv;
import std.math;

import bytecode;

const dmInstCapacity = 1024;
const dmStackCapacity = 1024;

enum Result
{
	OK = 0,
	STACK_OVERFLOW, STACK_UNDERFLOW,
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
	long stackSize;
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

bool loadByteCode(DM* dm, long[] byteCode)
{
	for (ulong i = 0; i < byteCode.length; i += 2) {
		if (!dm.appendInstruction(Inst(cast(InstType)byteCode[i], byteCode[i+1])))
			return false;
	}
	return true;
}

bool loadFromFile(DM* dm, string filename)
{
	ubyte[] data;
	try
		data = cast(ubyte[])filename.read();
	catch (Exception o)
		return false;

	if (data.length % 16 != 0)
		return false;

	long[] byteCode;
	for (ulong i = 0; i < data.length; i += 8) {
		ulong tmp = 0;
		foreach (idx, x; data[i..i+8])
			tmp += x << (idx*8);

		long tmp2 = cast(long)tmp;
		byteCode ~= tmp2 + (tmp2 < 0 ? 1 : 0);
	}
	return dm.loadByteCode(byteCode);
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

	writefln("Stack: [%s]", dm.stackSize);
	foreach (idx; 0..dm.stackSize) {
		writeln("  ", dm.stack[idx]);
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
		if (dm.stackSize >= dmInstCapacity)
			return Result.STACK_OVERFLOW;

		dm.stack[dm.stackSize] = instruction.operand;
		dm.stackSize++;
		break;

	case InstType.POP:
		if (dm.stackSize < 1)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stackSize--] = 0;
		break;

	case InstType.SWAP:
		if (dm.stackSize < 2)
			return Result.STACK_UNDERFLOW;

		auto temp = dm.stack[dm.stackSize - 1];
		dm.stack[dm.stackSize - 1] = dm.stack[dm.stackSize - 2];
		dm.stack[dm.stackSize - 2] = temp;
		break;

	case InstType.ADD:
		if (dm.stackSize < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stackSize - 2] += dm.stack[dm.stackSize - 1];
		dm.stack[--dm.stackSize] = 0;
		break;

	case InstType.SUB:
		if (dm.stackSize < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stackSize - 2] -= dm.stack[dm.stackSize - 1];
		dm.stack[--dm.stackSize] = 0;
		break;

	case InstType.MUL:
		if (dm.stackSize < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stackSize - 2] *= dm.stack[dm.stackSize - 1];
		dm.stack[--dm.stackSize] = 0;
		break;

	case InstType.DIV:
		if (dm.stackSize < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stackSize - 2] /= dm.stack[dm.stackSize - 1];
		dm.stack[--dm.stackSize] = 0;
		break;

	case InstType.DUP:
		if (dm.stackSize >= dmStackCapacity)
			return Result.STACK_OVERFLOW;
		if (dm.stackSize < (instruction.operand + 1))
			return Result.ILLEGAL_STACK_POINTER;
		dm.stack[dm.stackSize++] = dm.stack[dm.stackSize - instruction.operand - 2];
		break;

	case InstType.EQ:
		if (dm.stackSize < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stackSize - 1] == dm.stack[dm.stackSize - 2];
		dm.stack[dm.stackSize - 2] = res;
		dm.stackSize--;
		break;

	case InstType.NEQ:
		if (dm.stackSize < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stackSize - 1] != dm.stack[dm.stackSize - 2];
		dm.stack[dm.stackSize - 2] = res;
		dm.stackSize--;
		break;

	case InstType.GT:
		if (dm.stackSize < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stackSize - 1] > dm.stack[dm.stackSize - 2];
		dm.stack[dm.stackSize - 2] = res;
		dm.stackSize--;
		break;

	case InstType.LT:
		if (dm.stackSize < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stackSize - 1] < dm.stack[dm.stackSize - 2];
		dm.stack[dm.stackSize - 2] = res;
		dm.stackSize--;
		break;

	case InstType.JMPZ_ABS:
		if (instruction.operand > dm.instructionCount || instruction.operand < 0)
			return Result.ILLEGAL_INST_POINTER;

		if (dm.stackSize < 1)
			return Result.STACK_UNDERFLOW;

		if (dm.stack[dm.stackSize - 1] != 0)
			break;

		dm.stack[--dm.stackSize] = 0;
		dm.instPointer = instruction.operand;
		return Result.OK;

	case InstType.JMPZ_REL:
		if ((dm.instPointer + instruction.operand) > dm.instructionCount || (dm.instPointer + instruction.operand) < 0)
			return Result.ILLEGAL_INST_POINTER;

		if (dm.stackSize < 1)
			return Result.STACK_UNDERFLOW;

		if (dm.stack[dm.stackSize - 1] != 0)
			break;

		dm.stack[--dm.stackSize] = 0;
		dm.instPointer += instruction.operand;
		return Result.OK;

	case InstType.HALT:
		dm.halt = true;
		break;

	default:
		return Result.ILLEGAL_INSTRUCTION;}

	dm.instPointer++;
	return Result.OK;
}

// HALT = 0,
// PUSH, POP,
// ADD, SUB, MUL, DIV,
// DUP_REL, DUP_ABS,
// JMP_REL, JMP_ABS,


void executeUntilHalt(DM* dm)
{
	while (dm.halt != true) {
		auto res = dm.executeOne();
		if (res != Result.OK) {
			dm.halt = true;
			writeln("ERROR: ", res);
		}
		// dm.dumpDm();
	}
}

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
		fn = args[1];

	if (!loadFromFile(&dm, fn)) {
		writefln("ERROR: Could not load file `%s`", fn);
		return 1;
	}
	dumpDm(&dm);
	executeUntilHalt(&dm);
	dumpDm(&dm);
    return 0;
}


// appendInstruction(&dm, Inst(InstType.PUSH, 35));
// appendInstruction(&dm, Inst(InstType.PUSH, 35));
// appendInstruction(&dm, Inst(InstType.ADD));
// appendInstruction(&dm, Inst(InstType.PUSH, 1));
// appendInstruction(&dm, Inst(InstType.SUB));
// appendInstructions(&dm, [Inst(InstType.PUSH, 0),
// 						 Inst(InstType.PUSH, 1),
// 						 Inst(InstType.SWAP),
// 						 Inst(InstType.SUB),
// 						 Inst(InstType.JMPZ_ABS, 0),
// 						 Inst(InstType.HALT)]);
