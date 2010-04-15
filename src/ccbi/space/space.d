// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2006-06-09 17:34:29

module ccbi.space.space;

import tango.io.device.Array      : Array;
import tango.io.model.IConduit    : OutputStream;
import tango.io.stream.Typed      : TypedOutput;
import tango.math.Math            : min, max;
import tango.stdc.stdlib          : malloc, free;
import tango.util.container.HashMap;

       import ccbi.templateutils;
       import ccbi.stats;
       import ccbi.stdlib;
       import ccbi.utils;
       import ccbi.space.aabb;
public import ccbi.space.coords;
public import ccbi.space.utils;

struct FungeSpace(cell dim, bool befunge93) {
	static assert (dim >= 1 && dim <= 3);
	static assert (!befunge93 || dim == 2);

	alias .AABB     !(dim)                         AABB;
	alias .Coords   !(dim)                         Coords;
	alias .Dimension!(dim).Coords                  InitCoords;
	alias .Dimension!(dim).getEndOfContiguousRange getEndOfContiguousRange;

	// All arbitrary
	private const
		NEWBOX_PAD = 8,

		// A box 5 units wide, otherwise of size NEWBOX_PAD.
		ACCEPTABLE_WASTE = Power!(size_t, NEWBOX_PAD, dim-1) * 5,

		BIGBOX_PAD = 512,

		// Implicitly defines an ACCEPTABLE_WASTE for BIGBOXes: it's
		// (BIG_SEQ_MAX_SPACING - 1) * BIGBOX_PAD^(dim-1).
		//
		// This is a distance between two cells, not the number of spaces between
		// them, and thus should always be at least 1.
		BIG_SEQ_MAX_SPACING = 4,

		// Threshold for switching to BakAABB. Only limits opIndexAssign, not
		// load().
		MAX_PLACED_BOXEN = 64,

		// All-bits-set up to the dimth
		DimensionBits = 0b111 & ~(1 << dim+1);

	static assert (NEWBOX_PAD          >= 0);
	static assert (BIGBOX_PAD          >  NEWBOX_PAD);
	static assert (BIG_SEQ_MAX_SPACING >= 1);

	private {
		struct Memory {
			AABB box, finalBox;
			Coords c;
		}
		// If we allocate this many boxes in a line, we'll allocate a big box.
		AnamnesicRing!(Memory, 3) recentBuf;
		bool justPlacedBig = void;
		Coords bigSequenceStart = void, firstPlacedBig = void;

		void delegate()[] invalidatees;

		Coords lastBeg = void, lastEnd = void;
	}
	package {
		AABB[] boxen;
		BakAABB!(dim) bak;
	}
	Stats* stats;

	static typeof(*this) opCall(Stats* stats, Array source) {
		typeof(*this) x;
		x.stats = stats;
		// Not being in with is WORKAROUND:
		// http://www.dsource.org/projects/ldc/ticket/397
		// http://www.dsource.org/projects/ldc/ticket/400
		x.load(source, null, InitCoords!(0), false);
		with (x) {
			if (boxen.length) {
				lastBeg = boxen[0].beg;
				lastEnd = boxen[0].end;
			}
		}
		return x;
	}

	typeof(*this) deepCopy() {
		typeof(*this) copy = *this;

		with (copy) {
			// deep copy space
			boxen = boxen.dup;
			foreach (i, ref aabb; boxen) {
				auto orig = aabb.data;
				aabb.data = cmalloc(aabb.size);
				aabb.data[0..aabb.size] = orig[0..aabb.size];
			}

			// Empty out invalidatees, they refer to the other space
			invalidatees.length = 0;
		}
		return copy;
	}

	void free() {
		foreach (box; boxen)
			.free(box.data);
		boxen.length = 0;
	}

	size_t boxCount() { return boxen.length; }

	void addInvalidatee(void delegate() i) { invalidatees ~= i; }

	cell opIndex(Coords c) {
		++stats.space.lookups;

		AABB box = void;
		if (findBox(c, box))
			return box[c];
		else if (usingBak)
			return bak[c];
		else
			return ' ';
	}
	void opIndexAssign(cell v, Coords c) {
		++stats.space.assignments;

		AABB box = void;
		if (findBox(c, box) || placeBoxFor(c, box))
			box[c] = v;
		else
			bak[c] = v;
	}

	static if (!befunge93) {
		void getLooseBounds(out Coords beg, out Coords end) {
			beg = lastBeg;
			end = lastEnd;
			foreach (box; boxen) {
				beg.minWith(box.beg);
				end.maxWith(box.end);
			}
			if (usingBak) {
				beg.minWith(bak.beg);
				end.maxWith(bak.end);
			}
		}
		void getTightBounds(out Coords beg, out Coords end) {
			bool begSp = (*this)[lastBeg] == ' ',
			     endSp = (*this)[lastEnd] == ' ';

			if (begSp && endSp) {
				beg = InitCoords!(cell.max,cell.max,cell.max);
				end = InitCoords!(cell.min,cell.min,cell.min);
			} else if (!begSp && !endSp) {
				beg = lastBeg;
				end = lastEnd;
			} else if (!endSp)
				beg = end = lastEnd;
			else {
				assert (!begSp);
				beg = end = lastBeg;
			}

			findBeg!(0)(beg);
			findEnd!(0)(end);
			static if (dim > 1) {
				findBeg!(1)(beg);
				findEnd!(1)(end);
			}
			static if (dim > 2) {
				findBeg!(2)(beg);
				findEnd!(2)(end);
			}

			if (usingBak) {
				// Might as well tighten the approximate bak.beg and bak.end while
				// we're at it
				auto bakBeg = bak.end;
				auto bakEnd = bak.beg;

				foreach (c, v; bak.data) {
					assert (v != ' ');
					bakBeg.minWith(c);
					bakEnd.maxWith(c);
				}
				bak.beg = bakBeg;
				bak.end = bakEnd;

				beg.minWith(bak.beg);
				end.maxWith(bak.end);
			}
			lastBeg = beg;
			lastEnd = end;
		}
		void findBeg(ubyte axis)(ref Coords beg) {
			bool removed = false;

			nextBox: for (size_t i = 0; i < boxen.length; ++i)
			if (boxen[i].beg.v[axis] < beg.v[axis]) {
				auto box = boxen[i];

				// Common case
				++stats.space.lookups;
				if (box.getNoOffset(InitCoords!(0)) != ' ') {
					beg.minWith(box.beg);
					continue;
				}

				auto last = box.end;

				// If our beg is already better than part of the box, don't check
				// the whole box
				if (box.end.v[axis] > beg.v[axis])
					last.v[axis] = beg.v[axis] - 1;

				last -= box.beg;

				Coords c = void;

				// Allow us to think the box is empty iff we're going to traverse
				// it completely
				bool emptyBox = box.end.v[axis] <= beg.v[axis];

				const CHECK = "{
					++stats.space.lookups;
					if (box.getNoOffset(c) != ' ') {

						beg.minWith(c + box.beg);
						if (beg.v[axis] <= box.beg.v[axis])
							continue nextBox;

						last.v[axis] = min(last.v[axis], c.v[axis]);
						emptyBox = false;
						break;
					}
				}";

				const start = InitCoords!(0);

				static if (axis == 0)
					mixin (CoordsLoop!(
						dim, "c", "start", "last", "<=", "+= 1",
						CHECK));

				else static if (axis == 1) {
					mixin (
						(dim==3 ? OneCoordsLoop!(
								      3, "c", "start", "last", "<=", "+= 1","")
								  : "") ~ "
						for (c.x = 0; c.x <= last.x; ++c.x)
						for (c.y = 0; c.y <= last.y; ++c.y)"
							~ CHECK);

				} else static if (axis == 2) {
					for (c.y = 0; c.y <= last.y; ++c.y)
					for (c.x = 0; c.x <= last.x; ++c.x)
					for (c.z = 0; c.z <= last.z; ++c.z)
						mixin (CHECK);
				} else
					static assert (false);

				if (emptyBox) {
					.free(box.data);
					boxen.removeAt(i--);
					removed = true;
					++stats.space.emptyBoxesDropped;
				}
			}
			if (removed)
				foreach (i; invalidatees)
					i();
		}
		void findEnd(ubyte axis)(ref Coords end) {
			bool removed = false;

			nextBox: for (size_t i = 0; i < boxen.length; ++i)
			if (boxen[i].end.v[axis] > end.v[axis]) {
				auto box = boxen[i];

				++stats.space.lookups;
				if (box[box.end] != ' ') {
					end.maxWith(box.end);
					continue;
				}

				auto last = InitCoords!(0);

				// Careful with underflow here: don't use max
				if (box.beg.v[axis] < end.v[axis])
					last.v[axis] = end.v[axis] + 1 - box.beg.v[axis];

				Coords c = void;

				bool emptyBox = box.beg.v[axis] >= end.v[axis];

				const CHECK = "{
					++stats.space.lookups;
					if (box.getNoOffset(c) != ' ') {

						end.maxWith(c + box.beg);
						if (end.v[axis] >= box.end.v[axis])
							continue nextBox;

						last.v[axis] = max(last.v[axis], c.v[axis]);
						emptyBox = false;
						break;
					}
				}";

				auto start = box.end - box.beg;

				static if (axis == 0)
					mixin (CoordsLoop!(
						dim, "c", "start", "last", ">=", "-= 1",
						CHECK));

				else static if (axis == 1) {
					mixin (
						(dim==3 ? OneCoordsLoop!(
								      3, "c", "start", "last", ">=", "-= 1","")
								  : "") ~ "
						for (c.x = start.x; c.x >= last.x; --c.x)
						for (c.y = start.y; c.y >= last.y; --c.y)"
							~ CHECK);

				} else static if (axis == 2) {
					for (c.y = start.y; c.y >= last.y; --c.y)
					for (c.x = start.x; c.x >= last.x; --c.x)
					for (c.z = start.z; c.z >= last.z; --c.z)
						mixin (CHECK);
				} else
					static assert (false);

				if (emptyBox) {
					.free(box.data);
					boxen.removeAt(i--);
					removed = true;
					++stats.space.emptyBoxesDropped;
				}
			}
			if (removed)
				foreach (i; invalidatees)
					i();
		}
	}

package:
	bool usingBak() { return bak.data !is null; }

	Coords jumpToBox(
		Coords pos, Coords delta, out AABB box, out size_t idx, out bool hitBak)
	{
		bool found = tryJumpToBox(pos, delta, box, idx, hitBak);
		assert (found);
		return pos;
	}
	bool tryJumpToBox(
		ref Coords pos, Coords delta,
		out AABB aabb, out size_t boxIdx, out bool hitBak)
	in {
		AABB _;
		assert (!findBox(pos, _));
	} body {
		alias Dimension!(dim).rayIntersects rayIntersects;

		ucell moves = 0;
		Coords pos2 = void;
		size_t idx  = void;
		ucell  m    = void;
		Coords c    = void;
		foreach (i, box; boxen) {
			if (rayIntersects(pos, delta, box.beg, box.end, m, c)
			 && (m < moves || !moves))
			{
				pos2  = c;
				idx   = i;
				moves = m;
			}
		}

		if (usingBak && rayIntersects(pos, delta, bak.beg, bak.end, m, c)
		             && (m < moves || !moves))
		{
			pos    = c;
			hitBak = true;
			return true;
		}
		if (moves) {
			pos    = pos2;
			boxIdx = idx;
			aabb   = boxen[idx];
			hitBak = false;
			return true;
		}
		return false;
	}

	// The AABB parameter has to be ref regardless of what the proper semantics
	// seem. (Or rather, it's more convenient to make it ref than to make
	// temporaries at the call sites where it matters.)
	//
	// Consider: we move to just outside a box in stringmode. (In other cases we
	// would move into the box, but in stringmode we have to stop at the space.)
	// We are now not in the box we were in previously, so we check findBox()
	// for a new one, but don't find one: fine, we're at a space.
	//
	// Next we move by a convenient delta into (0,0), which just so happens to
	// be what the "out" in findBox initialized the box to. Alas, it's not the
	// correct box, just something with a null pointer and beg and end: boom.
	//
	// Aside from that, it's a nice optimization, since we don't then waste
	// cycles nullifying it.
	bool findBox(Coords pos, ref AABB aabb, out size_t idx) {
		foreach (i, box; boxen) if (box.contains(pos)) {
			idx  = i;
			aabb = box;
			return true;
		}
		return false;
	}
	private bool findBox(Coords pos, ref AABB aabb) {
		size_t _;
		return findBox(pos, aabb, _);
	}

private:
	bool placeBoxFor(Coords c, out AABB aabb) {
		if (boxen.length >= MAX_PLACED_BOXEN) {
			if (bak.data is null)
				bak.initialize(c);
			return false;
		}

		auto box = getBoxFor(c);
		placeBox(box, &c, &aabb);
		recentBuf.push(Memory(box, aabb, c));
		return true;
	}
	AABB getBoxFor(Coords c)
	in {
		foreach (box; boxen)
			assert (!box.contains(c));
	} out (box) {
		assert (box.safeContains(c));
	} body {
		if (recentBuf.size() == recentBuf.CAPACITY) {

			Memory[recentBuf.CAPACITY] a;
			auto recents = a[0..recentBuf.read(a)];

			if (justPlacedBig) {

				auto last = recents[$-1].finalBox;

				// See if c is at bigSequenceStart except for one axis, along which
				// it's just past last.end or last.beg.
				{bool sawEnd = false, sawBeg = false;
				outer: for (cell i = 0; i < dim; ++i) {
					if (c.v[i] >  last.end.v[i] &&
					    c.v[i] <= last.end.v[i] + BIG_SEQ_MAX_SPACING)
					{
						if (sawBeg)
							break;
						sawEnd = true;

						// We can break here since we want, for any axis i, all other
						// axes to be at bigSequenceStart. Even if one of the others
						// is a candidate for this if block, the fact that the
						// current axis isn't at bigSequenceStart means that that one
						// wouldn't be correct.
						for (cell j = i + 1; j < dim; ++j)
							if (c.v[j] != bigSequenceStart.v[j])
								break outer;

						// We're making a line/rectangle/box (depending on the value
						// of i): extend last along the axis where c was outside it.
						auto end = last.end;
						end.v[i] += BIGBOX_PAD;
						return AABB.unsafe(c, end);

					// First of many places in this function where we need to check
					// the negative direction separately from the positive.
					} else if (c.v[i] <  last.beg.v[i] &&
					           c.v[i] >= last.beg.v[i] - BIG_SEQ_MAX_SPACING)
					{
						if (sawEnd)
							break;
						sawBeg = true;
						for (cell j = i + 1; j < dim; ++j)
							if (c.v[j] != bigSequenceStart.v[j])
								break outer;

						auto beg = last.beg;
						beg.v[i] -= BIGBOX_PAD;
						return AABB.unsafe(beg, c);

					} else if (c.v[i] != bigSequenceStart.v[i])
						break;
				}}

				// Match against firstPlacedBig. This is for the case when we've
				// made a few non-big boxes and then hit a new dimension for the
				// first time in a location which doesn't match with the actual
				// box. E.g.:
				//
				// BsBfBBB
				// BBBc  b
				//  n
				//
				// B being boxes, c being c, and f being firstPlacedBig. The others
				// are explained below.
				static if (dim > 1) {
					bool foundOneMatch = false;
					for (cell i = 0; i < dim; ++i) {
						if (
							(c.v[i] >  firstPlacedBig.v[i] &&
							 c.v[i] <= firstPlacedBig.v[i] + BIG_SEQ_MAX_SPACING))
						{
							// One other axis should match firstPlacedBig exactly, or
							// we'd match a point like the b in the graphic, which we
							// do not want.
							if (!foundOneMatch) {
								for (cell j = i+1; j < dim; ++j) {
									if (c.v[j] == firstPlacedBig.v[j]) {
										foundOneMatch = true;
										break;
									}
								}
								// We can break instead of continue, since this axis
								// wasn't equal (in here instead of the else), nor were
								// any of the previous ones (!foundOneMatch before
								// this), nor were any of the following ones
								// (!foundOneMatch after the above loop).
								if (!foundOneMatch)
									break;
							}

							auto end = last.end;
							end.v[i] += BIGBOX_PAD;

							// We want to start the resulting box from
							// bigSequenceStart (s in the graphic) instead of c, since
							// after we've finished the line on which c lies, we'll be
							// going to the point marked n next.
							//
							// If we were to make a huge box which doesn't include the
							// n column, we'd not only have to have a different
							// heuristic for the n case but we'd need to move all the
							// data in the big box to the resulting different big box
							// anyway. This way is much better.
							return AABB.unsafe(bigSequenceStart, end);

						// Negative direction
						} else if (
							(c.v[i] <  firstPlacedBig.v[i] &&
							 c.v[i] >= firstPlacedBig.v[i] - BIG_SEQ_MAX_SPACING))
						{
							if (!foundOneMatch) {
								for (cell j = i+1; j < dim; ++j) {
									if (c.v[j] == firstPlacedBig.v[j]) {
										foundOneMatch = true;
										break;
									}
								}
								if (!foundOneMatch)
									break;
							}

							auto beg = last.beg;
							beg.v[i] -= BIGBOX_PAD;
							return AABB.unsafe(beg, bigSequenceStart);

						} else if (c.v[i] == firstPlacedBig.v[i])
							foundOneMatch = true;
					}
				}

			} else {
				bool allAlongPosLine = true, allAlongNegLine = true;

				alongLoop: for (size_t i = 0; i < recents.length - 1; ++i) {
					auto v = recents[i+1].c - recents[i].c;

					for (cell d = 0; d < dim; ++d) {
						if (allAlongPosLine &&
						    v.v[d] >  NEWBOX_PAD &&
						    v.v[d] <= NEWBOX_PAD + BIG_SEQ_MAX_SPACING)
						{
							for (cell j = d + 1; j < dim; ++j) {
								if (v.v[j] != 0) {
									allAlongPosLine = false;
									if (!allAlongNegLine)
										break alongLoop;
								}
							}

						// Negative direction
						} else if (allAlongNegLine &&
						           v.v[d] <  -NEWBOX_PAD &&
						           v.v[d] >= -NEWBOX_PAD - BIG_SEQ_MAX_SPACING)
						{
							for (cell j = d + 1; j < dim; ++j) {
								if (v.v[j] != 0) {
									allAlongNegLine = false;
									if (!allAlongPosLine)
										break alongLoop;
								}
							}
						} else if (v.v[d] != 0) {
							allAlongPosLine = allAlongNegLine = false;
							break alongLoop;
						}
					}
				}

				if (allAlongPosLine || allAlongNegLine) {
					if (!justPlacedBig) {
						justPlacedBig = true;
						firstPlacedBig = c;
						bigSequenceStart = recents[0].c;
					}

					ubyte axis = void;
					for (ubyte i = 0; i < dim; ++i) {
							if (recents[0].box.beg.v[i] != recents[1].box.beg.v[i]) {
							axis = i;
							break;
						}
					}

					if (allAlongPosLine) {
						auto end = c;
						end.v[axis] += BIGBOX_PAD;
						return AABB.unsafe(c, end);
					} else {
						assert (allAlongNegLine);
						auto beg = c;
						beg.v[axis] -= BIGBOX_PAD;
						return AABB.unsafe(beg, c);
					}
				}
			}
		}
		justPlacedBig = false;
		return AABB(c.clampedSub(NEWBOX_PAD), c.clampedAdd(NEWBOX_PAD));
	}

	void placeBox(AABB aabb, Coords* reason = null, AABB* reasonBox = null)
	in {
		assert ((reason == null) == (reasonBox == null));
	} body {
		// Split the box up along any axes it wraps around on.
		AABB[1 << dim] aabbs;
		size_t a = 1;
		aabbs[0] = aabb;

		for (ucell i = 0; i < dim; ++i) {
			foreach (inout box; aabbs[0..a]) {
				if (box.beg.v[i] > box.end.v[i]) {
					auto end = box.end;
					end.v[i] = cell.max;
					aabbs[a++] = AABB.unsafe(box.beg, end);
					box.beg.v[i] = cell.min;
				}
			}
		}

		placing: foreach (box; aabbs[0..a]) {
			foreach (placed; boxen) if (placed.contains(box)) {
				++stats.space.boxesIncorporated;
				continue placing;
			}
			box.finalize();
			auto placed = reallyPlaceBox(box);
			if (reason && placed.contains(*reason))
				*reasonBox = placed;

			// If it crossed bak, we need to fix things up and move any occupied
			// cells from bak (which is below all boxen) to the appropriate box
			// (which may not be placed, if it has any overlaps).
			if (usingBak && placed.overlaps(AABB.unsafe(bak.beg, bak.end))) {

				assert (boxen[$-1] == placed);
				bool overlaps = false;
				if (bak.data.size > boxen.length) foreach (b; boxen[0..$-1]) {
					if (b.overlaps(placed)) {
						overlaps = true;
						break;
					}
				}

				Coords c = void;
				cell   v = void;
				for (auto it = bak.data.iterator; it.next(c, v);) {
					if (placed.contains(c)) {
						if (overlaps)
							(*this)[c] = v;
						else
							placed[c] = v;
						it.remove();
					}
				}
			}
		}
	}

	// Returns the placed box, which may be bigger than the given box
	AABB reallyPlaceBox(AABB aabb)
	in {
		foreach (box; boxen)
			assert (!box.contains(aabb));
	} out (result) {

		assert (result.contains(aabb));

		bool found = false;
		foreach (box; boxen) {
			assert (!found);
			if (box == result) {
				found = true;
				break;
			}
		}
		assert (found);

	} body {
		++stats.space.boxesPlaced;

		size_t food = void;
		size_t foodSize = 0;
		size_t usedCells = aabb.size;

		auto eater = AABB.unsafe(aabb.beg, aabb.end);

		auto subsumes   = new size_t[boxen.length];
		auto candidates = new size_t[boxen.length];
		foreach (i, ref c; candidates)
			c = i;

		size_t s = 0;

		for (;;) {
			// Disjoint assumes that it comes after fusables. Some reasoning for
			// why that's probably a good idea anyway:
			//
			// F
			// FD
			// A
			//
			// F is fusable, D disjoint. If we looked for disjoints before
			// fusables, we might subsume D, leaving us worse off than if we'd
			// subsumed F.
			    subsumeContains(candidates, subsumes, s, eater, food, foodSize, usedCells);
			if (subsumeFusables(candidates, subsumes, s, eater, food, foodSize, usedCells)) continue;
			if (subsumeDisjoint(candidates, subsumes, s, eater, food, foodSize, usedCells)) continue;
			if (subsumeOverlaps(candidates, subsumes, s, eater, food, foodSize, usedCells)) continue;
			break;
		}

		if (s)
			aabb = consumeSubsume(subsumes[0..s], food, eater);
		else
			aabb.alloc;

		boxen ~= aabb;
		stats.newMax(stats.space.maxBoxesLive, boxen.length);

		foreach (i; invalidatees)
			i();

		return aabb;
	}

	// Doesn't return bool like the others since it doesn't change eater
	void subsumeContains(
		ref size_t[] candidates, ref size_t[] subsumes, ref size_t sLen,
		AABB eater,
		ref size_t food, ref size_t foodSize,
		ref size_t usedCells)
	{
		for (size_t i = 0; i < candidates.length; ++i) {
			auto c = candidates[i];
			if (eater.contains(boxen[c])) {
				subsumes[sLen++] = c;
				minMaxSize(null, null, food, foodSize, usedCells, c);
				candidates.removeAt(i--);

				++stats.space.subsumedContains;
			}
		}
	}
	bool subsumeFusables(
		ref size_t[] candidates, ref size_t[] subsumes, ref size_t sLen,
		ref AABB eater,
		ref size_t food, ref size_t foodSize,
		ref size_t usedCells)
	{
		auto start = sLen;

		// Get all the fusables first
		//
		// Somewhat HACKY to avoid memory allocation: subsumes[start..sLen] are
		// indices to candidates, not boxen
		foreach (i, c; candidates)
			if (eater.canFuseWith(boxen[c]))
				subsumes[sLen++] = i;

		// Now grab those that we can actually fuse, preferring those along the
		// primary axis (y for 2D, z for 3D)
		//
		// This ensures that all the ones we fuse with are along the same axis.
		// For instance, A can't fuse with both X and Y in the following:
		//
		// X
		// AY
		//
		// Not needed for 1D since they're trivially all along the same axis.
		static if (dim > 1) if (sLen - start > 1) {
			size_t j = start;
			for (size_t i = start; i < sLen; ++i) {
				auto c = candidates[subsumes[i]];
				if (eater.onSamePrimaryAxisAs(boxen[c]))
					subsumes[j++] = subsumes[i];
			}

			if (j == start) {
				j = start + 1;
				auto orig = boxen[candidates[subsumes[start]]];
				for (size_t i = j; i < sLen; ++i)
					if (orig.onSameAxisAs(boxen[candidates[subsumes[i]]]))
						subsumes[j++] = subsumes[i];
			}
			sLen = j;
		}

		assert (sLen >= start);
		if (sLen == start)
			return false;
		else {
			// Sort them so that we can find the correct offset to apply to the
			// array index (since we're removing these from candidates as we go):
			// if the lowest index is always next, the following ones' indices are
			// reduced by one
			subsumes[start..sLen].sort;

			size_t offset = 0;
			foreach (ref s; subsumes[start..sLen]) {
				auto corrected = s - offset++;
				s = candidates[corrected];

				minMaxSize(&eater.beg, &eater.end, food, foodSize, usedCells, s);
				candidates.removeAt(corrected);

				++stats.space.subsumedFusables;
			}
			return true;
		}
	}
	bool subsumeDisjoint(
		ref size_t[] candidates, ref size_t[] subsumes, ref size_t sLen,
		ref AABB eater,
		ref size_t food, ref size_t foodSize,
		ref size_t usedCells)
	{
		auto dg = (AABB b, AABB fodder, size_t usedCells) {
			return cheaperToAlloc(b.clampedSize, usedCells + fodder.size);
		};

		auto orig = sLen;
		for (size_t i = 0; i < candidates.length; ++i) {
			auto c = candidates[i];

			// All fusables have been removed so a sufficient condition for
			// disjointness is non-overlappingness
			if (!eater.overlaps(boxen[c])
			 && validMinMaxSize(
			    	dg, eater.beg, eater.end, food, foodSize, usedCells, c))
			{
				subsumes[sLen++] = c;
				candidates.removeAt(i--);

				++stats.space.subsumedDisjoint;
			}
		}
		assert (sLen >= orig);
		return sLen > orig;
	}
	bool subsumeOverlaps(
		ref size_t[] candidates, ref size_t[] subsumes, ref size_t sLen,
		ref AABB eater,
		ref size_t food, ref size_t foodSize,
		ref size_t usedCells)
	{
		auto dg = (AABB b, AABB fodder, size_t usedCells) {
			AABB overlap = void;
			size_t overSize = 0;

			if (eater.getOverlapWith(fodder, overlap))
				overSize = overlap.size;

			return cheaperToAlloc(
				b.clampedSize, usedCells + fodder.size - overSize);
		};

		auto orig = sLen;
		for (size_t i = 0; i < candidates.length; ++i) {
			auto c = candidates[i];

			if (eater.overlaps(boxen[c])
			 && validMinMaxSize(
			    	dg, eater.beg, eater.end, food, foodSize, usedCells, c))
			{
				subsumes[sLen++] = c;
				candidates.removeAt(i--);
				++stats.space.subsumedOverlaps;
			}
		}
		assert (sLen >= orig);
		return sLen > orig;
	}
	bool cheaperToAlloc(size_t together, size_t separate) {
		return
			together <= ACCEPTABLE_WASTE ||
			  cell.sizeof * (together - ACCEPTABLE_WASTE)
			< cell.sizeof * separate + AABB.sizeof;
	}

	AABB consumeSubsume(size_t[] subsumes, size_t food, AABB aabb) {
		irrelevizeSubsumptionOrder(subsumes);

		aabb.finalize;
		aabb.consume(boxen[food]);

		// NOTE: strictly speaking this should be a foreach_reverse and subsumes
		// should be sorted, since we don't want below-boxes to overwrite
		// top-boxes' data. However, irrelevizeSubsumptionOrder copies the data so
		// that the order is, in fact, irrelevant.
		//
		// I think that 'food' would also have to be simply subsumes[$-1] after
		// sorting, but I haven't thought this completely through so I'm not
		// sure.
		//
		// In debug mode, do exactly the "wrong" thing (subsume top-down), in the
		// hopes of bug catching.
		debug subsumes.sort;

		foreach (i; subsumes) if (i != food) {
			aabb.subsume(boxen[i]);
			.free(boxen[i].data);
		}

		outer: for (size_t i = 0, n = 0; i < boxen.length; ++i) {
			foreach (s; subsumes) {
				if (i == s-n) { boxen.removeAt(i--); ++n; }
				if (boxen.length == 0) break outer;
			}
		}

		return aabb;
	}

	// Consider the following:
	//
	// +-----++---+
	// | A +--| C |
	// +---|B +*--+
	//     +----+
	//
	// Here, A is the one being placed and C is a fusable. * is a point whose
	// data is in C but which is contained in both B and C. Since the final
	// subsumer-box is going to be below all existing boxes, we'll end up
	// with:
	//
	// +----------+
	// | X +----+ |
	// +---|B  *|-+
	//     +----+
	//
	// Where X is the final box placed. Note that * is now found in B, not in
	// X, but its data was in C (now X)! Oops!
	//
	// So, we do the following, which in the above case would copy the data
	// from C to B.
	//
	// Since findBeg and findEnd check all boxes without considering
	// overlappingness, we also space the overlapped area in C to prevent
	// mishaps there.
	//
	// Caveat: this assumes that the final box will always be placed
	// bottom-most. This does not really matter, it's just extra work if it's
	// not; but in any case, if not, the relevant overlapping boxes would be
	// those which would end up above the final box.
	void irrelevizeSubsumptionOrder(size_t[] subsumes) {
		AABB overlap = void;
		foreach (i; subsumes) {
			// Check boxes below boxen[i]
			for (auto j = i+1; j < boxen.length; ++j) {

				if (boxen[i].contains(boxen[j]) || boxen[j].contains(boxen[i]))
					continue;

				// If they overlap, copy the overlap area to the lower box and
				// space that area in the higher one.
				if (boxen[i].getOverlapWith(boxen[j], overlap)) {
					boxen[j].subsumeArea(boxen[i], overlap);
					boxen[i].blankArea(overlap);
				}
			}
		}
	}

	// Finds the bounds of the tightest AABB containing all the boxen referred
	// by indices, as well as the largest box among them, and keeps a running
	// sum of their sizes.
	//
	// Assumes they're all allocated and max isn't.
	void minMaxSize(
		Coords* beg, Coords* end,
		ref size_t max, ref size_t maxSize,
		ref size_t size,
		size_t[] indices)
	{
		foreach (i; indices)
			minMaxSize(beg, end, max, maxSize, size, i);
	}
	void minMaxSize(
		Coords* beg, Coords* end,
		ref size_t max, ref size_t maxSize,
		ref size_t size,
		size_t i)
	{
		auto box = boxen[i];
		size += box.size;
		if (box.size > maxSize) {
			maxSize = box.size;
			max = i;
		}
		if (beg) beg.minWith(box.beg);
		if (end) end.maxWith(box.end);
	}

	// Fills in the input values with the minMaxSize data, returning what the
	// given validator delegate returns.
	//
	// The input delegate takes:
	// - box that subsumes (unallocated)
	// - box to be subsumed (allocated)
	// - number of cells that are currently contained in any box that the subsumer
	//   contains
	bool validMinMaxSize(
		bool delegate(AABB, AABB, size_t) valid,
		ref Coords beg, ref Coords end,
		ref size_t max, ref size_t maxSize,
		ref size_t usedCells,
		size_t idx)
	{
		auto
			tryBeg = beg, tryEnd = end,
			tryMax = max, tryMaxSize = maxSize,
			tryUsed = usedCells;

		minMaxSize(&tryBeg, &tryEnd, tryMax, tryMaxSize, tryUsed, idx);

		if (valid(AABB(tryBeg, tryEnd), boxen[idx], usedCells)) {
			beg       = tryBeg;
			end       = tryEnd;
			max       = tryMax;
			maxSize   = tryMaxSize;
			usedCells = tryUsed;
			return true;
		} else
			return false;
	}

	// Gives a contiguous area of Funge-Space to the given delegate.
	// Additionally guarantees that the successive areas passed are consecutive.
	//
	// The delegate should update the given statistics with the number of reads
	// and writes it performed, respectively.
	public void map(Coords a,Coords b,void delegate(cell[],ref Stat,ref Stat) f)
	{
		auto aabb = AABB(a, b);
		placeBox(aabb);
		mapNoPlace(aabb, f, null);
	}

	// If an area in the given range does not fall into any allocated area,
	// simply does not call the function for that area: instead calls the second
	// function with the number of cells skipped. It may be null, in which case
	// it is obviously not called.
	//
	// Of course, the first function may still get an array full of spaces any
	// number of times.
	public void mapNoAlloc(
		Coords a, Coords b, void delegate(cell[], ref Stat, ref Stat) f,
		                    void delegate(size_t) g = null)
	{
		auto aabb = AABB(a,b);
		mapNoPlace(aabb, f, g);

		if (usingBak && aabb.overlaps(AABB.unsafe(bak.beg, bak.end))) {
			foreach (c, v; bak.data) {
				if (aabb.contains(c)) {
					auto nv = v;
					f((&nv)[0..1], stats.space.lookups, stats.space.assignments);
					if (nv != v)
						bak.data[c] = nv;
				}
			}
		}
	}

	// If g is non-null the AABB should be finalized, since sizes are used
	// to calculate its argument.
	void mapNoPlace(
		AABB aabb, void delegate(cell[], ref Stat, ref Stat) f,
		           void delegate(size_t) g)
	{
		auto beg = aabb.beg;

		iterating: for (bool hitEnd = false;;) {
			foreach (b, box; boxen) if (box.contains(beg)) {
				// Consider:
				//     +-----+
				// x---|░░░░░|---+
				// |░░░|░░░░░|░░░|
				// |░░░|░░░░░|░B░y
				// |   |  A  |   |
				// +---|     |---+
				//     +-----+
				// We want to map the range from x to y (shaded). Unless we
				// tessellate, we'll get the whole thing from box B straight away.
				auto tesBeg = box.beg;
				auto tesEnd = box.end;
				tessellateAt(beg, boxen[0..b], tesBeg, tesEnd);

				auto begIdx = box.getIdx(beg);
				auto endIdx = box.getIdx(getEndOfContiguousRange(
					tesEnd, beg, aabb.end, aabb.beg, hitEnd, tesBeg, box.beg));
				assert (begIdx < endIdx + 1);

				f(box.data[begIdx .. endIdx+1],
				  stats.space.lookups, stats.space.assignments);
				if (hitEnd)
					return;
				else
					continue iterating;
			}

			// No hits for beg: find the next beg we can hit, or abort if there's
			// nothing left.
			size_t skipped = 0;
			auto found = getNextIn(beg, aabb, skipped);
			if (g)
				g(skipped);
			if (!found)
				break;
		}
	}

	// Passes some extra data to the delegate, for matching array index
	// calculations with the location of the cell[] (probably quite specific to
	// file loading, where this is used):
	//
	// - The width and area of the enclosing box.
	//
	// - The indices in the cell[] of the previous line and page (note: always
	//   zero or negative (thus big numbers, since unsigned)).
	//
	// - Whether a new line or page was just reached, with one bit for each
	//   boolean (LSB for line, next-most for page).
	//
	// Since this is currently only used from this class, we update stats
	// directly instead of passing them to the delegate.
	void mapNoPlace(
		AABB aabb, void delegate(cell[], size_t,size_t,size_t,size_t, ubyte) f,
		           void delegate(size_t) g)
	{
		auto beg = aabb.beg;

		iterating: for (bool hitEnd = false;;) {
			foreach (b, box; boxen) if (box.contains(beg)) {
				size_t
					width = void,
					area = void,
					pageStart = void;

				// DMD doesn't like passing uninitialized things to functions...
				version (DigitalMars) {
					width = 0;
					area = 0;
					pageStart = 0;
				}

				// These depend on the original beg and thus have to be initialized
				// before the call to getEndOfContiguousRange

				// {box.beg.x, beg.y, beg.z}
				Coords ls = beg;
				ls.x = box.beg.x;

				static if (dim >= 2) {
					// {box.beg.x, box.beg.y, beg.z}
					Coords ps = box.beg;
					ps.v[2..$] = beg.v[2..$];
				}

				auto tesBeg = box.beg;
				auto tesEnd = box.end;
				tessellateAt(beg, boxen[0..b], tesBeg, tesEnd);

				auto begIdx = box.getIdx(beg);
				auto endIdx = box.getIdx(getEndOfContiguousRange(
					tesEnd, beg, aabb.end, aabb.beg, hitEnd, tesBeg, box.beg));

				assert (begIdx < endIdx + 1);
				auto arr = box.data[begIdx .. endIdx + 1];

				ubyte hit = 0;

				// Unefunge needs this to skip leading spaces
				auto lineStart = box.getIdx(ls) - (arr.ptr - box.data);

				static if (dim >= 2) {
					width = box.width;
					hit |= (beg.x == aabb.beg.x && beg.y != ls.y) << 0;

					// Befunge needs this to skip leading newlines
					pageStart = box.getIdx(ps) - (arr.ptr - box.data);
				}
				static if (dim >= 3) {
					area = box.area;
					hit |= (beg.y == aabb.beg.y && beg.z != ls.z) << 1;
				}

				f(arr, width, area, lineStart, pageStart, hit);

				if (hitEnd)
					return;
				else
					continue iterating;
			}

			size_t skipped = 0;
			auto found = getNextIn(beg, aabb, skipped);
			if (g)
				g(skipped);
			if (!found)
				break;
		}
	}

	// The next allocated point after pt which is also within the given AABB.
	// Updates skipped to reflect the number of unallocated cells skipped.
	bool getNextIn(inout Coords pt, AABB aabb, inout size_t skipped)
	in {
		AABB _;
		assert (!findBox(pt, _));
	} out (found) {
		if (found) {
			AABB _;
			assert (findBox(pt, _));
		}
	} body {
		auto bestIn = boxen.length;
		cell bestCoord = void;

		auto wrappedIn = boxen.length;
		cell bestWrapped = void;

		for (ucell i = 0; i < dim; ++i) {
			foreach (b, box; boxen) {
				if ((box.beg.v[i] < bestCoord || bestIn == boxen.length) &&
				    AABB.unsafe(aabb.beg, aabb.end).safeContains(box.beg) &&

				    // If pt has crossed an axis within the AABB, prevent us from
				    // grabbing a new pt on the other side of the axis we're
				    // wrapped around, or we'll just keep looping around that axis.
				    (pt.v[i] >= aabb.beg.v[i] || box.beg.v[i] <= aabb.end.v[i]))
				{
					// If [pt,aabb.end] is wrapped around, take the global minimum
					// box.beg as a last-resort option if nothing else is found, so
					// that we wrap around if there's no non-wrapping solution.
					//
					// Note that bestWrapped <= bestCoord so we can test this within
					// here.
					if (pt.v[i] > aabb.end.v[i] &&
					    (box.beg.v[i] < bestWrapped || wrappedIn == boxen.length))
					{
						bestWrapped = box.beg.v[i];
						wrappedIn = b;

					// The ordinary best solution is the minimal box.beg greater
					// than pt.
					} else if (box.beg.v[i] > pt.v[i]) {
						bestCoord = box.beg.v[i];
						bestIn = b;
					}
				}
			}
			if (bestIn == boxen.length && wrappedIn < boxen.length) {
				bestCoord = bestWrapped;
				bestIn = wrappedIn;
			}
			if (bestIn < boxen.length) {
				auto old = pt;

				pt.v[0..i] = aabb.beg.v[0..i];
				pt.v[i] = bestCoord;

				// Remember that old was already a space, or we wouldn't have
				// called this function in the first place. Hence skipped is always
				// at least one.
				++skipped;

				for (ucell j = 0; j < dim-1; ++j)
					skipped += (aabb.end.v[j] - old.v[j]) * aabb.volumeOn(j);

				skipped += (pt.v[$-1] - old.v[$-1] - 1) * aabb.volumeOn(dim-1);

				// When setting pt.v[0..i] above, we may not end up in any box. So
				// just go again with the updated pt.
				if (i > 0 && !boxen[bestIn].contains(pt) && !findBox(pt, aabb))
					return getNextIn(pt, aabb, skipped);

				return true;
			}
		}
		return false;
	}

	// Takes ownership of the Array, closing it.
	public void load(Array arr, Coords* end, Coords target, bool binary) {

		scope (exit) arr.close;

		auto input = cast(ubyte[])arr.slice;

		static if (befunge93) {
			assert (target == 0);
			assert (end is null);
			assert (!binary);

			befunge93Load(input);
		} else {
			auto aabbs = getAABBs(input, binary, target);

			if (aabbs.length == 0)
				return;

			foreach (box; aabbs) {
				if (end)
					end.maxWith(box.end);
				placeBox(box);
			}

			// Build one to rule them all.
			//
			// Note that it may have beg > end along any number of axes!
			auto aabb = aabbs[0];
			if (aabbs.length > 1) {
				// If any box was placed past an axis, the end of that axis is the
				// maximum of the ends of such boxes. Otherwise, it's the plain
				// maximum.
				//
				// Similarly, if any box was placed before an axis, the beg is the
				// minimum of such boxes' begs.
				ubyte foundPast = 0, foundBefore = 0;

				for (ucell i = 0; i < dim; ++i) {
					if (aabb.beg.v[i] < target.v[i]) foundPast   |= 1 << i;
					else                             foundBefore |= 1 << i;
				}

				foreach (b, box; aabbs[1..$]) for (ucell i = 0; i < dim; ++i) {

					if (box.beg.v[i] < target.v[i]) {
						if (foundPast & 1 << i)
							aabb.end.v[i] = max(aabb.end.v[i], box.end.v[i]);
						else {
							aabb.end.v[i] = box.end.v[i];
							foundPast |= 1 << i;
						}
					} else if (!(foundPast & 1 << i))
						aabb.end.v[i] = max(aabb.end.v[i], box.end.v[i]);

					if (box.beg.v[i] >= target.v[i]) {
						if (foundBefore & 1 << i)
							aabb.beg.v[i] = min(aabb.beg.v[i], box.beg.v[i]);
						else {
							aabb.beg.v[i] = box.beg.v[i];
							foundBefore |= 1 << i;
						}
					} else if (!(foundBefore & 1 << i))
						aabb.beg.v[i] = min(aabb.beg.v[i], box.beg.v[i]);
				}
				aabb.finalize;
			}

			auto p = input.ptr;

			auto pEnd = input.ptr + input.length;

			if (binary) {
				mapNoPlace(aabb, (cell[] arr,ref Stat,ref Stat) {
					foreach (ref x; arr) {
						ubyte b = *p++;
						if (b != ' ') {
							x = b;
							++stats.space.assignments;
						}
					}
				},
				(size_t n) {
					while (n--) {
						if (*p == ' ')
							++p;
						else
							break;
					}
				});
			} else {
				// Used only for skipping leading spaces/newlines and thus not
				// really representative of the cursor position at any point
				static if (dim >= 2) auto x = target.x;
				static if (dim >= 3) auto y = target.y;

				mapNoPlace(aabb, (cell[] arr, size_t width,     size_t area,
				                              size_t lineStart, size_t pageStart,
				                              ubyte hit)
				{
					size_t i = 0;
					while (i < arr.length) {
						assert (p < pEnd);
						ubyte b = *p++;
						switch (b) {
							default:
								arr[i++] = b;
								++stats.space.assignments;
								break;

							case ' ':
								// Ignore leading spaces (west of aabb.beg.x)
								bool leadingSpace = i == lineStart;
								static if (dim >= 2)
									leadingSpace = leadingSpace && x++ < aabb.beg.x;

								if (!leadingSpace)
									++i;

							static if (dim < 2) { case '\r','\n': }
							static if (dim < 3) { case '\f': }
								break;

							static if (dim >= 2) {
							case '\r':
								if (p < pEnd && *p == '\n')
									++p;
							case '\n':
								// Ignore leading newlines (north of aabb.beg.y)
								bool leadingNewline = i == pageStart;
								static if (dim >= 3)
									leadingNewline = leadingNewline && y++ < aabb.beg.y;

								if (!leadingNewline) {
									i = lineStart += width;
									x = target.x;
								}
								break;
							}
							static if (dim >= 3) {
							case '\f':
								// Ignore leading form feeds (above aabb.beg.z)
								if (i != 0) {
									i = lineStart = pageStart += area;
									y = target.y;
								}
								break;
							}
						}
					}
					if (i == arr.length && hit && p < pEnd) {
						// We didn't find a newline yet (in which case i would exceed
						// arr.length) but we finished with this block. We touched an
						// EOL or EOP in the array, and likely a newline or form feed
						// terminates them in the code. Eat them here lest we skip a
						// line by seeing them in the next call.

						static if (dim >= 2) if (hit & 0b01) {
							// Skip any trailing other whitespace
							while (*p == ' ' || *p == '\f')
								++p;

							if (p < pEnd) {
								assert (*p == '\r' || *p == '\n');
								if (*p++ == '\r' && p < pEnd && *p == '\n')
									++p;
							}
						}
						static if (dim == 3) if (hit & 0b10 && p < pEnd) {
							// Skip any trailing other whitespace
							while (*p == '\r' || *p == '\n' || *p == ' ')
								++p;

							if (p < pEnd) {
								assert (*p == '\f');
								++p;
							}
						}
					}
				},
				(size_t n) {
					while (n--) {
						if (*p == ' ' || *p == '\r' || *p == '\n' || *p == '\f')
							++p;
						else
							break;
					}
				});
			}
			for (; p < pEnd; ++p)
				assert (*p == ' ' || *p == '\r' || *p == '\n' || *p == '\f');
			assert (p == pEnd);
		}
	}

	static if (befunge93)
	void befunge93Load(ubyte[] input) {
		auto aabb = AABB(InitCoords!(0,0), InitCoords!(79,24));
		aabb.alloc;
		boxen ~= aabb;

		bool gotCR = false;
		auto pos = InitCoords!(0,0);

		bool newLine() {
			gotCR = false;
			pos.x = 0;
			++pos.y;
			return pos.y >= 25;
		}

		loop: for (size_t i = 0; i < input.length; ++i) switch (input[i]) {
			case '\r': gotCR = true; break;
			case '\n':
				if (newLine())
					break loop;
				break;
			default:
				if (gotCR && newLine())
					break loop;

				if (input[i] != ' ')
					aabb[pos] = input[i];

				if (++pos.x < 80)
					break;

				++i;
				skipRest: for (; i < input.length; ++i) switch (input[i]) {
					case '\r': gotCR = true; break;
					case '\n':
						if (newLine())
							break loop;
						break skipRest;
					default:
						if (gotCR) {
							if (newLine())
								break loop;
							break skipRest;
						}
						break;
				}
				break;
		}
	}

	// Returns an array of AABBs (a slice out of a static buffer) which describe
	// where the input should be loaded. There are at most 2^dim of them; in
	// binary mode, at most 2.
	//
	// If nothing would be loaded, returns null.
	//
	// target: where input is being loaded to
	static if (!befunge93)
	AABB[] getAABBs(ubyte[] input, bool binary, Coords target)
	out (result) {
		if (binary)
			assert (result.length <= 2);
	} body {
		AABB[1 << dim] aabbs;
		size_t a = 0;
		static typeof(aabbs) aabbsRet;

		if (binary) {
			auto beg = target;
			auto end = target;

			size_t i = 0;
			while (i < input.length && input[i++] == ' '){}

			beg.x += i-1;

			if (i == input.length) {
				// All spaces: nothing to load.
				return null;
			}

			i = input.length;

			// No need to check bounds here since it can't be all spaces
			while (input[--i] == ' '){}

			if (end.x > cast(cell)(cast(size_t)cell.max - i)) {
				auto begX = beg.x;
				end.x = cell.max;
				aabbsRet[a++] = AABB(beg, end);

				beg.x = cell.min;
			}
			end.x += i;

			aabbsRet[a++] = AABB(beg, end);
			return aabbsRet[0..a];
		}

		auto pos = target;

		// The index a as used below is a bitmask of along which axes pos
		// overflowed. Thus it changes over time as we read something like:
		//
		//          |
		//   foobarb|az
		//      qwer|ty
		// ---------+--------
		//      arst|mei
		//     qwfp |
		//          |
		//
		// After the ending 'p', a will not have its maximum value, which was in
		// the "mei" quadrant. So we have to keep track of it separately.
		typeof(a) maxA = 0;

		// A bitmask of which axes we want to search for the beginning point for.
		// Reset completely at overflows and partially at line and page breaks.
		auto getBeg = DimensionBits;

		// We want minimal boxes, and thus exclude spaces at edges. These are
		// helpers toward that. lastNonSpace points to the last found nonspace
		// and foundNonSpaceFor is the index of the box it belonged to.
		auto lastNonSpace = target;
		auto foundNonSpaceFor = aabbs.length;

		// Not per-box: if this remains unchanged, we don't need to load a thing.
		auto foundNonSpaceForAnyone = aabbs.length;

		foreach (ref box; aabbs) {
			box.beg = InitCoords!(cell.max, cell.max, cell.max);
			box.end = InitCoords!(cell.min, cell.min, cell.min);
		}

		static if (dim >= 2) {
			bool gotCR = false;

			void newLine() {
				gotCR = false;

				aabbs[a].end.x = max(aabbs[a].end.x, lastNonSpace.x);

				pos.x = target.x;

				if (++pos.y == cell.min) {
					if (foundNonSpaceFor == a)
						aabbs[a].end.maxWith(lastNonSpace);

					foundNonSpaceFor = aabbs.length;
					getBeg = DimensionBits;

					maxA = max(maxA, a |= 0b010);
				}
				a &= ~0b001;
				getBeg = foundNonSpaceFor == a ? 0b001 : 0b011;
			}
		}

		foreach (b; input) switch (b) {
			case '\r':
				static if (dim >= 2)
					gotCR = true;
				break;

			case '\n':
				static if (dim >= 2)
					newLine();
				break;

			case '\f':
				static if (dim >= 2)
					if (gotCR)
						newLine();

				static if (dim >= 3) {
					aabbs[a].end.x = max(aabbs[a].end.x, lastNonSpace.x);
					aabbs[a].end.y = max(aabbs[a].end.y, lastNonSpace.y);

					pos.x = target.x;
					pos.y = target.y;

					if (++pos.z == cell.min) {
						if (foundNonSpaceFor == a)
							aabbs[a].end.maxWith(lastNonSpace);

						foundNonSpaceFor = aabbs.length;
						getBeg = DimensionBits;

						maxA = max(maxA, a |= 0b100);
					}
					a &= ~0b011;
					getBeg = foundNonSpaceFor == a ? 0b011 : 0b111;
				}
				break;

			default:
				static if (dim >= 2)
					if (gotCR)
						newLine();

				if (b != ' ') {
					foundNonSpaceFor = foundNonSpaceForAnyone = a;
					lastNonSpace = pos;

					if (getBeg) for (size_t i = 0; i < dim; ++i) {
						if (getBeg & 1 << i) {
							if (pos.v[i] < aabbs[a].beg.v[i])
								aabbs[a].beg.v[i] = pos.v[i];
							getBeg &= ~(1 << i);
						}
					}
				}
				if (++pos.x == cell.min) {
					if (foundNonSpaceFor == a)
						aabbs[a].end.maxWith(lastNonSpace);

					foundNonSpaceFor = aabbs.length;
					getBeg = DimensionBits;

					maxA = max(maxA, a |= 0b001);
				}
				break;
		}
		if (foundNonSpaceForAnyone == aabbs.length)
			return null;

		if (foundNonSpaceFor < aabbs.length)
			aabbs[foundNonSpaceFor].end.maxWith(lastNonSpace);

		// Since a is a bitmask, the AABBs that we used aren't necessarily in
		// order. Fix that while copying them to aabbsRet.
		size_t i = 0;
		foreach (inout box; aabbs[0..maxA+1]) {
			if (!(box.beg.x == cell.max && box.end.x == cell.min)) {
				for (ucell j = 0; j < dim; ++j)
					assert (box.beg.v[j] <= box.end.v[j]);
				aabbsRet[i++] = box;
			}
		}
		return aabbsRet[0..i];
	}

	// Outputs space in the range [beg,end).
	// Puts form feeds / line breaks only between rects/lines.
	// Doesn't trim trailing spaces or anything like that.
	// Doesn't close the given OutputStream.
	public void binaryPut(OutputStream file, Coords beg, Coords end) {
		scope tfile = new TypedOutput!(ubyte)(file);
		scope (exit) tfile.flush;

		Coords c = void;
		ubyte b = void;

		const char[] X =
			"for (c.x = beg.x; c.x < end.x; ++c.x) {"
			"	b = cast(ubyte)(*this)[c];"
			"	tfile.write(b);"
			"}";

		const char[] Y =
			"for (c.y = beg.y; c.y < end.y;) {"
			"	" ~ X ~
			"	if (++c.y != end.y) foreach (ch; NewlineString) {"
			"		b = ch;"
			"		tfile.write(b);"
			"	}"
			"}";

		static if (dim == 3) {
			for (c.z = beg.z; c.z < end.z;) {
				mixin (Y);
				if (++c.z != end.z) {
					b = '\f';
					tfile.write(b);
				}
			}
		} else static if (dim == 2)
			mixin (Y);

		else static if (dim == 1)
			mixin (X);
	}
}

private struct BakAABB(cell dim) {
	alias .Coords   !(dim) Coords;
	alias .Dimension!(dim).Coords InitCoords;

	HashMap!(Coords, cell) data;
	Coords beg = void, end = void;

	void initialize(Coords c) {
		beg = c;
		end = c;
		data = new typeof(data);
	}

	cell opIndex(Coords p) {
		auto c = p in data;
		return c ? *c : ' ';
	}
	void opIndexAssign(cell c, Coords p) {
		if (c == ' ')
			// If we call data.removeKey(p) instead, we trigger some kind of
			// codegen bug which I couldn't track down. Fortunately, its
			// definition is to just call take, and this works, so we're good.
			data.take(p, c);
		else {
			beg.minWith(p);
			end.maxWith(p);
			data[p] = c;
		}
	}
	bool contains(Coords p) { return Dimension!(dim).contains(p, beg, end); }
}
