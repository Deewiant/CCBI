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

	alias .AABB     !(dim)        AABB;
	alias .Coords   !(dim)        Coords;
	alias .Dimension!(dim).Coords InitCoords;

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
		MAX_PLACED_BOXEN = 64;

	static assert (NEWBOX_PAD          >= 0);
	static assert (BIGBOX_PAD          >  NEWBOX_PAD);
	static assert (BIG_SEQ_MAX_SPACING >= 1);

	private {
		struct Memory {
			AABB box, finalBox;
			Coords c;
		}
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
				auto bakBeg = bak.beg;
				auto bakEnd = bak.end;
				foreach (c, v; bak.data) {
					assert (v != ' ');
					bakBeg.minWith(c);
					bakEnd.maxWith(c);
				}
				// Might as well improve these approximate bounds while we're at it
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
			if (boxen[i].beg.anyLess(beg)) {
				auto box = boxen[i];

				// Common case
				++stats.space.lookups;
				if (box.getNoOffset(InitCoords!(0)) != ' ') {
					beg.minWith(box.beg);
					continue;
				}

				auto last = box.end;
				last.v[axis] = min(last.v[axis], beg.v[axis]);

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
					}
				}";

				const start = InitCoords!(0);

				static if (axis == 0) {
					mixin (CoordsLoop!(
						dim, "c", "start", "last", "<=", "+= 1",
						CHECK));

				} else static if (axis == 1) {
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
			if (boxen[i].end.anyGreater(end)) {
				auto box = boxen[i];

				++stats.space.lookups;
				if (box[box.end] != ' ') {
					end.maxWith(box.end);
					continue;
				}

				auto last = InitCoords!(0);
				last.v[axis] = max(last.v[axis], end.v[axis] - box.beg.v[axis]);

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

	Coords jumpToBox(Coords pos, Coords delta, out AABB box, out size_t idx) {
		bool found = tryJumpToBox(pos, delta, box, idx);
		assert (found);
		return pos;
	}
	bool tryJumpToBox(
		ref Coords pos, Coords delta, out AABB aabb, out size_t boxIdx)
	in {
		AABB _;
		assert (!findBox(pos, _));
	} body {
		ucell moves = 0;
		Coords pos2 = void;
		size_t idx  = void;
		foreach (i, box; boxen) {
			ucell m;
			Coords c;
			if (box.rayIntersects(pos, delta, m, c) && (m < moves || !moves)) {
				pos2  = c;
				idx   = i;
				moves = m;
			}
		}
		if (moves) {
			pos    = pos2;
			boxIdx = idx;
			aabb   = boxen[idx];
			return true;
		} else
			return false;
	}

	bool findBox(Coords pos, out AABB aabb, out size_t idx) {
		foreach (i, box; boxen) if (box.contains(pos)) {
			idx  = i;
			aabb = box;
			return true;
		}
		return false;
	}
	private bool findBox(Coords pos, out AABB aabb) {
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
		auto pox = reallyPlaceBox(box);
		recentBuf.push(Memory(box, pox, c));
		aabb = pox;
		return true;
	}
	AABB getBoxFor(Coords c)
	in {
		foreach (box; boxen)
			assert (!box.contains(c));
	} out (box) {
		assert (box.contains(c));
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
						for (cell j = i + cast(cell)1; j < dim; ++j)
							if (c.v[j] != bigSequenceStart.v[j])
								break outer;

						// We're making a line/rectangle/box (depending on the value
						// of i): extend last along the axis where c was outside it.
						auto end = last.end;
						end.v[i] += BIGBOX_PAD;
						return AABB(c, end);

					// First of many places in this function where we need to check
					// the negative direction separately from the positive.
					} else if (c.v[i] <  last.beg.v[i] &&
					           c.v[i] >= last.beg.v[i] - BIG_SEQ_MAX_SPACING)
					{
						if (sawEnd)
							break;
						sawBeg = true;
						for (cell j = i + cast(cell)1; j < dim; ++j)
							if (c.v[j] != bigSequenceStart.v[j])
								break outer;

						auto beg = last.beg;
						beg.v[i] -= BIGBOX_PAD;
						return AABB(beg, c);

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
								for (cell j = i+cast(cell)1; j < dim; ++j) {
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
							return AABB(bigSequenceStart, end);

						// Negative direction
						} else if (
							(c.v[i] <  firstPlacedBig.v[i] &&
							 c.v[i] >= firstPlacedBig.v[i] - BIG_SEQ_MAX_SPACING))
						{
							if (!foundOneMatch) {
								for (cell j = i+cast(cell)1; j < dim; ++j) {
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
							return AABB(beg, bigSequenceStart);

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
							for (cell j = d + cast(cell)1; j < dim; ++j) {
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
							for (cell j = d + cast(cell)1; j < dim; ++j) {
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
						return AABB(c, end);
					} else {
						assert (allAlongNegLine);
						auto beg = c;
						beg.v[axis] -= BIGBOX_PAD;
						return AABB(beg, c);
					}
				}
			}
		}
		justPlacedBig = false;
		return AABB(c - NEWBOX_PAD, c + NEWBOX_PAD);
	}

	void placeBox(AABB aabb) {
		foreach (box; boxen) if (box.contains(aabb)) {
			++stats.space.boxesIncorporated;
			return;
		}
		return reallyPlaceBox(aabb);
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

		auto beg = aabb.beg, end = aabb.end;
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
			return cheaperToAlloc(b.size, usedCells + fodder.size);
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
				b.size, usedCells + fodder.size - overSize);
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
		foreach (i; subsumes) {
			// Check boxes below boxen[i]
			AABB overlap = void;
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

	// Finds the bounds of the tightest AABB containing all the boxen referred by
	// indices, as well as the largest box among them, and keeps a running sum of
	// their lengths.
	//
	// Assumes they're all allocated and max isn't.
	void minMaxSize(
		Coords* beg, Coords* end,
		ref size_t max, ref size_t maxSize,
		ref size_t length,
		size_t[] indices)
	{
		foreach (i; indices)
			minMaxSize(beg, end, max, maxSize, length, i);
	}

	void minMaxSize(
		Coords* beg, Coords* end,
		ref size_t max, ref size_t maxSize,
		ref size_t length,
		size_t i)
	{
		auto box = boxen[i];
		length += box.size;
		if (box.size > maxSize) {
			maxSize = box.size;
			max = i;
		}
		if (beg) beg.minWith(box.beg);
		if (end) end.maxWith(box.end);
	}

	// The input delegate takes:
	// - box that subsumes (unallocated)
	// - box to be subsumed (allocated)
	// - number of cells that are currently contained in any box that the subsumer
	//   contains
	size_t validMinMaxSize(
		bool delegate(AABB, AABB, size_t) valid,
		ref Coords beg, ref Coords end,
		ref size_t max, ref size_t maxSize,
		ref size_t length,
		size_t idx)
	{
		auto
			tryBeg = beg, tryEnd = end,
			tryMax = max, tryMaxSize = maxSize,
			tryLen = length;

		minMaxSize(&tryBeg, &tryEnd, tryMax, tryMaxSize, tryLen, idx);

		if (valid(AABB(tryBeg, tryEnd), boxen[idx], length)) {
			beg     = tryBeg;
			end     = tryEnd;
			max     = tryMax;
			maxSize = tryMaxSize;
			length  = tryLen;
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
		map(AABB(a, b), f);
	}
	void map(AABB aabb, void delegate(cell[], ref Stat, ref Stat) f) {
		placeBox(aabb);

		auto beg = aabb.beg;

		for (bool hitEnd = false;;) foreach (box; boxen) {
			if (box.overlaps(AABB.unsafe(beg, aabb.end))) {
				f(box.getContiguousRange(beg, aabb.end, aabb.beg, hitEnd),
				  stats.space.lookups, stats.space.assignments);
				if (hitEnd)
					return;
				else
					break;
			}
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
	void map(
		AABB aabb, void delegate(cell[], size_t,size_t,size_t,size_t, ubyte) f)
	{
		// This ensures we don't have to worry about bak, but also means that we
		// can't use this as much as we might like since we risk box count
		// explosion
		placeBox(aabb);

		auto beg = aabb.beg;

		for (bool hitEnd = false;;) foreach (box; boxen) {

			if (box.overlaps(AABB.unsafe(beg, aabb.end))) {
				size_t
					width = void,
					area = void,
					pageStart = void;

				// These depend on the original beg and thus have to be initialized
				// before the call to getContiguousRange

				// {box.beg.x, aabb.beg.y, aabb.beg.z}
				Coords ls = beg;
				ls.x = box.beg.x;

				static if (dim >= 2) {
					// {box.beg.x, box.beg.y, aabb.beg.z}
					Coords ps = box.beg;
					ps.v[2..$] = beg.v[2..$];
				}

				auto arr = box.getContiguousRange(beg, aabb.end, aabb.beg, hitEnd);

				ubyte hit = 0;

				// Unefunge needs this to skip leading spaces
				auto lineStart = box.getIdx(ls) - (arr.ptr - box.data);

				static if (dim >= 2) {
					width = box.width;
					hit |= (beg.x == aabb.beg.x) << 0;

					// Befunge needs this to skip leading newlines
					pageStart = box.getIdx(ps) - (arr.ptr - box.data);
				}
				static if (dim >= 3) {
					area = box.area;
					hit |= (beg.y == aabb.beg.y) << 1;
				}

				f(arr, width, area, lineStart, pageStart, hit);

				if (hitEnd)
					return;
				else
					break;
			}
		}
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
			auto aabb = getAABB(input, binary, target);

			if (aabb.end.x < aabb.beg.x)
				return;

			aabb.finalize;

			if (end)
				end.maxWith(aabb.end);

			auto p = input.ptr;

			auto pEnd = input.ptr + input.length;

			if (binary) {
				map(aabb, (cell[] arr,ref Stat,ref Stat) {
					foreach (ref x; arr) {
						ubyte b = *p++;
						if (b != ' ') {
							x = cast(cell)b;
							++stats.space.assignments;
						}
					}
				});
			} else {
				// Used only for skipping leading spaces/newlines and thus not
				// really representative of the cursor position at any point
				static if (dim >= 2) auto x = target.x;
				static if (dim >= 3) auto y = target.y;

				map(aabb, (cell[] arr, size_t width,     size_t area,
				                       size_t lineStart, size_t pageStart,
				                       ubyte hit)
				{
					size_t i = 0;
					while (i < arr.length) {
						assert (p < pEnd);
						ubyte b = *p++;
						switch (b) {
							default:
								arr[i++] = cast(cell)b;
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
					aabb[pos] = cast(cell)input[i];

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

	// If nothing would be loaded, end.x < beg.x in the return value
	//
	// target: where input is being loaded to
	AABB getAABB(
		ubyte[] input,
		bool binary,
		Coords target)
	{
		Coords beg = void;
		Coords end = target;

		if (binary) {
			beg = target;

			size_t i = 0;
			while (i < input.length && input[i++] == ' '){}

			beg.x += i-1;

			// If i == input.length it was all spaces
			if (i != input.length) {
				i = input.length;
				while (i > 0 && input[--i] == ' '){}

				end.x += i;
			}

			return AABB.unsafe(beg, end);
		}

		beg = InitCoords!(cell.max,cell.max,cell.max);
		ubyte getBeg = 0b111;
		auto pos = target;
		auto lastNonSpace = end;
		bool foundNonSpace = false;

		static if (dim >= 2) {
			bool gotCR = false;

			void newLine() {
				end.x = max(lastNonSpace.x, end.x);

				pos.x = target.x;
				++pos.y;
				gotCR = false;

				if (foundNonSpace)
					getBeg = 0b001;
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
					end.x = max(lastNonSpace.x, end.x);
					end.y = max(lastNonSpace.y, end.y);

					pos.x = target.x;
					pos.y = target.y;
					++pos.z;

					if (foundNonSpace)
						getBeg = 0b011;
				}
				break;

			default:
				static if (dim >= 2)
					if (gotCR)
						newLine();

				if (b != ' ') {
					foundNonSpace = true;
					lastNonSpace = pos;

					if (getBeg) for (size_t i = 0; i < dim; ++i) {
						auto mask = 1 << i;
						if (getBeg & mask && pos.v[i] < beg.v[i]) {
							beg.v[i] = pos.v[i];
							getBeg &= ~mask;
						}
					}
				}
				++pos.x;
				break;
		}
		end.maxWith(lastNonSpace);

		return AABB.unsafe(beg, end);
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
