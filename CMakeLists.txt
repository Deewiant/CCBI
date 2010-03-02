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

set(D_FLAGS -Isrc)

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
	list(APPEND D_FLAGS -oq)
endif()

set(DC_ARGS "" CACHE STRING "Extra arguments to pass to the D compiler, semicolon-separated.")
foreach(arg ${DC_ARGS})
	list(APPEND D_FLAGS ${arg})
	list(APPEND D_LINK_FLAGS ${arg})
endforeach()

set(CCBI_BUILD_TYPE "Release" CACHE STRING
    "How to build CCBI, one of: Release; Debug; Release-LLVM (requires LDC, LLVM, sed, and (for C wrappers) clang; highly recommended).")

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
	3DSP BASE CPLI DATE DIRF EVAR FILE FIXP FPDP FPSP FRTH IIPC IMAP INDV SOCK STRN SUBR TERM TIME TRDS)

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

########
# Advanced options

option(CCBI_LINK_TANGO_RT
       "If enabled, link the Tango runtime manually instead of relying on the compiler to do it for us."
       OFF)
option(CCBI_LINK_TANGO_USER
       "If enabled, link the Tango user modules manually instead of relying on the compiler to do it for us."
       OFF)

mark_as_advanced(CCBI_LINK_TANGO_RT CCBI_LINK_TANGO_USER)

find_program(STRIP strip DOC "Debug symbols stripper, used when CCBI_BUILD_TYPE is not Debug. Unset to disable stripping.")
mark_as_advanced(STRIP)

########
# Gather D sources by running ${DC} -v -o- (requires a nonancient DMD/LDC)

if(GOT_FUNGE)
	message(STATUS "Gathering D sources with ${DC}...")

	execute_process(
		COMMAND ${DC} ${D_FLAGS} -v -o- src/ccbi/ccbi.d
		WORKING_DIRECTORY "${CCBI_SOURCE_DIR}"
		OUTPUT_STRIP_TRAILING_WHITESPACE
		OUTPUT_VARIABLE D_SOURCES
		ERROR_VARIABLE D_COMPILE_ERRORS)

	# Get rid of the fingerprints' pragma(msg) stuff
	string(REGEX REPLACE "[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9] :: .*\r?\n" "" D_COMPILE_ERRORS "${D_COMPILE_ERRORS}")

	if(NOT D_COMPILE_ERRORS STREQUAL "")
		message(FATAL_ERROR "${DC} failed at compiling:\n${D_COMPILE_ERRORS}")
	endif()

	string(REGEX REPLACE "\r?\n" ";" D_SOURCES "${D_SOURCES}")
	foreach(line ${D_SOURCES})
		string(SUBSTRING "${line}" 0 7 s)
		if(s STREQUAL "import ")
			string(REGEX REPLACE ".*[.]di[)]$" "" line "${line}")
			string(REGEX REPLACE "[^(]*[(](.*)[)]$" "\\1" line "${line}")

			if(   (NOT CCBI_LINK_TANGO_USER AND line MATCHES "/tango/")
				OR (NOT CCBI_LINK_TANGO_RT AND (line MATCHES "/tango/core/"
			                            	 OR  line MATCHES "/ldc/")))
				set(line "")
			endif()

			if(line)
				list(APPEND D_SOURCES2 "${line}")
			endif()
		endif()
	endforeach()
	set(D_SOURCES ${D_SOURCES2})
	unset(D_SOURCES2)
	list(INSERT D_SOURCES 0 src/ccbi/ccbi.d)
endif()

########
# Add executable-building command

set(CCBI_BIN "${CCBI_BINARY_DIR}/bin/ccbi${CMAKE_EXECUTABLE_SUFFIX}")
set(OBJDIR "${CCBI_BINARY_DIR}/obj")

if(CCBI_BUILD_TYPE STREQUAL "Release-LLVM")

	# Build the .bc
	set(CCBI_BC "${OBJDIR}/ccbi.ccbi.bc")
	add_custom_command(VERBATIM
		OUTPUT "${CCBI_BC}"
		WORKING_DIRECTORY "${CCBI_SOURCE_DIR}"
		DEPENDS ${D_SOURCES}
		COMMAND ldmd ${D_FLAGS} -c -output-bc -singleobj -od${OBJDIR} -release ${D_SOURCES})

	# Build .bc's out of the C wrappers
	foreach(C_SRC ${C_SOURCES})
		get_filename_component(fn "${C_SRC}" NAME_WE)
		set(C_OBJ "${OBJDIR}/${fn}${CMAKE_C_OUTPUT_EXTENSION}")
		list(APPEND C_OBJS "${C_OBJ}")
		add_custom_command(VERBATIM
			OUTPUT "${C_OBJ}"
			DEPENDS "${C_SRC}"
			COMMAND clang "${C_SRC}" -c -emit-llvm "-o${C_OBJ}")
	endforeach()

	# Link .bc's, fix weak to linkonce (LDC...), optimize
	set(CCBI_BC_OPT "${CCBI_BC}.opt")
	add_custom_command(VERBATIM
		OUTPUT "${CCBI_BC_OPT}"
		DEPENDS "${CCBI_BC}" ${C_OBJS}
		COMMAND llvm-link "${CCBI_BC}" ${C_OBJS} | llvm-dis
		        | sed "s/= weak/= linkonce/;s/define weak/define linkonce/" | llvm-as
		        | opt -std-compile-opts -std-link-opts -internalize-public-api-list=_Dmain
		              -unroll-allow-partial
		        > "${CCBI_BC_OPT}")

	# Assemble, make .o, link
	add_custom_command(VERBATIM
		OUTPUT "${CCBI_BIN}"
		DEPENDS "${CCBI_BC_OPT}"
		COMMAND llc -O3 -regalloc=pbqp < "${CCBI_BC_OPT}" > "${CCBI_BC_OPT}.s"
		COMMAND clang -c "${CCBI_BC_OPT}.s" -o "${CCBI_BC_OPT}.o"
		COMMAND ${DC} ${D_LINK_FLAGS} "-of${CCBI_BIN}" "${CCBI_BC_OPT}.o")
else()
	if(CCBI_BUILD_TYPE STREQUAL "Release")
		set(EXTRA_ARGS -O -inline -release)
	elseif(CCBI_BUILD_TYPE STREQUAL "Debug")
		set(EXTRA_ARGS -debug)
	else()
		message(FATAL_ERROR "Unsupported CCBI_BUILD_TYPE!")
	endif()

	# Easy way of building all C wrappers: make a library out of them
	set(LIBRARY_OUTPUT_PATH "${OBJDIR}")
	add_library("wrappers" STATIC ${C_SOURCES})

	add_custom_command(VERBATIM
		OUTPUT "${CCBI_BIN}"
		WORKING_DIRECTORY "${CCBI_SOURCE_DIR}"
		DEPENDS "wrappers" ${D_SOURCES}
		COMMAND ${DC} ${D_FLAGS} ${D_LINK_FLAGS} ${EXTRA_ARGS} "-of${CCBI_BIN}" "-od${OBJDIR}"
		        "-L-L${OBJDIR}" -L-lwrappers ${D_SOURCES})
endif()

add_custom_target(CCBI ALL "" DEPENDS "${CCBI_BIN}")

if(STRIP AND NOT CCBI_BUILD_TYPE STREQUAL "Debug")
	add_custom_command(VERBATIM TARGET CCBI POST_BUILD COMMAND ${STRIP} -s "${CCBI_BIN}")
endif()

install(PROGRAMS "${CCBI_BIN}" DESTINATION bin)
