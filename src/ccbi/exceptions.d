// File created: 2009-09-15 19:20:52

module ccbi.exceptions;

class InfiniteLoopException : Exception {
	char[] preamble;
	this(char[] p, char[] msg) {
		preamble = p;
		super(msg);
	}
}
