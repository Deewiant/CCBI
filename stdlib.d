// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:56:07

// Stuff that could/should be in the standard library.
module ccbi.stdlib;

import tango.core.Exception : IOException, PlatformException;
import tango.core.Traits    : isUnsignedIntegerType;
import tango.io.Conduit     : OutputFilter;
import tango.io.Console     : Cin;
import tango.io.Stdout      : Stdout, Stderr;
import tango.io.FileConst;
import tango.io.FileConduit;
import tango.math.Math      : min;
import tango.sys.Common;

const FileConduit.Style WriteCreate = { FileConduit.Access.Write, FileConduit.Open.Create, FileConduit.Share.init, FileConduit.Cache.Stream, };

version (Posix)
         import tango.stdc.posix.unistd : isatty;

public alias FileConst.NewlineString NewlineString;

A ipow(A, B)(A z, B exp) {
	static assert (isUnsignedIntegerType!(B));

	A n = 1;
	while (exp--)
		n *= z;
	return n;
}

template ToUtf8(uint n) {
	static if (n < 10)
		const ToUtf8 = "" ~ cast(char)(n + '0');
	else
		const ToUtf8 = ToUtf8!(n / 10) ~ ToUtf8!(n % 10);
}

private alias char[][char[]] environment_t;

private environment_t env;
bool envChanged = true;

version (Win32) {
	pragma (lib, "kernel32");

	extern (Windows) {
		void* GetEnvironmentStringsA();
		bool  FreeEnvironmentStringsA(in char**);
	}

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

		environment_t arr;

		auto key = new char[20];
		auto val = new char[40];

		for (auto str = cast(char*)env; *str; ++str) {
			size_t k = 0, v = 0;

			while (*str != '=') {
				if (k == key.length)
					key.length = 2 * key.length;

				key[k++] = *str++;
			}

			++str;

			while (*str) {
				if (v == val.length)
					val.length = 2 * val.length;

				val[v++] = *str++;
			}

			arr[key[0..k].dup] = val[0..v].dup;
		}

		envChanged = false;

		return (.env = arr);
	}
} else {
	pragma (msg, "If this is not a Posix-compliant platform, trying to access environment\n"
	             "variables might cause an access violation and thereby a crash."
	);

	extern (C) extern char** environ;

	environment_t environment() {
		if (!envChanged)
			return .env;

		environment_t arr;

		for (auto p = environ; *p; ++p) {
			size_t i = 0;

			auto str = *p;

			while (*str++ != '=')
				++i;

			auto key = (*p)[0..i];

			i = 0;

			auto val = str;
			while (*str++)
				++i;

			arr[key] = val[0..i];
		}

		envChanged = false;

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

// a capturing filter on Stdout and Stderr to disable Unicode translation on console output
// Win32 code ripped off of Tango's (0.98 RC2) Console.Conduit, changed to to use WriteConsoleA
// Posix code from DeviceConduit
class RawCoutFilter(bool stderr) : OutputFilter {
private:
	void error() {throw new IOException("RawCoutFilter :: " ~ SysError.lastMsg);}

	typeof(Stdout.stream()) superArgs() {return stderr ? Stderr.stream : Stdout.stream;}

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

		public override uint write(void[] src) {
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
					// avoid console buffer size limitations, write in smaller chunks
					if (!WriteConsoleA(handle, p, min(end - p, 32 * 1024), &i, null))
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

		public override uint write(void[] src) {
			ptrdiff_t written = posix.write(handle, src.ptr, src.length);
			if (written < 0)
				error();
			return written;
		}
	}
}
