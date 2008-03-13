// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-06-15 08:56:37

module ccbi.mini.funge;

import tango.io.Buffer;
import tango.io.FileConduit;
import tango.io.Stdout;

import ccbi.ip;

import ccbi.mini.instructions;
import ccbi.mini.vars;

MiniFungeInstruction*[][cell] minis;

struct MiniFungeInstruction {
	IP miniIp;
	typeof(*mSpace) miniSpace;
	char command = 0;

	void init() {
		miniIp = IP(&miniSpace, .ip);
	}

	void instruction() {
		miniIp. x = miniIp.y = miniIp.dy = 0;
		miniIp.dx = 1;

		rip    = ip;
		ip     = &miniIp;
		mSpace = &miniSpace;

		for (;;) {
			miniIp.gotoNextInstruction();

			execute(miniSpace[miniIp.x, miniIp.y]);

			if (mOver) {
				mOver = false;
				break;
			}

			if (mNeedMove)
				miniIp.move();
			else
				mNeedMove = true;
		}
	}

	private void execute(cell i) {
		if (miniIp.mode & IP.STRING) {
			if (i == '"') {
				miniIp.mode ^= IP.STRING;
			} else
				miniIp.stack.push(i);
		} else {
			if (i < miniIns.length) {
				auto instruction = miniIns[i];
				if (instruction)
					return instruction();
			}

			if (warnings) {
				Stdout.flush;
				Stderr.formatln(
					"Unavailable instruction '{0}'({1:d}) (0x{1:x}) encountered at ({}, {}) in Mini-Funge.",
					cast(char)i, i, miniIp.x, miniIp.y
				);
			}
			miniIns['r']();
		}
	}
}

// a simplified form of ccbi.utils.loadIntoFungeSpace
// also modified to read the Mini-Funge file format
bool loadMiniFunge(cell fing)
in {
	assert (miniMode != Mini.NONE);
} body {
	if (fing in minis)
		return true;

	auto fingStr = "\0\0\0\0.fl";

	fingStr[0] = cast(char)(fing >> 24);
	fingStr[1] = cast(char)(fing >> 16);
	fingStr[2] = cast(char)(fing >> 8);
	fingStr[3] = cast(char)(fing);

	scope FileConduit fc;
	try fc = new typeof(fc)(fingStr);
	catch {
		return false;
	}

	auto file = new Buffer(fc);
	auto ins = new MiniFungeInstruction; (*ins).init();
	ubyte i = 0; // the instruction char

	cellidx x, y;

	void put(ubyte t) { ins.miniSpace[x++, y] = cast(cell)t; }

	bool lineBreak, expected = false;

	for (uint ungot = 0x100;;) {
		ubyte[1] ar;
		ubyte c, d;

		if (ungot < 0x100) {
			c = cast(ubyte)ungot;
			ungot = 0x100;
		} else {
			if (file.read(ar) == Buffer.Eof)
				break;
			c = ar[0];
		}

		if (c == '=') {
			if (!(i >= 'A' && i <= 'Z'))
				return false;

			if (i) {
				minis[fing][i] = ins;
				ins = new MiniFungeInstruction; (*ins).init();
				x = y = 0;
			}

			if (file.read(ar) == Buffer.Eof)
				return false;
			i = ar[0];

			if (file.read(ar) == Buffer.Eof)
				return false;
			c = ar[0];

			expected = true;
		}

		if (c == '\r') {
			lineBreak = true;
			if (file.read(ar) != Buffer.Eof && ar[0] != '\n')
				ungot = ar[0];
			d = ar[0];

		} else if (c == '\n')
			lineBreak = true;
		else
			lineBreak = false;

		if (expected) {
			if (!lineBreak)
				return false;

			expected = false;
			continue;
		}

		if (lineBreak) {
			++y;
			x = 0;
		} else {
			if (y > ins.miniSpace.endY && c != ' ')
				ins.miniSpace.endY = y;

			if (x > ins.miniSpace.endX && c != ' ')
				ins.miniSpace.endX = x;

			else if (x < ins.miniSpace.begX && c != ' ')
				ins.miniSpace.begX = x;

			put(c);
		}
	}
	fc.close();

	minis[fing][i] = ins;

	return true;
}
