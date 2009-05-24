// File created: 2009-04-29 21:56:10

module ccbi.stats;

import tango.math.Math : max;

struct Stats {
	ulong
		executionCount      = 0,
		stdExecutionCount   = 0,
		fingExecutionCount  = 0,
		unimplementedCount  = 0,
		execDormant         = 0,
		ipForked            = 0,
		ipStopped           = 0,
		ipDormant           = 0,
		ipTravelledToPast   = 0,
		ipTravelledToFuture = 0,
		travellerArrived    = 0,
		timeStopped         = 0;

	struct SpaceStats {
		ulong
			lookups           = 0,
			assignments       = 0,
			boxesIncorporated = 0,
			boxesPlaced       = 0,
			maxBoxesLive      = 0,
			subsumedContains  = 0,
			subsumedDisjoint  = 0,
			subsumedFusables  = 0,
			subsumedOverlaps  = 0;
	}
	SpaceStats space;

	void newMax(ref ulong old, ulong n) { old = max(old, n); }
};

struct ContainerStats {
	ulong
		pushes         = 0,
		pops           = 0,
		peeks          = 0,
		popUnderflows  = 0,
		peekUnderflows = 0,
		resizes        = 0,
		clears         = 0,
		cleared        = 0;
}
