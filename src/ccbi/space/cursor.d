// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2009-09-20 11:59:10

module ccbi.space.cursor;

       import ccbi.exceptions;
       import ccbi.space.aabb;
public import ccbi.space.space;

struct Cursor(cell dim, bool befunge93) {
private:
	alias .Coords    !(dim)            Coords;
	alias .Dimension !(dim).Coords     InitCoords;
	alias .Dimension !(dim).contains   contains;
	alias .AABB      !(dim)            AABB;
	alias .FungeSpace!(dim, befunge93) FungeSpace;

	static if (befunge93)
		const ubyte mode = FungeSpace.STATIC;
	else
		ubyte mode = FungeSpace.STATIC;

	// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=1055
	// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=3991
	version (DigitalMars) {
		Coords relPos, oBeg, ob2b, ob2e;
		AABB box;
		size_t boxIdx;
		Coords actualPos, beg, end;
	} else union {
		// mode = DYNAMIC
		struct {
			// mode = STATIC
			Coords relPos = void;

			Coords oBeg = void, ob2b = void, ob2e = void;
			AABB box = void;
			size_t boxIdx = void;
		}
		// mode = BAK
		struct { Coords actualPos = void, beg = void, end = void; }
	}

public:
	FungeSpace* space;

	static typeof(*this) opCall(Coords c, Coords delta, FungeSpace* s) {

		typeof(*this) cursor;
		with (cursor) {
			space = s;

			static if (befunge93) {
				bool found = space.findBox(c, box, boxIdx);
				assert (found);

			} else if (!getBox(c)) {
				if (space.tryJumpToBox(c, delta, box, boxIdx, mode))
					tessellate(c);
				else
					infLoop("IP diverged while being placed.",
					        c.toString(), delta.toString());
			}
		}
		return cursor;
	}

	private bool inBox() {
		if (mode == FungeSpace.STATIC)
			return contains(relPos, InitCoords!(0), space.staticBox.REL_END);
		else if (mode == FungeSpace.DYNAMIC)
			return contains(relPos, ob2b, ob2e);
		else
			return contains(actualPos, beg, end);
	}

	cell get()
	out (c) {
		debug (ExpensiveCursorChecks)
			assert ((*space)[pos] == c);
	} body {
		static if (befunge93)
			assert (inBox());
		else if (!inBox()) {
			auto p = pos;
			if (!getBox(p)) {
				++space.stats.space.lookups;
				return ' ';
			}
		}
		return unsafeGet();
	}
	cell unsafeGet()
	in {
		assert (inBox());
	} out (c) {
		debug (ExpensiveCursorChecks)
			assert ((*space)[pos] == c);
	} body {
		++space.stats.space.lookups;

		if (mode == FungeSpace.STATIC)
			return space.staticBox.getNoOffset(relPos);
		else if (mode == FungeSpace.DYNAMIC)
			return box.getNoOffset(relPos);
		else
			return space.bak[pos];
	}

	void set(cell c)
	out {
		debug (ExpensiveCursorChecks)
			assert ((*space)[pos] == c);
	} body {
		static if (befunge93)
			assert (inBox());
		else if (!inBox()) {
			auto p = pos;
			if (!getBox(p))
				return (*space)[p] = c;
		}
		unsafeSet(c);
	}
	void unsafeSet(cell c)
	in {
		assert (inBox());
	} out {
		debug (ExpensiveCursorChecks)
			assert ((*space)[pos] == c);
	} body {
		++space.stats.space.assignments;

		if (mode == FungeSpace.STATIC)
			space.staticBox.setNoOffset(relPos, c);
		else if (mode == FungeSpace.DYNAMIC)
			box.setNoOffset(relPos, c);
		else
			space.bak[pos] = c;
	}

	Coords pos() {
		if (mode == FungeSpace.STATIC)
			return relPos + space.staticBox.BEG;
		else if (mode == FungeSpace.DYNAMIC)
			return relPos + oBeg;
		else
			return actualPos;
	}
	void pos(Coords c) {
		if (mode == FungeSpace.STATIC)
			relPos = c - space.staticBox.BEG;
		else if (mode == FungeSpace.DYNAMIC)
			relPos = c - oBeg;
		else
			actualPos = c;
	}

	static if (befunge93) void invalidate() { assert (false); }
	else
	void invalidate() {
		auto p = pos;
		if (!getBox(p)) {
			// Just grab a box which we aren't contained in; skipMarkers will sort
			// it out. Prefer STATIC because it's the fastest to work with.
			mode = FungeSpace.STATIC;
		}
	}

	private void tessellate(Coords p) {
		if (mode == FungeSpace.STATIC) {
			// staticBox is the topmost: nothing to do but set relPos.
			relPos = p - space.staticBox.BEG;

		} else if (mode == FungeSpace.BAK) {
			beg = space.bak.beg;
			end = space.bak.end;
			tessellateAt(p, space.boxen, beg, end);
			actualPos = p;
		} else {
			// box now becomes only a view: it shares its data with the original
			// box. Be careful! Only contains and the *NoOffset functions in it
			// work properly, since the others (notably, getIdx and thereby
			// opIndex[Assign]) tend to depend on beg and end matching data.
			//
			// In addition, it is weird: its width and height are not its own, so
			// that its getNoOffsets work.

			oBeg = box.beg;
			relPos = p - oBeg;

			// Care only about boxes that are above box
			tessellateAt(p, space.staticBox.BEG, space.staticBox.END, box.beg, box.end);
			foreach (b; space.boxen[0..boxIdx])
				if (b.overlaps(box))
					tessellateAt(p, b.beg, b.end, box.beg, box.end);

			ob2b = box.beg - oBeg;
			ob2e = box.end - oBeg;
		}
	}

	static if (!befunge93)
	private bool getBox(Coords p) {
		if (space.staticBox.contains(p)) {
			mode = FungeSpace.STATIC;
			tessellate(p);
			return true;
		}
		if (space.findBox(p, box, boxIdx)) {
			mode = FungeSpace.DYNAMIC;
			tessellate(p);
			return true;
		}
		if (space.usingBak && space.bak.contains(p)) {
			mode = FungeSpace.BAK;
			tessellate(p);
			return true;
		}
		return false;
	}

	void advance(Coords delta) {
		if (mode == FungeSpace.BAK)
			actualPos += delta;
		else
			relPos += delta;
	}
	void retreat(Coords delta) {
		if (mode == FungeSpace.BAK)
			actualPos -= delta;
		else
			relPos -= delta;
	}

	template DetectInfiniteLoopDecls() {
		version (detectInfiniteLoops) {
			Coords firstExit;
			bool gotFirstExit = false;
		}
	}
	template DetectInfiniteLoop(char[] doing) {
		const DetectInfiniteLoop = `
			version (detectInfiniteLoops) {
				if (gotFirstExit) {
					if (pos == firstExit)
						infLoop(
							"IP found itself whilst ` ~doing~ `.",
							pos.toString(), delta.toString());
				} else {
					firstExit    = pos;
					gotFirstExit = true;
				}
			}
		`;
	}

	static if (befunge93) {
		void skipMarkers(Coords delta)
		in   { assert (!inBox()); assert (mode == FungeSpace.STATIC); }
		out  { assert ( inBox()); assert (mode == FungeSpace.STATIC); }
		body {
			// Since only the cardinal deltas are available, only one axis can
			// wrap at a time.
			     if (relPos.x <  0) relPos.x = 79;
			else if (relPos.x > 79) relPos.x = 0;
			else if (relPos.y <  0) relPos.y = 24;
			else if (relPos.y > 24) relPos.y = 0;
		}
	} else
	void skipMarkers(Coords delta)
	in {
		assert (get() == ' ' || get() == ';');
	} out {
		assert (unsafeGet() != ' ');
		assert (unsafeGet() != ';');
	} body {
		mixin DetectInfiniteLoopDecls!();

		if (!inBox())
			goto findBox;

		if (unsafeGet() == ';')
			goto semicolon;

		do {
			while (!skipSpaces(delta)) {
findBox:
				auto p = pos;
				if (!getBox(p)) {
					mixin (DetectInfiniteLoop!("processing spaces"));
					if (space.tryJumpToBox(p, delta, box, boxIdx, mode))
						tessellate(p);
					else
						infLoop(
							"IP journeys forever in the void, "
							"futilely seeking a nonspace...",
							p.toString(), delta.toString());
				}
			}
			if (unsafeGet() == ';') {
semicolon:
				bool inMiddle = false;
				while (!skipSemicolons(delta, inMiddle)) {
					auto p = pos;
					if (!getBox(p)) {
						mixin (DetectInfiniteLoop!("jumping over semicolons"));
						tessellate(space.jumpToBox(p, delta, box, boxIdx, mode));
					}
				}
			} else
				break;
		} while (unsafeGet() == ' ')
	}
	static if (!befunge93)
	bool skipSpaces(Coords delta) {
		version (detectInfiniteLoops)
			if (delta == 0)
				infLoop(
					"Delta is zero: skipping spaces forever...",
					pos.toString(), delta.toString());

		++space.stats.space.lookups;

		// Evidently it is a noticeable performance improvement to lift out the
		// condition.
		if (mode == FungeSpace.STATIC) {
			while (space.staticBox.getNoOffset(relPos) == ' ') {
				relPos += delta;
				if (!contains(relPos, InitCoords!(0), space.staticBox.REL_END))
					return false;
				++space.stats.space.lookups;
			}
		} else if (mode == FungeSpace.DYNAMIC) {
			while (box.getNoOffset(relPos) == ' ') {
				relPos += delta;
				if (!contains(relPos, ob2b, ob2e))
					return false;
				++space.stats.space.lookups;
			}
		} else {
			while (space.bak[actualPos] == ' ') {
				actualPos += delta;
				if (!contains(actualPos, beg, end))
					return false;
				++space.stats.space.lookups;
			}
		}
		return true;
	}
	static if (!befunge93)
	bool skipSemicolons(Coords delta, ref bool inMid) {
		version (detectInfiniteLoops)
			if (delta == 0)
				infLoop(
					"Delta is zero: skipping semicolons forever...",
					pos.toString(), delta.toString());

		// As in skipSpaces, lifting out this condition is worthwhile but ugly.
		if (mode == FungeSpace.STATIC) {
			if (inMid)
				goto continuePrevStat;

			++space.stats.space.lookups;
			while (space.staticBox.getNoOffset(relPos) == ';') {
				do {
					relPos += delta;
					if (!contains(relPos, InitCoords!(0),space.staticBox.REL_END)) {
						inMid = true;
						return false;
					}
continuePrevStat:
					++space.stats.space.lookups;
				} while (space.staticBox.getNoOffset(relPos) != ';')

				relPos += delta;
				if (!contains(relPos, InitCoords!(0), space.staticBox.REL_END)) {
					inMid = false;
					return false;
				}
				++space.stats.space.lookups;
			}
		} else if (mode == FungeSpace.DYNAMIC) {
			if (inMid)
				goto continuePrevDyn;

			++space.stats.space.lookups;
			while (box.getNoOffset(relPos) == ';') {
				do {
					relPos += delta;
					if (!contains(relPos, ob2b, ob2e)) {
						inMid = true;
						return false;
					}
continuePrevDyn:
					++space.stats.space.lookups;
				} while (box.getNoOffset(relPos) != ';')

				relPos += delta;
				if (!contains(relPos, ob2b, ob2e)) {
					inMid = false;
					return false;
				}
				++space.stats.space.lookups;
			}
		} else if (mode == FungeSpace.BAK) {
			if (inMid)
				goto continuePrevBak;

			++space.stats.space.lookups;
			while (space.bak[actualPos] == ';') {
				do {
					actualPos += delta;
					if (!contains(actualPos, beg, end)) {
						inMid = true;
						return false;
					}
continuePrevBak:
					++space.stats.space.lookups;
				} while (space.bak[actualPos] != ';')

				actualPos += delta;
				if (!contains(actualPos, beg, end)) {
					inMid = false;
					return false;
				}
				++space.stats.space.lookups;
			}
		}
		return true;
	}
	static if (!befunge93)
	void skipToLastSpace(Coords delta) {

		mixin DetectInfiniteLoopDecls!();

		Coords p = void;

		if (!inBox()) {
			// We should retreat only if we saw at least one space, so don't jump
			// into the loop just because we fell out of the box: that doesn't
			// necessarily mean a space.
			if (!getBox(p = pos))
				goto jumpToBox;
		}

		++space.stats.space.lookups;
		if (unsafeGet() == ' ') {
			while (!skipSpaces(delta)) {
				if (!getBox(p = pos)) {
jumpToBox:
					mixin (DetectInfiniteLoop!("processing spaces in a string"));
					if (space.tryJumpToBox(p, delta, box, boxIdx, mode))
						tessellate(p);
					else
						infLoop(
							"IP journeys forever in the void, "
							"futilely seeking an end to the infinity...",
							p.toString(), delta.toString());
				}
			}
			retreat(delta);
		}
	}
}
private void infLoop(char[] msg, char[] pos, char[] delta) {
	throw new SpaceInfiniteLoopException("Funge-Space", pos, delta, msg);
}
