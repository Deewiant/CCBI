// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
// Copyright (c) 2006-2010 Matti Niemenmaa
// See license.txt, which you should have received together with this file, for
// licensing information.

// File created: 2007-01-20 21:15:02

module ccbi.fingerprints.rcfunge98.trds;

import ccbi.fingerprint;

// 0x54524453: TRDS
// IP travel in time and space
// ---------------------------

mixin (Fingerprint!(
	"TRDS",
	"IP travel in time and space

      Time travel to the past is implemented as rerunning from the tick on
      which TRDS was loaded. Hence, one can't jump to any earlier tick.

      Output (console/file) during rerunning is not performed. Console input
      results in constant values, which probably won't be the same as those
      that were originally input. The 'i' instruction is ignorant of TRDS, as
      are these fingerprints: DIRF, FILE, SOCK, SCKE.\n",

	"C", "resume",
	"D", "absSpace",
	"E", "relSpace",
	"G", "now",
	"I", "returnCoords",
	"J", "jump",
	"P", "maxT",
	"R", "reset",
	"S", "stop",
	"T", "absTime",
	"U", "relTime",
	"V", "vector"
));

template TRDS() {

import tango.core.Traits : isUnsignedIntegerType;
import tango.math.Math   : max;

static assert (is(typeof(state.tick) == typeof(cip.tardisTick)));
static assert (is(typeof(state.tick) == typeof(cip.jumpedTo)));
static assert (is(typeof(state.tick) == typeof(cip.jumpedAt)));
static assert (isUnsignedIntegerType!(typeof(state.tick)));

// {{{ data and ctor

struct StoppedIPData {
	typeof(cip.id) id;
	typeof(state.tick) jumpedAt, jumpedTo;
}
StoppedIPData[] stoppedIPdata;
IP[] travellers;

// The state of the world when TRDS is first loaded: the earliest point of time
// we allow ourselves to jump back to.
//
// Doing a copy of the Funge-Space when the file is loaded just in case TRDS is
// ever needed (what we used to do) leads to poor performance for no good
// reason. It does allow jumping back to tick 0 but loading TRDS immediately
// allows you to jump back that far which is just as useful...
typeof(state)      earlyState = void;
typeof(state.tick) loadedTick = state.tick.max;

// If we have multiple threads running when TRDS is loaded, remember the
// correct one to execute when we jump back, since some of them may already
// have been executed.
//
// Set externally by FungeMachine.
typeof(state.ips).Iterator cipIt = void;

// When rerunning time to jump point, don't output (since that isn't
// "happening")
typeof(state.tick) ioAfter = 0;

// Bit of optimization for the main execution methods; avoid calling our
// callbacks until this is true.
bool usingTRDS = false;

void ctor() {
	usingTRDS = true;
	if (loadedTick == loadedTick.max) {
		loadedTick = state.tick;
		state.deepCopyTo(&earlyState);

		// Start executing from the next IP after cip instead of the first
		auto nextIt = cipIt;
		nextIt++;
		earlyState.startIt = nextIt;
		earlyState.useStartIt = true;
	}
}
void dtor() {
	// If we still have people arriving or time is stopped, don't disable the
	// callbacks
	if (!isNormalTime())
		return;

	foreach (ip; travellers)
		if (state.tick < ip.jumpedTo)
			return;

	usingTRDS = false;
}

// }}}
// {{{ FungeMachine callbacks

bool isNormalTime() {
	return state.timeStopper is null;
}
bool executable(bool normalTime, IP ip) {
	return (normalTime || ip is state.timeStopper)
	    && state.tick >= ip.jumpedTo;
}

void newTick() {
	// If an IP is jumping to the future and it is the only one alive,
	// just jump.
	if (state.ips.first.val.jumpedTo > state.tick && state.ips.length == 1)
		state.tick = state.ips.first.val.jumpedTo;

	foreach (ip; travellers) if (state.tick == ip.jumpedTo) {
		++stats.travellerArrived;

		// Arriving travellers must be the first to execute.
		auto arriver = ip.deepCopy(true, &state.space);
		state.ips.prependTo(state.ips.first, arriver);

		if (arriver.mode & IP.EX_TIME_STOPPER)
			state.timeStopper = arriver;
	}
}

void ipStopped(IP ip) {
	// Resume time if the time stopper dies
	if (ip is state.timeStopper)
		resume();

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

// }}}
// {{{ instructions

Request jump() {
	assert (state.tick >= loadedTick);

	cip.tardisReturnPos   = cip.pos + cip.delta;
	cip.tardisReturnDelta = cip.delta;
	cip.tardisReturnTick  = state.tick;

	if (cip.mode & IP.SPACE_SET) {
		if (cip.mode & IP.ABS_SPACE)
			cip.pos = cip.tardisPos;
		else
			cip.move(cip.tardisPos);
	} else
		// We do want to move the IP off the J now in any case, since we return
		// either Request.NONE or Request.TIMEJUMP, neither of which move the IP.
		cip.pos = cip.tardisReturnPos;

	if (cip.mode & IP.DELTA_SET)
		cip.delta = cip.tardisDelta;

	if (cip.mode & IP.TIME_SET) {

		cip.jumpedTo = cip.tardisTick;

		// If ABS_TIME, tardisTick is already guaranteed to be correctly set with
		// respect to loadedTick.
		if (!(cip.mode & IP.ABS_TIME)) {
			if (cip.mode & IP.NEG_TIME) {

				// Otherwise, if jumpedTo is negative (as determined by our bonus
				// sign bit of NEG_TIME), check its magnitude to make sure it
				// doesn't go too far back.
				//
				// We want tick - jumpedTo >= loadedTick, so this check is correct.
				// The vars are unsigned and state.tick >= loadedTick so we won't
				// underflow lіke this.
				if (cip.jumpedTo <= state.tick - loadedTick)
					cip.jumpedTo = state.tick - cip.jumpedTo;
				else
					cip.jumpedTo = loadedTick;
			} else
				cip.jumpedTo += state.tick;
		}

		assert (cip.jumpedTo >= loadedTick);

		if (cip.jumpedTo < state.tick) {
			// jump into the past

			// if another IP with the same ID as cip exists, and it jumped at this
			// time, kill cip
			/+ because:
			 + 	the other IP must be cip, having travelled back in time
			 + 	thus, if cip were to do a jump back now, it would be the same
			 + 	jump and thus we would enter an infinite loop, jumping again
			 + 	and again from the same time to the same time
			 +/
			// NOTE a slight HACKINESS: relies on ip.jumpedAt not being set on
			// jumps to the future
			foreach (ip; state.ips)
			if (cip.id == ip.id && cip !is ip && ip.jumpedAt == state.tick)
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
			if (cip.id == dat.id && dat.jumpedAt == state.tick) {
				foreach (traveller; travellers)
				if (
					traveller.jumpedAt > state.tick &&
					traveller.jumpedTo <= dat.jumpedTo &&
					dat.jumpedTo != typeof(state.tick).max
				) {
					// HACK: see above comment
					dat.jumpedTo = typeof(state.tick).max;
					break outer;
				}

				return Request.STOP;
			}

			// See HACKINESS above
			cip.jumpedAt = state.tick;
		}

		return timeJump(cip);
	}
	return Request.NONE;
}
Request timeJump(IP ip) {
	// Nothing special if jumping to the future, just don't trace it.
	// Be careful not to compare against ip.jumpedAt: see HACKINESS above
	if (ip.jumpedTo >= state.tick) {
		++stats.ipTravelledToFuture;

		ip.mode &= ~IP.FROM_FUTURE;

		version (tracer)
			Tracer.ipJumpedToFuture(ip);

		return Request.NONE;
	}

	++stats.ipTravelledToPast;

	ioAfter = ip.jumpedTo;

	// add ip to travellers unless it's already there
	bool found = false;
	foreach (traveller; travellers)
	if (traveller.id == ip.id && traveller.jumpedAt == ip.jumpedAt) {
		found = true;
		break;
	}
	if (!found) {
		if (ip is state.timeStopper)
			ip.mode |= IP.EX_TIME_STOPPER;

		ip.mode |= IP.FROM_FUTURE;
		travellers ~= ip.deepCopy(false);
	}

	// Since travellers are deepCopied and all IPs are being reset, no live IP
	// can be the time stopper. (Hence also the EX_TIME_STOPPER mode.)
	state.timeStopper = null;

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

	state.free();
	earlyState.deepCopyTo(&state, true);

	version (tracer)
		Tracer.jumpedToPast();

	return Request.RETICK;
}

void stop  () { ++stats.timeStopped; state.timeStopper = cip;  }
void resume() {                      state.timeStopper = null; }

void now () { cip.stack.push(state.tick); }
void maxT() { cip.stack.push(loadedTick); }

void reset() {
	cip.mode &=
		~(IP.ABS_SPACE | IP.SPACE_SET |
		  IP.ABS_TIME  | IP.TIME_SET  | IP.DELTA_SET);

	cip.tardisPos = cip.tardisDelta = InitCoords!(0);
	cip.tardisTick = 0;
}

void returnCoords() {
	cip.mode |=
		IP.ABS_SPACE | IP.SPACE_SET |
		IP.ABS_TIME  | IP.TIME_SET  | IP.DELTA_SET;

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

	cip.tardisTick = max(max(cip.stack.pop, 0), loadedTick);
}
void relTime() {
	cip.mode &= ~IP.ABS_TIME;
	cip.mode |=  IP.TIME_SET;

	auto t = cip.stack.pop;

	if (t < 0) {
		cip.mode |=  IP.NEG_TIME;
		cip.tardisTick = -t;
	} else {
		cip.mode &= ~IP.NEG_TIME;
		cip.tardisTick = t;
	}
}
void vector() {
	cip.mode |= IP.DELTA_SET;

	cip.tardisDelta = popVector();
}

// }}}
}
