// File created: 2009-09-15 19:20:52

module ccbi.exceptions;

// We don't version this because we can't do "try {} version (foo) catch {}"
class InfiniteLoopException : Exception {
	char[] detector;
	this(char[] d, char[] msg) {
		detector = d;
		super(msg);
	}
}

// We can version all the subclasses, though.
version (detectInfiniteLoops):

final class SpaceInfiniteLoopException : InfiniteLoopException {
	this(char[] src, char[] pos, char[] delta, char[] msg) {
		super(src ~ " at " ~ pos ~ " with delta " ~ delta, msg);
	}
}
