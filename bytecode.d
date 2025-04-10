import std.stdio;
import std.file;
import std.format;
import std.math;
import std.conv;
import std.string;

const dmInstCapacity = 1024;
const dmStackCapacity = 1024;
const dmCallStackCapacity = 256;

union Word {
	ubyte asU8;
	long asI64;
	ulong asU64;
	double asF64;
	ulong asPtr;

    void toString(scope void delegate(const(char)[]) sink) const
	{
		sink("{ %d , %d , %d , %.8f , %016X }".format(this.asU8, this.asI64, this.asU64, this.asF64, this.asPtr));
	}
}

enum InstType
{
    HALT = 0,
    PUSH, POP, SWAP,
    ADDI, SUBI, MULI, DIVI,
    ADDF, SUBF, MULF, DIVF,
    DUP,
	EQ, NEQ,
	GTI, LTI, GTU, LTU, GTF, LTF,
	JMPZ_REL, JMPZ_ABS,
	CALL, RET,
}

bool takesArgument(InstType type)
{
	final switch (type) {
	case InstType.HALT:
	case InstType.POP:
	case InstType.SWAP:
	case InstType.ADDI:
	case InstType.SUBI:
	case InstType.MULI:
	case InstType.DIVI:
	case InstType.ADDF:
	case InstType.SUBF:
	case InstType.MULF:
	case InstType.DIVF:
	case InstType.EQ:
	case InstType.NEQ:
	case InstType.GTI:
	case InstType.LTI:
	case InstType.GTU:
	case InstType.LTU:
	case InstType.GTF:
	case InstType.LTF:
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
    Word operand;

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
		case InstType.ADDI:
			sink("addi"); break;
		case InstType.SUBI:
			sink("subi"); break;
		case InstType.MULI:
			sink("muli"); break;
		case InstType.DIVI:
			sink("divi"); break;
		case InstType.ADDF:
			sink("addf"); break;
		case InstType.SUBF:
			sink("subf"); break;
		case InstType.MULF:
			sink("mulf"); break;
		case InstType.DIVF:
			sink("divf"); break;
		case InstType.EQ:
			sink("eq"); break;
		case InstType.NEQ:
			sink("neq"); break;
		case InstType.GTI:
			sink("gti"); break;
		case InstType.LTI:
			sink("lti"); break;
		case InstType.GTU:
			sink("gtu"); break;
		case InstType.LTU:
			sink("ltu"); break;
		case InstType.GTF:
			sink("gtf"); break;
		case InstType.LTF:
			sink("ltf"); break;
		case InstType.RET:
			sink("ret " ~ this.operand.asI64.text ~ "  ; " ~ "%.8f".format(this.operand.asF64)); break;
		case InstType.PUSH:
			sink("push " ~ this.operand.asI64.text ~ "  ; " ~ "%.8f".format(this.operand.asF64)); break;
		case InstType.DUP:
			sink("dup " ~ this.operand.asI64.text ~ "  ; " ~ "%.8f".format(this.operand.asF64)); break;
		case InstType.JMPZ_REL:
			sink("jmpz " ~ this.operand.asI64.text ~ "  ; " ~ "%.8f".format(this.operand.asF64)); break;
		case InstType.JMPZ_ABS:
			sink("jmpz@ " ~ this.operand.asI64.text ~ "  ; " ~ "%.8f".format(this.operand.asF64)); break;
		case InstType.CALL:
			sink("call " ~ this.operand.asI64.text ~ "  ; " ~ "%.8f".format(this.operand.asF64)); break;
		}
    }

	ubyte[] toByteCode() {
		ubyteLong tmp;
		tmp.asLong = this.operand.asI64;
		if (this.takesArgument)
			return [cast(ubyte)this.type] ~ tmp.asUbytes;
		else
			return [cast(ubyte)this.type];
		assert(0);
	}
}

union ubyteLong
{
	ubyte[8] asUbytes;
	long asLong;
}

enum Result
{
	OK = 0,
	INSTRUCTION_STACK_OVERFLOW,
	STACK_OVERFLOW, STACK_UNDERFLOW,
	CALLSTACK_OVERFLOW, CALLSTACK_UNDERFLOW,
	INVALID_INST_POINTER, INVALID_STACK_POINTER,
	INVALID_INSTRUCTION,
	INVALID_DECIMAL, INVALID_INTEGER,
	NO_ARGUMENT_PROVIDED, UNKNOWN_LABEL,
	FILE_READ_ERROR, INVALID_FILE_HEADER,

}

struct DM
{
	bool halt;

    Inst[dmInstCapacity] instructions;
	long instructionCount;
    long instPointer;

    Word[dmStackCapacity] stack;
	long stackCount;

    long[dmCallStackCapacity] callStack;
	long callStackCount;
}

Result appendInstruction(DM* dm, Inst inst)
{
	if (dm.instructionCount >= dmInstCapacity)
		return Result.INSTRUCTION_STACK_OVERFLOW;

	dm.instructions[dm.instructionCount++] = inst;

	return Result.OK;
}

Result appendInstructions(DM* dm, Inst[] insts)
{
	foreach(inst; insts) {
		auto res = appendInstruction(dm, inst);
		if (res != Result.OK)
			return res;
	}

	return Result.OK;
}


Result loadByteCode(DM* dm, ubyte[] data)
{
	Inst[] instructions;
	bool expectingInstruction = true;

	for (ulong i = 0; i < data.length;) {
		if (expectingInstruction) {
			if (InstType.min > data[i] || data[i] > InstType.max)
				return Result.INVALID_INSTRUCTION;
			InstType type = cast(InstType)data[i];
			if (type.takesArgument)
				expectingInstruction = false;
			i += 1;
			instructions ~= Inst(type);
		} else {
			ubyte[8] tmp = data[i..i+8];
			instructions[$-1].operand.asI64 = (cast(ubyteLong)tmp).asLong;
			expectingInstruction = true;
			i += 8;
		}
	}
	return dm.appendInstructions(instructions);
}

Result loadFromFile(DM* dm, string filename)
{
	ubyte[] data;
	try
		data = cast(ubyte[])filename.read();
	catch (Exception o)
		return Result.FILE_READ_ERROR;

	if (data[0..4].assumeUTF == "DBC\2")
		data = data[4..$];
	else
		return Result.INVALID_FILE_HEADER;

	return dm.loadByteCode(data);
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
		return Result.INVALID_INST_POINTER;
	auto instruction = dm.instructions[dm.instPointer];

	final switch (instruction.type) {
	case InstType.PUSH:
		if (dm.stackCount >= dmInstCapacity)
			return Result.STACK_OVERFLOW;

		dm.stack[dm.stackCount] = instruction.operand;
		dm.stackCount++;
		break;

	case InstType.POP:
		if (dm.stackCount < 1)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stackCount--].asI64 = 0;
		break;

	case InstType.SWAP:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;

		auto temp = dm.stack[dm.stackCount - 1];
		dm.stack[dm.stackCount - 1] = dm.stack[dm.stackCount - 2];
		dm.stack[dm.stackCount - 2] = temp;
		break;

	case InstType.ADDI:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stackCount - 2].asI64 += dm.stack[dm.stackCount - 1].asI64;
		dm.stack[--dm.stackCount].asI64 = 0;
		break;

	case InstType.SUBI:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stackCount - 2].asI64 -= dm.stack[dm.stackCount - 1].asI64;
		dm.stack[--dm.stackCount].asI64 = 0;
		break;

	case InstType.MULI:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stackCount - 2].asI64 *= dm.stack[dm.stackCount - 1].asI64;
		dm.stack[--dm.stackCount].asI64 = 0;
		break;

	case InstType.DIVI:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stackCount - 2].asI64 /= dm.stack[dm.stackCount - 1].asI64;
		dm.stack[--dm.stackCount].asI64 = 0;
		break;

	case InstType.ADDF:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stackCount - 2].asF64 += dm.stack[dm.stackCount - 1].asF64;
		dm.stack[--dm.stackCount].asF64 = 0;
		break;

	case InstType.SUBF:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stackCount - 2].asF64 -= dm.stack[dm.stackCount - 1].asF64;
		dm.stack[--dm.stackCount].asF64 = 0;
		break;

	case InstType.MULF:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stackCount - 2].asF64 *= dm.stack[dm.stackCount - 1].asF64;
		dm.stack[--dm.stackCount].asF64 = 0;
		break;

	case InstType.DIVF:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stackCount - 2].asF64 /= dm.stack[dm.stackCount - 1].asF64;
		dm.stack[--dm.stackCount].asF64 = 0;
		break;

	case InstType.DUP:
		if (dm.stackCount >= dmStackCapacity)
			return Result.STACK_OVERFLOW;
		if (dm.stackCount < (instruction.operand.asI64 + 1))
			return Result.INVALID_STACK_POINTER;
		dm.stack[dm.stackCount++] = dm.stack[dm.stackCount - instruction.operand.asI64 - 2];
		break;

	case InstType.EQ:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stackCount - 1] == dm.stack[dm.stackCount - 2];
		dm.stack[dm.stackCount - 2].asI64 = res;
		dm.stackCount--;
		break;

	case InstType.NEQ:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stackCount - 1] != dm.stack[dm.stackCount - 2];
		dm.stack[dm.stackCount - 2].asI64 = res;
		dm.stackCount--;
		break;

	case InstType.GTI:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stackCount - 1].asI64 > dm.stack[dm.stackCount - 2].asI64;
		dm.stack[dm.stackCount - 2].asI64 = res;
		dm.stackCount--;
		break;

	case InstType.LTI:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stackCount - 1].asI64 < dm.stack[dm.stackCount - 2].asI64;
		dm.stack[dm.stackCount - 2].asI64 = res;
		dm.stackCount--;
		break;

	case InstType.GTU:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stackCount - 1].asU64 > dm.stack[dm.stackCount - 2].asU64;
		dm.stack[dm.stackCount - 2].asI64 = res;
		dm.stackCount--;
		break;

	case InstType.LTU:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stackCount - 1].asU64 < dm.stack[dm.stackCount - 2].asU64;
		dm.stack[dm.stackCount - 2].asI64 = res;
		dm.stackCount--;
		break;

	case InstType.GTF:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stackCount - 1].asF64 > dm.stack[dm.stackCount - 2].asF64;
		dm.stack[dm.stackCount - 2].asI64 = res;
		dm.stackCount--;
		break;

	case InstType.LTF:
		if (dm.stackCount < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stackCount - 1].asF64 < dm.stack[dm.stackCount - 2].asF64;
		dm.stack[dm.stackCount - 2].asI64 = res;
		dm.stackCount--;
		break;

	case InstType.JMPZ_ABS:
		if (instruction.operand.asI64 > dm.instructionCount || instruction.operand.asI64 < 0)
			return Result.INVALID_INST_POINTER;

		if (dm.stackCount < 1)
			return Result.STACK_UNDERFLOW;

		if (dm.stack[dm.stackCount - 1].asI64 != 0)
			break;

		dm.stack[--dm.stackCount].asI64 = 0;
		dm.instPointer = instruction.operand.asI64;
		return Result.OK;

	case InstType.JMPZ_REL:
		if ((dm.instPointer + instruction.operand.asI64) > dm.instructionCount || (dm.instPointer + instruction.operand.asI64) < 0)
			return Result.INVALID_INST_POINTER;

		if (dm.stackCount < 1)
			return Result.STACK_UNDERFLOW;

		if (dm.stack[dm.stackCount - 1].asI64 != 0)
			break;

		dm.stack[--dm.stackCount].asI64 = 0;
		dm.instPointer += instruction.operand.asI64;
		return Result.OK;

	case InstType.CALL:
		if (instruction.operand.asI64 > dm.instructionCount || instruction.operand.asI64 < 0)
			return Result.INVALID_INST_POINTER;

		if (dm.callStackCount >= dmCallStackCapacity)
			return Result.CALLSTACK_OVERFLOW;

		dm.callStack[dm.callStackCount++] = dm.instPointer;
		dm.instPointer = instruction.operand.asI64;

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
	}

	dm.instPointer++;
	return Result.OK;
}
