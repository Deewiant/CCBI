// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2010-04-17 11:33:40

module ccbi.fingerprints.rcfunge98.long_;

import ccbi.fingerprint;

mixin (Fingerprint!(
	"LONG",
	"Long Integers",

	"A", "add",
	"B", "abs",
	"D", "div",
	"E", "sext",
	"L", "shl",
	"M", "mul",
	"N", "neg",
	"O", "mod",
	"P", "print",
	"R", "shr",
	"S", "sub",
	"Z", "atoi"));

version (LDC) {
	version (D_InlineAsm_X86_64)
		version = LLVMAsm64;
	else
		// The intrinsic tends to cause ICEs if used on nonnative lengths...
		static if (size_t.sizeof >= cell.sizeof)
			version = Oadd;
}

template LONG() {

static if (cell.sizeof == 4)
	alias long lcell;
// Testing for cent is impossible with its current DMDFE implementation...
//else static if (cell.sizeof == 8 && is(cent))
//	alias cent lcell;

static if (is(lcell))
	union Long {
		version (BigEndian) align (1) struct { cell hi, lo; }
		else                align (1) struct { cell lo, hi; }
		lcell l;
	}
else
	struct Long {
		// Endianness doesn't matter here, but in theory compilers might do
		// better if the ordering matches the native bigger int...
		version (BigEndian) struct { ucell hi, lo; }
		else                struct { ucell lo, hi; }
	}

Long pop() {
	with (*cip.stack) {
		Long l;
		l.lo = pop;
		l.hi = pop;
		return l;
	}
}
void push(Long l) { cip.stack.push(l.hi, l.lo); }

void sext() { auto n = cip.stack.pop; Long l; l.lo = n; push(l); }

static if (is(lcell)) {
	import tango.text.convert.Integer : parse;

	void add() { auto a = pop(), b = pop(); b.l += a.l; push(b); }
	void sub() { auto a = pop(), b = pop(); b.l -= a.l; push(b); }
	void mul() { auto a = pop(), b = pop(); b.l *= a.l; push(b); }

	void div() { auto a = pop(), b = pop(); b.l = a.l ? b.l / a.l : 0; push(b); }
	void mod() { auto a = pop(), b = pop(); b.l = a.l ? b.l % a.l : 0; push(b); }

	void shl() { auto c = cip.stack.pop; auto n = pop(); n.l <<=             c % (n.sizeof * 8);  push(n); }
	void shr() { auto c = cip.stack.pop; auto n = pop(); n.l >>= cast(lcell)(c % (n.sizeof * 8)); push(n); }

	void neg() { auto n = pop(); n.l *= -1;        push(n); }
	void abs() { auto n = pop(); n.l  = .abs(n.l); push(n); }

	void print() {
		auto n = pop();
		version (TRDS)
			if (state.tick < ioAfter)
				return;
		try Sout(n.l)(' '); catch { reverse; }
	}

	void atoi() {
		auto s = popString();
		Long l;
		uint ate = void;
		l.l = parse(s, 10, &ate);
		if (ate != s.length)
			return reverse;
		push(l);
	}
} else {
	import tango.text.convert.Integer : convert;

	version (LLVMAsm64)
		import ldc.llvmasm;
	else
		import tango.math.BigInt;

	void add() { push(doAdd(pop(), pop())); }

	version (LLVMAsm64) {
		Long doAdd(Long a, Long b) {
			b.lo = __asm!(ucell)("addq $2, $0", "=r,0,r,~{flags}", b.lo, a.lo);
			b.hi = __asm!(ucell)("adcq $2, $0", "=r,0,r,~{flags}", b.hi, a.hi);
			return b;
		}
	} else version (Oadd) {
		struct Carry(T) { T n; bool c; }
		pragma (intrinsic, "llvm.uadd.with.overflow.i#") Carry!(T) oadd(T)(T,T);

		Long doAdd(Long a, Long b) {
			auto o = oadd(b.lo, a.lo);
			b.lo = o.n;
			b.hi += a.hi + o.c;
			return b;
		}
	} else
		Long doAdd(Long a, Long b) {
			b.lo += a.lo;
			if (b.lo < a.lo)
				++b.hi;
			b.hi += a.hi;
			return b;
		}

	void sub() {
		auto a = pop, b = pop();
		version (LLVMAsm64) {
			b.lo = __asm!(ucell)("subq $2, $0", "=r,0,r,~{flags}", b.lo, a.lo);
			b.hi = __asm!(ucell)("sbbq $2, $0", "=r,0,r,~{flags}", b.hi, a.hi);
		} else {
			if (b.lo < a.lo)
				--b.hi;
			b.lo -= a.lo;
			b.hi -= a.hi;
		}
		push(b);
	}

	void mul() { push(doMul(pop(), pop())); }
	private Long doMul(Long a, Long b) {
		version (LLVMAsm64) {
			// Based on: Software Optimization Guide for AMD Family 10h Processors
			// rev. 3.09, November 2008
			b = __asm!(Long)(
				"orq %rax, %rsi\n"
				"jnz 1f\n"
				"mulq %rdx\n"        // Both .hi are zero
				"jmp 2f\n"
			"1:"
				"imulq %rax, %rcx\n" // b.hi * a.lo
				"imulq %rbx, %rdx\n" // a.hi * b.lo
				"addq %rdx, %rcx\n"  // +
				"mulq %rbx\n"        // b.lo * a.lo
				"addq %rcx, %rdx\n"  // +
			"2:",
				"={ax},={dx},"
				"{cx},{bx},{dx},{ax},{si},"
				"~{flags}",
				b.hi, b.lo, a.hi, a.lo, b.hi);
		} else {
			// Multiply two N-bit numbers without an N-bit type. Split each into four
			// (N/4)-bit numbers (since we do have an N/2-bit type) and work on
			// those...
			auto all = a.lo &  cell.max >> cell.sizeof * 4;
			auto alh = a.lo >> cell.sizeof * 4;
			auto ahl = a.hi &  cell.max >> cell.sizeof * 4;
			auto ahh = a.hi >> cell.sizeof * 4;
			auto bll = b.lo &  cell.max >> cell.sizeof * 4;
			auto blh = b.lo >> cell.sizeof * 4;
			auto bhl = b.hi &  cell.max >> cell.sizeof * 4;
			auto bhh = b.hi >> cell.sizeof * 4;

			auto mll = all * bll;
			auto mlh = alh * blh;
			auto mhl = ahl * bhl;
			auto mhh = ahh * bhh;

			b.hi = mhl + mhh;

			version (Oadd) {
				auto o = oadd(mll, mlh);
				b.lo = o.n;
				if (o.c)
					++b.hi;
			} else {
				b.lo = mll + mlh;
				if (b.lo < mll)
					++b.hi;
			}
		}
		return b;
	}

	void div() {
		auto divisor = pop(), dividend = pop();

		if (!divisor.lo && !divisor.hi)
			return cip.stack.push(0,0);

		push(doDiv(dividend, divisor));
	}
	private Long doDiv(Long dividend, Long divisor) {
		version (LLVMAsm64) {
			// Based on: Software Optimization Guide for AMD Family 10h Processors
			// rev. 3.09, November 2008
			dividend = __asm!(Long)(
				"movq %rcx, %rsi\n"
				"xorq %rdx, %rsi\n"
				"sarq $$63, %rsi\n"
				"movq %rdx, %rdi\n"
				"sarq $$63, %rdi\n"
				"xorq %rdi, %rax\n"
				"xorq %rdi, %rdx\n"
				"subq %rdi, %rax\n"
				"sbbq %rdi, %rdx\n"
				"movq %rcx, %rdi\n"
				"sarq $$63, %rdi\n"
				"xorq %rdi, %rbx\n"
				"xorq %rdi, %rcx\n"
				"subq %rdi, %rbx\n"
				"sbbq %rdi, %rcx\n"
				"jz 2f\n"
				"cmpq %rbx, %rdx\n"
				"jb 1f\n"
				"movq %rax, %rcx\n"
				"movq %rdx, %rax\n"
				"xorq %rdx, %rdx\n"
				"divq %rbx\n"
				"xchgq %rax, %rcx\n"
			"1:"
				"divq %rbx\n"
				"movq %rcx, %rdx\n"
				"jmp 3f\n"
			"2:"
				"movq %rax, %r8\n"
				"movq %rbx, %r9\n"
				"movq %rdx, %r10\n"
				"movq %rcx, %rdi\n"
				"shrq $$1, %rdx\n"
				"rcrq $$1, %rax\n"
				"rorq $$1, %rdi\n"
				"rcrq $$1, %rbx\n"
				"bsrq %rcx, %rcx\n"
				"shrdq %cl, %rdi, %rbx\n"
				"shrdq %cl, %rdx, %rax\n"
				"shrq %cl, %rdx\n"
				"rolq $$1, %rdi\n"
				"divq %rbx\n"
				"movq %r8, %rbx\n"
				"movq %rax, %rcx\n"
				"imulq %rax, %rdi\n"
				"mulq %r9\n"
				"addq %rdi, %rdx\n"
				"subq %rax, %rbx\n"
				"movq %rcx, %rax\n"
				"movq %r10, %rcx\n"
				"sbbq %rdx, %rcx\n"
				"sbbq $$0, %rax\n"
				"xorq %rdx, %rdx\n"
			"3:"
				"xorq %rsi, %rax\n"
				"xorq %rsi, %rdx\n"
				"subq %rsi, %rax\n"
				"sbbq %rsi, %rdx\n",
				"={ax},={dx},"
				"{dx},{cx},{ax},{bx},"
				"~{si},~{di},~{r8},~{r9},~{r10},~{flags}",
				dividend.hi, divisor.hi, dividend.lo, divisor.lo);
		} else {
			auto dend = BigInt(dividend.hi);
			auto dsor = BigInt(divisor.hi);
			dend <<= cell.sizeof * 8;
			dend += dividend.lo;
			dsor <<= cell.sizeof * 8;
			dsor += divisor.lo;

			dend /= dsor;

			BigInt mod;
			mod += ucell.max;
			++mod;
			dividend.lo = (dend % mod).toLong();
			dividend.hi = (dend >> cell.sizeof * 8).toLong();
		}
		return dividend;
	}

	void mod() {
		auto divisor = pop(), dividend = pop();

		if (!divisor.lo && !divisor.hi)
			return cip.stack.push(0,0);

		push(doMod(dividend, divisor));
	}
	private Long doMod(Long dividend, Long divisor) {
		version (LLVMAsm64) {
			// Based on: Software Optimization Guide for AMD Family 10h Processors
			// rev. 3.09, November 2008
			dividend = __asm!(Long)(
				"movq %rdx, %rsi\n"
				"sarq $$63, %rsi\n"
				"movq %rdx, %rdi\n"
				"sarq $$63, %rdi\n"
				"xorq %rdi, %rax\n"
				"xorq %rdi, %rdx\n"
				"subq %rdi, %rax\n"
				"sbbq %rdi, %rdx\n"
				"movq %rcx, %rdi\n"
				"sarq $$63, %rdi\n"
				"xorq %rdi, %rbx\n"
				"xorq %rdi, %rcx\n"
				"subq %rdi, %rbx\n"
				"sbbq %rdi, %rcx\n"
				"jnz 2f\n"
				"cmpq %rbx, %rdx\n"
				"jae 1f\n"
				"divq %rbx\n"
				"movq %rdx, %rax\n"
				"movq %rcx, %rdx\n"
				"jmp 3f\n"
			"1:"
				"movq %rax, %rcx\n"
				"movq %rdx, %rax\n"
				"xorq %rdx, %rdx\n"
				"divq %rbx\n"
				"movq %rcx, %rax\n"
				"divq %rbx\n"
				"movq %rdx, %rax\n"
				"xorq %rdx, %rdx\n"
				"jmp 3f\n"
			"2:"
				"movq %rax, %r8\n"
				"movq %rbx, %r9\n"
				"movq %rdx, %r10\n"
				"movq %rcx, %r11\n"
				"movq %rcx, %rdi\n"
				"shrq $$1, %rdx\n"
				"rcrq $$1, %rax\n"
				"rorq $$1, %rdi\n"
				"rcrq $$1, %rbx\n"
				"bsrq %rcx, %rcx\n"
				"shrdq %cl, %rdi, %rbx\n"
				"shrdq %cl, %rdx, %rax\n"
				"shrq %cl, %rdx\n"
				"rolq $$1, %rdi\n"
				"divq %rbx\n"
				"movq %r8, %rbx\n"
				"movq %rax, %rcx\n"
				"imulq %rax, %rdi\n"
				"mulq %r9\n"
				"addq %rdi, %rdx\n"
				"subq %rax, %rbx\n"
				"movq %r10, %rcx\n"
				"sbbq %rdx, %rcx\n"
				"sbbq %rax, %rax\n"
				"movq %r11, %rdx\n"
				"andq %rax, %rdx\n"
				"andq %r9, %rax\n"
				"addq %rbx, %rax\n"
				"addq %rcx, %rdx\n"
			"3:"
				"xorq %rsi, %rax\n"
				"xorq %rsi, %rdx\n"
				"subq %rsi, %rax\n"
				"sbbq %rsi, %rdx\n",
				"={ax},={dx},"
				"{dx},{cx},{ax},{bx},"
				"~{si},~{di},~{r8},~{r9},~{r10},~{r11},~{flags}",
				dividend.hi, divisor.hi, dividend.lo, divisor.lo);
		} else {
			auto dend = BigInt(dividend.hi);
			auto dsor = BigInt(divisor.hi);
			dend <<= cell.sizeof * 8;
			dend += dividend.lo;
			dsor <<= cell.sizeof * 8;
			dsor += divisor.lo;

			dend %= dsor;

			BigInt mod;
			mod += ucell.max;
			++mod;
			dividend.lo = (dend % mod).toLong();
			dividend.hi = (dend >> cell.sizeof * 8).toLong();
		}
		return dividend;
	}

	void shl() {
		auto c = cip.stack.pop;
		auto m = c % (cell.sizeof * 8);
		auto n = pop();
		n.hi <<= m;
		n.hi |= n.lo >>> n.sizeof * 8 - m;
		n.lo <<= m;
		if (c & 1UL << cell.sizeof * 8) {
			n.hi = n.lo;
			n.lo = 0;
		}
		push(n);
	}
	void shr() {
		auto c = cip.stack.pop;
		auto m = c % (cell.sizeof * 8);
		auto n = pop();
		n.lo >>>= m;
		n.lo |= n.hi << n.sizeof * 8 - m;
		n.hi >>>= m;
		if (c & 1UL << cell.sizeof * 8) {
			n.lo = n.hi;
			n.hi = 0;
		}
		push(n);
	}

	void neg() {
		auto n = pop();
		n.hi = ~n.hi;
		n.lo = -n.lo;
		if (!n.lo)
			++n.hi;
		push(n);
	}
	void abs() {
		auto n = pop();
		if (cast(cell)n.hi < 0) {
			n.hi = ~n.hi;
			n.lo = -n.lo;
			if (!n.lo)
				++n.hi;
		}
		push(n);
	}

	void print() {
		auto n = pop();

		bool sign = false;

		if (n.hi & ~cell.max) {
			n.hi &= cell.max;
			sign = true;
		}

		// 3.32 ≈ lg(10)
		char[Long.sizeof*8 / 3.32 + 0.5] s;
		auto i = s.length;

		Long d;
		d.hi = 0;
		d.lo = 1000_0000_0000_0000_0000U; // Biggest that fits 64-bit ucell
		const DSZ = 19;

		while (n.lo | n.hi) {
			auto m = doMod(n, d).lo;
			n = doDiv(n, d);
			auto ni = i < DSZ ? 0 : i - DSZ;
			foreach_reverse (inout c; s[ni..i]) {
				c = m%10 + '0';
				m /= 10;
			}
			i = ni;
		}
		if (i == s.length)
			s[i = $-1] = '0';
		else
			while (i != s.length-1 && s[i] == '0')
				++i;

		try {
			if (sign)
				Sout('-');
			Sout(s[i..$])(' ');
		} catch { reverse; }
	}

	void atoi() {
		auto s = popString();
		size_t i = 0;
		bool sign = false;

		if (s.length > 0 && (s[0] == '-' | s[0] == '+')) {
			sign = s[0] == '-';
			++i;
		}
		if (i >= s.length)
			return reverse;

		Long m;
		m.hi = 0;
		m.lo = 1000_0000_0000_0000_0000U; // As in print()
		const MSZ = 19;

		Long n = {0,0};

		for (; i < s.length; i += MSZ) {
			auto eat = s[i..min(i+MSZ,$)];
			uint ate = void;
			auto v = convert(eat, 10, &ate);
			if (ate != eat.length)
				return reverse;

			Long a;
			a.hi = 0;
			a.lo = v;

			if (ate != MSZ)
				m.lo = ipow(10UL, ate);

			n = doMul(n, m);
			n = doAdd(n, a);
		}
		if (sign)
			n.hi |= ~cell.max;
		push(n);
	}
}

}
