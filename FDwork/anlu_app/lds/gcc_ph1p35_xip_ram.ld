/*
* Copyright (c) 2023, Anlogic Inc. and Contributors. All rights reserved.
*
* SPDX-License-Identifier: BSD-3-Clause
*/

OUTPUT_ARCH( "riscv" )

ENTRY( _start )

MEMORY
{
flash (rxa!w) : ORIGIN = 0x20E00000, LENGTH = 1M
dlm (wxa!r)   : ORIGIN = 0x08008000, LENGTH = 16k
}

REGION_ALIAS("ROM", flash)
REGION_ALIAS("DLM", dlm)

SECTIONS
{
/* To provide symbol __STACK_SIZE, __HEAP_SIZE and __SMP_CPU_CNT */
PROVIDE(__STACK_SIZE = 2K);
PROVIDE(__HEAP_SIZE = 2K);
PROVIDE(__SMP_CPU_CNT = 1);
__TOT_STACK_SIZE = __STACK_SIZE * __SMP_CPU_CNT;

.init           : ALIGN(4)
{
/* vector table locate at ROM */
*(.vtable)
KEEP (*(SORT_NONE(.init)))
. = ALIGN(4);
} >ROM AT>ROM

.config_settings          : ALIGN(4)
{
KEEP (*(SORT_NONE(.config_settings_code)))
. = ALIGN(4);
} >DLM AT>ROM

PROVIDE( _config_settings_load_start = LOADADDR(.config_settings));
PROVIDE( _config_settings_vma_start = ADDR(.config_settings));
PROVIDE( _config_settings_vma_end = ADDR(.config_settings) + SIZEOF(.config_settings));

/* Code section located at ROM */
.text           : ALIGN(4)
{
*(.text.unlikely .text.unlikely.*)
*(.text.startup .text.startup.*)
*(.text .text.*)
*(.gnu.linkonce.t.*)
/* below sections are used for rt-thread */
. = ALIGN(4);
__rt_init_start = .;
KEEP(*(SORT(.rti_fn*)))
__rt_init_end = .;
. = ALIGN(4);
__fsymtab_start = .;
KEEP(*(FSymTab))
__fsymtab_end = .;
. = ALIGN(4);
__vsymtab_start = .;
KEEP(*(VSymTab))
__vsymtab_end = .;
} >ROM AT>ROM

.fini           : ALIGN(4)
{
KEEP (*(SORT_NONE(.fini)))
} >ROM AT>ROM

.preinit_array  : ALIGN(4)
{
PROVIDE_HIDDEN (__preinit_array_start = .);
KEEP (*(.preinit_array))
PROVIDE_HIDDEN (__preinit_array_end = .);
} >ROM AT>ROM

.init_array     : ALIGN(4)
{
PROVIDE_HIDDEN (__init_array_start = .);
KEEP (*(SORT_BY_INIT_PRIORITY(.init_array.*) SORT_BY_INIT_PRIORITY(.ctors.*)))
KEEP (*(.init_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .ctors))
PROVIDE_HIDDEN (__init_array_end = .);
} >ROM AT>ROM

.fini_array     : ALIGN(4)
{
PROVIDE_HIDDEN (__fini_array_start = .);
KEEP (*(SORT_BY_INIT_PRIORITY(.fini_array.*) SORT_BY_INIT_PRIORITY(.dtors.*)))
KEEP (*(.fini_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .dtors))
PROVIDE_HIDDEN (__fini_array_end = .);
} >ROM AT>ROM

.ctors          : ALIGN(4)
{
/* gcc uses crtbegin.o to find the start of
* the constructors, so we make sure it is
* first.  Because this is a wildcard, it
* doesn't matter if the user does not
* actually link against crtbegin.o; the
* linker won't look for a file to match a
* wildcard.  The wildcard also means that it
* doesn't matter which directory crtbegin.o
* is in.
*/
KEEP (*crtbegin.o(.ctors))
KEEP (*crtbegin?.o(.ctors))
/* We don't want to include the .ctor section from
* the crtend.o file until after the sorted ctors.
* The .ctor section from the crtend file contains the
* end of ctors marker and it must be last
*/
KEEP (*(EXCLUDE_FILE (*crtend.o *crtend?.o ) .ctors))
KEEP (*(SORT(.ctors.*)))
KEEP (*(.ctors))
} >ROM AT>ROM

.dtors          : ALIGN(4)
{
KEEP (*crtbegin.o(.dtors))
KEEP (*crtbegin?.o(.dtors))
KEEP (*(EXCLUDE_FILE (*crtend.o *crtend?.o ) .dtors))
KEEP (*(SORT(.dtors.*)))
KEEP (*(.dtors))
} >ROM AT>ROM

PROVIDE( _ilm_lma = LOADADDR(.text) );
PROVIDE( _ilm = ADDR(.text) );
PROVIDE( _eilm = . );
PROVIDE( _text_lma = LOADADDR(.text) );

PROVIDE( _text = ADDR(.text) );
PROVIDE( _text_start = ADDR(.text) );
PROVIDE (_etext = .);
PROVIDE (__etext = .);
PROVIDE (etext = .);
PROVIDE( _text_size = _etext - _text);

.rodata_in_ram : ALIGN(8)
{
. = ALIGN(8);
*(.srodata.cst16)
*(.srodata.cst8)
*(.srodata.cst4)
*(.srodata.cst2)
*(.srodata .srodata.*)
*(.rdata)
*(.rodata .rodata.*)
*(.gnu.linkonce.r.*)
} >DLM AT>ROM

.data            : ALIGN(8)
{
KEEP(*(.data.ctest*))
*(.data .data.*)
*(.gnu.linkonce.d.*)
. = ALIGN(8);
PROVIDE( __global_pointer$ = . + 0x800 );
*(.sdata .sdata.* .sdata*)
*(.gnu.linkonce.s.*)
. = ALIGN(8);
} >DLM AT>ROM

.tdata           : ALIGN(8)
{
PROVIDE( __tls_base = . );
*(.tdata .tdata.* .gnu.linkonce.td.*)
} >DLM AT>ROM

.dlm_section            : ALIGN(8)
{
. = ALIGN(8);
*(.dlm_section)
. = ALIGN(8);
} >DLM AT>ROM

PROVIDE( _data_lma = LOADADDR(.rodata_in_ram) );
PROVIDE( _data = ADDR(.rodata_in_ram) );
PROVIDE( _edata = . );
PROVIDE( _data_size = _edata - _data);
PROVIDE( edata = . );

PROVIDE( _fbss = . );
PROVIDE( __bss_start = . );

.tbss (NOLOAD)   : ALIGN(8)
{
*(.tbss .tbss.* .gnu.linkonce.tb.*)
*(.tcommon)
PROVIDE( __tls_end = . );
} >DLM AT>DLM

.tbss_space (NOLOAD) : ALIGN(8)
{
. = . + SIZEOF(.tbss);
} >DLM AT>DLM

.bss (NOLOAD)   : ALIGN(8)
{
*(.sbss*)
*(.gnu.linkonce.sb.*)
*(.bss .bss.*)
*(.gnu.linkonce.b.*)
*(COMMON)
. = ALIGN(4);
} >DLM AT>DLM

PROVIDE( _end = . );
PROVIDE( end = . );

/* Nuclei C Runtime Library requirements:
* 1. heap need to be align at 16 bytes
* 2. __heap_start and __heap_end symbol need to be defined
* 3. reserved at least __HEAP_SIZE space for heap
*/
.heap (NOLOAD)   : ALIGN(16)
{
. = ALIGN(16);
PROVIDE( _heap_start = . );
PROVIDE( __heap_start = . );
. += __HEAP_SIZE;
. = ALIGN(16);
PROVIDE( __heap_limit = . );
} >DLM AT>DLM

.stack ORIGIN(DLM) + LENGTH(DLM) - __TOT_STACK_SIZE (NOLOAD) :
{
. = ALIGN(16);
PROVIDE( _heap_end = . );
PROVIDE( __heap_end = . );
PROVIDE( __StackLimit = . );
PROVIDE( __StackBottom = . );
. += __TOT_STACK_SIZE;
. = ALIGN(16);
PROVIDE( __StackTop = . );
PROVIDE( _sp = . );
} >DLM AT>DLM
}
