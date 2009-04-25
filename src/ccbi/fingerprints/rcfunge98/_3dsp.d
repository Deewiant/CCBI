// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2008-08-10 12:26:22

module ccbi.fingerprints.rcfunge98._3dsp;

import ccbi.fingerprint;

// 0x33445350: 3DSP
// 3D space manipulation extension
// -------------------------------
mixin (Fingerprint!(
	"3DSP",

	"A", "add",
	"B", "subtract",
	"C", "cross",
	"D", "dot",
	"L", "length",
	"M", "mulVector",
	"N", "normalize",
	"P", "copy",
	"R", "makeRotate",
	"S", "makeScale",
	"T", "makeTranslate",
	"U", "dup",
	"V", "to2D",
	"X", "transform",
	"Y", "mulMatrix",
	"Z", "scale"
));

template _3DSP() {

import tango.math.Math : sqrt, sin, cos;

union Union {
	float f;
	cell c;
}
static assert (Union.sizeof == float.sizeof);

float pop ()        { Union u; u.c = cip.stack.pop; return u.f; }
void  push(float f) { Union u; u.f = f; cip.stack.push(u.c); }

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
	Coords
		s = popOffsetVector(),
		t = popOffsetVector();

	for (cell y = 0; y < 4; ++y, ++t.y, ++s.y) {
		for (cell x = 0; x < 4; ++x, ++t.x, ++s.x)
			space[t] = space[s];
		t.x -= 4;
		s.x -= 4;
	}
}

// helper
void writeMatrix(Coords c, float[] m) {
	assert (m.length == 16);
	for (cell y = 0; y < 4; ++y, ++c.y) {
		for (cell x = 0; x < 4; ++x, ++c.x) {
			Union u = void;
			u.f = m[4*y + x];
			space[c] = u.c;
		}
		c.x -= 4;
	}
}

void makeRotate() {
	float angle = pop();
	cell axis = cip.stack.pop();
	Coords pos = popOffsetVector();

	if (!(axis >= 1 && axis <= 3))
		return reverse();

	angle *= PI/180;

	float s = sin(angle);
	float c = cos(angle);

	switch (axis) {
		case 1:
			writeMatrix(pos,
				[1f, 0, 0, 0
				, 0, c,-s, 0
				, 0, s, c, 0
				, 0, 0, 0, 1]);
			break;
		case 2:
			writeMatrix(pos,
				[ c, 0, s, 0
				, 0, 1, 0, 0
				,-s, 0, c, 0
				, 0, 0, 0, 1]);
			break;
		case 3:
			writeMatrix(pos,
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

	writeMatrix(popOffsetVector(),
		[v[0],   0,   0,   0
		,   0,v[1],   0,   0
		,   0,   0,v[2],   0
		,   0,   0,   0,   1]);
}
void makeTranslate() {
	float[3] v = void;
	popVec(v);

	writeMatrix(popOffsetVector(),
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
	cip.stack.push(u1.c, u2.c);
}

// helper
void readMatrix(float[] m, Coords c) {
	assert (m.length == 16);

	for (cell y = 0; y < 4; ++y, ++c.y) {
		for (cell x = 0; x < 4; ++x, ++c.x) {
			Union u = void;
			u.c = space[c];
			m[y*4 + x] = u.f;
		}
		c.x -= 4;
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
	Coords mc = popOffsetVector();

	float[4] v = void;
	popVec(v[0..3]);
	v[3] = 1;

	float[16] m = void;
	readMatrix(m, mc);

	float[4] r = void;
	mulMatrices!(4,4,4,1)(m, v, r);
	pushVec(r[0..3]);
}

void mulMatrix() {
	Coords
		bc = popOffsetVector(),
		ac = popOffsetVector(),
		tc = popOffsetVector();

	float[16] a = void, b = void, r = void;
	readMatrix(b, bc);
	readMatrix(a, ac);

	mulMatrices!(4,4,4,4)(b, a, r);

	for (cell y = 0; y < 4; ++y, ++tc.y) {
		for (cell x = 0; x < 4; ++x, ++tc.x) {
			Union u = void;
			u.f = r[y*4 + x];
			space[tc] = u.c;
		}
		tc.x -= 4;
	}
}

}
