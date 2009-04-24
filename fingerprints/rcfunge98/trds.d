// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2007-01-20 21:15:02

module ccbi.fingerprints.rcfunge98.trds; private:

import ccbi.fingerprint;
import ccbi.instructions : printAfter, normalTime;
import ccbi.ip;
import ccbi.utils;

// 0x54524453: TRDS
// IP travel in time and space
// ---------------------------

static this() {
	mixin (Code!("TRDS"));

	fingerprints[TRDS]['C'] =& resume;
	fingerprints[TRDS]['D'] =& absSpace;
	fingerprints[TRDS]['E'] =& relSpace;
	fingerprints[TRDS]['G'] =& now;
	fingerprints[TRDS]['I'] =& returnCoords;
	fingerprints[TRDS]['J'] =& jump;
	fingerprints[TRDS]['P'] =& max;
	fingerprints[TRDS]['R'] =& reset;
	fingerprints[TRDS]['S'] =& stop;
	fingerprints[TRDS]['T'] =& absTime;
	fingerprints[TRDS]['U'] =& relTime;
	fingerprints[TRDS]['V'] =& vector;
}

void jump() {
	ip.tardisReturnX = ip.x + ip.dx;
	ip.tardisReturnY = ip.y + ip.dy;

	ip.tardisReturnDx   = ip.dx;
	ip.tardisReturnDy   = ip.dy;
	ip.tardisReturnTick = ticks;

	if (ip.mode & IP.SPACE_SET) {
		if (ip.mode & IP.ABS_SPACE) {
			ip.x  = ip.tardisX;
			ip.y  = ip.tardisY;
		} else {
			ip.x += ip.tardisX;
			ip.y += ip.tardisY;
		}
	} else {
		// We do want to move the IP off the J now in any case.
		// I'm not at all aware why but not doing so causes problems.
		ip.x = ip.tardisReturnX;
		ip.y = ip.tardisReturnY;
	}
	needMove = false;

	if (ip.mode & IP.DELTA_SET) {
		ip.dx = ip.tardisDx;
		ip.dy = ip.tardisDy;
	}

	if (ip.mode & IP.TIME_SET) {
		if (ip.mode & IP.ABS_TIME)
			ip.jumpedTo = ip.tardisTick;
		else
			ip.jumpedTo = ticks + ip.tardisTick;

		if (ip.jumpedTo < 1)
			ip.jumpedTo = 1;

		if (ip.jumpedTo < ticks) {
			// jump into the past

			// if we set needMove = false above, we're not blocking this IP from moving
			// we're blocking either some random IP (if we set State.STOPPING and
			// return, below) or the initial IP (if we jump)
			needMove = true;

			// if another IP with the same ID as ip exists, and it jumped at this time, kill ip
			/+ because:
			 + 	the other IP must be ip, that has traveled back in time
			 + 	thus, if ip were to do a jump back now, it would be the same jump
			 + 	and thus, we would enter an infinite loop,
			 + 	jumping again and again from the same time to the same time
			 +/
			foreach (i; ips)
			if (ip.id == i.id && ip !is &i && i.jumpedAt == ticks)
				return stateChange = State.STOPPING;

			// ditto for an IP which has been stopped, but had the same ID

			/+
			The original problem that stopped IP data solves:

			- An IP jumps back from 200 to 100.
			- We rerun the program up to 100, and place the traveler.
			- The traveler does something and hits an @, so we add it to stopped IP data.
			- Now, again at 200, we don't let the IP jump, since we have the stopped IP
			  data which prevents us from entering this infinite loop.

			Essentially, it complements the check implemented in RC/Funge-98 which only
			checks for whether the IP exists now.

			However, there's a problem it doesn't solve in itself:

			- An IP jumps back from 300 to 200.
			- We rerun the program up to 200, and place the traveler.
			- The traveler does something and hits an @, so we add it to stopped IP data.
			- At 200, we don't jump again due to the stopped IP data, preventing an
			  infinite loop.
			- A different IP jumps back from 400 to 100.
			- We rerun to 100, and place this traveler.
			- It waits around to 200, expecting the other traveler. However, it won't be
			  there yet.
			  The two IPs will meet only when we now run to 300, jump back, and while
			  rerunning to 200 place this 400->100 traveler at 100.
			- The second traveler now jumps back to 400.
			- So it is frozen, and we run up to 400.

			Here is the problem:

			- At 300, we don't jump back to 200 again due to the stopped IP data.

			However, this time we should, because the situation has changed. We have the
			second traveler, which will be going to have been waiting for it (sorry,
			English is strictly 3-dimensional) after doing its own jump of 400->100. That
			traveler is in the travelers array, and would be placed at 100.

			- At 400, we correctly don't jump since the IP which jumped back to the future
			  is in the ips array.

			The inner loop makes jumps like the one at 300 in the above example happen
			again. It does so by looking for a traveler which will, in the future, jump
			further back than the jump recorded in the stopped IP data. If such a traveler
			exists, we should perform this jump.

			Unfortunately, this alone makes the jump happen every time after the second
			traveler is placed in the travelers array, leading to an infinite loop.

			This is where I remain stumped. I added the simple hack of setting the stopped
			IP data's jumpedTo to a negative number, so that the traveler.jumpedTo <=
			dat.jumpedTo check fails every time after the first.

			This is very smelly code, and I doubt it's a robust solution. However, I can't
			think of a test case which would break it, and I'm out of patience testing this
			stupid fingerprint which nobody uses.
			+/

			outer: foreach (inout dat; stoppedIPdata)
			if (ip.id == dat.id && dat.jumpedAt == ticks) {
				foreach (traveler; travelers)
				if (traveler.jumpedAt > ticks && traveler.jumpedTo <= dat.jumpedTo) {
					dat.jumpedTo = -1;
					break outer;
				}

				return stateChange = State.STOPPING;
			}

			ips[0]         = *ip;
			ips.length     = 1;
			ip             = &ips[0];
			IP.currentID   = IP.CURRENTID_INIT;
			ip.jumpedAt    = ticks;
			ticks          = 0;
			IP.timeStopper = IP.TIMESTOPPER_INIT;
			printAfter     = ip.jumpedTo;
		}

		stateChange = State.TIMEJUMP;
	}
}

void stop  () { IP.timeStopper = ip.id; normalTime = false; }
void resume() { IP.timeStopper = IP.TIMESTOPPER_INIT; normalTime = true; }

void now() { ip.stack.push(cast(cell)ticks); }
void max() { ip.stack.push(              0); }

void reset() {
	ip.mode &= ~(IP.ABS_SPACE | IP.SPACE_SET | IP.ABS_TIME | IP.TIME_SET | IP.DELTA_SET);

	ip.tardisX = ip.tardisY = ip.tardisDx = ip.tardisDy = 0;
	ip.tardisTick = 0;
}

void returnCoords() {
	// just like RC/Funge-98, we don't set IP.TIME_SET
	// makes RIJ not work
	ip.mode |= IP.ABS_SPACE | IP.SPACE_SET | IP.ABS_TIME | IP.DELTA_SET;

	ip.tardisX    = ip.tardisReturnX;
	ip.tardisY    = ip.tardisReturnY;
	ip.tardisDx   = ip.tardisReturnDx;
	ip.tardisDy   = ip.tardisReturnDy;
	ip.tardisTick = ip.tardisReturnTick;
}
void absSpace() {
	ip.mode |= IP.ABS_SPACE | IP.SPACE_SET;

	popVector(ip.tardisX, ip.tardisY);
}
void relSpace() {
	ip.mode &= ~IP.ABS_SPACE;
	ip.mode |=  IP.SPACE_SET;

	popVector(ip.tardisX, ip.tardisY);
}
void absTime() {
	ip.mode |= IP.ABS_TIME | IP.TIME_SET;

	ip.tardisTick = ip.stack.pop;
}
void relTime() {
	ip.mode &= ~IP.ABS_TIME;
	ip.mode |=  IP.TIME_SET;

	ip.tardisTick = ip.stack.pop;
}
void vector() {
	ip.mode |= IP.DELTA_SET;

	popVector!(false)(ip.tardisDx, ip.tardisDy);
}
