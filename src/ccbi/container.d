// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2007-01-21 12:14:27

module ccbi.container;

import tango.core.Memory : GC;
import tango.core.Exception : onOutOfMemoryError;
import tango.core.Tuple;
import tango.math.Math : max;
import c = tango.stdc.stdlib;
import tango.stdc.string : memmove;

import ccbi.cell;
import ccbi.stats;
import ccbi.stdlib : ceilDiv;
import ccbi.templateutils;

private {
	// Just like with the Funge-Space, using the C heap reduces memory usage to
	// a half or less than what it would be with the GC. Also, not initializing
	// unused elements is a very noticeable speedup.
	//
	// NOTE! In addition to classes/interfaces, pointers are reported to the GC!
	T* malloc(T)(size_t n) {
		auto p = cast(T*)c.malloc(n * T.sizeof);
		if (!p)
			onOutOfMemoryError();

		static if (is(T == class) || is(T == interface) || is(T : void*))
			GC.addRange(p, n * T.sizeof);

		return p;
	}
	T* realloc(T)(T* p0, size_t n) {
		auto p = cast(T*)c.realloc(p0, n * T.sizeof);
		if (!p)
			onOutOfMemoryError();

		static if (is(T == class) || is(T == interface) || is(T : void*)) {
			if (p != p0) {
				GC.removeRange(p0);
				GC.addRange(p, n * T.sizeof);
			}
		}

		return p;
	}
	void free(T)(T* p) {
		c.free(p);
		static if (is(T == class) || is(T == interface) || is(T : void*))
			GC.removeRange(p);
	}
}

private template F(char[] ty, char[] f, args...) {
	static if (args.length)
		const F =
			ty ~ " " ~ f ~ "(" ~ Intercalate!(",", args) ~ ") {"
			"	if (isDeque)"
			"		return deque." ~f~ "(" ~ Intercalate!(",", ArgNames!(args)) ~ ");"
			"	else"
			"		return stack." ~f~ "(" ~ Intercalate!(",", ArgNames!(args)) ~ ");"
			"}";
	else
		const F =
			ty ~ " " ~ f ~ "(" ~ Intercalate!(",", args) ~ ") {"
			"	if (isDeque)"
			"		return deque." ~f~ ";"
			"	else"
			"		return stack." ~f~ ";"
			"}";
}
private template ArgNames(args...) {
	static if (args.length)
		alias Tuple!(
			args[0][
				FindLast!(' ', args[0])+1 ..
				Find!('.', args[0], FindLast!(' ', args[0]))],

			ArgNames!(args[1..$])) ArgNames;
	else
		alias Tuple!() ArgNames;
}

version (MODE)
struct CellContainer {
	bool isDeque = false;
	// WORKAROUND: http://d.puremagic.com/issues/show_bug.cgi?id=1055
	version (DigitalMars) {
		Stack!(cell) stack;
		Deque        deque;
	} else union {
		Stack!(cell) stack;
		Deque        deque;
	}

	static typeof(*this) opCall(bool isDeque, ContainerStats* stats) {
		CellContainer cc;
		cc.isDeque = isDeque;
		if (isDeque)
			cc.deque = Deque(stats);
		else
			cc.stack = Stack!(cell)(stats);
		return cc;
	}

	mixin (F!("cell", "pop"));

	// pop n elements, ignoring their values
	mixin (F!("void", "pop", "size_t n"));

	mixin (F!("void", "clear"));

	mixin (F!("cell", "top"));

	void push(T...)(T xs) {
		if (isDeque)
			deque.push(xs);
		else
			stack.push(xs);
	}

	mixin (F!("size_t", "size"));
	mixin (F!("bool", "empty"));

	mixin (F!("ContainerStats*", "stats"));

	mixin (F!("void", "free"));

	mixin (F!("int", "opApply", "int delegate(inout cell c) f"));

	mixin (F!("int", "topToBottom", "int delegate(inout cell c) f"));
	mixin (F!("int", "bottomToTop", "int delegate(inout cell c) f"));

	// Abstraction-breaking stuff

	// Makes sure that there's capacity for at least the given number of cells.
	// Modifies size, but doesn't guarantee any values for the reserved
	// elements.
	//
	// Returns a pointer to the top of the array overlaying the storage that
	// backs this Container, guaranteeing that following the pointer there is
	// space for least the given number of Ts.
	//
	// Altogether, this is an optimization on top of "push".
	//
	// Beware invertmode! If invertmode is enabled, you should fill the data
	// after the pointer appropriately (i.e. in reverse order)!
	mixin (F!("cell*", "reserve", "size_t n"));

	// Calls the first given function over consecutive sequences of the top n
	// elements, whose union is the top n elements. Traverses bottom-to-top.
	//
	// If n is greater than the size, instead first calls the second given
	// function with the difference of n and the size, then proceeds to call the
	// first function as though the size had been passed as n.
	//
	// Altogether, this is an optimization on top of "pop".
	//
	// But once again, beware modes! In queuemode, you will get the /bottom/ n
	// elements, still in bottom-to-top order, and the second function will be
	// called /after/ the first with the size difference, not before!
	mixin (F!("void", "mapFirstN",
		"size_t n", "void delegate(cell[]) f", "void delegate(size_t) g"));

	// Non-queuemode mapFirstN: used in tracing
	mixin (F!("void", "mapFirstNHead",
		"size_t n", "void delegate(cell[]) f", "void delegate(size_t) g"));

	// at(x) gives the x'th element from the bottom without allocating.
	//
	// Another optimization on top of "pop".
	//
	// And as usual: in queuemode, you'll get the x'th element from the top, not
	// the bottom.
	mixin (F!("cell", "at", "size_t i"));

	// setAt(x,c) is the writing form of at(x): an optimization on top of both
	// "pop" and "push".
	mixin (F!("cell", "setAt", "size_t i", "cell c"));

	// *Pushed() forms take invertmode into account, applying from the correct
	// direction so as to work on cells that have just been pushed. They don't
	// update statistics and assume a nonempty stack.
	mixin (F!("void", "popPushed", "size_t n"));
	mixin (F!("cell", "topPushed"));
	mixin (F!("void", "mapFirstNPushed",
		"size_t n", "void delegate(cell[]) f", "void delegate(size_t) g"));

	byte mode() { return isDeque ? deque.mode : 0; }
}

// The stack is, by default, a Stack instead of a Deque even though the MODE
// fingerprint needs a Deque.
//
// This is because a simple Stack is measurably faster when the full Deque
// functionality is not needed.
struct Stack(T) {
	private {
		T* array;
		size_t capacity;
		size_t head;
	}
	ContainerStats* stats;

	static typeof(*this) opCall(ContainerStats* stats, size_t n = 0100)
	{
		typeof(*this) x;
		x.stats = stats;
		x.capacity = n;
		x.array = malloc!(T)(x.capacity);
		return x;
	}

	static typeof(*this) opCall(Stack s) {
		typeof(*this) x;
		with (x) {
			stats          = s.stats;
			head           = s.size;
			capacity       = s.capacity;
			array          = malloc!(T)(capacity);
			array[0..head] = s.array[0..head];
		}
		return x;
	}

	version (MODE)
	static typeof(*this) opCall(ContainerStats* stats, Deque q) {
		typeof(*this) x;
		x.stats = stats;
		with (x) {
			head = q.size;

			static if (is(T : cell)) {
				auto arr = q.elementsBottomToTop;
				capacity = arr.length;
				array = malloc!(T)(capacity);
				array[0..head] = arr[0..head];
			} else
				assert (false, "Trying to make non-cell stack out of deque");
		}
		return x;
	}

	void free() { .free(array); }

	T pop() {
		++stats.pops;

		// not an error to pop an empty stack
		if (empty) {
			static if (is (T : cell)) {
				++stats.popUnderflows;
				return 0;
			} else
				assert (false, "Attempted to pop empty non-cell stack.");
		} else
			return array[--head];
	}

	void pop(size_t i) {
		stats.pops += i;

		if (i >= head) {
			stats.popUnderflows += i - head;
			head = 0;
		} else
			head -= i;
	}
	void popPushed(size_t n) {
		stats.pops -= n;
		pop(n);
	}

	void clear() {
		++stats.clears;
		stats.cleared += size;

		head = 0;
	}

	T top() {
		++stats.peeks;

		if (empty) {
			static if (is (T : cell)) {
				++stats.peekUnderflows;
				return 0;
			} else
				assert (false, "Attempted to peek empty non-cell stack.");
		}

		return array[head-1];
	}
	T topPushed() {
		assert (!empty);
		return array[head-1];
	}

	void push(U...)(U ts) {
		stats.pushes += ts.length;
		stats.newMax(stats.maxSize, size + ts.length);

		auto neededRoom = head + ts.length;
		if (neededRoom > capacity) {
			++stats.resizes;

			capacity = 2 * capacity +
				(neededRoom > 2 * capacity ? neededRoom : 0);

			array = realloc(array, capacity);
		}

		foreach (t; ts)
			array[head++] = cast(T)t;
	}

	size_t size() { return head; }
	bool empty()  { return head == 0; }



	T* reserve(size_t n) {
		stats.pushes += n;

		if (capacity < n + head) {
			++stats.resizes;

			capacity = n + head;
			array = realloc(array, capacity);
		}

		auto ptr = &array[head];

		head += n;
		assert (head <= capacity);

		return ptr;
	}

	T    at(size_t i)      { return array[i]; }
	T setAt(size_t i, T t) { return array[i] = t; }

	void mapFirstN(size_t n, void delegate(T[]) f, void delegate(size_t) g) {
		if (n <= head)
			f(array[head-n .. head]);
		else {
			g(n - head);
			f(array[0 .. head]);
		}
	}
	void mapFirstNHead(size_t n, void delegate(T[]) f, void delegate(size_t) g)
	{
		return mapFirstN(n, f, g);
	}
	void mapFirstNPushed(
		size_t n, void delegate(T[]) f, void delegate(size_t) g)
	{
		return mapFirstN(n, f, g);
	}



	int opApply(int delegate(inout T t) dg) {
		int r = 0;
		foreach (inout a; array[0..head])
			if (r = dg(a), r)
				break;
		return r;
	}

	int topToBottom(int delegate(inout T t) dg) {
		int r = 0;
		foreach_reverse (inout a; array[0..head])
			if (r = dg(a), r)
				break;
		return r;
	}

	int bottomToTop(int delegate(inout T t) dg) {
		return opApply(dg);
	}
}

enum : byte {
	INVERT_MODE = 1 << 0,
	QUEUE_MODE  = 1 << 1
}

// Chunk-style implementation: keeps a doubly linked list of chunks, each of
// which contains an array of data. Grows forwards as a stack and backwards as
// a queue.
//
// Abnormally, new chunks are only created when growing backwards: when growing
// forwards, the headmost chunk is merely resized.
version (MODE)
struct Deque {
	private {
		struct Chunk {
			cell* array;     // Typically not resizable
			size_t capacity; // Typically constant

			// head: the index of one past the topmost value: (0, capacity]
			// tail: the index of the bottommost value:       [0,capacity)
			//
			// Note that head can be zero and tail can be the
			// capacity when the chunk is empty.
			size_t head, tail;

			Chunk* next, prev;

			size_t size() { return head - tail; }
		}
		// tail may have a nonnull prev and head may have a nonnull next: this is
		// so that if we keep pop/pushing one cell at a chunk boundary we don't
		// have to constantly reallocate.
		Chunk* head, tail;

		ContainerStats* stats;
	}
	byte mode = 0;

	// Have to be a bit conservative here since after free() a lot of stuff is
	// invalidated. Otherwise both head and tail are nonnull, for example.
	invariant {
		if (head != tail) {
			assert (head);
			assert (tail);
			assert (tail.head == tail.capacity);
			assert (head.tail == 0);
		}
		if (tail && tail.prev)
			assert (!tail.prev.prev);
		if (head && head.next)
			assert (!head.next.next);
		for (auto c = tail; c; c = c.next)
			assert (c.tail <= c.head);
	}

	private const size_t
		DEFAULT_SIZE  = 0100,
		NEW_TAIL_SIZE = 020000;

	static typeof(*this) opCall(ContainerStats* stats, size_t n = DEFAULT_SIZE)
	{
		typeof(*this) x;
		x.stats = stats;
		x.head = x.tail = malloc!(Chunk)(1);

		with (*x.head) {
			capacity = n;
			array = malloc!(cell)(capacity);
			head = tail = 0;
			next = prev = null;
		}
		return x;
	}

	static typeof(*this) opCall(Deque q) {
		typeof(*this) x;
		with (x) {
			stats = q.stats;
			mode  = q.mode;

			tail = malloc!(Chunk)(1);

			// We don't care about q.tail.prev even if it exists
			tail.prev = null;

			for (auto qc = q.tail, c = tail;;) {
				c.head = qc.head;
				c.tail = qc.tail;
				c.capacity = qc.capacity;
				with (*c) {
					array = malloc!(cell)(capacity);
					array[tail..head] = qc.array[tail..head];
				}
				if (qc == q.head) {
					c.next = null;
					head = c;
					break;
				}
				c.next = malloc!(Chunk)(1);
				c.next.prev = c;
				c  =  c.next;
				qc = qc.next;
			}
		}
		return x;
	}
	static typeof(*this) opCall(ContainerStats* stats, Stack!(cell) s) {
		typeof(*this) x;
		x.stats = stats;
		x.head = x.tail = malloc!(Chunk)(1);

		with (*x.head) {
			capacity = max(s.size, DEFAULT_SIZE);
			array = malloc!(cell)(capacity);
			array[0..s.size] = s.array[0..s.size];
			tail = 0;
			head = s.size;
			next = prev = null;
		}
		return x;
	}

	void free() {
		.free(tail.array);
		if (tail.prev) {
			.free(tail.prev.array);
			.free(tail.prev);
		}
		if (tail.next) for (auto c = tail.next;;) {
			.free(c.array);
			.free(c.prev);
			if (c.next)
				c = c.next;
			else {
				.free(c);
				break;
			}
		} else
			.free(tail);
		head = tail = null;
	}

	cell pop() {
		++stats.pops;

		if (empty) {
			++stats.popUnderflows;
			return 0;
		}

		if (mode & QUEUE_MODE)
			return popTail();
		else
			return popHead();
	}

	void pop(size_t i)  {
		stats.pops += i;

		if (mode & QUEUE_MODE)
			i = popTail(i);
		else
			i = popHead(i);
		stats.popUnderflows += i;
	}
	void popPushed(size_t n) {
		if (mode & INVERT_MODE)
			popTail(n);
		else
			popHead(n);
	}
	private size_t popHead(size_t i) {
		for (;;) {
			if (i <= head.size) {
				head.head -= i;
				return 0;
			}
			i -= head.size;
			if (!dropHeadChunk())
				return i;
		}
	}
	private size_t popTail(size_t i) {
		for (;;) {
			if (i < tail.size) {
				tail.tail += i;
				return 0;
			}
			i -= tail.size;
			if (!dropTailChunk())
				return i;
		}
	}

	private cell popHead() {
		auto c = head.array[--head.head];

		if (head.head <= head.tail)
			dropHeadChunk();

		return c;
	}
	private cell popTail() {
		auto c = tail.array[tail.tail++];

		if (tail.tail >= tail.head)
			dropTailChunk();

		return c;
	}

	void clear() {
		++stats.clears;

		stats.cleared += tail.size;

		// Drop back down to one chunk, which might as well be the current tail.
		//
		// Note that we might still have a tail.prev alive, which is fine.
		if (head != tail) {
			auto c = tail.next;

			stats.cleared += c.size;
			.free(c.array);

			for (c = c.next;;) {
				stats.cleared += c.size;
				.free(c.array);
				.free(c.prev);
				if (c.next)
					c = c.next;
				else {
					.free(c);
					break;
				}
			}
			tail.next = null;
			head = tail;
		}
		tail.head = tail.tail = 0;
	}

	cell top() {
		++stats.peeks;

		if (empty) {
			++stats.peekUnderflows;
			return 0;
		}

		if (mode & QUEUE_MODE)
			return tail.array[tail.tail];
		else
			return head.array[head.head-1];
	}
	cell topPushed() {
		assert (!empty);

		if (mode & INVERT_MODE)
			return tail.array[tail.tail];
		else
			return head.array[head.head-1];
	}

	void push(C...)(C cs) {
		stats.pushes += cs.length;
		stats.newMax(stats.maxSize, size + cs.length);

		if (mode & INVERT_MODE)
			pushTail(cs);
		else
			pushHead(cs);
	}
	private void pushHead(C...)(C cs) {
		auto newHead = head.head + cs.length;
		if (newHead > head.capacity) {
			++stats.resizes;

			head.capacity = 2 * head.capacity +
				(newHead > 2 * head.capacity ? newHead :  0);

			head.array = realloc(head.array, head.capacity);
		}

		foreach (c; cs)
			head.array[head.head++] = c;
	}
	private void pushTail(C...)(C cs) {
		size_t i = 0;

		auto newTail = tail.tail - cs.length;
		if (newTail > tail.capacity) {
			if (head == tail && head.size == 0 && cs.length <= head.capacity) {
				// We can fixup the position in the chunk instead of having to
				// resort to resizing
				head.head = head.tail = max(cs.length, head.capacity / 2);
			} else {
				// Tuple hacks, equivalent to:
				// while (tail.tail > 0) tail.array[--tail.tail] = cs[i++].
				// i.e. push what we can into the current tail.
				foreach (j, c; cs) {
					if (tail.tail > 0)
						tail.array[--tail.tail] = c;
					else {
						i = j;
						break;
					}
				}

				newTailChunk(cs.length - i);
			}
		}

		// Another tuple hacks, equivalent to foreach (c; cs[i..$]).
		foreach (j, c; cs)
			if (j >= i)
				tail.array[--tail.tail] = c;
	}

	bool empty() { return head == tail && head.head <= head.tail; }
	size_t size() {
		size_t n = 0;
		for (auto c = tail; c; c = c.next)
			n += c.size;
		return n;
	}



	cell* reserve(size_t n) {
		if (mode & INVERT_MODE)
			return reserveTail(n);
		else
			return reserveHead(n);
	}
	cell* reserveHead(size_t n) {
		stats.pushes += n;

		auto newHead = head.head + n;
		if (head.capacity < newHead) {
			++stats.resizes;

			head.capacity = newHead;
			head.array = realloc(head.array, head.capacity);
		}

		auto ptr = &head.array[head.head];
		head.head = newHead;
		return ptr;
	}
	cell* reserveTail(size_t n) {
		stats.pushes += n;

		// Tricky.

		// If it fits in the tail chunk directly, just give that.
		{auto newTail = tail.tail - n;
		if (newTail < tail.capacity) {
			tail.tail = newTail;
			return &tail.array[tail.tail];
		}}

		if (head == tail && head.size == 0 && n <= head.capacity) {
			// Just fixup the position in the chunk
			head.head = max(n, head.capacity / 2);
			head.tail = head.head - n;
			return &head.array[head.tail];
		}

		const EXPENSIVE_RESIZE_LIMIT = NEW_TAIL_SIZE * 32;

		// If tail is small enough, resize it. More expensive than resizing the
		// head because we need to move the data to the right place. Thus also
		// pad it out to avoid having to resize it again in the near future.
		if (tail.size <= EXPENSIVE_RESIZE_LIMIT) {
			with (*tail) {
				++stats.resizes;

				capacity = 2 * capacity + (n > 2 * capacity ? n : 0);
				array = realloc(array, capacity);
			}

			if (head != tail) with (*tail) {
				// Need to move the data to the end
				if (capacity - size < head)
					array[capacity - size .. capacity] = array[tail..head];
				else
					memmove(&array[capacity - size], &array[tail], size);

				tail = capacity - size;
				head = capacity;

			} else with (*tail) {
				// Moving to the very end of the capacity might not be what we
				// want... leave an equal amount of free space at the beginning and
				// the end
				auto space = (capacity - (size + n)) / 2;
				auto odd   = (capacity - (size + n)) % 2;

				auto oldTailTgt = space + n + odd;

				if (head <= space + n)
					array[oldTailTgt .. oldTailTgt + size] = array[tail..head];
				else
					memmove(&array[oldTailTgt], &array[tail], size);

				tail = oldTailTgt - n;
				head = capacity - space;
			}
			assert (tail.size >= n);
			return &tail.array[tail.tail];
		}

		// If there is a tail.next and tail and tail.next are small enough,
		// resize tail.next (expensive again), copy tail into tail.next, and use
		// the now-empty tail.
		if (tail.next && tail.size <= EXPENSIVE_RESIZE_LIMIT/2
		              && tail.next.size <= EXPENSIVE_RESIZE_LIMIT/2)
		{
			++stats.resizes;

			tail.next.capacity = 2 * tail.next.capacity +
				(tail.size > 2 * tail.next.capacity ? tail.size : 0);

			tail.next.array = realloc(tail.next.array, tail.next.capacity);

			with (*tail.next) {
				if (head <= capacity - size)
					array[capacity - size .. capacity] = array[tail..head];
				else
					memmove(&array[capacity - size], &array[tail], size);

				tail = capacity - size;
				head = capacity;
			}
			tail.next.array[0..tail.size] = tail.array[tail.tail..tail.head];

			with (*tail) {
				if (capacity < n) {
					++stats.resizes;

					capacity = 2 * capacity + (n > 2 * capacity ? n : 0);
					array = realloc(array, capacity);
				}
				tail = capacity - n;
				head = capacity;
				return &array[tail];
			}
		}

		// Tail has no suitable neighbour and/or is too large to justify the
		// expensive size increasing: instead shrink tail's capacity to its
		// current size and use a different chunk for the reserve request.

		// First move the data to the beginning of tail so that the realloc
		// doesn't lose any of it.
		with (*tail) if (tail > 0) {
			if (size <= tail)
				array[0..size] = array[tail..head];
			else
				memmove(&array[0], &array[tail], size);
		}

		++stats.resizes;

		tail.capacity = tail.size;
		tail.array = realloc(tail.array, tail.capacity);

		newTailChunk(n);

		tail.tail = tail.capacity - n;
		return &tail.array[tail.tail];
	}

	cell at(size_t i) {
		if (mode & QUEUE_MODE)
			i = size-1 - i;

		for (auto c = tail;; c = c.next) {
			if (i < c.size)
				return c.array[c.tail + i];
			else
				i -= c.size;
		}
	}
	cell setAt(size_t i, cell x) {
		if (mode & QUEUE_MODE)
			i = size-1 - i;

		for (auto c = tail;; c = c.next) {
			if (i < c.size)
				return c.array[c.tail + i] = x;
			else
				i -= c.size;
		}
	}

	void mapFirstN(size_t n, void delegate(cell[]) f, void delegate(size_t) g) {
		if (mode & QUEUE_MODE)
			return mapFirstNTail(n, f, g);
		else
			return mapFirstNHead(n, f, g);
	}
	void mapFirstNPushed(
		size_t n, void delegate(cell[]) f, void delegate(size_t) g)
	{
		if (mode & INVERT_MODE)
			return mapFirstNTail(n, f, g);
		else
			return mapFirstNHead(n, f, g);
	}
	private void mapFirstNHead(
		size_t n, void delegate(cell[]) f, void delegate(size_t) g)
	{
		if (n <= head.size)
			return f(head.array[head.head-n .. head.head]);

		// Didn't fit into the head chunk... since we want to map from tail to
		// head, find the tailmost relevant chunk and the start position in it.
		auto tailMost = head.prev;
		n -= head.size;
		while (tailMost && n > tailMost.size) {
			n -= tailMost.size;
			tailMost = tailMost.prev;
		}

		if (!tailMost) {
			// Ran out of chunks: underflow by n
			g(n);
			tailMost = tail;
		} else if (n > 0) {
			// Didn't run out of chunks but want only n out of the last one
			f(tailMost.array[tailMost.head-n .. tailMost.head]);
			tailMost = tailMost.next;
		}

		do {
			f(tailMost.array[tailMost.tail .. tailMost.head]);
			tailMost = tailMost.next;
		} while (tailMost);
	}
	private void mapFirstNTail(
		size_t n, void delegate(cell[]) f, void delegate(size_t) g)
	{
		for (auto c = tail; c; c = c.next) {
			if (n <= c.size)
				return f(c.array[c.tail .. n + c.tail]);

			f(c.array[c.tail..c.head]);
			n -= c.size;
		}
		g(n);
	}



	int opApply(int delegate(inout cell t) dg) {
		for (auto ch = tail; ch; ch = ch.next)
			foreach (inout c; ch.array[ch.tail..ch.head])
				if (auto r = dg(c))
					return r;
		return 0;
	}

	int topToBottom(int delegate(inout cell t) dg) {
		for (auto ch = head; ch; ch = ch.prev)
			foreach_reverse (inout c; ch.array[ch.tail..ch.head])
				if (auto r = dg(c))
					return r;
		return 0;
	}

	int bottomToTop(int delegate(inout cell t) dg) {
		return opApply(dg);
	}

	cell[] elementsBottomToTop() {
		auto elems = new cell[size];

		auto p = elems.ptr;
		for (auto c = tail; c; c = c.next) {
			p[0..c.size] = c.array[c.tail..c.head];
			p += c.size;
		}
		return elems;
	}


	// Helpers

	private void newTailChunk(size_t minSize) {
		++stats.resizes;

		with (*tail) if (size == 0) {
			// Just resize the existing tail.

			// We shouldn't get into this situation unless something has detected
			// the capacity to be insufficient...
			assert (capacity < minSize);

			head = tail = capacity = minSize;
			array = realloc(array, capacity);
			return;
		}

		if (tail.prev) {
			// We have an extra chunk ready and waiting: use that
			with (*tail.prev) {
				if (capacity < minSize) {
					capacity = minSize;
					array = realloc(array, capacity);
				}
				head = tail = capacity;
			}
			tail = tail.prev;
			return;
		}

		auto c = malloc!(Chunk)(1);
		with (*c) {
			head = tail = capacity = max(minSize, NEW_TAIL_SIZE);
			array = malloc!(cell)(capacity);
			prev = null;
		}
		c.next = tail;
		tail = tail.prev = c;
	}
	private bool dropHeadChunk() {
		if (head == tail) {
			head.head = head.tail = 0;
			return false;
		}

		auto c = head;
		head = head.prev;
		head.next = null;

		.free(c.array);
		.free(c);
		return true;
	}
	private bool dropTailChunk() {
		if (head == tail) {
			tail.head = tail.tail = tail.capacity;
			return false;
		}

		// Keep the old tail in case we'll be needing it soon, but leave at most
		// one unused tail chunk
		if (tail.prev) {
			.free(tail.prev.array);
			.free(tail.prev);

			tail.prev = null;
		}
		tail.head = tail.tail = tail.capacity;
		tail = tail.next;
		return true;
	}
}

// No heap allocation if the length ends up at less than N.
struct SmallArray(T, size_t N) {
	static assert (N > 0);

	private {
		T[N] smallData;
		T* data = null;
		size_t len = 0, capacity = N;
	}

	void free() { .free(data); }

	size_t size() { return len; }
	T*     ptr () { return data ? data : smallData.ptr; }

	T opIndex           (size_t i) { assert (i < len); return ptr[i]; }
	T opIndexAssign(T t, size_t i) { assert (i < len); return ptr[i] = t; }

	void opCatAssign(T t) {
		if (len >= capacity)
			growBy(1);

		assert (len < capacity);

		ptr[len++] = t;
	}
	void opCatAssign(T[] ts) {
		auto newLen = len + ts.length;
		if (newLen > capacity)
			growBy(capacity - newLen);

		assert (newLen < capacity);

		ptr[len..newLen] = ts;
		len = newLen;
	}

	T[] opSlice() { return ptr[0..len]; }

private:
	void growBy(size_t incr) {
		capacity = 2 * capacity + (incr > 2 * capacity ? incr : 0);

		if (data == null) {
			data = malloc!(T)(capacity);
			data[0..len] = smallData[0..len];
		} else
			data = realloc(data, capacity);
	}
}

// Unrolled doubly linked list designed for prepending at any position (assumes
// no appends and thus stores the first element last in each node).
//
// Central nodes might have length shorter than N.
struct UDLL(T, ubyte N) {
	static assert (N > 0);
	static assert (N-1 < ubyte.max - (2+1)); // Beware ceilDiv overflow

	private {
		struct Node {
			Node* prev, next;
			ubyte beg;
			T[N] data;

			ubyte length() { return N - beg; }
		}
		Node* tail = void;
		size_t len = 0;
	}
	struct Iterator {
		private {
			Node* node;
			ubyte i;
		}

		T    val() { return node.data[i]; }
		void val(T t) { node.data[i] = t; }

		bool ok() { return node !is null; }
		void opPostInc() {
			if (i < N-1)
				++i;
			else {
				node = node.next;
				if (node)
					i = node.beg;
			}
		}
	}

	static typeof(*this) opCall(T t) {
		typeof(*this) dll;
		with (dll) {
			tail = malloc!(Node)(1);
			tail.prev = tail.next = null;
			tail.beg = N-1;
			len = 1;
			tail.data[N-1] = t;
		}
		return dll;
	}
	static typeof(*this) opCall(size_t n)
	in {
		assert (n > 0);
	} body {
		typeof(*this) dll;
		with (dll) {
			len = n;

			tail = malloc!(Node)(1);
			tail.prev = null;

			auto lastNode = tail;

			if (n > N) {
				tail.beg = 0;
				auto prevNode = tail;
				for (n -= N; n > N; n -= N) {
					auto node = malloc!(Node)(1);
					node.prev = prevNode;
					prevNode.next = node;
					node.beg = 0;
					prevNode = node;
				}
				lastNode = prevNode;
			}
			lastNode.next = null;
			lastNode.beg = N - n;
		}
		return dll;
	}

	size_t  length() { return len; }
	Iterator first() { return Iterator(tail, tail.beg); }

	void free()
	in {
		assert (length > 0);
	} body {
		len = 0;
		if (!tail.next)
			return .free(tail);
		for (auto node = tail.next;; node = node.next) {
			.free(node.prev);
			if (!node.next) {
				.free(node);
				break;
			}
		}
	}

	void prependTo(Iterator it, T t) {
		++len;

		if (it.node.length < N) {
			if (it.i > it.node.beg) {
				// Make a gap in it.node.data. E.g. prepending to 3:
				// [ x 1 2 3 4 5 ]
				//     b   i
				// [ x 1 2 3 4 5 ]
				//   ^ beg - 1, at wrong place
				// So memmove: [ 1 2 x 3 4 5 ]
				memmove(
					it.node.data.ptr + it.node.beg - 1,
					it.node.data.ptr + it.node.beg,
					(it.i - it.node.beg) * T.sizeof);
			}
			--it.node.beg;
			it.node.data[it.i - 1] = t;
			return;
		}

		auto node = malloc!(Node)(1);
		node.prev = it.node.prev;
		node.next = it.node;
		it.node.prev = node;
		if (node.prev)
			node.prev.next = node;
		else {
			assert (it.node == tail);
			tail = node;
		}

		if (it.i == 0) {
			// Nothing precedes t so we have no choice (don't bother seeing if
			// node has a prev and trying to even even more), put it alone into
			// the new node.
			node.beg = N-1;
			node.data[N-1] = t;
			return;
		}

		// Try to even things out: copy half (instead of all) of what needs to
		// move over to the new node, and put t into the old (instead of the
		// new) node.
		auto copyOver = ceilDiv!(typeof(it.i))(it.i, 2);

		assert (copyOver > 0);

		node.data[N-copyOver..N] = it.node.data[0..copyOver];
		node.beg = N-copyOver;

		memmove(
			it.node.data.ptr + copyOver - 1,
			it.node.data.ptr + copyOver,
			(it.i - copyOver) * T.sizeof);

		it.node.beg = copyOver - 1;
		it.node.data[it.i-1] = t;
	}

	Iterator removeAt(Iterator it)
	in {
		// Not sure if everything works when the whole thing empties...
		assert (length > 1);
	} body {
		--len;
		if (it.node.length > 1) {
			if (it.i > it.node.beg) {
				// Fill the gap in it.node.data. E.g. removing 3:
				// [ x 1 2 3 4 5 ]
				//     b   i
				// [ x 1 2 3 4 5 ]
				//       ^ beg + 1, at wrong place
				// So memmove: [ x 1 1 2 4 5 ]
				memmove(
					it.node.data.ptr + it.node.beg + 1,
					it.node.data.ptr + it.node.beg,
					(it.i - it.node.beg) * T.sizeof);
			}
			++it.node.beg;
			it++;
			return it;
		}

		if (it.node.prev) it.node.prev.next = it.node.next;
		if (it.node.next) it.node.next.prev = it.node.prev;

		if (it.node == tail) tail = tail.next;

		auto next = it.node.next;

		.free(it.node);

		typeof(next.beg) nextBeg = void;
		if (next)
			nextBeg = next.beg;

		return Iterator(next, nextBeg);
	}

	int opApply(int delegate(inout T) f) {
		for (auto it = first; it.ok; it++)
			if (auto r = f(it.node.data[it.i]))
				return r;
		return 0;
	}

version (tracer):

	// Indexes from the rear!
	T opIndex(size_t i)
	in {
		assert (i < length);
	} body {
		foreach (j, t; *this)
			if (i == j)
				return t;
		assert (false);
	}

	Iterator iterOf(size_t i)
	in {
		assert (i < length);
	} body {
		for (auto node = tail;; node = node.next) {
			if (i < node.length)
				return Iterator(node, N - (i+1));

			i -= node.length;
		}
	}

	// Traverses from the rear, matching opIndex!
	//
	// Modifications to the index are dropped.
	int opApply(int delegate(inout size_t, inout T) f)
	in {
		assert (length > 0);
	} body {
		auto head = tail;
		for (; head.next; head = head.next){}

		size_t i = 0;
		for (auto node = head; node; node = node.prev) {
			for (auto j = N; j-- > node.beg;) {
				auto k = i++;
				if (auto r = f(k, node.data[j]))
					return r;
			}
		}
		return 0;
	}
}
