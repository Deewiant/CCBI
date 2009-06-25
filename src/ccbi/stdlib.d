// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:56:07

// Stuff that could/should be in the standard library.
module ccbi.stdlib;

import tango.core.Exception    : IOException, PlatformException;
import tango.core.Traits       : isUnsignedIntegerType;
import tango.io.Stdout         : Stdout, Stderr;
import tango.io.device.Conduit : OutputFilter;
import tango.io.model.IFile    : FileConst;
import tango.io.stream.Typed   : TypedInput;
import tango.math.Math         : min;
import tango.sys.Common;

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

private alias char[][] environment_t;
private size_t envSize = 0x20;

private environment_t env;
bool envChanged = true;

version (Win32) {
	pragma (lib, "kernel32");

	extern (Windows) {
		void* GetEnvironmentStringsA();
		bool  FreeEnvironmentStringsA(in char**);
	}

	private size_t maxSize = 0x80;

	environment_t environment() {
		if (!envChanged)
			return .env;

		auto env = cast(char**)GetEnvironmentStringsA();

		if (!env)
			throw new PlatformException("Couldn't get environment");

		scope (exit) {
			if (!FreeEnvironmentStringsA(env))
				throw new PlatformException("Couldn't free environment");
		}

		auto arr = new environment_t(envSize);

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

			if (j > maxSize)
				maxSize = j;

			if (i == arr.length)
				arr.length = 2 * arr.length;
			arr[i++] = val;
		}
		arr.length = envSize = i;
		envChanged = false;
		arr.sort;
		return (.env = arr);
	}
} else version (Posix) {
	import tango.stdc.string : strlen;

	extern (C) extern char** environ;

	environment_t environment() {
		if (!envChanged)
			return .env;

		auto arr = new environment_t(envSize);

		size_t i = 0;
		for (auto p = environ; *p; ++p) {
			auto j = strlen(*p);

			if (i == arr.length)
				arr.length = 2 * arr.length;
			arr[i++] = (*p)[0..j];
		}
		arr.length = envSize = i;
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

T[] stripr(T)(T[] s) {
	size_t i = s.length;
	foreach_reverse (c; s) {
		if (c != ' ')
			break;
		--i;
	}
	return s[0..i];
}

// a capturing filter on Stdout and Stderr to disable Unicode translation on
// console output
//
// Win32 code ripped off of Tango's (0.98 RC2) Console.Conduit, changed to use
// WriteConsoleA
//
// Posix code from DeviceConduit
class RawCoutFilter(bool stderr) : OutputFilter {
private:
	void error() {throw new IOException("RawCoutFilter :: "~ SysError.lastMsg);}

	typeof(Stdout.stream()) superArgs() {
		return stderr
			? Stderr.stream
			: Stdout.stream;
	}

	version (Win32) {
		HANDLE handle;
		bool redirected;

		public this() {
			reopen();

			super(superArgs());
		}

		void reopen() {
			// stderr is -12, stdout is -11
			handle = GetStdHandle(-cast(DWORD)stderr - 11);

			if (handle is null) {
				handle = CreateFileA(
					"CONOUT$",
					GENERIC_READ | GENERIC_WRITE,
					FILE_SHARE_READ | FILE_SHARE_WRITE,
					null,
					OPEN_EXISTING,
					0,
					cast(HANDLE)0
				);

				if (handle is null)
					error();
			}

			DWORD dummy;
			redirected = !GetConsoleMode(handle, &dummy);
		}

		public override size_t write(void[] src) {
			if (redirected) {
				DWORD written;

				if (!WriteFile(handle, src.ptr, src.length, &written, null))
					error();

				return written;
			} else {
				DWORD i = src.length;

				if (i == 0)
					return 0;

				for (auto p = src.ptr, end = src.ptr + i; p < end; p += i)
					// avoid console buffer size limitations, write in chunks
					if (!WriteConsoleA(handle, p, min(end - p, 32*1024), &i, null))
						error();

				return src.length;
			}
		}
	} else { // Posix

		// stdout is 1, stderr is 2
		const int handle = cast(int)stderr + 1;

		public this() {
			super(superArgs());
		}

		public override size_t write(void[] src) {
			ptrdiff_t written = posix.write(handle, src.ptr, src.length);
			if (written < 0)
				error();
			return written;
		}
	}
}

// Solves for x in the equation ax = 1 (mod 2^(U.sizeof * 8)), given a.
// Alternatively stated, finds the modular inverse of a in the same ring as the
// type's normal integer arithmetic works.
//
// For all unsigned integer types U and odd values a of that type, it holds
// that a * modInv!(U)(a) = 1.
//
// For even values, this returns 0: there's no inverse.
//
// The comments speak of 32-bit throughout but this works for any unsigned
// type.
U modInv(U)(U a) {
	static assert (isUnsignedIntegerType!(U));

	// No solution if not coprime with 2^32
	if (a % 2 == 0)
		return 0;

	// Extended Euclidean algorithm with a few tricks at the start to deal with
	// the fact that U can't represent the initial modulus

	// We need quot = floor(2^32 / p)
	//
	// floor(2^31 / p) * 2 differs from floor(2^32 / p) by at most 1. I seem
	// unable to discern what property p needs to have for them to differ, so we
	// figure it out using a possibly suboptimal method.
	U p   = a;
	U gcd = 1 << (U.sizeof * 8 - 1);
	U quot;

	if (p <= gcd)
		quot = gcd / p * cast(U)2;
	else
		// The above algorithm obviously doesn't work if p exceeds gcd:
		// fortunately, we know that quot = 1 in all those cases.
		quot = 1;

	// So now quot is either floor(2^32 / p) or floor(2^32 / p) - 1.
	//
	// 2^32 = quot * p + rem
	//
	// If quot is the former, then rem = -p * quot. Otherwise, rem = -p * (1 +
	// quot) and quot needs to be corrected.
	//
	// So we try the former case. For this to be the correct remainder, it
	// should be in the range [0,p). If it isn't, we know that quot is off by
	// one.
	U rem = -p * quot;

	if (rem >= p) {
		rem -= p;
		++quot;
	}

	// And now we can continue using normal division.
	//
	// We peeled only half of the first iteration above so the loop condition is
	// in the middle.
	U x = 0;
	for (U u = 1;;) {
		U oldX = x;

		gcd = p;
		p = rem;
		x = u;
		u = oldX - u*quot;

		if (!p) break;

		quot = gcd / p;
		rem  = gcd % p;
	}

	return x;
}

// Solves for x in the equation ax = b (mod 2^(U.sizeof * 8)), given nonzero a
// and b.
//
// Returns false if there was no solution; if there is a solution, it is stored
// in the out parameter and true is returned.
bool modDiv(U)(U a, U b, out U result) {

	// modInv can't deal with even numbers, so handle that here
	while (b % 2 == 0 && a % 2 == 0) {
		b /= 2;
		a /= 2;
	}
	if (b % 2 == 0)
		return false;

	result = a * modInv(b);
	return true;
}
