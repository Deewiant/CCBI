// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:13:52

module ccbi.fingerprints.rcfunge98.file; private:

import Path = tango.io.Path;
import c = tango.stdc.stdio;

import ccbi.fingerprint;
import ccbi.instructions : reverse;
import ccbi.ip;
import ccbi.space;
import ccbi.utils;

// 0x46494c45: FILE
// File I/O functions
// ------------------
static this() {
	mixin (Code!("FILE"));

	fingerprints[FILE]['C'] =& fclose;
	fingerprints[FILE]['D'] =& unlink;
	fingerprints[FILE]['G'] =& fgets;
	fingerprints[FILE]['L'] =& ftell;
	fingerprints[FILE]['O'] =& fopen;
	fingerprints[FILE]['P'] =& fputs;
	fingerprints[FILE]['R'] =& fread;
	fingerprints[FILE]['S'] =& fseek;
	fingerprints[FILE]['W'] =& fwrite;
}

struct FileHandle {
	c.FILE* handle;
	cellidx x, y; // IO buffer in Funge-Space
}

FileHandle[] handles;

cell nextFreeHandle() {
	foreach (i, h; handles)
		if (h.handle is null)
			return cast(cell)i;

	auto n = handles.length;
	handles.length = (handles.length + 1) * 2;
	return cast(cell)n;
}

void fopen() {
	auto name = popStringz();
	cell modeCell = ip.stack.pop;
	cellidx x, y;
	popVector(x, y);

	cell h = nextFreeHandle();

	c.FILE* file;
	switch (modeCell) {
		case 0: file = c.fopen(name,  "rb"); if (!file) goto default; break;
		case 1: file = c.fopen(name,  "wb"); if (!file) goto default; break;
		case 2: file = c.fopen(name,  "ab"); if (!file) goto default; c.rewind(file); break;
		case 3: file = c.fopen(name, "r+b"); if (!file) goto default; break;
		case 4: file = c.fopen(name, "w+b"); if (!file) goto default; break;
		case 5: file = c.fopen(name, "a+b"); if (!file) goto default; c.rewind(file); break;
		default: return reverse();
	}

	handles[h].handle = file;
	handles[h].x = x;
	handles[h].y = y;

	ip.stack.push(h);
}

void fclose() {
	cell h = ip.stack.pop;
	if (h >= handles.length || !handles[h].handle)
		return reverse();

	if (c.fclose(handles[h].handle) == c.EOF)
		reverse();

	handles[h].handle = null;
}

void unlink() {
	auto fp = popString();
	if (Path.exists(fp) && !Path.isFolder(fp)) {
		try Path.remove(fp);
		catch { reverse(); }
	} else
		reverse();
}

void fgets() {
	cell h = ip.stack.pop;
	if (h >= handles.length || !handles[h].handle)
		return reverse();
	ip.stack.push(h);

	auto hnd = handles[h].handle;

	try {
		auto str = new char[80];
		size_t s = 0;
		int ch;

		void append() {
			if (s >= str.length)
				str.length = str.length * 2;
			str[s++] = cast(char)ch;
		}

		loop: for (;;) {
			ch = c.fgetc(hnd);
			switch (ch) {
				default: append(); break;

				case '\r':
					append();
					ch = c.fgetc(hnd);
					if (ch != '\n') {
						c.ungetc(ch, hnd);
						break loop;
					}

				case '\n': append(); break loop;

				case c.EOF:
					if (c.ferror(hnd)) {
						c.clearerr(hnd);
						return reverse();
					} else {
						assert (c.feof(hnd));
						break loop;
					}
			}
		}
		str.length = s;

		pushStringz(str);
		ip.stack.push(cast(cell)str.length);
	} catch {
		return reverse();
	}
}

void fputs() {
	auto str = popStringz();
	cell h = ip.stack.pop;
	if (h >= handles.length || !handles[h].handle)
		return reverse();
	ip.stack.push(h);

	if (c.fputs(cast(char*)str, handles[h].handle) == c.EOF) {
		assert (c.ferror(handles[h].handle));
		c.clearerr(handles[h].handle);
		return reverse();
	}
}

void ftell() {
	cell h = ip.stack.pop;
	if (h >= handles.length || !handles[h].handle)
		return reverse();
	ip.stack.push(h);

	auto p = c.ftell(handles[h].handle);
	if (p == -1) {
		assert (c.ferror(handles[h].handle));
		c.clearerr(handles[h].handle);
		return reverse();
	}

	ip.stack.push(cast(cell)p);
}

void fseek() {
	cell n = ip.stack.pop,
	     m = ip.stack.pop,
	     h = ip.stack.pop;
	if (h >= handles.length || !handles[h].handle)
		return reverse();
	ip.stack.push(h);

	switch (m) {
		case 0: if (c.fseek(handles[h].handle, n, c.SEEK_SET)) break; else return;
		case 1: if (c.fseek(handles[h].handle, n, c.SEEK_CUR)) break; else return;
		case 2: if (c.fseek(handles[h].handle, n, c.SEEK_END)) break; else return;
		default: break;
	}

	assert (c.ferror(handles[h].handle));
	c.clearerr(handles[h].handle);

	return reverse();
}

void fread() {
	cell n = ip.stack.pop,
	     h = ip.stack.pop;
	if (h >= handles.length || !handles[h].handle)
		return reverse();
	ip.stack.push(h);

	ubyte[] buf;
	try buf = new ubyte[n];
	catch {
		return reverse();
	}

	auto hnd = handles[h].handle;

	if (c.fread(buf.ptr, ubyte.sizeof, buf.length, hnd) != buf.length) {
		if (c.ferror(hnd)) {
			c.clearerr(hnd);
			return reverse();
		} else
			assert (c.feof(hnd));
	}

	foreach (i, b; buf)
		space[handles[h].x + cast(cellidx)i, handles[h].y] = cast(cell)b;
}

void fwrite() {
	cell n = ip.stack.pop,
	     h = ip.stack.pop;
	if (h >= handles.length || !handles[h].handle)
		return reverse();
	ip.stack.push(h);

	ubyte[] buf;
	try buf = new ubyte[n];
	catch {
		return reverse();
	}

	foreach (i, inout b; buf)
		b = cast(ubyte)space[handles[h].x + cast(cellidx)i, handles[h].y];

	auto hnd = handles[h].handle;

	if (c.fwrite(buf.ptr, ubyte.sizeof, buf.length, hnd) != buf.length) {
		assert (c.ferror(hnd));
		c.clearerr(hnd);
		return reverse();
	}
}
