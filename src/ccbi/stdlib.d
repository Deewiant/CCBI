// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2007-01-20 21:56:07

// Stuff that could/should be in the standard library.
module ccbi.stdlib;

import tango.core.Exception   : IOException, PlatformException;
import tango.core.Traits      : isUnsignedIntegerType;
import tango.io.device.Device : Device;
import tango.io.model.IFile   : FileConst;
import tango.io.stream.Typed  : TypedInput;
import tango.math.Math        : min;
import tango.sys.Common;

import ccbi.templateutils : ToString;

public alias FileConst.NewlineString NewlineString;

A ipow(A, B)(A x, B exp) {
	static assert (isUnsignedIntegerType!(B));

	A n = 1;
	while (exp) {
		if (exp % 2) {
			n *= x;
			--exp;
		}
		x   *= x;
		exp /= 2;
	}
	return n;
}

// Tango's abs isn't templated...
T abs(T)(T n) { return n < 0 ? -n : n; }

T clampedAdd(T)(T a, T b) { return a > T.max - b ? T.max : a + b; }

private alias char[][] environment_t;
private size_t envCount = 0x20;
private size_t envSize = void;

private environment_t env;
bool envChanged = true;

version (Win32) {
	pragma (lib, "kernel32");

	extern (Windows) {
		void* GetEnvironmentStringsA();
		bool  FreeEnvironmentStringsA(in char**);
	}

	private size_t maxSize = 0x80;

	// Sums the lengths into the given pointer too
	environment_t environment(size_t* size = null) {
		if (!envChanged) {
			if (size)
				*size = envSize;
			return .env;
		}

		auto env = cast(char**)GetEnvironmentStringsA();

		if (!env)
			throw new PlatformException("Couldn't get environment");

		scope (exit) {
			if (!FreeEnvironmentStringsA(env))
				throw new PlatformException("Couldn't free environment");
		}

		auto arr = new environment_t(envCount);
		envSize = 0;

		size_t i = 0;
		for (auto str = cast(char*)env; *str; ++str) {

			auto val = new char[maxSize];

			size_t j = 0;

			while (*str) {
				if (j == val.length)
					val.length = 2 * val.length;
				val[j++] = *str++;
			}
			val.length = j;

			envSize += j;

			if (j > maxSize)
				maxSize = j;

			if (i == arr.length)
				arr.length = 2 * arr.length;
			arr[i++] = val;
		}
		arr.length = envCount = i;
		envChanged = false;
		arr.sort;
		return (.env = arr);
	}
} else version (Posix) {
	import tango.stdc.string : strlen;

	extern (C) extern char** environ;

	environment_t environment(size_t* size = null) {
		if (!envChanged) {
			if (size)
				*size = envSize;
			return .env;
		}

		auto arr = new environment_t(envCount);
		envSize = 0;

		size_t i = 0;
		for (auto p = environ; *p; ++p) {
			auto j = strlen(*p);

			envSize += j;

			if (i == arr.length)
				arr.length = 2 * arr.length;
			arr[i++] = (*p)[0..j];
		}
		if (size)
			*size = envSize;
		arr.length = envCount = i;
		envChanged = false;
		arr.sort;
		return (.env = arr);
	}
}

TypedInput!(ubyte) Sin;
private uint_fast16_t unget;

ubyte cget() {
	ubyte c;
	if (unget != unget.max) {
		c = cast(ubyte)unget;
		unget = unget.max;
	} else if (!Sin.read(c))
		throw new IOException("No more input available.");
	return c;
}
void cunget(ubyte c) { unget = c; }

// cput is in Utils

T[] stripr(T)(T[] s) {
	size_t i = s.length;
	foreach_reverse (c; s) {
		if (c != ' ')
			break;
		--i;
	}
	return s[0..i];
}

struct LineSplitter {
	private char[] src;

	int opApply(int delegate(ref char[]) f) {

		size_t prev = 0;
		for (size_t i = 0; i < src.length; ++i) {

			auto sepStart = i;

			if (src[i] == '\r') {
				if (i+1 < src.length && src[i+1] == '\n')
					++i;
			} else if (src[i] != '\n')
				continue;

			auto line = src[prev .. sepStart];
			if (auto ret = f(line))
				return ret;

			prev = i + 1;
		}
		if (prev <= src.length) {
			auto line = src[prev..$];
			return f(line);
		} else
			return 0;
	}
}

// A conduit for console output without Unicode translation
//
// Win32 code ripped off of Tango's (0.98 RC2) Console.Conduit, changed to use
// WriteConsoleA
//
// Posix code from DeviceConduit
class RawCoutDevice(bool stderr) : Device {
private:
	void error() {throw new IOException("RawCoutDevice :: "~ SysError.lastMsg);}

	version (Win32) {
		bool redirected;

		public this() {
			// stderr is -12, stdout is -11
			super.io.handle = GetStdHandle(-cast(DWORD)stderr - 11);

			if (io.handle is null) {
				io.handle = CreateFileA(
					"CONOUT$",
					GENERIC_READ | GENERIC_WRITE,
					FILE_SHARE_READ | FILE_SHARE_WRITE,
					null,
					OPEN_EXISTING,
					0,
					cast(HANDLE)0
				);

				if (io.handle is null)
					error();
			}

			DWORD dummy;
			redirected = !GetConsoleMode(io.handle, &dummy);
		}

		public override size_t write(void[] src) {
			if (redirected) {
				DWORD written;

				if (!WriteFile(io.handle, src.ptr, src.length, &written, null))
					error();

				return written;
			} else {
				DWORD i = src.length;

				if (i == 0)
					return 0;

				for (auto p = src.ptr, end = src.ptr + i; p < end; p += i)
					// avoid console buffer size limitations, write in chunks
					if (!WriteConsoleA(io.handle, p, min(end - p, 32*1024), &i, null))
						error();

				return src.length;
			}
		}
	} else { // Posix

		// stdout is 1, stderr is 2
		public this() { super.handle = cast(int)stderr + 1; }

		public override size_t write(void[] src) {
			ptrdiff_t written = posix.write(handle, src.ptr, src.length);
			if (written == -1)
				error();
			return written;
		}
	}

	public override size_t read(void[]) { return Eof; }
}

// Solves for x in the equation ax = b (mod 2^(U.sizeof * 8)), given nonzero a
// and b.
//
// Returns false if there was no solution.
//
// If there is a solution, returns true. A solution is stored in the result
// parameter.
//
// The second out parameter, "gcdLog", holds the binary logarithm of the number
// of solutions: that is, lg(gcd(a, 2^(U.sizeof * 8))). The solution count
// іtself can be constructed by raising two to that power, since it is
// guaranteed to be a power of two.
//
// Further solutions can be formed by adding 2^(U.sizeof * 8 - gcdLog) to the
// one solution given.
bool modDiv(U)(U a, U b, out U result, out ubyte gcdLog)
in {
	assert (a != 0);
} body {
	// modInv can't deal with even numbers, so handle that here
	gcdLog = 0;
	while (a % 2 == 0 && b % 2 == 0) {
		a /= 2;
		b /= 2;
		++gcdLog;
	}

	// a even and b odd: no solution
	if (a % 2 == 0)
		return false;

	result = modInv(a) * b;
	return true;
}
// Solves for x in the equation ax = 1 (mod 2^(U.sizeof * 8)), given a.
// Alternatively stated, finds the modular inverse of a in the same ring as the
// type's normal integer arithmetic works.
//
// For all unsigned integer types U and odd values a of that type, it holds
// that a * modInv!(U)(a) = 1.
//
// For even values, this asserts: there's no inverse.
//
// The comments speak of 32-bit throughout but this works for any unsigned
// type.
private U modInv(U)(U a)
out (inv) {
	assert (inv != 0);
} body {
	// Typedefs... this is the best we can easily do with respect to checking
	// whether it's an unsigned integer type or not.
	static assert (U.min == 0);

	// No solution if not coprime with 2^32
	assert (a % 2);

	// Extended Euclidean algorithm with a few tricks at the start to deal with
	// the fact that U can't represent the initial modulus

	// We need quot = floor(2^32 / a)
	//
	// floor(2^31 / a) * 2 differs from floor(2^32 / a) by at most 1. I seem
	// unable to discern what property a needs to have for them to differ, so we
	// figure it out using a possibly suboptimal method.
	U gcd = 1 << (U.sizeof * 8 - 1);
	U quot;

	if (a <= gcd)
		quot = gcd / a * cast(U)2;
	else
		// The above algorithm obviously doesn't work if a exceeds gcd:
		// fortunately, we know that quot = 1 in all those cases.
		quot = 1;

	// So now quot is either floor(2^32 / a) or floor(2^32 / a) - 1.
	//
	// 2^32 = quot * a + rem
	//
	// If quot is the former, then rem = -a * quot. Otherwise, rem = -a * (1 +
	// quot) and quot needs to be corrected.
	//
	// So we try the former case. For this to be the correct remainder, it
	// should be in the range [0,a). If it isn't, we know that quot is off by
	// one.
	U rem = -a * quot;

	if (rem >= a) {
		rem -= a;
		++quot;
	}

	// And now we can continue using normal division.
	//
	// We peeled only half of the first iteration above so the loop condition is
	// in the middle.
	U x = 0;
	for (U u = 1;;) {
		U oldX = x;

		gcd = a;
		a = rem;
		x = u;
		u = oldX - u*quot;

		if (!a) break;

		quot = gcd / a;
		rem  = gcd % a;
	}
	return x;
}

// gcd(2^(ucell.sizeof * 8), n) is a power of two: this returns the
// power, i.e. its binary logarithm.
ubyte gcdLog(U)(U n) {
	// Since one of the operands is a power of two, the result is also a
	// power of two: it's actually two to the power of (number of times we
	// can divide n by until it becomes odd). The proof is left as an
	// exercise to the reader.

	// Odd numbers have a trivial gcd of 1.
	if (n & 1)
		return 0;

	// We can abuse the bit representation of integers to do the
	// even-number case in a tricky way.

	// c is the trailing zero count, which we calculate; the gcd is then
	// 2^c. Algorithm adapted from:
	//
	// http://graphics.stanford.edu/~seander/bithacks.html#ZerosOnRightBinSearch
	// (Credits to Matt Whitlock and Andrew Shapira)
	ubyte c = 1;

	auto maskBits = U.sizeof * 8 / 2;
	auto mask = U.max >>> maskBits;

	while (mask > 1) {
		if ((n & mask) == 0) {
			n >>>= maskBits;
			c += maskBits;
		}
		maskBits /= 2;
		mask >>>= maskBits;
	}
	return c - (n & 1);
}

// All set by default
struct BitFields(F...) {
	private ubyte[(F.length + 7)/8] bits = ubyte.max;

	bool opIndex(size_t i) {
		assert (i < F.length);
		return (bits[i/8] & 1 << (i%8)) != 0;
	}
	bool opIndexAssign(bool b, size_t i) {
		assert (i < F.length);
		if (b)
			bits[i/8] |=   1 << (i%8);
		else
			bits[i/8] &= ~(1 << (i%8));
		return b;
	}

	void   setAll() { bits[] = ubyte.max; }
	void unsetAll() { bits[] = 0; }

	bool allUnset() {
		if (bits.length) {
			foreach (b; bits[0..$-1])
				if (b)
					return false;

			auto last = bits[$-1];
			for (ubyte i = 0; i < F.length % 8; ++i)
				if (last & 1 << i)
					return false;
		}

		return true;
	}

	mixin (BitFieldsHelper!(0, F));
}
private template BitFieldsHelper(size_t n, F...) {
	static if (F.length == 0)
		const BitFieldsHelper = "";
	else
		const BitFieldsHelper = "
			bool " ~F[0]~ "()       { return (*this)[" ~ToString!(n)~ "];     }
			bool " ~F[0]~ "(bool b) { return (*this)[" ~ToString!(n)~ "] = b; }"
			~ BitFieldsHelper!(n+1, F[1..$]);
}
