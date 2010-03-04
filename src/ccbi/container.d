// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-21 12:14:27

module ccbi.container;

import ccbi.cell;
import ccbi.stats;

abstract class Container(T) {
	const size_t DEFAULT_SIZE = 0100;

	abstract {
		T pop();

		// different to pop() in queuemode, needed for tracing
		T popHead();

		// pop this many elements, ignoring their values
		void pop(size_t);

		void clear();

		T top();

		void push(T[]...);

		// different to push() in invertmode, needed for tracing and copying
		void pushHead(T[]...);

		size_t size();
		bool empty();

		// Abstraction-breaking stuff

		// Makes sure that there's capacity for at least the given number of Ts.
		// Modifies size, but doesn't guarantee any values for the reserved
		// elements.
		//
		// Returns a pointer to the top of the array overlaying the storage that
		// backs this Container, guaranteeing that following the pointer there is
		// space for least the given number of Ts.
		T* reserve(size_t);

		// at(x) is equivalent to elementsBottomToTop()[x] but doesn't allocate.
		T at(size_t);
	}

	protected {
		T[] array;
		size_t head = 0;
	}
	ContainerStats* stats;

	// only needed in Deque, but it's easier to pass it from stack to stack
	// (since it's meant to be per-IP) if it's declared here
	byte mode;

	abstract {
		int opApply    (int delegate(inout T t) dg);

		int topToBottom(int delegate(inout T t) dg);
		int bottomToTop(int delegate(inout T t) dg);

		T[] elementsBottomToTop();
	}
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

final class Stack(T) : Container!(T) {
	private this() {}

	this(Stack s) {
		super.stats = s.stats;

		array = s.array.dup;
		head  = s.size;

	}

	this(ContainerStats* stats, Deque q) {
		super.stats = stats;

		static if (is(T : cell))
			array = q.elementsBottomToTop.dup;
		else
			assert (false, "Trying to make non-cell stack out of deque");

		head = q.size;
	}

	this(ContainerStats* stats, size_t n = super.DEFAULT_SIZE) {
		super.stats = stats;
		array.length = n;
	}

	final {
		override T pop() {
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

		override T popHead() { return pop(); }

		override void pop(size_t i)  {
			stats.pops          += i;
			stats.popUnderflows += i;

			if (i >= head) {
				stats.popUnderflows -= head;
				head = 0;
			} else
				head -= i;
		}

		override void clear() {
			++stats.clears;
			stats.cleared += size;

			head = 0;
		}

		override T top() {
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

		override void push(T[] ts...) {
			stats.pushes += ts.length;

			auto neededRoom = head + ts.length;
			if (neededRoom > array.length) {
				++stats.resizes;

				array.length = 2 * array.length +
					(neededRoom > 2 * array.length ? neededRoom : 0);
			}

			foreach (t; ts)
				array[head++] = t;
		}
		override void pushHead(T[] ts...) { push(ts); }

		override size_t size() { return head; }
		override bool empty()  { return head == 0; }



		override T* reserve(size_t n) {
			if (array.length < n + head)
				array.length = n + head;

			auto ptr = &array[head];

			head += n;
			assert (head <= array.length);

			return ptr;
		}

		override T at(size_t i) { return array[i]; }



		override int opApply(int delegate(inout T t) dg) {
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



		override T[] elementsBottomToTop() { return array[0..head]; }
	}
}

enum : byte {
	INVERT_MODE = 1 << 0,
	QUEUE_MODE  = 1 << 1
}

// only used if the MODE fingerprint is loaded
final class Deque : Container!(cell) {
	private this() {}

	this(Deque q) {
		super.stats = q.stats;

		mode  = q.mode;
		tail  = q.tail;
		head  = q.head;
		array = q.array.dup;
	}
	this(ContainerStats* stats, Stack!(cell) s) {
		super.stats = stats;

		assert (mode == 0);

		allocateArray(s.size);

		this.push(s.elementsBottomToTop);
	}

	this(ContainerStats* stats, size_t n = super.DEFAULT_SIZE) {
		super.stats = stats;
		allocateArray(n);
	}

	private typeof(head) tail = 0;

	final {
		override cell pop() {
			if (mode & QUEUE_MODE)
				return popTail();
			else
				return popHead();
		}

		override void pop(size_t i)  {
			stats.pops += i;

			if (!empty) {
				if (mode & QUEUE_MODE) while (i--) {
					tail = (tail - 1) & (array.length - 1);
					if (empty)
						break;
				} else while (i--) {
					head = (head + 1) & (array.length - 1);
					if (empty)
						break;
				}
			}

			stats.popUnderflows += i;
		}
		override cell popHead() {
			++stats.pops;

			if (empty) {
				++stats.popUnderflows;
				return 0;
			}

			auto h = array[head];
			head = (head + 1) & (array.length - 1);
			return h;
		}

		override void clear() {
			++stats.clears;
			stats.cleared += size;

			head = tail = 0;
		}

		override cell top() {
			if (mode & QUEUE_MODE)
				return peekTail();
			else
				return peekHead();
		}

		override void push(cell[] ts...) {
			if (mode & INVERT_MODE)
				pushTail(ts);
			else
				pushHead(ts);
		}
		override void pushHead(cell[] cs...) {
			stats.pushes += cs.length;

			foreach (c; cs) {
				head = (head - 1) & (array.length - 1);
				array[head] = c;
				if (head == tail)
					doubleCapacity();
			}
		}

		override size_t size() { return (tail - head) & (array.length - 1); }
		override bool empty()  { return tail == head; }



		override cell* reserve(size_t n) {
			assert (false, "TODO");
		}

		override cell at(size_t i) {
			assert (false, "TODO");
		}



		override int opApply(int delegate(inout cell t) dg) {
			int r = 0;
			for (size_t i = head; i != tail; i = (i + 1) & (array.length - 1))
				if (r = dg(array[i]), r)
					break;
			return r;
		}

		int topToBottom(int delegate(inout cell t) dg) {
			return opApply(dg);
		}

		int bottomToTop(int delegate(inout cell t) dg) {
			int r = 0;
			for (size_t i = tail; i != head; i = (i - 1) & (array.length - 1))
				if (r = dg(array[i]), r)
					break;
			return r;
		}

		override cell[] elementsBottomToTop() {
			auto elems = new cell[size];

			if (head < tail)
				elems[0..size] = array[head..head + size];
			else if (head > tail) {
				auto lh = array.length - head;
				elems[ 0..lh]        = array[head..$];
				elems[lh..lh + tail] = array[0..tail];
			}

			return elems.reverse;
		}
	}

	private final {
		void pushTail(cell[] cs...) {
			stats.pushes += cs.length;

			foreach (c; cs) {
				array[tail] = c;
				tail = (tail + 1) & (array.length - 1);
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

			tail = (tail - 1) & (array.length - 1);
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
				return array[(tail - 1) & (array.length - 1)];
		}

		void allocateArray(size_t length) {
			auto newSize = super.DEFAULT_SIZE;

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

			array = new typeof(array)(newSize);
		}

		void doubleCapacity() {
			assert (head == tail);

			++stats.resizes;

			// elems to the right of head
			auto r = array.length - head;

			auto newArray = new typeof(array)(array.length * 2);
			newArray[0..r     ] = array[head..head+r];
			newArray[r..r+head] = array[0   ..head  ];

			head  = 0;
			tail  = array.length;
			array = newArray;
		}
	}
}
