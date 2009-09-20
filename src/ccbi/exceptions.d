// File created: 2009-09-15 19:20:52

module ccbi.exceptions;

// We don't version this because we can't do "try {} version (foo) catch {}"
class InfiniteLoopException : Exception {
	char[] preamble;
	this(char[] p, char[] msg) {
		preamble = p;
		super(msg);
	}
}

// We can version all the subclasses, though.
version (detectInfiniteLoops):

final class SpaceInfiniteLoopException : InfiniteLoopException {
	this(char[] src, char[] pos, char[] delta, char[] msg) {
		super(
			"Detected by " ~ src ~ " at " ~ pos ~
			" with delta " ~ delta ~
			":", msg);
	}
}
