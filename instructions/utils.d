// File created: 2008-09-06 17:16:04

module ccbi.instructions.utils;

import ccbi.templateutils;

template PushNumber(uint n) {
	const PushNumber = "cip.stack.push(" ~ ToString!(n) ~ ")";
}
