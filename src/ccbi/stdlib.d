// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:56:07

// Stuff that could/should be in the standard library.
module ccbi.stdlib;

import tango.core.Exception         : IOException, PlatformException;
import tango.core.Traits            : isUnsignedIntegerType;
import tango.io.Console             : Cin;
import tango.io.Stdout              : Stdout, Stderr;
import tango.io.device.Conduit      : OutputFilter;
import tango.io.device.File         : File;
import tango.io.model.IFile         : FileConst;
import tango.math.Math              : min;
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

char[] buffer;
size_t pos = size_t.max;

char cget() {
	if (pos >= buffer.length) {
		if (!Cin.readln(buffer, true))
			throw new IOException("No more input available.");
		pos = 0;
	}

	return buffer[pos++];
}

void cunget()
in   { assert (pos > 0); }
out  { assert (pos < buffer.length); }
body { --pos; }

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
