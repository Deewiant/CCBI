// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:14:10

module ccbi.fingerprints.rcfunge98.fpdp; private:

import tango.text.convert.Float : toFloat;
import math = tango.math.Math;
import tango.io.Stdout;

alias math.rndint round;

import ccbi.fingerprint;
import ccbi.instructions : reverse;
import ccbi.ip;
import ccbi.utils : popString;

// 0x46504450: FPDP
// Double precision floating point
// -------------------------------

static this() {
	mixin (Code!("FPDP"));

	fingerprints[FPDP]['A'] =& add;
	fingerprints[FPDP]['B'] =& sin;
	fingerprints[FPDP]['C'] =& cos;
	fingerprints[FPDP]['D'] =& div;
	fingerprints[FPDP]['E'] =& asin;
	fingerprints[FPDP]['F'] =& fromInt;
	fingerprints[FPDP]['G'] =& atan;
	fingerprints[FPDP]['H'] =& acos;
	fingerprints[FPDP]['I'] =& toInt;
	fingerprints[FPDP]['K'] =& ln;
	fingerprints[FPDP]['L'] =& log10;
	fingerprints[FPDP]['M'] =& mul;
	fingerprints[FPDP]['N'] =& neg;
	fingerprints[FPDP]['P'] =& print;
	fingerprints[FPDP]['Q'] =& sqrt;
	fingerprints[FPDP]['R'] =& fromASCII;
	fingerprints[FPDP]['S'] =& sub;
	fingerprints[FPDP]['T'] =& tan;
	fingerprints[FPDP]['V'] =& abs;
	fingerprints[FPDP]['X'] =& exp;
	fingerprints[FPDP]['Y'] =& pow;
}

union Union {
	double d;
	align (1) struct { cell h, l; }
}
Union u;
double d;

void popDbl() {
	u.l = ip.stack.pop;
	u.h = ip.stack.pop;
}
void pushDbl() {
	ip.stack.push(u.h);
	ip.stack.push(u.l);
}

void add() { popDbl(); d = u.d; popDbl(); u.d += d; pushDbl(); }
void sub() { popDbl(); d = u.d; popDbl(); u.d -= d; pushDbl(); }
void mul() { popDbl(); d = u.d; popDbl(); u.d *= d; pushDbl(); }
void div() { popDbl(); d = u.d; popDbl(); u.d /= d; pushDbl(); }

void  sin() { popDbl(); u.d = math. sin(u.d); pushDbl(); }
void  cos() { popDbl(); u.d = math. cos(u.d); pushDbl(); }
void  tan() { popDbl(); u.d = math. tan(u.d); pushDbl(); }
void asin() { popDbl(); u.d = math.asin(u.d); pushDbl(); }
void acos() { popDbl(); u.d = math.acos(u.d); pushDbl(); }
void atan() { popDbl(); u.d = math.atan(u.d); pushDbl(); }

void neg() { popDbl(); u.d *= -1;           pushDbl(); }
void abs() { popDbl(); u.d = math.abs(u.d); pushDbl(); }

void pow () { popDbl(); d = u.d; popDbl(); u.d = math.pow(u.d, d); pushDbl(); }

void sqrt () { popDbl(); u.d = math.sqrt (u.d); pushDbl(); }
void ln   () { popDbl(); u.d = math.log  (u.d); pushDbl(); }
void log10() { popDbl(); u.d = math.log10(u.d); pushDbl(); }
void exp  () { popDbl(); u.d = math.exp  (u.d); pushDbl(); }

void fromASCII() { auto str = popString(); try u.d = toFloat(cast(char[])str); catch { return reverse(); } pushDbl(); }
void fromInt  () { auto c = ip.stack.pop; u.d = math.rndint(c); pushDbl(); }

void toInt() { popDbl(); ip.stack.push(cast(cell)round(u.d)); }
void print() { popDbl(); Stdout.format("{:f6} ", u.d); }
