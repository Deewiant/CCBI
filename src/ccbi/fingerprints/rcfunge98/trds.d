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

// {{{ data

struct StoppedIPData {
	typeof(cip.id) id;
	typeof(tick) jumpedAt, jumpedTo;
}
StoppedIPData[] stoppedIPdata;
IP[] travellers;
IP timeStopper = null;

// Keep a copy of the original space so we don't have to reload from file when
// rebooting
FungeSpace initialSpace;

// When rerunning time to jump point, don't output (since that isn't
// "happening")
typeof(tick) printAfter = 0;

// }}}
// {{{ FungeMachine callbacks

bool isNormalTime() {
	return timeStopper is null;
}
bool executable(bool normalTime, IP ip) {
	return (normalTime || timeStopper is ip) && tick >= ip.jumpedTo;
}

void newTick() {
	if (flags.fingerprintsEnabled) {
		// If an IP is jumping to the future and it is the only one alive,
		// just jump.
		if (ips[0].jumpedTo > tick && ips.length == 1)
			tick = ips[0].jumpedTo;

		// Must be appended: preserves correct execution order
		for (size_t i = 0; i < travellers.length; ++i)
			if (tick == travellers[i].jumpedTo) {
				++stats.travellerArrived;
				ips ~= new IP(travellers[i]);
			}
	}
}

void ipStopped(IP ip) {
	// Resume time if the time stopper dies
	if (ip is timeStopper)
		timeStopper = null;

	// Store data of stopped IPs which have jumped
	// See jump() for the reason
	if (ip.jumpedAt) {
		bool found = false;

		foreach (dat; stoppedIPdata)
		if (dat.id == ip.id && dat.jumpedAt == ip.jumpedAt) {
			found = true;
			break;
		}

		if (!found)
			stoppedIPdata ~= StoppedIPData(ip.id, ip.jumpedAt, ip.jumpedTo);
	}
}

void timeJump(IP ip) {
	// nothing special if jumping to the future, just don't trace it
	if (tick > 0) {
		++stats.ipTravelledToFuture;

		if (ip.jumpedTo >= ip.jumpedAt)
			ip.mode &= ~IP.FROM_FUTURE;

		// TODO: move this to Tracer
		if (ip is tip)
			tip = null;
		return;
	}

	++stats.ipTravelledToPast;

	// add ip to travellers unless it's already there
	bool found = false;
	foreach (traveller; travellers)
	if (traveller.id == ip.id && traveller.jumpedAt == ip.jumpedAt) {
		found = true;
		break;
	}
	if (!found) {
		ip.mode |= IP.FROM_FUTURE;
		travellers ~= new IP(ip);
	}

	/+
	Whenever we jump back in time, history from the jump target forward is
	forgotten. Thus if there are travellers that jumped to a time later than
	the jump target, forget about them as well.

	Example:
	- IP 1 travels from time 300 to 200.
	- We rerun from time 0 to 200, then place the IP. It does some stuff,
	  then teleports and jumps back to 300.

	- IP 2 travels from time 400 to 100.
	- We rerun from time 0 to 100, then place the IP. It does some stuff,
	  then teleports and jumps back to 400.

	- At time 300, IP 1 travels again to 200.
	- We rerun from time 0 to 200. But at time 100, we need to place IP 2
	  again. So we do. (Hence the whole travellers array.)
	- IP 2 does its stuff, and teleports and freezes itself until 400.

	- Come time 200, we would place IP 1 again if we hadn't done the
	  following, and removed it back when we placed IP 2 for the second time.
	+/
	for (size_t i = 0; i < travellers.length; ++i)
		if (ip.jumpedTo < travellers[i].jumpedTo)
			travellers.removeAt(i--);

	reboot();
}
// }}}
// {{{ instructions

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

		static assert (typeof(cip.jumpedTo).min < 0);
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

void stop  () { ++stats.timeStopped; timeStopper = cip;  }
void resume() {                      timeStopper = null; }

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

// }}}
}
