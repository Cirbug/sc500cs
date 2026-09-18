#########################################################################
##
# gcc arm option:   https://gcc.gnu.org/onlinedocs/gcc/ARM-Options.html
# support feature:
# SMP, ENABLE_MMU, ENABLE_ICACHE, ENABLE_DCACHE, ARMv8_EL


#########################################################################
# ARMv8_STATE, SMP
ifeq ($(ARMv8_STATE),64)
    ARCH_ABI        := aarch64
    ARCH_FLAG       := -mtune=$(MTUNE) -march=$(CHIP_ARCH) -mcpu=$(MTUNE)

    ifeq ($(benchmark),)
        ARCH_FLAG       += -mstrict-align
    endif
else ifeq ($(ARMv8_STATE),32)
    ARCH_ABI        := aarch32
    ARCH_FLAG       := -mtune=$(MTUNE) -mcpu=$(MTUNE) -mfpu=neon-fp-armv8 -marm -gdwarf-2 -mno-unaligned-access -mfloat-abi=hard

    ifeq ($(benchmark),)
    CFLAGS += -fno-omit-frame-pointer -fno-stack-protector
    endif

endif

ifeq ($(SMP),1)
    ARCH_FLAG   += -DSMP
endif

#########################################################################
# ENABLE_MMU, ENABLE_DCACHE, DDR_2M_MAPPING, ENABLE_ICACHE, CODE_READONLY
ifeq ($(ENABLE_MMU),1)
    ARCH_FLAG   += -DENABLE_MMU=1

    ifeq ($(DDR_2M_MAPPING),1)
        ARCH_FLAG   += -DDDR_2M_MAPPING=1
        ifeq ($(CODE_READONLY),1)
            ARCH_FLAG   += -DCODE_READONLY=1
        endif
    endif

endif

ifeq ($(ENABLE_ICACHE),1)
    ARCH_FLAG   += -DENABLE_ICACHE=1
endif

ifeq ($(ENABLE_DCACHE),1)
    ARCH_FLAG   += -DENABLE_DCACHE=1
endif

#########################################################################
# ARMv8_EL, ARMv8_SECURE

ifeq ($(ARMv8_EL), EL1)
    CFLAGS += -DSWITCH_TO_EL1_EL0_FROM_EL3
    ifeq ($(ARMv8_SECURE), NONSECURE)
        CFLAGS += -DSUPPORT_NONSECURE
    endif
endif

#########################################################################
# ARMv8_CORE
ifeq ($(ARMv8_CORE), SLAVE)
    CFLAGS += -DARM_CORE_SLAVE
endif


# vim: syntax=make
