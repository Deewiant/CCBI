// File created: 2009-04-29 21:56:10

module ccbi.stats;

import tango.math.Math : max;

version (statistics)
	alias ulong Stat;
else
	alias DummyStat Stat;

struct Stats {
	mixin (MkStats!(
		"executionCount",
		"stdExecutionCount",
		"fingExecutionCount",
		"unimplementedCount",
		"execDormant",
		"ipForked",
		"ipStopped",
		"ipDormant",
		"ipTravelledToPast",
		"ipTravelledToFuture",
		"travellerArrived",
		"timeStopped"
	));

	struct SpaceStats {
		mixin (MkStats!(
			"lookups",
			"assignments",
			"boxesIncorporated",
			"boxesPlaced",
			"maxBoxesLive",
			"subsumedContains",
			"subsumedDisjoint",
			"subsumedFusables",
			"subsumedOverlaps"
		));
	}
	SpaceStats space;

	version (statistics)
		static void newMax(ref ulong old, ulong n) { old = max(old, n); }
	else
		static void newMax(ref DummyStat, ulong) {}
};

struct ContainerStats {
	mixin (MkStats!(
		"pushes",
		"pops",
		"peeks",
		"popUnderflows",
		"peekUnderflows",
		"resizes",
		"clears",
		"cleared"
	));
}

version (statistics) {} else struct DummyStat {
	static void opAddAssign(ulong) {}
	static void opSubAssign(ulong) {}
}

private template MkStats(S...) {
	static if (S.length)
		const MkStats =
			`version (statistics) ulong ` ~S[0]~ ` = 0;`
			`else DummyStat ` ~S[0]~ `;`
			~ MkStats!(S[1..$]);
	else
		const MkStats = "";
}
