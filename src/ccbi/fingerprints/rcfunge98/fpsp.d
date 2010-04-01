// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2007-01-20 21:14:13

module ccbi.fingerprints.rcfunge98.fpsp;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"FPSP",
	"Single precision floating point

      'F' rounds the number using the current rounding mode.
      'P' prints like the standard '.', with a space after the number.
      'R' reverses if the string doesn't represent a floating point number.\n",

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

template FPSP() {

import math = tango.math.Math;
import tango.text.convert.Float : toFloat;

union Union {
	float f;
	int c;
}
static assert (Union.sizeof == float.sizeof);

Union popFl() { Union u; u.c = cip.stack.pop; return u; }
void pushFl(Union u) { cip.stack.push(u.c); }

void add() { auto u = popFl; auto f = u.f; u = popFl; u.f += f; pushFl(u); }
void sub() { auto u = popFl; auto f = u.f; u = popFl; u.f -= f; pushFl(u); }
void mul() { auto u = popFl; auto f = u.f; u = popFl; u.f *= f; pushFl(u); }
void div() { auto u = popFl; auto f = u.f; u = popFl; u.f /= f; pushFl(u); }
void pow() { auto u = popFl; auto f = u.f; u = popFl; u.f = math.pow(u.f, f); pushFl(u); }

void  sin() { auto u = popFl; u.f = math. sin(u.f); pushFl(u); }
void  cos() { auto u = popFl; u.f = math. cos(u.f); pushFl(u); }
void  tan() { auto u = popFl; u.f = math. tan(u.f); pushFl(u); }
void asin() { auto u = popFl; u.f = math.asin(u.f); pushFl(u); }
void acos() { auto u = popFl; u.f = math.acos(u.f); pushFl(u); }
void atan() { auto u = popFl; u.f = math.atan(u.f); pushFl(u); }

void neg() { auto u = popFl; u.f *= -1;           pushFl(u); }
void abs() { auto u = popFl; u.f = math.abs(u.f); pushFl(u); }

void sqrt () { auto u = popFl; u.f = math.sqrt (u.f); pushFl(u); }
void ln   () { auto u = popFl; u.f = math.log  (u.f); pushFl(u); }
void log10() { auto u = popFl; u.f = math.log10(u.f); pushFl(u); }
void exp  () { auto u = popFl; u.f = math.exp  (u.f); pushFl(u); }

void fromASCII() {
	Union u;
	try u.f = toFloat(popString());
	catch {
		return reverse;
	}
	pushFl(u);
}
void fromInt() { auto c = cip.stack.pop; Union u; u.f = math.rndint(c); pushFl(u); }

void toInt() { auto u = popFl; cip.stack.push(cast(cell)math.rndint(u.f)); }
void print() {
	auto u = popFl;
	version (TRDS)
		if (state.tick < ioAfter)
			return;
	Sout.format("{:f6} ", u.f);
}

}
