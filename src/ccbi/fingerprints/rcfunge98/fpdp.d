// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:14:10

module ccbi.fingerprints.rcfunge98.fpdp;

import ccbi.fingerprint;

// 0x46504450: FPDP
// Double precision floating point
// -------------------------------

mixin (Fingerprint!(
	"FPDP",

	"A", "add",
	"B", "sin",
	"C", "cos",
	"D", "div",
	"E", "asin",
	"F", "fromInt",
	"G", "atan",
	"H", "acos",
	"I", "toInt",
	"K", "ln",
	"L", "log10",
	"M", "mul",
	"N", "neg",
	"P", "print",
	"Q", "sqrt",
	"R", "fromASCII",
	"S", "sub",
	"T", "tan",
	"V", "abs",
	"X", "exp",
	"Y", "pow"
));

template FPDP() {

import math = tango.math.Math;
import tango.text.convert.Float : toFloat;

union Union {
	double d;
	align (1) struct { cell h, l; }
}
static assert (Union.sizeof == double.sizeof);

Union popDbl() {
	Union u;
	u.l = cip.stack.pop;
	u.h = cip.stack.pop;
	return u;
}
void pushDbl(Union u) {
	cip.stack.push(u.h);
	cip.stack.push(u.l);
}

void add() { auto u = popDbl; auto d = u.d; u = popDbl; u.d += d; pushDbl(u); }
void sub() { auto u = popDbl; auto d = u.d; u = popDbl; u.d -= d; pushDbl(u); }
void mul() { auto u = popDbl; auto d = u.d; u = popDbl; u.d *= d; pushDbl(u); }
void div() { auto u = popDbl; auto d = u.d; u = popDbl; u.d /= d; pushDbl(u); }
void pow() { auto u = popDbl; auto d = u.d; u = popDbl; u.d = math.pow(u.d, d); pushDbl(u); }

void  sin() { auto u = popDbl; u.d = math. sin(u.d); pushDbl(u); }
void  cos() { auto u = popDbl; u.d = math. cos(u.d); pushDbl(u); }
void  tan() { auto u = popDbl; u.d = math. tan(u.d); pushDbl(u); }
void asin() { auto u = popDbl; u.d = math.asin(u.d); pushDbl(u); }
void acos() { auto u = popDbl; u.d = math.acos(u.d); pushDbl(u); }
void atan() { auto u = popDbl; u.d = math.atan(u.d); pushDbl(u); }

void neg() { auto u = popDbl; u.d *= -1;           pushDbl(u); }
void abs() { auto u = popDbl; u.d = math.abs(u.d); pushDbl(u); }

void sqrt () { auto u = popDbl; u.d = math.sqrt (u.d); pushDbl(u); }
void ln   () { auto u = popDbl; u.d = math.log  (u.d); pushDbl(u); }
void log10() { auto u = popDbl; u.d = math.log10(u.d); pushDbl(u); }
void exp  () { auto u = popDbl; u.d = math.exp  (u.d); pushDbl(u); }

void fromASCII() {
	Union u;
	try u.d = toFloat(popString());
	catch {
		return reverse;
	}
	pushDbl(u);
}
void fromInt() { auto c = cip.stack.pop; Union u; u.d = math.rndint(c); pushDbl(u); }

void toInt() { auto u = popDbl; cip.stack.push(cast(cell)math.rndint(u.d)); }
void print() { auto u = popDbl; Stdout.format("{:f6} ", u.d); }

}
