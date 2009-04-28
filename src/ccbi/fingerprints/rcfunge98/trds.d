// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:15:02

module ccbi.fingerprints.rcfunge98.trds;

import ccbi.fingerprint;

// 0x54524453: TRDS
// IP travel in time and space
// ---------------------------

mixin (Fingerprint!(
	"TRDS",

	"C", "resume",
	"D", "absSpace",
	"E", "relSpace",
	"G", "now",
	"I", "returnCoords",
	"J", "jump",
	"P", "max",
	"R", "reset",
	"S", "stop",
	"T", "absTime",
	"U", "relTime",
	"V", "vector"
));

template TRDS() {

static assert (is(typeof(tick) == typeof(cip.tardisTick)));

Request jump() {
	cip.tardisReturnPos   = cip.pos + cip.delta;
	cip.tardisReturnDelta = cip.delta;
	cip.tardisReturnTick  = tick;

	if (cip.mode & IP.SPACE_SET) {
		if (cip.mode & IP.ABS_SPACE)
			cip.pos  = cip.tardisPos;
		else
			cip.pos += cip.tardisPos;
	} else
		// We do want to move the IP off the J now in any case.
		// I'm not at all aware why but not doing so causes problems.
		cip.pos = cip.tardisReturnPos;

	if (cip.mode & IP.DELTA_SET)
		cip.delta = cip.tardisDelta;

	if (cip.mode & IP.TIME_SET) {
		cip.jumpedTo = cip.tardisTick;
		if (!(cip.mode & IP.ABS_TIME))
			cip.jumpedTo += tick;

		if (cip.jumpedTo < 1)
			cip.jumpedTo = 1;

		if (cip.jumpedTo < tick) {
			// jump into the past

			// if another IP with the same ID as cip exists, and it jumped at this
			// time, kill cip
			/+ because:
			 + 	the other IP must be cip, having travelled back in time
			 + 	thus, if cip were to do a jump back now, it would be the same
			 + 	jump and thus we would enter an infinite loop, jumping again
			 + 	and again from the same time to the same time
			 +/
			foreach (ip; ips)
			if (cip.id == ip.id && cip !is ip && ip.jumpedAt == tick)
				return Request.STOP;

			// ditto for an IP which has been stopped, but had the same ID

			/+
			The original problem that stopped IP data solves:

			- An IP jumps back from 200 to 100.
			- We rerun the program up to 100, and place the traveller.
			- The traveller does something and hits an @, so we add it to stopped
			  IP data.
			- Now, again at 200, we don't let the IP jump, since we have the
			  stopped IP data which prevents us from entering this infinite loop.

			Essentially, it complements the above check which only checks for
			whether the IP exists now.

			However, there's a problem it doesn't solve in itself:

			- An IP jumps back from 300 to 200.
			- We rerun the program up to 200, and place the traveller.
			- The traveller does something and hits an @, so we add it to stopped
			  IP data.
			- At 300, we don't jump again due to the stopped IP data, preventing
			  an infinite loop.
			- A different IP jumps back from 400 to 100.
			- We rerun to 100, and place this traveller.
			- It waits around to 200, expecting the other traveller. However, it
			  won't be there yet.
			  The two IPs will meet only when we now run to 300, jump back, and
			  while rerunning to 200 place this 400->100 traveller at 100.
			- The second traveller now jumps back to 400.
			- So it is frozen, and we run up to 400.

			Here is the problem:

			- At 300, we don't jump back to 200 again due to the stopped IP data.

			However, this time we should, because the situation has changed. We
			have the second traveller, which will be going to have been waiting
			for it (sorry, English is strictly 3-dimensional) after doing its own
			jump of 400->100. That traveller is in the travellers array, and
			would be placed at 100.

			- At 400, we correctly don't jump since the IP which jumped back to
			  the future is in the ips array.

			The inner loop makes jumps like the one at 300 in the above example
			happen again. It does so by looking for a traveller which will, in the
			future, jump further back than the jump recorded in the stopped IP
			data. If such a traveller exists, we should perform this jump.

			Unfortunately, this alone makes the jump happen every time after the
			second traveller is placed in the travellers array, leading to an
			infinite loop.

			This is where I remain stumped. I added the simple hack of setting the
			stopped IP data's jumpedTo to the maximum possible tick value and
			checking for it, so that the if fails every time after the first.

			This is very smelly code, and I doubt it's a robust solution. However,
			I can't think of a test case which would break it.
			+/

			outer: foreach (inout dat; stoppedIPdata)
			if (cip.id == dat.id && dat.jumpedAt == tick) {
				foreach (traveller; travellers)
				if (
					traveller.jumpedAt > tick &&
					traveller.jumpedTo <= dat.jumpedTo &&
					dat.jumpedTo != typeof(tick).max
				) {
					// HACK: see above comment
					dat.jumpedTo = typeof(tick).max;
					break outer;
				}

				return Request.STOP;
			}

			ips[0]        = cip;
			ips.length    = 1;
			currentID     = 0;
			cip.jumpedAt  = tick;
			tick          = 0;
			printAfter    = cip.jumpedTo;
			resume();
		}

		return Request.TIMEJUMP;
	}
	return Request.NONE;
}

void stop  () { timeStopper = cip;  }
void resume() { timeStopper = null; }

void now() { cip.stack.push(cast(cell)tick); }
void max() { cip.stack.push(             0); }

void reset() {
	cip.mode &=
		~(IP.ABS_SPACE | IP.SPACE_SET |
		  IP.ABS_TIME  | IP.TIME_SET  | IP.DELTA_SET);

	cip.tardisPos  = cip.tardisDelta = InitCoords!(0);
	cip.tardisTick = 0;
}

void returnCoords() {
	// just like RC/Funge-98, we don't set IP.TIME_SET
	// makes RIJ not work
	cip.mode |= IP.ABS_SPACE | IP.SPACE_SET | IP.ABS_TIME | IP.DELTA_SET;

	cip.tardisPos   = cip.tardisReturnPos;
	cip.tardisDelta = cip.tardisReturnDelta;
	cip.tardisTick  = cip.tardisReturnTick;
}
void absSpace() {
	cip.mode |= IP.ABS_SPACE | IP.SPACE_SET;

	cip.tardisPos = popOffsetVector();
}
void relSpace() {
	cip.mode &= ~IP.ABS_SPACE;
	cip.mode |=  IP.SPACE_SET;

	cip.tardisPos = popOffsetVector();
}
void absTime() {
	cip.mode |= IP.ABS_TIME | IP.TIME_SET;

	cip.tardisTick = cip.stack.pop;
}
void relTime() {
	cip.mode &= ~IP.ABS_TIME;
	cip.mode |=  IP.TIME_SET;

	cip.tardisTick = cip.stack.pop;
}
void vector() {
	cip.mode |= IP.DELTA_SET;

	cip.tardisDelta = popVector();
}

}
