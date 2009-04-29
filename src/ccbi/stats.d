// File created: 2009-04-29 21:56:10

module ccbi.stats;

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
};
