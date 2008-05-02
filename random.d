// This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter

// File created: 2006-04-27 16:13:32

module ccbi.random;

/+ Deewiant:

Cut off a bunch of stuff we don't use.
Added some explicit casts to make it compile with -w.
Added the static this().

+/

static this() {
	init_genrand(42, true);
}

/*
   A D-program ported by Derek Parnell 2006/04/12,
   based on the C-program for MT19937,  with initialization improved 2002/1/26,
      coded by Takuji Nishimura and Makoto Matsumoto.

   Before using, initialize the state by using init_genrand(seed)
   or init_by_array(init_key). However, if you do not
   a seed is generated based on the current date-time of the system.

   Derek Parnell: init_genrand, init_bt_array, and genrand_int32 all
   now take an optional boolean parameter. If 'true' then an new seed
   is generated using some limited entropy (clock and previous random).
   This is to increase the non-sequential set of returned values.

   Copyright (C) 1997 - 2002, Makoto Matsumoto and Takuji Nishimura,
   All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions
   are met:

     1. Redistributions of source code must retain the above copyright
        notice, this list of conditions and the following disclaimer.

     2. Redistributions in binary form must reproduce the above copyright
        notice, this list of conditions and the following disclaimer in the
        documentation and/or other materials provided with the distribution.

     3. The names of its contributors may not be used to endorse or promote
        products derived from this software without specific prior written
        permission.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
   "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
   A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
   CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


   Any feedback is very welcome.
   http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html
   email: m-mat @ math.sci.hiroshima-u.ac.jp (remove space)
*/

private:

import tango.time.Clock;

/* Period parameters */
const uint N          = 624;
const uint M          = 397;
const uint MATRIX_A   = 0x9908b0df;   /* constant vector a */
const uint UPPER_MASK = 0x80000000; /* most significant w-r bits */
const uint LOWER_MASK = 0x7fffffff; /* least significant r bits */

uint[N] mt; /* the array for the state vector  */
uint mti=mt.length+1; /* mti==mt.length+1 means mt[] is not initialized */
uint vLastRand; /* The most recent random uint returned. */

/* initializes mt[] with a seed */
void init_genrand(uint s, bool pAddEntropy = false)
{
    mt[0]= cast(uint)((s + (pAddEntropy ? vLastRand + Clock.now().ticks + cast(uint)&init_genrand
                                        : 0))
            &  0xffffffffUL);
    for (mti=1; mti<mt.length; mti++)
    {
        mt[mti] = cast(uint)(1812433253UL * (mt[mti-1] ^ (mt[mti-1] >> 30)) + mti);
        /* See Knuth TAOCP Vol2. 3rd Ed. P.106 for multiplier. */
        /* In the previous versions, MSBs of the seed affect   */
        /* only MSBs of the array mt[].                        */
        /* 2002/01/09 modified by Makoto Matsumoto             */
        mt[mti] &= 0xffffffffUL;
        /* for >32 bit machines */
    }
}

/* generates a random number on [0,0xffffffff]-interval */
uint genrand_int32(bool pAddEntropy = false)
{
    uint y;
    static uint mag01[2] =[0, MATRIX_A];
    /* mag01[x] = x * MATRIX_A  for x=0,1 */

    if (mti >= mt.length) { /* fill the entire mt[] at one time */
        int kk;

//        if (pAddEntropy || mti > mt.length)   /* if init_genrand() has not been called, */
//        {
//            init_genrand( 5489UL, pAddEntropy ); /* a default initial seed is used */
//        }

        for (kk=0;kk<mt.length-M;kk++)
        {
            y = (mt[kk]&UPPER_MASK)|(mt[kk+1]&LOWER_MASK);
            mt[kk] = mt[kk+M] ^ (y >> 1) ^ mag01[cast(uint)(y & 1UL)];
        }
        for (;kk<mt.length-1;kk++) {
            y = (mt[kk]&UPPER_MASK)|(mt[kk+1]&LOWER_MASK);
            mt[kk] = mt[kk+(M-mt.length)] ^ (y >> 1) ^ mag01[cast(uint)(y & 1UL)];
        }
        y = (mt[mt.length-1]&UPPER_MASK)|(mt[0]&LOWER_MASK);
        mt[mt.length-1] = mt[M-1] ^ (y >> 1) ^ mag01[cast(uint)(y & 1UL)];

        mti = 0;
    }

    y = mt[mti++];

    /* Tempering */
    y ^= (y >> 11);
    y ^= (y << 7)  &  0x9d2c5680UL;
    y ^= (y << 15) &  0xefc60000UL;
    y ^= (y >> 18);

    vLastRand = y;
    return y;
}

public {
	uint rand_up_to(uint MAX)() {
		const mod = uint.max - uint.max % MAX;

		uint val;
		do val = genrand_int32();
		while (val >= mod);

		return val % MAX;
	}

	uint rand_up_to(float dummy = 0)(uint max) {
		if (max == 0)
			return 0;

		auto mod = uint.max - uint.max % max;

		uint val;
		do val = genrand_int32();
		while (val >= mod);

		return val % max;
	}
}
