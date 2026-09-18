/*
 * Copyright (c) 2022, Commonwealth Scientific and Industrial Research
 * Organisation (CSIRO) ABN 41 687 119 230.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <al_compiler.h>

/*
 * QEMU requires that the semihosting trap instruction sequence, consisting of
 * three uncompressed instructions, lie in the same page, and refuses to
 * interpret the trap sequence if these instructions are placed across two
 * different pages.
 *
 * The `semihost_exec` function, which occupies 12 bytes, is aligned at a
 * 16-byte boundary to ensure that the three trap sequence instructions are
 * never placed across two different pages.
 */
/** @brief Semihosting instructions */
enum semihost_instr {
	/*
	 * File I/O operations
	 */

	/** Open a file or stream on the host system. */
	SEMIHOST_OPEN   = 0x01,
	/** Check whether a file is associated with a stream/terminal */
	SEMIHOST_ISTTY  = 0x09,
	/** Write to a file or stream. */
	SEMIHOST_WRITE  = 0x05,
	/** Read from a file at the current cursor position. */
	SEMIHOST_READ   = 0x06,
	/** Closes a file on the host which has been opened by SEMIHOST_OPEN. */
	SEMIHOST_CLOSE  = 0x02,
	/** Get the length of a file. */
	SEMIHOST_FLEN   = 0x0C,
	/** Set the file cursor to a given position in a file. */
	SEMIHOST_SEEK   = 0x0A,
	/** Get a temporary absolute file path to create a temporary file. */
	SEMIHOST_TMPNAM = 0x0D,
	/** Remove a file on the host system. Possibly insecure! */
	SEMIHOST_REMOVE = 0x0E,
	/** Rename a file on the host system. Possibly insecure! */
	SEMIHOST_RENAME = 0x0F,

	/*
	 * Terminal I/O operations
	 */

	/** Write one character to the debug terminal. */
	SEMIHOST_WRITEC         = 0x03,
	/** Write a NULL terminated string to the debug terminal. */
	SEMIHOST_WRITE0         = 0x04,
	/** Read one character from the debug terminal. */
	SEMIHOST_READC          = 0x07,

	/*
	 * Time operations
	 */
	SEMIHOST_CLOCK          = 0x10,
	SEMIHOST_ELAPSED        = 0x30,
	SEMIHOST_TICKFREQ       = 0x31,
	SEMIHOST_TIME           = 0x11,

	/*
	 * System/Misc. operations
	 */

	/** Retrieve the errno variable from semihosting operations. */
	SEMIHOST_ERRNO          = 0x13,
	/** Get commandline parameters for the application to run with */
	SEMIHOST_GET_CMDLINE    = 0x15,
	SEMIHOST_HEAPINFO       = 0x16,
	SEMIHOST_ISERROR        = 0x08,
	SEMIHOST_SYSTEM         = 0x12
};

long __ALIGNED(16) semihost_exec(enum semihost_instr instr, void *args)
{
	register unsigned long a0 __asm__ ("a0") = instr;
	register void *a1 __asm__ ("a1") = args;
	register long ret __asm__ ("a0");

	__asm__ volatile (
		".option push\n\t"
		".option norvc\n\t"
		"slli zero, zero, 0x1f\n\t"
		"ebreak\n\t"
		"srai zero, zero, 0x7\n\t"
		".option pop"
		: "=r" (ret) : "r" (a0), "r" (a1) : "memory");

	return ret;
}
