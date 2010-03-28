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

	bool bak = false;
	union {
		// bak = false
		struct {
			Coords relPos = void, oBeg = void, ob2b = void, ob2e = void;
			AABB box = void;
			size_t boxIdx = void;
		}
		// bak = true
		struct { Coords actualPos = void, beg = void, end = void; }
	}

public:
	FungeSpace* space;

	static typeof(*this) opCall(Coords c, Coords delta, FungeSpace* s) {

		typeof(*this) cursor;
		with (cursor) {
			space = s;

			if (!space.findBox(c, box, boxIdx)) {

				if (!space.tryJumpToBox(c, delta, box, boxIdx)) {
					if (space.usingBak && space.bak.contains(c))
						bak = true;
					else
						infLoop(
							"IP diverged while being placed.",
							c.toString(), delta.toString());
				}
			}
			tessellate(c);
		}
		return cursor;
	}

	private bool inBox() {
		return bak ? contains(pos, beg, end)
		           : contains(relPos, ob2b, ob2e);
	}

	cell get()
	out (c) {
		debug (ExpensiveCursorChecks)
			assert ((*space)[pos] == c);
	} body {
		if (!inBox()) {
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
		return bak ? space.bak[pos]
		           : box.getNoOffset(relPos);
	}

	void set(cell c)
	out {
		debug (ExpensiveCursorChecks)
			assert ((*space)[pos] == c);
	} body {
		if (!inBox()) {
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
		bak ? space.bak[pos] = c
		    : box.setNoOffset(relPos, c);
	}

	Coords pos()         { return bak ? actualPos : relPos + oBeg; }
	void   pos(Coords c) { bak ? actualPos = c : (relPos = c - oBeg); }

	void invalidate() {
		auto p = pos;
		if (!getBox(p))
			// Just grab a box which we aren't contained in; skipMarkers will sort
			// it out
			box = space.boxen[boxIdx = 0];
	}

	private void tessellate(Coords p) {
		if (bak) {
			beg = space.bak.beg;
			end = space.bak.end;
			tessellateAt(p, space.boxen, beg, end);
			actualPos = p;
		} else {
			// Care only about boxes that are above box
			auto overlaps = new AABB[boxIdx];
			size_t i = 0;
			foreach (b; space.boxen[0..boxIdx])
				if (b.overlaps(box))
					overlaps[i++] = b;

			oBeg = box.beg;
			relPos = p - oBeg;

			// box is now only a view: it shares its data with the original box.
			// Be careful! Only contains and the *NoOffset functions in it work
			// properly, since the others (notably, getIdx and thereby
			// opIndex[Assign]) tend to depend on beg and end matching data.
			//
			// In addition, it is weird: its width and height are not its own, so
			// that its getNoOffsets work.
			tessellateAt(p, overlaps[0..i], box.beg, box.end);

			ob2b = box.beg - oBeg;
			ob2e = box.end - oBeg;
		}
	}

	private bool getBox(Coords p) {
		if (space.findBox(p, box, boxIdx)) {
			bak = false;
			tessellate(p);
			return true;

		} else if (space.usingBak && space.bak.contains(p)) {
			bak = true;
			tessellate(p);
			return true;

		} else
			return false;
	}

	void advance(Coords delta) { bak ? actualPos += delta : (relPos += delta); }
	void retreat(Coords delta) { bak ? actualPos -= delta : (relPos -= delta); }

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
					if (relPos == firstExit)
						infLoop(
							"IP found itself whilst ` ~doing~ `.",
							(relPos + oBeg).toString(), delta.toString());
				} else {
					firstExit    = relPos;
					gotFirstExit = true;
				}
			}
		`;
	}

	static if (befunge93) {
		void skipMarkers(Coords delta)
		in   { assert (!inBox()); }
		out  { assert ( inBox()); }
		body { pos = space.jumpToBox(pos, delta, box, boxIdx); }
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
					if (space.tryJumpToBox(p, delta, box, boxIdx))
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
						tessellate(space.jumpToBox(p, delta, box, boxIdx));
					}
				}
			}
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
		if (bak) {
			while (space.bak[actualPos] == ' ') {
				actualPos += delta;
				if (!contains(actualPos, beg, end))
					return false;
				++space.stats.space.lookups;
			}
		} else {
			while (box.getNoOffset(relPos) == ' ') {
				relPos += delta;
				if (!contains(relPos, ob2b, ob2e))
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
		if (bak) {
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
		} else {
			if (inMid)
				goto continuePrevBox;

			++space.stats.space.lookups;
			while (box.getNoOffset(relPos) == ';') {
				do {
					relPos += delta;
					if (!contains(relPos, ob2b, ob2e)) {
						inMid = true;
						return false;
					}
continuePrevBox:
					++space.stats.space.lookups;
				} while (box.getNoOffset(relPos) != ';')

				relPos += delta;
				if (!contains(relPos, ob2b, ob2e)) {
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

		if (!inBox())
			goto findBox;

		++space.stats.space.lookups;
		if (unsafeGet() == ' ') {
			while (!skipSpaces(delta)) {
findBox:
				auto p = pos;
				if (!getBox(p)) {
					mixin (DetectInfiniteLoop!("processing spaces in a string"));
					if (space.tryJumpToBox(p, delta, box, boxIdx))
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
