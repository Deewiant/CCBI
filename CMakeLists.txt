# This file is part of CCBI - Conforming Concurrent Befunge-98 Interpreter
# Copyright (c) 2006-2010 Matti Niemenmaa
# See license.txt, which you should have received together with this file, for
# copyright details.

# File created: 2010-02-28 11:35:22

cmake_minimum_required (VERSION 2.8 FATAL_ERROR)
project (CCBI)

include(FindCurses)

if(NOT CMAKE_BUILD_TYPE)
	set(CMAKE_BUILD_TYPE "Release" CACHE STRING
	    "The build type for C wrappers, one of: None Debug Release RelWithDebInfo MinSizeRel.")
endif()
mark_as_advanced(
	CMAKE_BUILD_TYPE
	CURSES_HAVE_CURSES_H
	CURSES_CURSES_H_PATH)

if(CURSES_CURSES_LIBRARY)
	mark_as_advanced(CLEAR CURSES_CURSES_LIBRARY)
endif()
if(CURSES_FORM_LIBRARY)
	mark_as_advanced(CLEAR CURSES_FORM_LIBRARY)
endif()
if(CURSES_EXTRA_LIBRARY)
	mark_as_advanced(CLEAR CURSES_EXTRA_LIBRARY)
endif()

set(D_FLAGS -I${CCBI_SOURCE_DIR}/src)

if(WIN32)
	list(APPEND D_FLAGS -version=Win32SansUnicode)
endif()

########
# User-visible options

find_program(DC NAMES ldmd dmd DOC "D compiler to use.")

if(NOT DC)
	message(SEND_ERROR "Could not find a D compiler: wanted 'ldmd' or 'dmd'.")
endif()
if (DC MATCHES "ldmd")
	set(VENDOR "ldc")
	list(APPEND D_FLAGS -oq)
else()
	set(VENDOR "dmd")
endif()

set(DC_ARGS "" CACHE STRING "Extra arguments to pass to the D compiler, semicolon-separated.")
foreach(arg ${DC_ARGS})
	list(APPEND D_FLAGS ${arg})
	list(APPEND D_LINK_FLAGS ${arg})
endforeach()

set(CCBI_BUILD_TYPE "Release" CACHE STRING
    "How to build CCBI, one of: Release; Debug; Release-LLVM (requires LDC, LLVM, sed, and clang; highly recommended); Release-LLVM-Safer (less LTO, less buggy).")

option(CELL_IS_64_BIT "Stack and Funge-Space cells are 64-bit integers instead of 32-bit." OFF)

option(ENABLE_BEFUNGE93  "Build support for Befunge-93." ON)
option(ENABLE_FUNGE98_1 "Build support for Unefunge-98 (one-dimensional Funge-98)." OFF)
option(ENABLE_FUNGE98_2  "Build support for Befunge-98 (two-dimensional Funge-98)." ON)
option(ENABLE_FUNGE98_3 "Build support for Trefunge-98 (three-dimensional Funge-98)." OFF)

if(ENABLE_BEFUNGE93 OR ENABLE_FUNGE98_1 OR ENABLE_FUNGE98_2 OR ENABLE_FUNGE98_3)
	set(GOT_FUNGE TRUE)
else()
	message(SEND_ERROR "You must enable support for at least one kind of Funge!")
endif()

option(ENABLE_TRACER "Build support for the tracer (debugger)." ON)
option(ENABLE_STATISTICS "Build support for calculating and emitting various runtime statistics." ON)
option(ENABLE_DETECT_INFINITY "Build extended support for infinite loop detection: some runtime cost." ON)

macro(ccbiFlagOpt opt flag)
	if(${opt})
		list(APPEND D_FLAGS ${flag})
	endif()
endmacro()

ccbiFlagOpt(CELL_IS_64_BIT -version=cell64)
ccbiFlagOpt(ENABLE_BEFUNGE93 -version=befunge93)
ccbiFlagOpt(ENABLE_FUNGE98_1 -version=unefunge98)
ccbiFlagOpt(ENABLE_FUNGE98_2 -version=befunge98)
ccbiFlagOpt(ENABLE_FUNGE98_3 -version=trefunge98)
ccbiFlagOpt(ENABLE_TRACER -version=tracer)
ccbiFlagOpt(ENABLE_STATISTICS -version=statistics)
ccbiFlagOpt(ENABLE_DETECT_INFINITY -version=detectInfiniteLoops)

macro(ccbiFing)
	foreach(fing ${ARGV})
		option(FINGERPRINT_${fing} "Build support for the ${fing} fingerprint." ON)
		if(FINGERPRINT_${fing})
			if(${fing} MATCHES "^[0-9]")
				list(APPEND D_FLAGS -version=_${fing})
			else()
				list(APPEND D_FLAGS -version=${fing})
			endif()
		endif()
	endforeach()
endmacro()
ccbiFing(
	HRTI MODE MODU NULL ORTH PERL REFC ROMA TOYS TURT
	SCKE
	JSTR NCRS
	3DSP ARRY BASE BOOL CPLI DATE DIRF EVAR FILE FING FIXP FPDP FPRT FPSP FRTH IIPC IMAP INDV REXP SOCK STRN SUBR TERM TIME TRDS)

if(FINGERPRINT_SCKE AND NOT FINGERPRINT_SOCK)
	message(FATAL_ERROR "FINGERPRINT_SCKE requires FINGERPRINT_SOCK!")
endif()
if(FINGERPRINT_NCRS)
	if(CURSES_FOUND)
		list(APPEND C_SOURCES "${CCBI_SOURCE_DIR}/src/wrapncrs.c")
		foreach(lib ${CURSES_LIBRARIES})
			list(APPEND D_LINK_FLAGS -L${lib})
		endforeach()
	else()
		message(SEND_ERROR "Need CURSES_FOUND to build NCRS!")
	endif()
endif()
if(FINGERPRINT_REXP)
	# CMake doesn't provide a FindRegex or equivalent... just hope it works
	list(APPEND C_SOURCES "${CCBI_SOURCE_DIR}/src/wraprexp.c")
endif()
if(FINGERPRINT_TERM AND (NOT WIN32 OR CYGWIN)) # Presumably version=Posix in Cygwin
	if(CURSES_FOUND)
		foreach(lib ${CURSES_LIBRARIES})
			list(APPEND D_LINK_FLAGS -L${lib})
		endforeach()
	else()
		message(SEND_ERROR "Need CURSES_FOUND to build TERM on non-Windows system!")
	endif()
endif()

########
# Advanced options

option(CCBI_LINK_TANGO_RT
       "If enabled, link the Tango runtime manually instead of relying on the compiler to do it for us. Very advanced! Requires TANGO_DIR."
       OFF)
option(CCBI_LINK_TANGO_USER
       "If enabled, link the Tango user modules manually instead of relying on the compiler to do it for us."
       OFF)

set(TANGO_DIR "" CACHE PATH "Tango root directory, required only by CCBI_LINK_TANGO_RT.")

if(CCBI_LINK_TANGO_RT)
	if(VENDOR STREQUAL "ldc")
		list(APPEND D_LINK_FLAGS -nodefaultlib)
	endif()

	if(NOT IS_DIRECTORY "${TANGO_DIR}")
		message(FATAL_ERROR "TANGO_DIR '${TANGO_DIR}' does not exist! Fix that or disable CCBI_LINK_TANGO_RT.")
	endif()

	set(TMP "tango/core/rt/compiler/${VENDOR}" "tango/core/rt/compiler/util")
	foreach(dir ${TMP})
		if(IS_DIRECTORY "${TANGO_DIR}/${dir}")
			file(GLOB_RECURSE TMP2 "${TANGO_DIR}/${dir}/*.d")
			foreach(file ${TMP2})
				list(APPEND D_SOURCES "${file}")
			endforeach()
			file(GLOB_RECURSE TMP2 "${TANGO_DIR}/${dir}/*.c")
			foreach(file ${TMP2})
				list(APPEND C_SOURCES "${file}")
			endforeach()
		else()
			message(SEND_ERROR "TANGO_DIR invalid (or unsupported Tango version): dir '${TANGO_DIR}/${dir}' not found! Fix that or disable CCBI_LINK_TANGO_RT.")
		endif()
	endforeach()
	set(TMP "tango/core/rt/gc/basic")
	foreach(dir ${TMP})
		if(IS_DIRECTORY "${TANGO_DIR}/${dir}")
			file(GLOB_RECURSE TMP2 "${TANGO_DIR}/${dir}/*.d")
			foreach(file ${TMP2})
				list(APPEND D_SOURCES "${file}")
			endforeach()
			file(GLOB_RECURSE TMP2 "${TANGO_DIR}/${dir}/*.c")
			foreach(file ${TMP2})
				list(APPEND C_SOURCES "${file}")
			endforeach()
		else()
			message(SEND_ERROR "TANGO_DIR invalid (or unsupported Tango version): dir '${TANGO_DIR}/${dir}' not found! Fix that or disable CCBI_LINK_TANGO_RT.")
		endif()
	endforeach()
	set(TMP "tango/core/Runtime.d" "tango/core/Exception.d" "tango/core/Thread.d")
	foreach(file ${TMP})
		if(EXISTS "${TANGO_DIR}/${file}" AND NOT IS_DIRECTORY "${TANGO_DIR}/${file}")
			list(APPEND D_SOURCES "${TANGO_DIR}/${file}")
		else()
			message(SEND_ERROR "TANGO_DIR invalid (or unsupported Tango version): file '${TANGO_DIR}/${file}' not found! Fix that or disable CCBI_LINK_TANGO_RT.")
		endif()
	endforeach()
endif()

mark_as_advanced(CCBI_LINK_TANGO_RT CCBI_LINK_TANGO_USER TANGO_DIR)

find_program(STRIP strip DOC "Debug symbols stripper, used when CCBI_BUILD_TYPE is not Debug. Unset to disable stripping.")

########
# Gather D sources by running ${DC} -v -o- (requires a nonancient DMD/LDC)

if(GOT_FUNGE)
	message(STATUS "Gathering D sources with ${DC}...")

	execute_process(
		COMMAND ${DC} ${D_FLAGS} -v -o- ${CCBI_SOURCE_DIR}/src/ccbi/ccbi.d
		OUTPUT_STRIP_TRAILING_WHITESPACE
		OUTPUT_VARIABLE GATHERED_D_SOURCES
		ERROR_VARIABLE D_COMPILE_ERRORS)

	# Get rid of the fingerprints' pragma(msg) stuff
	string(REGEX REPLACE "[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9] :: .*\r?\n" "" D_COMPILE_ERRORS "${D_COMPILE_ERRORS}")

	if(NOT D_COMPILE_ERRORS STREQUAL "")
		message(FATAL_ERROR "${DC} failed at compiling:\n${D_COMPILE_ERRORS}")
	endif()

	string(REGEX REPLACE "\r?\n" ";" GATHERED_D_SOURCES "${GATHERED_D_SOURCES}")
	foreach(line ${GATHERED_D_SOURCES})
		string(SUBSTRING "${line}" 0 7 s)
		if(s STREQUAL "import ")
			string(REGEX REPLACE ".*[.]di[)]$" "" line "${line}")
			string(REGEX REPLACE "[^(]*[(](.*)[)]$" "\\1" path "${line}")

			if(   (NOT CCBI_LINK_TANGO_USER AND path MATCHES "/tango/")
			   OR (NOT CCBI_LINK_TANGO_RT   AND path MATCHES "/tango/core/")
			   OR path MATCHES "/${VENDOR}/")
				set(path "")
			elseif(CCBI_LINK_TANGO_RT)
				# Did we already add it when populating stuff from TANGO_DIR?
				string(REGEX REPLACE ".*/tango/" "${TANGO_DIR}/tango/" tmp "${path}")
				list(FIND D_SOURCES "${tmp}" tmp)
				if(tmp GREATER -1)
					set(path "")
				endif()
			endif()

			if(path)
				list(APPEND D_SOURCES "${path}")
			endif()
		endif()
	endforeach()
	list(INSERT D_SOURCES 0 ${CCBI_SOURCE_DIR}/src/ccbi/ccbi.d)
	list(REMOVE_DUPLICATES D_SOURCES)
endif()

########
# Add executable-building command

set(CCBI_BIN "${CCBI_BINARY_DIR}/bin/ccbi${CMAKE_EXECUTABLE_SUFFIX}")
set(OBJDIR "${CCBI_BINARY_DIR}/obj")

if(VENDOR STREQUAL "ldc")
	list(APPEND D_FLAGS -linkonce-templates)
endif()

if(EXISTS "${OBJDIR}" AND NOT IS_DIRECTORY "${OBJDIR}")
	message(FATAL_ERROR "${OBJDIR} is a temporary directory we want to use, please get rid of it!")
endif()

if(CCBI_BUILD_TYPE MATCHES "^Release-LLVM")

	# Ensure OBJDIR exists
	# TODO test on Win32
	if(WIN32 AND NOT CYGWIN)
		set(MKDIR_OBJDIR mkdir "${OBJDIR}" >NUL 2>NUL)
	else()
		set(MKDIR_OBJDIR mkdir -p "${OBJDIR}")
	endif()

	# Build the .bc
	set(CCBI_BC "${OBJDIR}/ccbi.bc")
	add_custom_command(VERBATIM
		OUTPUT "${CCBI_BC}"
		DEPENDS ${D_SOURCES}
		COMMAND ${MKDIR_OBJDIR}
		COMMAND ${DC} ${D_FLAGS} -c -output-bc -singleobj -of${CCBI_BC} -release ${D_SOURCES})

	# Build .bc's out of the C wrappers
	foreach(C_SRC ${C_SOURCES})
		get_filename_component(fn "${C_SRC}" NAME_WE)
		set(C_OBJ "${OBJDIR}/${fn}${CMAKE_C_OUTPUT_EXTENSION}")
		list(APPEND C_OBJS "${C_OBJ}")
		add_custom_command(VERBATIM
			OUTPUT "${C_OBJ}"
			DEPENDS "${C_SRC}"
			COMMAND ${MKDIR_OBJDIR}
			COMMAND clang -w "${C_SRC}" -c -emit-llvm "-o${C_OBJ}")
	endforeach()

	# Link .bc's, optimize

	if(CCBI_LINK_TANGO_RT)
		set(INTERNALIZE_OPT "")
	else()
		set(INTERNALIZE_OPT -internalize-public-api-list=_Dmain)
	endif()

	if(CCBI_BUILD_TYPE STREQUAL "Release-LLVM-Safer")
		# Identical to the default options but removes -inline from between -instcombine and -prune-eh
		# (And doesn't specify analysis passes explicitly, the transformations will request what they need)
		set(LTO -internalize ${INTERNALIZE_OPT} -ipsccp -globalopt -constmerge -deadargelim -instcombine -prune-eh -globalopt -globaldce -argpromotion -instcombine -jump-threading -scalarrepl -functionattrs -globalsmodref-aa -loopsimplify -licm -gvn -memcpyopt -dse -instcombine -jump-threading -mem2reg -simplifycfg -globaldce)
	else()
		set(LTO -std-link-opts ${INTERNALIZE_OPT})
	endif()

	set(CCBI_BC_OPT "${OBJDIR}/ccbi-opt.bc")
	add_custom_command(VERBATIM
		OUTPUT "${CCBI_BC_OPT}"
		DEPENDS "${CCBI_BC}" ${C_OBJS}
		COMMAND llvm-link "${CCBI_BC}" ${C_OBJS}
		        | llvm-dis
		        | sed "/call void @_d_assert\(/d"

		        # Up to 10% speedup in total
		        | sed "/^define .*FungeMachine18executeInstructionMF/ s/{/alwaysinline{/"
		        | sed "/^define .*FungeMachine15executeStandardMF/ s/{/alwaysinline{/"
		        | sed "/^define .*FungeMachine9executeIPMF/ s/{/alwaysinline{/"

		        # Need to do all of these for noticeable improvement
		        | sed "/^define .*6Cursor3getMF/ s/{/alwaysinline{/"
		        | sed "/^define .*2IP4cellMF/ s/{/alwaysinline{/"
		        | sed "/^define .*2IP19gotoNextInstructionMF/ s/{/alwaysinline{/"

		        | llvm-as
		        | opt -std-compile-opts -unroll-allow-partial ${LTO}
		        > "${CCBI_BC_OPT}")

	# Assemble
	set(CCBI_S "${OBJDIR}/ccbi-opt.s")
	add_custom_command(VERBATIM
		OUTPUT "${CCBI_S}"
		DEPENDS "${CCBI_BC_OPT}"
		COMMAND llc -O3 -regalloc=pbqp -post-RA-scheduler < "${CCBI_BC_OPT}" > "${CCBI_S}")

	# Make .o
	#
	# D_LINK_FLAGS is not in a format that clang would like so we can't use it
	# to link.
	set(CCBI_O "${OBJDIR}/ccbi-opt.o")
	add_custom_command(VERBATIM
		OUTPUT "${CCBI_O}"
		DEPENDS "${CCBI_S}"
		COMMAND clang -c "${CCBI_S}" -o "${CCBI_O}")

	# Link
	add_custom_command(VERBATIM
		OUTPUT "${CCBI_BIN}"
		DEPENDS "${CCBI_O}"
		COMMAND ${DC} ${D_LINK_FLAGS} "-of${CCBI_BIN}" "${CCBI_O}")
else()
	if(CCBI_BUILD_TYPE STREQUAL "Release")
		set(EXTRA_ARGS -O -inline -release)
	elseif(CCBI_BUILD_TYPE STREQUAL "Debug")
		set(EXTRA_ARGS -debug -g)
	else()
		message(FATAL_ERROR "Unsupported CCBI_BUILD_TYPE!")
	endif()

	# Easy way of building all C wrappers: make a library out of them
	if(C_SOURCES)
		set(LIBRARY_OUTPUT_PATH "${OBJDIR}")
		add_library("wrappers" STATIC ${C_SOURCES})
		set(WRAPPERS "wrappers")
		set(LWRAPPERS "-L-lwrappers")
	else()
		set(WRAPPERS "")
		set(LWRAPPERS "")
	endif()

	add_custom_command(VERBATIM
		OUTPUT "${CCBI_BIN}"
		DEPENDS ${WRAPPERS} ${D_SOURCES}
		COMMAND ${DC} ${D_FLAGS} ${D_LINK_FLAGS} ${EXTRA_ARGS} "-of${CCBI_BIN}" "-od${OBJDIR}"
		        "-L-L${OBJDIR}" ${LWRAPPERS} ${D_SOURCES})
endif()

add_custom_target(CCBI ALL "" DEPENDS "${CCBI_BIN}")

if(STRIP AND NOT CCBI_BUILD_TYPE STREQUAL "Debug")
	add_custom_command(VERBATIM TARGET CCBI POST_BUILD COMMAND ${STRIP} -s "${CCBI_BIN}")
endif()

install(PROGRAMS "${CCBI_BIN}" DESTINATION bin)
