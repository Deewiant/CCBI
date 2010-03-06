// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-21 12:14:27

module ccbi.container;

import tango.core.Memory : GC;
import tango.core.Exception : onOutOfMemoryError;
import tango.core.Tuple;
import c = tango.stdc.stdlib;

import ccbi.cell;
import ccbi.stats;
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

		static if (is(T == class) || is(T == interface) || is(T : T*))
			GC.addRange(p, n * T.sizeof);

		return p;
	}
	T* realloc(T)(T* p0, size_t n) {
		auto p = cast(T*)c.realloc(p0, n * T.sizeof);
		if (!p)
			onOutOfMemoryError();

		static if (is(T == class) || is(T == interface) || is(T : T*)) {
			if (p != p0) {
				GC.removeRange(p0);
				GC.addRange(p, n * T.sizeof);
			}
		}

		return p;
	}
	void free(T)(T* p) {
		c.free(p);
		static if (is(T == class) || is(T == interface))
			GC.removeRange(p);
	}
}

private const size_t DEFAULT_SIZE = 0100;

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

struct CellContainer {
	bool isDeque = false;
	union {
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

	// different to pop() in queuemode, needed for tracing
	mixin (F!("cell", "popHead"));

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
	// different to push() in invertmode, needed for tracing and copying
	void pushHead(T...)(T xs) {
		if (isDeque)
			deque.pushHead(xs);
		else
			stack.pushHead(xs);
	}

	mixin (F!("size_t", "size"));
	mixin (F!("bool", "empty"));

	mixin (F!("ContainerStats*", "stats"));

	mixin (F!("void", "free"));

	mixin (F!("int", "opApply", "int delegate(inout cell c) f"));

	mixin (F!("int", "topToBottom", "int delegate(inout cell c) f"));
	mixin (F!("int", "bottomToTop", "int delegate(inout cell c) f"));

	mixin (F!("cell[]", "elementsBottomToTop"));

	// Abstraction-breaking stuff

	// Makes sure that there's capacity for at least the given number of cells.
	// Modifies size, but doesn't guarantee any values for the reserved
	// elements.
	//
	// Returns a pointer to the top of the array overlaying the storage that
	// backs this Container, guaranteeing that following the pointer there is
	// space for least the given number of Ts.
	mixin (F!("cell*", "reserve", "size_t n"));

	// at(x) is equivalent to elementsBottomToTop()[x] but doesn't allocate.
	mixin (F!("cell", "at", "size_t i"));

	// Calls the first given function over consecutive sequences of the top n
	// elements, whose union is the top n elements. Traverses bottom-to-top.
	//
	// If n is greater than the size, instead first calls the second given
	// function with the difference of n and the size, then proceeds to call the
	// first function as though the size had been passed as n.
	mixin (F!("void", "mapTopN",
		"size_t n", "void delegate(cell[]) f", "void delegate(size_t) g"));
}

/+ The stack is, by default, a Stack instead of a Deque even though the MODE
 + fingerprint needs a Deque.
 + This is because of the following performance measurement:
 +
 +   Operation    Iterations    Time (ms) (Stack)    Time (ms) (Deque)    Ratio
 +
 +    push(int)   10 000 000           680                 2790            4.1
 +     pop(1)     10 000 000            45                  125            2.8
 +    push(int)   50 000 000        343265
 +     pop(1)     50 000 000           235
 +
 + (Time is +- 5 ms, averaged over two runs for the 10 000 000 case, ratio is
 + to one decimal point)
 +
 + Thus, until we really need the Deque functionality, it's smarter to use the
 + Stack.
 +/

struct Stack(T) {
	private {
		T* array;
		size_t capacity;
		size_t head;
		ContainerStats* stats;
	}

	static typeof(*this) opCall(ContainerStats* stats, size_t n = DEFAULT_SIZE)
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

	T popHead() { return pop(); }

	void pop(size_t i)  {
		stats.pops          += i;
		stats.popUnderflows += i;

		if (i >= head) {
			stats.popUnderflows -= head;
			head = 0;
		} else
			head -= i;
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

	void push(U...)(U ts) {
		stats.pushes += ts.length;

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
	void pushHead(U...)(U ts) { push(ts); }

	size_t size() { return head; }
	bool empty()  { return head == 0; }



	T* reserve(size_t n) {
		stats.pushes += n;

		if (capacity < n + head) {
			capacity = n + head;
			array = realloc(array, capacity);
		}

		auto ptr = &array[head];

		head += n;
		assert (head <= capacity);

		return ptr;
	}

	T at(size_t i) { return array[i]; }

	void mapTopN(size_t n, void delegate(T[]) f, void delegate(size_t) g) {
		if (n <= head)
			f(array[head-n .. head]);
		else {
			g(n - head);
			f(array[0 .. head]);
		}
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



	T[] elementsBottomToTop() { return array[0..head]; }
}

enum : byte {
	INVERT_MODE = 1 << 0,
	QUEUE_MODE  = 1 << 1
}

// only used if the MODE fingerprint is loaded
struct Deque {
	private {
		// Same order of members as in Stack!(cell)... may or may not lead to
		// better codegen with the union in CellContainer
		cell* array;
		size_t capacity;
		size_t head;
		ContainerStats* stats;

		size_t tail;
	}
	byte mode;

	static typeof(*this) opCall(ContainerStats* stats, size_t n = DEFAULT_SIZE)
	{
		typeof(*this) x;
		x.stats = stats;
		x.allocateArray(n);
		return x;
	}

	static typeof(*this) opCall(Deque q) {
		typeof(*this) x;
		with (x) {
			stats    = q.stats;
			mode     = q.mode;
			tail     = q.tail;
			head     = q.head;
			capacity = q.capacity;
			array    = malloc!(cell)(capacity);
		}
		return x;
	}
	static typeof(*this) opCall(ContainerStats* stats, Stack!(cell) s) {
		typeof(*this) x;
		x.stats = stats;
		with (x) {
			assert (mode == 0);

			allocateArray(s.size);

			foreach (c; &s.bottomToTop)
				push(c);
		}
		return x;
	}

	void free() { .free(array); }

	cell pop() {
		if (mode & QUEUE_MODE)
			return popTail();
		else
			return popHead();
	}

	void pop(size_t i)  {
		stats.pops += i;

		if (!empty) {
			if (mode & QUEUE_MODE) while (i--) {
				tail = (tail - 1) & (capacity - 1);
				if (empty)
					break;
			} else while (i--) {
				head = (head + 1) & (capacity - 1);
				if (empty)
					break;
			}
		}

		stats.popUnderflows += i;
	}
	cell popHead() {
		++stats.pops;

		if (empty) {
			++stats.popUnderflows;
			return 0;
		}

		auto h = array[head];
		head = (head + 1) & (capacity - 1);
		return h;
	}

	void clear() {
		++stats.clears;
		stats.cleared += size;

		head = tail = 0;
	}

	cell top() {
		if (mode & QUEUE_MODE)
			return peekTail();
		else
			return peekHead();
	}

	void push(T...)(T ts) {
		if (mode & INVERT_MODE)
			pushTail(ts);
		else
			pushHead(ts);
	}
	void pushHead(C...)(C cs) {
		stats.pushes += cs.length;

		foreach (c; cs) {
			head = (head - 1) & (capacity - 1);
			array[head] = cast(cell)c;
			if (head == tail)
				doubleCapacity();
		}
	}

	size_t size() { return (tail - head) & (capacity - 1); }
	bool empty()  { return tail == head; }



	cell* reserve(size_t n) {
		assert (false, "TODO");
	}

	cell at(size_t i) {
		assert (false, "TODO");
	}

	void mapTopN(size_t n, void delegate(cell[]) f, void delegate(size_t) g) {
		assert (false, "TODO");
	}



	int opApply(int delegate(inout cell t) dg) {
		int r = 0;
		for (size_t i = head; i != tail; i = (i + 1) & (capacity - 1))
			if (r = dg(array[i]), r)
				break;
		return r;
	}

	int topToBottom(int delegate(inout cell t) dg) {
		return opApply(dg);
	}

	int bottomToTop(int delegate(inout cell t) dg) {
		int r = 0;
		for (size_t i = tail; i != head; i = (i - 1) & (capacity - 1))
			if (r = dg(array[i]), r)
				break;
		return r;
	}

	cell[] elementsBottomToTop() {
		auto elems = new cell[size];

		if (head < tail)
			elems[0..size] = array[head..head + size];
		else if (head > tail) {
			auto lh = capacity - head;
			elems[ 0..lh]        = array[head..capacity];
			elems[lh..lh + tail] = array[0..tail];
		}

		return elems.reverse;
	}

private:

	void pushTail(C...)(C cs) {
		stats.pushes += cs.length;

		foreach (c; cs) {
			array[tail] = cast(cell)c;
			tail = (tail + 1) & (capacity - 1);
			if (head == tail)
				doubleCapacity();
		}
	}

	cell popTail() {
		++stats.pops;

		if (empty) {
			++stats.popUnderflows;
			return 0;
		}

		tail = (tail - 1) & (capacity - 1);
		return array[tail];
	}

	cell peekHead() {
		++stats.peeks;

		if (empty) {
			++stats.peekUnderflows;
			return 0;
		} else
			return array[head];
	}
	cell peekTail() {
		++stats.peeks;

		if (empty) {
			++stats.peekUnderflows;
			return 0;
		} else
			return array[(tail - 1) & (capacity - 1)];
	}

	void allocateArray(size_t length) {
		auto newSize = DEFAULT_SIZE;

		if (length >= newSize) {
			static assert (newSize.sizeof == 4 || newSize.sizeof == 8,
				"Change size calculation in ccbi.container.Deque.allocateArray");

			newSize = length;
			newSize |= (newSize >>>  1);
			newSize |= (newSize >>>  2);
			newSize |= (newSize >>>  4);
			newSize |= (newSize >>>  8);
			newSize |= (newSize >>> 16);

			static if (newSize.sizeof == 8)
			newSize |= (newSize >>> 32);

			// oops, overflowed
			if (++newSize < 0)
				newSize >>>= 1;
		}

		capacity = newSize;
		array = realloc(array, capacity);
	}

	void doubleCapacity() {
		assert (head == tail);

		++stats.resizes;

		// elems to the right of head
		auto r = capacity - head;

		auto newArray = malloc!(cell)(capacity * 2);
		newArray[0..r     ] = array[head..head+r];
		newArray[r..r+head] = array[0   ..head  ];

		head  = 0;
		tail  = capacity;
		array = newArray;
		capacity *= 2;
	}
}
