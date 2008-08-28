// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2008-08-10 12:26:22

module ccbi.fingerprints.rcfunge98._3dsp; private:

import tango.math.Math;

import ccbi.fingerprint;
import ccbi.instructions : reverse;
import ccbi.ip;
import ccbi.space;
import ccbi.utils;

// 0x33445350: 3DSP
// 3D space manipulation extension
// -------------------------------
static this() {
	mixin (Code!("3DSP", "_3DSP"));

	fingerprints[_3DSP]['A'] =& add;
	fingerprints[_3DSP]['B'] =& subtract;
	fingerprints[_3DSP]['C'] =& cross;
	fingerprints[_3DSP]['D'] =& dot;
	fingerprints[_3DSP]['L'] =& length;
	fingerprints[_3DSP]['M'] =& mulVector;
	fingerprints[_3DSP]['N'] =& normalize;
	fingerprints[_3DSP]['P'] =& copy;
	fingerprints[_3DSP]['R'] =& makeRotate;
	fingerprints[_3DSP]['S'] =& makeScale;
	fingerprints[_3DSP]['T'] =& makeTranslate;
	fingerprints[_3DSP]['U'] =& dup;
	fingerprints[_3DSP]['V'] =& to2D;
	fingerprints[_3DSP]['X'] =& transform;
	fingerprints[_3DSP]['Y'] =& mulMatrix;
	fingerprints[_3DSP]['Z'] =& scale;
}

union Union {
	float f;
	cell c;
}
static assert (Union.sizeof == float.sizeof);

float pop ()        { Union u; u.c = ip.stack.pop; return u.f; }
void  push(float f) { Union u; u.f = f; ip.stack.push(u.c); }

void popVec(float[] v) {
	assert (v.length == 3);

	v[2] = pop();
	v[1] = pop();
	v[0] = pop();
}
void pushVec(float[] v) {
	assert (v.length == 3);

	push(v[0]);
	push(v[1]);
	push(v[2]);
}

//////////

void add() {
	float[3] a = void, b = void;
	popVec(b);
	popVec(a);

	a[] += b[];

	pushVec(a);
}

void subtract() {
	float[3] a = void, b = void;
	popVec(b);
	popVec(a);

	a[] -= b[];

	pushVec(a);
}

void mulVector() {
	float[3] a = void, b = void;
	popVec(b);
	popVec(a);

	a[] *= b[];

	pushVec(a);
}

void cross() {
	float[3] a = void, b = void, c = void;
	popVec(b);
	popVec(a);

	c[0] = a[1]*b[2] - a[2]*b[1];
	c[1] = a[2]*b[0] - a[0]*b[2];
	c[2] = a[0]*b[1] - a[1]*b[0];

	pushVec(c);
}

void dot() {
	float[3] a = void, b = void;
	popVec(b);
	popVec(a);

	a[] *= b[];

	push(a[0] + a[1] + a[2]);
}

void scale() {
	float[3] v = void;
	popVec(v);
	float n = pop();

	v[] *= n;

	pushVec(v);
}

// helper
float len(float[] v) {
	assert (v.length == 3);
	return sqrt(v[0]*v[0] + v[1]*v[1] + v[2]*v[2]);
}

void length() {
	float[3] a = void;
	popVec(a);
	push(len(a));
}

void normalize() {
	float[3] a = void;
	popVec(a);
	a[] /= len(a);
	pushVec(a);
}

void dup() {
	float[3] a = void;
	 popVec(a);
	pushVec(a);
	pushVec(a);
}

void copy() {
	cellidx sx, sy, tx, ty;
	popVector(sx, sy);
	popVector(tx, ty);

	for (cellidx x = 0; x < 4; ++x)
	for (cellidx y = 0; y < 4; ++y)
		space[tx+x, ty+y] = space[sx+x, sy+y];
}

// helper
void writeMatrix(cellidx x, cellidx y, float[] m) {
	assert (m.length == 16);
	for (cellidx i = 0; i < 4; ++i)
	for (cellidx j = 0; j < 4; ++j) {
		Union u;
		u.f = m[4*j + i];
		space[x+i, y+j] = u.c;
	}
}

void makeRotate() {
	float angle = pop();
	cell axis = ip.stack.pop();
	cellidx x, y;
	popVector(x, y);

	if (!(axis >= 1 && axis <= 3))
		return reverse();

	angle *= PI/180;

	float s = sin(angle);
	float c = cos(angle);

	switch (axis) {
		case 1:
			writeMatrix(x, y,
				[1f, 0, 0, 0
				, 0, c,-s, 0
				, 0, s, c, 0
				, 0, 0, 0, 1]);
			break;
		case 2:
			writeMatrix(x, y,
				[ c, 0, s, 0
				, 0, 1, 0, 0
				,-s, 0, c, 0
				, 0, 0, 0, 1]);
			break;
		case 3:
			writeMatrix(x, y,
				[ c,-s, 0, 0
				, s, c, 0, 0
				, 0, 0, 1, 0
				, 0, 0, 0, 1]);
			break;
	}
}
void makeScale() {
	float[3] v = void;
	popVec(v);
	cellidx x, y;
	popVector(x, y);

	writeMatrix(x, y,
		[v[0],   0,   0,   0
		,   0,v[1],   0,   0
		,   0,   0,v[2],   0
		,   0,   0,   0,   1]);
}
void makeTranslate() {
	float[3] v = void;
	popVec(v);
	cellidx x, y;
	popVector(x, y);

	writeMatrix(x, y,
		[  1f,   0,   0,v[0]
		,   0,   1,   0,v[1]
		,   0,   0,   1,v[2]
		,   0,   0,   0,   1]);
}

void to2D() {
	float[3] v = void;
	popVec(v);
	if (v[2] != 0)
		v[0..2] /= v[2];

	Union u1 = void, u2 = void;
	u1.f = v[0];
	u2.f = v[1];
	ip.stack.push(u1.c, u2.c);
}

// helper
void readMatrix(float[] m, cellidx mx, cellidx my) {
	assert (m.length == 16);

	for (cellidx x = 0; x < 4; ++x)
	for (cellidx y = 0; y < 4; ++y) {
		Union u = void;
		u.c = space[mx+x, my+y];
		m[y*4 + x] = u.f;
	}
}

// helper
void mulMatrices
	(size_t ar, size_t ac, size_t br, size_t bc)
	(float[] a, float[] b, float[] r)
in {
	assert (a.length == ar*ac);
	assert (b.length == br*bc);
	assert (ac == br);
	assert (r.length == ar*bc);
} body {
	for (size_t i = 0; i < ar; ++i)
	for (size_t j = 0; j < bc; ++j) {
		float n = 0;
		for (size_t k = 0; k < ac; ++k)
			n += a[i*ac + k] * b[k*bc + j];
		r[i*bc + j] = n;
	}
}

unittest {
	float[16] a =
		[ 1, 2, 3, 4
		, 8, 7, 6, 5
		,-1, 0,-3,-8
		,-9,-2,-4,-6];
	float[4]
		b = [10,11,12,1],
		r = void;

	mulMatrices!(4,4,4,1)(a, b, r);

	assert (r == [72,234,-54,-166]);

	float[16]
		c = [ 10, 11, 12, 13
		    ,-10,-11,-12,-13
		    ,-16,-15, 17, 18
		    ,-18, 15,-17, 16],
		r2 = void;

	mulMatrices!(4,4,4,4)(a, c, r2);

	assert (r2 ==
		[-130f,   4, -29, 105
		, -176,  -4,  29, 201
		,  182, -86,  73,-195
		,  102,-107, -50,-259]);
}

void transform() {
	cellidx mx, my;
	popVector(mx, my);
	float[4] v = void;
	popVec(v[0..3]);
	v[3] = 1;

	float[16] m = void;
	readMatrix(m, mx, my);

	float[4] r = void;
	mulMatrices!(4,4,4,1)(m, v, r);
	pushVec(r[0..3]);
}

void mulMatrix() {
	cellidx tx, ty, ax, ay, bx, by;
	popVector(bx, by);
	popVector(ax, ay);
	popVector(tx, ty);

	float[16] a = void, b = void, r = void;
	readMatrix(b, bx, by);
	readMatrix(a, ax, ay);

	mulMatrices!(4,4,4,4)(b, a, r);

	for (cellidx x = 0; x < 4; ++x)
	for (cellidx y = 0; y < 4; ++y) {
		Union u = void;
		u.f = r[y*4 + x];
		space[tx+x, ty+y] = u.c;
	}
}
