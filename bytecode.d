import std.format;

enum InstType
{
    HALT = 0,
    PUSH, POP, SWAP,
    ADD, SUB, MUL, DIV,
    DUP,
	EQ, NEQ, GT, LT,
	JMPZ_REL, JMPZ_ABS,
}

struct Inst
{
    InstType type;
    long operand;

	string fn;
	ulong ln;

    void toString(scope void delegate(const(char)[]) sink) const
    {
		switch (this.type) {
		case InstType.HALT:
		case InstType.SWAP:
		case InstType.ADD:
		case InstType.SUB:
		case InstType.MUL:
		case InstType.DIV:
		case InstType.EQ:
		case InstType.NEQ:
		case InstType.GT:
		case InstType.LT:
			sink("%s".format(this.type));
			break;
		default:
			sink("%s(%s)".format(this.type, this.operand));
		}
    }

	long[] toByteCode() {
		return [cast(long)this.type, this.operand];

		if (0) // ???
		switch (this.type) {
		case InstType.HALT:
			return [cast(ubyte)InstType.HALT];

		case InstType.PUSH:
			return [cast(ubyte)InstType.PUSH, this.operand];

		case InstType.POP:
			return [cast(ubyte)InstType.POP];

		case InstType.SWAP:
			return [cast(ubyte)InstType.SWAP];

		case InstType.ADD:
			return [cast(ubyte)InstType.ADD];

		case InstType.SUB:
			return [cast(ubyte)InstType.SUB];

		case InstType.MUL:
			return [cast(ubyte)InstType.MUL];

		case InstType.DIV:
			return [cast(ubyte)InstType.DIV];

		case InstType.DUP:
			return [cast(ubyte)InstType.DUP, this.operand];

		case InstType.EQ:
			return [cast(ubyte)InstType.EQ, this.operand];

		case InstType.NEQ:
			return [cast(ubyte)InstType.NEQ, this.operand];

		case InstType.GT:
			return [cast(ubyte)InstType.GT, this.operand];

		case InstType.LT:
			return [cast(ubyte)InstType.LT, this.operand];

		case InstType.JMPZ_REL:
			return [cast(ubyte)InstType.JMPZ_REL, this.operand];

		case InstType.JMPZ_ABS:
			return [cast(ubyte)InstType.JMPZ_ABS, this.operand];

		default:
			return [];
		}
		assert(0);
	}
}
