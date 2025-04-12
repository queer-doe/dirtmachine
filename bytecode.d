import std.algorithm;
import std.conv;
import std.file;
import std.format;
import std.math;
import std.stdio;
import std.string;

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
	case InstType.SWAP:
	case InstType.DUP:
	case InstType.JMPZ_REL:
	case InstType.JMPZ_ABS:
	case InstType.CALL:
		return true;
	}
}

long wordsPopped(InstType type)
{
	final switch (type) {
	case InstType.DUP:
	case InstType.SWAP:
		return -1;

	case InstType.HALT:
	case InstType.RET:
	case InstType.PUSH:
	case InstType.CALL:
		return  0;

	case InstType.JMPZ_REL:
	case InstType.JMPZ_ABS:
	case InstType.POP:
		return  1;

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
		return  2;
	}
}

long wordsPushed(InstType type)
{
	final switch (type) {
	case InstType.HALT:
	case InstType.POP:
	case InstType.RET:
	case InstType.SWAP:
	case InstType.JMPZ_REL:
	case InstType.JMPZ_ABS:
	case InstType.CALL:
		return 0;

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
	case InstType.PUSH:
	case InstType.DUP:
		return 1;
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
			sink("ret"); break;
		case InstType.PUSH:
			sink("push " ~ this.operand.asI64.text ~ "  ; " ~ "%.8f".format(this.operand.asF64)); break;
		case InstType.SWAP:
			sink("swap " ~ this.operand.asI64.text ~ "  ; " ~ "%.8f".format(this.operand.asF64)); break;
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
		ubytesLong tmp;
		tmp.asLong = this.operand.asI64;
		if (this.takesArgument)
			return [cast(ubyte)this.type] ~ tmp.asUbytes;
		else
			return [cast(ubyte)this.type];
		assert(0);
	}
}

union ubytesLong
{
	ubyte[8] asUbytes;
	long asLong;
}

enum Result
{
	OK = 0,
	INSTRUCTION_LIMIT_REACHED,
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

    Inst[] instructions;
    long instPointer;

    Word[] stack;

    long[] callStack;
}

Result appendInstruction(DM* dm, Inst inst)
{
	dm.instructions ~= inst;
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

	long entrypoint = (cast(ubytesLong)data[0..8]).asLong;

	for (ulong i = 8; i < data.length;) {
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
			instructions[$-1].operand.asI64 = (cast(ubytesLong)tmp).asLong;
			expectingInstruction = true;
			i += 8;
		}
	}

	dm.instPointer = entrypoint;

	return dm.appendInstructions(instructions);
}

Result loadFromFile(DM* dm, string filename)
{
	ubyte[] data;
	try
		data = cast(ubyte[])filename.read();
	catch (Exception o)
		return Result.FILE_READ_ERROR;

	if (data[0..4].assumeUTF == "DBC\3")
		data = data[4..$];
	else
		return Result.INVALID_FILE_HEADER;

	return dm.loadByteCode(data);
}

void dumpDm(DM* dm)
{
	int pad;
	try {
		pad = to!int(log10(cast(double)dm.instructions.length)+1);
	} catch (Exception) {
		pad = 0;
	}
	writeln("\n");
	writefln("Instructions: [%s]", dm.instructions.length);
	if (dm.instructions.length > 0)
		foreach (idx; 0..dm.instructions.length) {
			if (idx == dm.instPointer)
				writefln("%*d > %s", pad, idx, dm.instructions[idx]);
			else
				writefln("%*d   %s", pad, idx, dm.instructions[idx]);
		}
	else
		writeln("  [empty]");

	writefln("Stack: [%s]", dm.stack.length);
	foreach (idx; 0..dm.stack.length) {
		writeln("  ", dm.stack[idx]);
	}
	writeln("  [top]");

	writefln("Callstack: [%s]", dm.callStack.length);
	foreach (idx; 0..dm.callStack.length) {
		writeln("  ", dm.callStack[idx]);
	}
	writeln("  [top]");
}

Result executeOne(DM* dm)
{
	if (dm.instPointer > dm.instructions.length-1 || dm.instPointer < 0)
		return Result.INVALID_INST_POINTER;

	auto instruction = dm.instructions[dm.instPointer];

	final switch (instruction.type) {
	case InstType.PUSH:
		dm.stack ~= instruction.operand;
		break;

	case InstType.POP:
		if (dm.stack.length < 1)
			return Result.STACK_UNDERFLOW;

		dm.stack = dm.stack[0..$-1];
		break;

	case InstType.SWAP:
		if (dm.stack.length < (instruction.operand.asI64 + 1))
			return Result.STACK_UNDERFLOW;

		auto temp = dm.stack[dm.stack.length - 1];
		dm.stack[dm.stack.length - 1] = dm.stack[dm.stack.length - (1 + instruction.operand.asI64)];
		dm.stack[dm.stack.length - (1 + instruction.operand.asI64)] = temp;
		break;

	case InstType.ADDI:
		if (dm.stack.length < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stack.length - 2].asI64 += dm.stack[dm.stack.length - 1].asI64;
		dm.stack = dm.stack[0..$-1];
		break;

	case InstType.SUBI:
		if (dm.stack.length < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stack.length - 2].asI64 -= dm.stack[dm.stack.length - 1].asI64;
		dm.stack = dm.stack[0..$-1];
		break;

	case InstType.MULI:
		if (dm.stack.length < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stack.length - 2].asI64 *= dm.stack[dm.stack.length - 1].asI64;
		dm.stack = dm.stack[0..$-1];
		break;

	case InstType.DIVI:
		if (dm.stack.length < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stack.length - 2].asI64 /= dm.stack[dm.stack.length - 1].asI64;
		dm.stack = dm.stack[0..$-1];
		break;

	case InstType.ADDF:
		if (dm.stack.length < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stack.length - 2].asF64 += dm.stack[dm.stack.length - 1].asF64;
		dm.stack = dm.stack[0..$-1];
		break;

	case InstType.SUBF:
		if (dm.stack.length < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stack.length - 2].asF64 -= dm.stack[dm.stack.length - 1].asF64;
		dm.stack = dm.stack[0..$-1];
		break;

	case InstType.MULF:
		if (dm.stack.length < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stack.length - 2].asF64 *= dm.stack[dm.stack.length - 1].asF64;
		dm.stack = dm.stack[0..$-1];
		break;

	case InstType.DIVF:
		if (dm.stack.length < 2)
			return Result.STACK_UNDERFLOW;

		dm.stack[dm.stack.length - 2].asF64 /= dm.stack[dm.stack.length - 1].asF64;
		dm.stack = dm.stack[0..$-1];
		break;

	case InstType.DUP:
		if (dm.stack.length < (instruction.operand.asI64 + 1))
			return Result.INVALID_STACK_POINTER;

		dm.stack ~= dm.stack[$ - instruction.operand.asI64 - 1];
		break;

	case InstType.EQ:
		if (dm.stack.length < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stack.length - 1] == dm.stack[dm.stack.length - 2];
		dm.stack[dm.stack.length - 2].asI64 = res;
		dm.stack = dm.stack[0..$-1];
		break;

	case InstType.NEQ:
		if (dm.stack.length < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stack.length - 1] != dm.stack[dm.stack.length - 2];
		dm.stack[dm.stack.length - 2].asI64 = res;
		dm.stack = dm.stack[0..$-1];
		break;

	case InstType.GTI:
		if (dm.stack.length < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stack.length - 1].asI64 > dm.stack[dm.stack.length - 2].asI64;
		dm.stack[dm.stack.length - 2].asI64 = res;
		dm.stack = dm.stack[0..$-1];
		break;

	case InstType.LTI:
		if (dm.stack.length < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stack.length - 1].asI64 < dm.stack[dm.stack.length - 2].asI64;
		dm.stack[dm.stack.length - 2].asI64 = res;
		dm.stack = dm.stack[0..$-1];
		break;

	case InstType.GTU:
		if (dm.stack.length < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stack.length - 1].asU64 > dm.stack[dm.stack.length - 2].asU64;
		dm.stack[dm.stack.length - 2].asI64 = res;
		dm.stack = dm.stack[0..$-1];
		break;

	case InstType.LTU:
		if (dm.stack.length < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stack.length - 1].asU64 < dm.stack[dm.stack.length - 2].asU64;
		dm.stack[dm.stack.length - 2].asI64 = res;
		dm.stack = dm.stack[0..$-1];
		break;

	case InstType.GTF:
		if (dm.stack.length < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stack.length - 1].asF64 > dm.stack[dm.stack.length - 2].asF64;
		dm.stack[dm.stack.length - 2].asI64 = res;
		dm.stack = dm.stack[0..$-1];
		break;

	case InstType.LTF:
		if (dm.stack.length < 2)
			return Result.STACK_UNDERFLOW;
		long res = dm.stack[dm.stack.length - 1].asF64 < dm.stack[dm.stack.length - 2].asF64;
		dm.stack[dm.stack.length - 2].asI64 = res;
		dm.stack = dm.stack[0..$-1];
		break;

	case InstType.JMPZ_ABS:
		if (instruction.operand.asI64 > dm.instructions.length || instruction.operand.asI64 < 0)
			return Result.INVALID_INST_POINTER;

		if (dm.stack.length < 1)
			return Result.STACK_UNDERFLOW;

		if (dm.stack[dm.stack.length - 1].asI64 != 0) {
			dm.stack = dm.stack[0..$-1];
			break;
		}

		dm.stack = dm.stack[0..$-1];
		dm.instPointer = instruction.operand.asI64;
		return Result.OK;

	case InstType.JMPZ_REL:
		if ((dm.instPointer + instruction.operand.asI64) > dm.instructions.length || (dm.instPointer + instruction.operand.asI64) < 0)
			return Result.INVALID_INST_POINTER;

		if (dm.stack.length < 1)
			return Result.STACK_UNDERFLOW;

		if (dm.stack[dm.stack.length - 1].asI64 != 0) {
			dm.stack = dm.stack[0..$-1];
			break;
		}

		dm.stack = dm.stack[0..$-1];
		dm.instPointer += instruction.operand.asI64;
		return Result.OK;

	case InstType.CALL:
		if (instruction.operand.asI64 > dm.instructions.length || instruction.operand.asI64 < 0)
			return Result.INVALID_INST_POINTER;

		dm.callStack ~= dm.instPointer;
		dm.instPointer = instruction.operand.asI64;

		return Result.OK;

	case InstType.RET:
		if (dm.callStack.length < 1)
			return Result.CALLSTACK_UNDERFLOW;

		dm.instPointer = dm.callStack[$-1];
		dm.callStack = dm.callStack[0..$-1];

		break;

	case InstType.HALT:
		dm.halt = true;
		return Result.OK;
	}

	dm.instPointer++;
	return Result.OK;
}

Result executeUntilHalt(DM* dm, long limit = -1)
{
	while (dm.halt != true) {
		auto res = dm.executeOne();
		if (res != Result.OK) {
			dm.halt = true;
			return res;
		}
		if (limit > 0)
			limit--;

		if (limit == 0)
			return Result.INSTRUCTION_LIMIT_REACHED;
	}
	return Result.OK;
}


