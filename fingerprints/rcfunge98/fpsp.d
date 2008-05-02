// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:14:13

module ccbi.fingerprints.rcfunge98.fpsp; private:

import tango.text.convert.Float : toFloat;
import math = tango.math.Math;
import tango.io.Stdout;

alias math.rndint round;

import ccbi.fingerprint;
import ccbi.instructions : reverse;
import ccbi.ip;
import ccbi.utils : popString;

// 0x46505350: FPSP
// Single precision floating point
// -------------------------------

static this() {
	mixin (Code!("FPSP"));

	fingerprints[FPSP]['A'] =& add;
	fingerprints[FPSP]['B'] =& sin;
	fingerprints[FPSP]['C'] =& cos;
	fingerprints[FPSP]['D'] =& div;
	fingerprints[FPSP]['E'] =& asin;
	fingerprints[FPSP]['F'] =& fromInt;
	fingerprints[FPSP]['G'] =& atan;
	fingerprints[FPSP]['H'] =& acos;
	fingerprints[FPSP]['I'] =& toInt;
	fingerprints[FPSP]['K'] =& ln;
	fingerprints[FPSP]['L'] =& log10;
	fingerprints[FPSP]['M'] =& mul;
	fingerprints[FPSP]['N'] =& neg;
	fingerprints[FPSP]['P'] =& print;
	fingerprints[FPSP]['Q'] =& sqrt;
	fingerprints[FPSP]['R'] =& fromASCII;
	fingerprints[FPSP]['S'] =& sub;
	fingerprints[FPSP]['T'] =& tan;
	fingerprints[FPSP]['V'] =& abs;
	fingerprints[FPSP]['X'] =& exp;
	fingerprints[FPSP]['Y'] =& pow;
}

union Union {
	float f;
	cell c;
}
static assert (Union.sizeof == float.sizeof);
Union u;
float f;

void add() { with (ip.stack) { u.c = pop; f = u.f; u.c = pop; u.f += f; push(u.c); } }
void sub() { with (ip.stack) { u.c = pop; f = u.f; u.c = pop; u.f -= f; push(u.c); } }
void mul() { with (ip.stack) { u.c = pop; f = u.f; u.c = pop; u.f *= f; push(u.c); } }
void div() { with (ip.stack) { u.c = pop; f = u.f; u.c = pop; u.f /= f; push(u.c); } }

void  sin() { u.c = ip.stack.pop; u.f = math. sin(u.f); ip.stack.push(u.c); }
void  cos() { u.c = ip.stack.pop; u.f = math. cos(u.f); ip.stack.push(u.c); }
void  tan() { u.c = ip.stack.pop; u.f = math. tan(u.f); ip.stack.push(u.c); }
void asin() { u.c = ip.stack.pop; u.f = math.asin(u.f); ip.stack.push(u.c); }
void acos() { u.c = ip.stack.pop; u.f = math.acos(u.f); ip.stack.push(u.c); }
void atan() { u.c = ip.stack.pop; u.f = math.atan(u.f); ip.stack.push(u.c); }

void neg() { u.c = ip.stack.pop; u.f *= -1;           ip.stack.push(u.c); }
void abs() { u.c = ip.stack.pop; u.f = math.abs(u.f); ip.stack.push(u.c); }

void pow () { with (ip.stack) { u.c = pop; f = u.f; u.c = pop; u.f = math.pow(u.f, f); push(u.c); } }

void sqrt () { u.c = ip.stack.pop; u.f = math.sqrt (u.f); ip.stack.push(u.c); }
void ln   () { u.c = ip.stack.pop; u.f = math.log  (u.f); ip.stack.push(u.c); }
void log10() { u.c = ip.stack.pop; u.f = math.log10(u.f); ip.stack.push(u.c); }
void exp  () { u.c = ip.stack.pop; u.f = math.exp  (u.f); ip.stack.push(u.c); }

void fromASCII() { auto str = popString(); try u.f = toFloat(cast(char[])str); catch { return reverse(); } ip.stack.push(u.c); }
void fromInt  () { auto c = ip.stack.pop; u.f = math.rndint(c); ip.stack.push(u.c); }

void toInt() { u.c = ip.stack.pop; ip.stack.push(cast(cell)round(u.f)); }
void print() { u.c = ip.stack.pop; Stdout.format("{:f6} ", u.f); }
