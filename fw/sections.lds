#if defined(DE0NANO_XIP) && defined(DE0NANO_RAM_BOOT)
#  error "DE0NANO_XIP and DE0NANO_RAM_BOOT are mutually exclusive"
#endif
#ifndef DE0NANO
#  error "This firmware is the DE0-Nano port; define DE0NANO"
#endif
#ifdef DE0NANO_XIP
#  define MEM_TOTAL 0x2000  /* 8 KiB scratchpad; matches MEM_WORDS=2048 */
#elif defined(DE0NANO_RAM_BOOT)
#  define MEM_TOTAL 0x8000  /* 32 KiB; matches MEM_WORDS=8192 */
#else
#  error "Define DE0NANO_RAM_BOOT or DE0NANO_XIP"
#endif

ENTRY(start)

#ifdef DE0NANO_RAM_BOOT

MEMORY
{
    RAM (xrw) : ORIGIN = 0x00000000, LENGTH = MEM_TOTAL
}

SECTIONS
{
    .text :
    {
        . = ALIGN(4);
        KEEP(*(.text.start))
        *(.text) *(.text*)
        *(.rodata) *(.rodata*) *(.srodata) *(.srodata*)
        . = ALIGN(4);
        _etext = .;
    } >RAM

    /* LMA == VMA: start.S .data copy is an identity memcpy. */
    .data :
    {
        . = ALIGN(4);
        _sdata = .;
        _sidata = .;
        _ram_start = .;
        *(.data) *(.data*) *(.sdata) *(.sdata*)
        . = ALIGN(4);
        _edata = .;
    } >RAM

    .bss :
    {
        . = ALIGN(4);
        _sbss = .;
        *(.bss) *(.bss*) *(.sbss) *(.sbss*) *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } >RAM

    .heap :
    {
        . = ALIGN(4);
        _heap_start = .;
    } >RAM
}

/* 32 KiB RAM-boot map:
 *   [0x0000, 0x5000)  .text/.data/.bss/.heap   (20 KiB)
 *   [0x5000, 0x6000)  memtest window           (4 KiB, not live stack)
 *   [0x6000, 0x8000)  stack; STACKADDR = 0x8000 grows down (8 KiB)
 */
ASSERT(_heap_start <= 0x5000, "RAM-boot .bss/.heap collided with memtest window");

#else /* DE0NANO_XIP */

MEMORY
{
    FLASH (rx) : ORIGIN = 0x00100000, LENGTH = 0x400000
    RAM   (xrw): ORIGIN = 0x00000000, LENGTH = MEM_TOTAL
}

SECTIONS
{
    .text :
    {
        . = ALIGN(4);
        KEEP(*(.text.start))
        *(.text) *(.text*)
        *(.rodata) *(.rodata*) *(.srodata) *(.srodata*)
        . = ALIGN(4);
        _etext = .;
        _sidata = _etext;
    } >FLASH

    .data : AT(_sidata)
    {
        . = ALIGN(4);
        _sdata = .;
        _ram_start = .;
        *(.data) *(.data*) *(.sdata) *(.sdata*)
        . = ALIGN(4);
        _edata = .;
    } >RAM

    .bss :
    {
        . = ALIGN(4);
        _sbss = .;
        *(.bss) *(.bss*) *(.sbss) *(.sbss*) *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } >RAM

    .heap :
    {
        . = ALIGN(4);
        _heap_start = .;
    } >RAM
}

#endif
