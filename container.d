// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-21 12:14:27

module ccbi.container;

import ccbi.cell;

abstract class Container(T) {
	const size_t DEFAULT_SIZE = 0100;

	T pop();
	T popHead(); // different to pop() in queuemode, needed for tracing
	void pop(size_t); // pop this many elements, ignoring their values
	void clear();

	T top();

	void push(T[]...);
	void pushHead(T[]...); // different to push() in invertmode, needed for tracing and copying

	size_t size();
	bool empty();

	protected {
		T[] array;
		size_t head = 0;
	}

	// only needed in Deque, but it's easier to pass it from stack to stack
	// (since it's meant to be per-IP) if it's declared here
	byte mode;

	int opApply    (int delegate(inout T t) dg);

	int topToBottom(int delegate(inout T t) dg);
	int bottomToTop(int delegate(inout T t) dg);

	T[] elementsBottomToTop();
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
	this(typeof(super) s) {
		assert (cast(typeof(this))s || cast(Deque)s);

		if (cast(typeof(this))s) {
			array = s.array.dup;
			head  = s.size;
		} else {
			auto q = cast(Deque)s;
			assert (q);

			static if (is(T : cell))
				array = q.elementsBottomToTop.dup;
			else
				assert (false, "Trying to make non-cell stack out of deque");

			head  = q.size;
		}
	}

	this(size_t n = super.DEFAULT_SIZE) { array.length = n; }

	final override {
		T pop() {
			// not an error to pop an empty stack
			if (empty) {
				static if (is (T : cell))
					return 0;
				else
					assert (false, "Attempted to pop empty non-cell stack.");
			} else
				return array[--head];
		}

		T popHead() { return pop(); }

		void pop(size_t i)  {
			if (i >= head)
				head = 0;
			else
				head -= i;
		}

		void clear() { head = 0; }

		T top() {
			if (empty) {
				static if (is (T : cell))
					return 0;
				else
					assert (false, "Attempted to peek empty non-cell stack.");
			}

			return array[head-1];
		}

		void push(T[] ts...) {
			auto neededRoom = head + ts.length;
			if (neededRoom >= array.length)
				array.length = 2 * array.length +
					(neededRoom >= 2 * array.length ? neededRoom : 0);

			foreach (t; ts)
				array[head++] = t;
		}
		void pushHead(T[] ts...) { push(ts); }

		size_t size() { return head; }
		bool empty()  { return head == 0; }



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
}

enum : byte {
	INVERT_MODE = 1 << 0,
	QUEUE_MODE  = 1 << 1
}

// only used if the MODE fingerprint is loaded
final class Deque : Container!(cell) {
	this(typeof(super) s) {
		assert (cast(Stack!(cell))s || cast(typeof(this))s);

		if (cast(Stack!(cell))s) {
			assert (mode == 0);

			allocateArray(s.size);

			this.push(s.elementsBottomToTop);
		} else {
			auto q = cast(typeof(this))s;
			assert (q !is null);

			mode  = q.mode;
			tail  = q.tail;
			head  = q.head;
			array = q.array.dup;
		}
	}

	this(size_t n = super.DEFAULT_SIZE) {
		allocateArray(n);
	}

	private typeof(head) tail = 0;

	final override {
		cell pop() {
			if (mode & QUEUE_MODE)
				return popTail();
			else
				return popHead();
		}

		void pop(size_t i)  {
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
		}
		cell popHead() {
			if (empty)
				return 0;

			auto h = array[head];
			head = (head + 1) & (array.length - 1);
			return h;
		}

		void clear() { head = tail = 0; }

		cell top() {
			if (mode & QUEUE_MODE)
				return peekTail();
			else
				return peekHead();
		}

		void push(cell[] ts...) {
			if (mode & INVERT_MODE)
				pushTail(ts);
			else
				pushHead(ts);
		}
		void pushHead(cell[] cs...) {
			foreach (c; cs) {
				head = (head - 1) & (array.length - 1);
				array[head] = c;
				if (head == tail)
					doubleCapacity();
			}
		}

		size_t size() { return (tail - head) & (array.length - 1); }
		bool empty()  { return tail == head; }



		int opApply(int delegate(inout cell t) dg) {
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

		cell[] elementsBottomToTop() {
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
			foreach (c; cs) {
				array[tail] = c;
				tail = (tail + 1) & (array.length - 1);
				if (head == tail)
					doubleCapacity();
			}
		}

		cell popTail() {
			if (empty)
				return 0;

			tail = (tail - 1) & (array.length - 1);
			return array[tail];
		}

		cell peekHead() {
			return empty ? 0 : array[head];
		}
		cell peekTail() {
			return empty ? 0 : array[(tail - 1) & (array.length - 1)];
		}

		void allocateArray(size_t length) {
			int newSize = super.DEFAULT_SIZE;

			if (length >= newSize) {
				static assert (newSize.sizeof == 4,
					"Change size calculation in ccbi.container.Deque.allocateArray");

				newSize = length;
				newSize |= (newSize >>>  1);
				newSize |= (newSize >>>  2);
				newSize |= (newSize >>>  4);
				newSize |= (newSize >>>  8);
				newSize |= (newSize >>> 16);

				// oops, overflowed
				if (++newSize < 0)
					newSize >>>= 1;
			}

			array = new typeof(array)(newSize);
		}

		void doubleCapacity() {
			assert (head == tail);

			// elems to the right of head
			auto r = array.length - head;

			auto newArray = new typeof(array)(array.length * 2);
			newArray[0..r     ] = array[head..head+r].dup;
			newArray[r..r+head] = array[0   ..head  ].dup;

			head  = 0;
			tail  = array.length;
			array = newArray;
		}
	}
}
