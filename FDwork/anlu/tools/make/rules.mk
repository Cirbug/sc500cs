SDK_VERSION = 20260206
AL_CFLAGS += -DSDK_VERSION=$(SDK_VERSION)
#########################################################################
AL_SDK_ROOT		?= $(SDK_ROOT)
AL_PLAT_DIR		?= $(PLAT_DIR)

COLOR_RESET  := \033[0m
COLOR_RED    := \033[31m
COLOR_GREEN  := \033[32m
COLOR_YELLOW := \033[33m
COLOR_CYAN   := \033[36m

include $(AL_SDK_ROOT)/tools/make/misc.inc
include $(AL_SDK_ROOT)/tools/make/config.mk
sinclude $(AL_PLAT_DIR)/board_cfg.mk


CC      = ${Q}$(COMPILE_PREFIX)gcc
CXX     = ${Q}$(COMPILE_PREFIX)g++
AR      = ${Q}$(COMPILE_PREFIX)ar
LD      = ${Q}$(COMPILE_PREFIX)ld
OBJCOPY = ${Q}$(COMPILE_PREFIX)objcopy
OBJDUMP = ${Q}$(COMPILE_PREFIX)objdump
NM      = ${Q}$(COMPILE_PREFIX)nm
AS      = ${Q}$(COMPILE_PREFIX)as
GDB     = ${Q}$(COMPILE_PREFIX)gdb
SIZE    = ${Q}$(COMPILE_PREFIX)size
ECHO  	= echo
MAKE    = make

ARFLAGS = crs


#########################################################################
ifeq ($(AL_CHIP), softcore)
LINKER_SCRIPT ?= $(CHIP_DIR)/lds/gcc_$(AL_CHIP)_$(DOWNLOAD).ld
else ifeq ($(AL_CHIP), ph1p35)
LINKER_SCRIPT ?= $(CHIP_DIR)/lds/gcc_$(AL_CHIP)_$(DOWNLOAD).ld
else
LINKER_SCRIPT ?= $(CHIP_DIR)/lds/gcc_$(AL_CHIP)_$(DOWNLOAD)_$(ARCH_ABI).ld
endif

ifeq ($(DOWNLOAD), ocm)
AL_CFLAGS   += -DDOWNLOAD_MODE=0
else ifeq ($(DOWNLOAD), ddr)
AL_CFLAGS   += -DDOWNLOAD_MODE=1
else ifeq ($(DOWNLOAD), tcm)
AL_CFLAGS   += -DDOWNLOAD_MODE=2
else ifeq ($(DOWNLOAD), xip)
AL_CFLAGS   += -DDOWNLOAD_MODE=3
endif

include $(AL_SDK_ROOT)/tools/make/$(AL_CHIP).inc

#########################################################################

MKDEP_OPT   = -MMD -MT $@ -MF $@.d

ifeq ($(RTOS),)
else
    AL_CFLAGS += -DUSE_RTOS
    ifeq ($(RTOS),freertos)
        AL_CFLAGS += -DRTOS_FREERTOS
        RTOSLIB   := FreeRTOS-Kernel
    else ifeq ($(RTOS),rtthread)
        AL_CFLAGS += -DRTOS_RTTHREAD
        RTOSLIB   := RT-Thread
    else ifeq ($(RTOS),freertos_smp)
        AL_CFLAGS += -DSMP=1 -DRTOS_FREERTOS
		RTOSLIB   := FreeRTOS-Kernel-SMP
    else ifeq ($(RTOS),rtthread_nano)
        AL_CFLAGS += -DRTOS_RTTHREAD_NANO
        RTOSLIB   := RT-Thread-Nano
    else
        RTOSLIB   := $(RTOS)
    endif
endif

########################################################################

ifeq ($(MAKELEVEL),0)
    PUBLIC_INC_DIR :=

    LIBS_DIR_LIST  := $(BSP_DIR) \
                      $(BSP_DIR)/lib/* \
					  $(AL_SDK_ROOT)/3rdparty/lib/semihost \
	                  $(AL_SDK_ROOT)/3rdparty/* \
                      $(AL_SDK_ROOT)/3rdparty/lib/FATFS \
					  $(AL_SDK_ROOT)/3rdparty/lib/jpu_driver \
					  $(AL_SDK_ROOT)/3rdparty/lib/libmetal \
					  $(AL_SDK_ROOT)/3rdparty/lib/open-amp \
                      $(AL_SDK_ROOT)/3rdparty/os/* \
                      $(AL_SDK_ROOT)/3rdparty/os/FreeRTOS/*

# lib_tinyusb
ifeq ($(USBLIB), tinyusb)
    LIBS_DIR_LIST  += $(AL_SDK_ROOT)/3rdparty/lib/tinyusb
else ifeq ($(USBLIB), cherryusb)
    LIBS_DIR_LIST  += $(AL_SDK_ROOT)/3rdparty/lib/CherryUSB
endif

ifeq ($(AL_CHIP), dr1v90)
    LIBS_DIR_LIST  += $(AL_SDK_ROOT)/3rdparty/lib/NMSIS
endif
    ##############################
    # find out libs
    LIBS_DIR      := $(dir $(wildcard $(addsuffix /Makefile, $(LIBS_DIR_LIST))))

    tinyusb_header_depends := tusb_config.h
    tinyusb_cfg := $(shell find $(AL_SDK_ROOT) $(AL_CUR_DIR) $(APP_INC) -name $(tinyusb_header_depends) 2>/dev/null)

    ifeq ($(tinyusb_cfg),)
    LIBS_DIR     := $(filter-out %tinyusb/,$(LIBS_DIR))
    endif

    cherryusb_header_depends := usb_config.h
    cherryusb_cfg := $(shell find $(AL_SDK_ROOT) $(AL_CUR_DIR) $(APP_INC) -name $(cherryusb_header_depends) 2>/dev/null)

    ifeq ($(cherryusb_cfg),)
    LIBS_DIR     := $(filter-out %cherryusb_driver/,$(LIBS_DIR))
    endif

    ifdef select_module_by_name
    LIBS_DIR      := $(call select_module_by_name,$(LIBS_DIR))
    endif

    ##############################
    # include the libs Makefile
	BSP_LIB_MAKEFILES := $(wildcard $(BSP_DIR)/lib/*/Makefile)
    $(foreach lib,$(LIBS_DIR),\
	    $(eval include $(lib)/Makefile) \
		$(eval include $(BSP_DIR)/Makefile) \
		$(foreach bsp_lib_mk,$(BSP_LIB_MAKEFILES),\
			$(eval include $(bsp_lib_mk)) \
		)\
	);


    PUBLIC_INC  :=  $(foreach subdir,$(sort $(PUBLIC_INC_DIR)), -I$(subdir))

    export PUBLIC_INC


    ######################################
    # PLAT created by hpf, keep compatible
    LIBS_DIR += $(PLAT_DIR)
    LIBS_DIR += $(patsubst %/Makefile, %, $(wildcard $(PLAT_DIR)/src/ddr_demo/Makefile))


endif

APP_INC_DIR += $(APP_INC)

## module inc
MODULE_INC  :=  $(foreach subdir,$(sort $(INC_DIR)), \
				-I$(subdir)) $(foreach subdir,$(sort $(APP_INC_DIR)), \
				-I$(subdir)) -I$(AL_PLAT_DIR)/inc -I$(AL_PLAT_DIR)
#########################################################################

ifeq ($(CORE),arm)
CFLAGS +=  -mcpu=cortex-a35 -gdwarf-2

ifeq ($(benchmark),)
CFLAGS += -fno-omit-frame-pointer -fno-stack-protector
endif

endif

CFLAGS += $(CFLAG)
AL_CFLAGS  += $(CFLAGS) $(PUBLIC_INC) $(MODULE_INC) $(MKDEP_OPT) -Wall
#########################################################################
# ldflags
ifneq ($(NOGC),1)
GC_CFLAGS  =   -ffunction-sections -fdata-sections
GC_LDFLAGS +=  -Wl,--gc-sections -Wl,--check-sections
else
GC_LDFLAGS +=
endif


ifeq ($(PFLOAT),1)
NEWLIB_LDFLAGS += -u _printf_float
endif

LIB_OPT  = $(addprefix -L, $(sort $(LIB_DIR)))

#########################################################################
# source

C_SRCS     += $(foreach subdir, $(SRC_DIR), $(wildcard $(subdir)/*.c $(subdir)/*.C $(subdir)/*.CPP $(subdir)/*.cc $(subdir)/*.cpp))
ASM_SRCS   += $(foreach subdir, $(SRC_DIR), $(wildcard $(subdir)/*.s $(subdir)/*.S))

APP_C_SRCS += $(foreach subdir, $(APP_SRC_DIR), $(wildcard $(subdir)/*.c $(subdir)/*.cpp $(subdir)/*.C $(subdir)/*.CPP $(subdir)/*.cc $(subdir)/*.CC))

C_SRCS_ABSPATH 		:= $(abspath $(C_SRCS))
ASM_SRCS_ABSPATH 	:= $(abspath $(ASM_SRCS))

APP_C_SRCS_ABSPATH 	:= $(abspath $(APP_C_SRCS))

export CHIP_ARCH
export ARCH_EXT
export INC_DIR

C_OBJS     			:= $(patsubst $(AL_SDK_ROOT)/%,$(OBJ_DIR)/%.o, $(C_SRCS_ABSPATH))
ASM_OBJS   			:= $(patsubst $(AL_SDK_ROOT)/%,$(OBJ_DIR)/%.o, $(ASM_SRCS_ABSPATH))
APP_C_OBJS			:= $(patsubst $(APP_CUR_DIR)/%,$(APP_OBJ_DIR)/%.o, $(APP_C_SRCS_ABSPATH))


ALL_OBJS   			:= $(ASM_OBJS) $(C_OBJS) $(CXX_OBJS) $(APP_C_OBJS)
ALL_DEPS   			:= $(ALL_OBJS:=.d)


VPATH = $(dir $(C_SRCS_ABSPATH)) $(dir $(ASM_SRCS_ABSPATH)) $(dir $(APP_C_SRCS_ABSPATH))

CLEAN_OBJS += $(TARGET).elf $(TARGET).map $(TARGET).bin $(TARGET).dump $(TARGET).dasm \
				 $(TARGET).hex $(TARGET).verilog $(AL_SDK_ROOT)/build $(APP_TAR_DIR)

REAL_CLEAN_OBJS = $(subst /,$(PS), $(CLEAN_OBJS))

#########################################################################
# Prerequesties
COMMON_PREREQS +=	$(AL_SDK_ROOT)/tools/make/rules.mk
COMMON_PREREQS +=	$(AL_SDK_ROOT)/tools/make/config.mk
COMMON_PREREQS +=	$(AL_CUR_DIR)/Makefile
COMMON_PREREQS +=   Makefile

#########################################################################
# target: build elf, or build libs
#
all: $(TARGET)

TARGET_ELF := $(TARGET_PATH)/build/$(TARGET).elf
$(TARGET): $(TARGET_ELF)

#########################################################################
# Default goal, placed before dependency includes
#

#########################################################################
# include dependency files of application
#
ifneq ($(MAKECMDGOALS),clean)
-include $(ALL_DEPS)
endif

.PHONY: all info help clean

info:
	@$(ECHO) "====================================="
	@$(ECHO) "Anlogic FPSoc Software Development Kit"
	@$(ECHO) "AL_CHIP=$(AL_CHIP) CORE=$(CORE) V=$(V) PLAT=$(notdir $(PLAT_DIR)) RTOS=$(RTOS) PFLOAT=$(PFLOAT) NOGC:$(NOGC) DOWNLOAD: $(DOWNLOAD) "
	@$(ECHO) "====================================="

help:
	@$(ECHO) "Anlogic FPSoc Software Development Kit "
	@$(ECHO) "== Make variables used in FPSoc SDK =="
	@$(ECHO) "SOC:         Select SoC built in FPSoc SDK, will select board_dr1x90_emulation by default"
	@$(ECHO) "BOARD:       Select SoC's Board built in FPSoc SDK, will select nuclei_fpga_eval by default"
	@$(ECHO) "DOWNLOAD:    Select SoC's download mode, use ocm by default, optional ocm/ddr"
	@$(ECHO) "V:           V=1 verbose make, will print more information, by default V=0"
	@$(ECHO) "== Example Usage =="
	@$(ECHO) "cd $(AL_SDK_ROOT)/solutions/demo/baremetal/helloworld make DOWNLOAD=ocm"

#########################################################################
# Convenience function for verifying option has a boolean value
# $(eval $(call assert_boolean,FOO)) will assert FOO is 0 or 1
define assert_boolean
    $(if $(filter-out 0 1,$($1)),$(error $1 must be boolean))
endef

# Convenience function for verifying options have boolean values
# $(eval $(call assert_booleans,FOO BOO)) will assert FOO and BOO for 0 or 1 values
define assert_booleans
    $(foreach bool,$1,$(eval $(call assert_boolean,$(bool))))
endef

# Convenience function for verifying option has a right string
# $(eval $(call assert_option,option1 option2, FOO)) will assert FOO is string1 or string2
define assert_two_option
    $(if $(filter-out $1 $2, $3),$(error $4 must be $1 or $2))
endef

define assert_three_option
    $(if $(filter-out $1$2$3,$4),$(error$5must be $1 or $2 or $3))
endef

define assert_empty
    $(if $(strip $(1)),,$(error $1 must be not empty))
endef

.PHONY: check

check:
	$(call assert_booleans, DDR_2M_MAPPING ENABLE_MMU CODE_READONLY VERBOSE SILENT PFLOAT NOGC)
	$(call assert_option_two_option, 32, 64, $(ARMv8_STATE), ARMv8_STATE)
	$(call assert_two_option,EL1, EL3, $(ARMv8_EL), ARMv8_EL)
	$(call assert_two_option,SECURE, NONSECURE, $(ARMv8_SECURE), ARMv8_SECURE)
	$(call assert_two_option,MASTER, SLAVE, $(ARMv8_CORE), ARMv8_CORE)
	$(call assert_three_option,dr1v90, dr1m90, softcore, $(AL_CHIP), AL_CHIP)
	$(call assert_three_option,FreeRTOS-Kernel, FreeRTOS-Kernel-SMP,RT-Thread, $(RTOS), RTOS)
	$(call assert_three_option,ocm,ddr,tcm $(DOWNLOAD), DOWNLOAD)
	@$(ECHO) "all parameters have been checked"

define make_target_dir
    @mkdir -p $(dir $@)
endef

#########################################################################
empty :=
space += $(empty) $(empty)

define depth_difference
$(strip \
    $(eval _pathA := $(subst \,/,$(abspath $(1)))) \
    $(eval _pathB := $(subst \,/,$(abspath $(2)))) \
    $(eval _depthA := $(words $(subst /, ,$(_pathA)))) \
    $(eval _depthB := $(words $(subst /, ,$(_pathB)))) \
    $(shell echo $$(($(_depthB) - $(_depthA)))) \
)
endef

define path_to_backtrack
$(strip \
    $(eval _depth_diff := $(call depth_difference,$(1),$(2))) \
    $(subst $(space),,$(wordlist 1,$(_depth_diff),../ ../ ../ ../ ../ ../ ../ ../ ../ ../)) \
)
endef

define change_relative_path
$(strip \
    $(if $(and $(1),$(2),$(3)),, \
        $(error Missing arguments for convert_cflags) \
    ) \
    $(eval _base := $(1)) \
    $(eval _current := $(2)) \
    $(eval _cflags := $(3)) \
    $(eval _backtrack := $(call path_to_backtrack,$(_base),$(_current))) \
    $(patsubst -I$(_base)/%, -I$(_backtrack)%, $(_cflags)) \
)
endef


#########################################################################

$(ASM_OBJS): $(OBJ_DIR)/%.o: $(AL_SDK_ROOT)/% $(COMMON_PREREQS)
	@$(ECHO) "Compling: " $(notdir $@)
	$(make_target_dir)
	$(CC) $(call change_relative_path, $(AL_SDK_ROOT), $(CURDIR), $(AL_CFLAGS)) -c -o $@ $<

#########################################################################
$(C_OBJS) $(CXX_OBJS): $(OBJ_DIR)/%.o: $(AL_SDK_ROOT)/% $(COMMON_PREREQS)
	@$(ECHO) "Compling: " $(notdir $@)
	$(make_target_dir)
	$(CC) $(call change_relative_path, $(AL_SDK_ROOT), $(CURDIR), $(AL_CFLAGS)) -c -o $@ $<

#########################################################################
$(APP_C_OBJS) $(APP_CPP_OBJS): $(APP_OBJ_DIR)/%.o: $(APP_CUR_DIR)/% $(COMMON_PREREQS)
	@$(ECHO) "Compling: " $(notdir $@)
	$(make_target_dir)
	$(CC) $(call change_relative_path, $(APP_CUR_DIR), $(CURDIR), $(AL_CFLAGS)) -c -o $@ $<


#########################################################################
#### if target is elf
####

ifeq ($(RTOS), freertos)
filterout_lib = %librtthread %libfreertos_smp
else ifeq ($(RTOS), rtthread)
filterout_lib = %libfreertos %libfreertos_smp
else ifeq ($(RTOS), freertos_smp)
filterout_lib = %libfreertos %librtthread
else
filterout_lib = %libfreertos %libfreertos_smp %librtthread
endif


$(TARGET_ELF): make_all_libs $(ALL_OBJS)
	$(eval ld_libs := $(shell find $(subst $(CURDIR)/,,$(LIB_OUTPUT_DIR)) $(subst $(CURDIR)/,,$(LIB_PREBUILD_DIR)) -name '*.a' 2>/dev/null | \
	  grep -v "$(filterout_lib)" | \
	  sed 's#.*/lib\(.*\)\.a#-l\1#' | tr '\n' ' '))
	$(CC) -Wl,--start-group -Wl,--whole-archive $(subst $(CURDIR)/,,$(ALL_OBJS)) $(ld_libs) $(LD_LIBS) -z noexecstack -Wl,--no-whole-archive -lgcc -lg -lc -lm -lstdc++ -u _write -Wl,--end-group -L$(subst $(CURDIR)/,,$(LIB_OUTPUT_DIR)) -L$(subst $(CURDIR)/,,$(LIB_PREBUILD_DIR)) $(subst $(CURDIR)/,,$(LIB_OPT)) \
	-T$(LINKER_SCRIPT) -nostartfiles -Wl,-M,-Map=$(TARGET_PATH)/build/$(TARGET).map \
    $(LDFLAGS) $(GC_LDFLAGS) $(NEWLIB_LDFLAGS) --specs=nosys.specs -Wl,--build-id=none -o $@
	$(OBJCOPY) $@ -O binary $(TARGET_PATH)/build/$(TARGET).bin
	$(SIZE) $@



########################################################################
# get bsp library path: bps folder name is different between
# sdk workspace and embedded workspace

.PHONY: bsp_clean
bsp_clean:
ifneq ($(BSP_DIR),)
	@$(MAKE) -C $(BSP_DIR) lib.do.clean
endif


.PHONY: make_all_libs
make_all_libs: $(addsuffix /make.lib, $(LIBS_DIR))

.PHONY:
%/make.lib: | info
	$(MAKE) -C $(patsubst %/make.lib,%,$@) lib

.PHONY:
lib.do.clean:
	$(RM) -rf $(OBJ_DIR) $(LIB_OUTPUT_DIR)/lib$(LIBNAME).a

#########################################################################
#### if target is lib
####

lib: $(LIB_OUTPUT_DIR)/lib$(LIBNAME).a
$(LIB_OUTPUT_DIR)/lib$(LIBNAME).a: $(ALL_OBJS) $(SUB_LD_LIBS)
	@mkdir -p $(LIB_OUTPUT_DIR)
	$(AR) $(ARFLAGS) $@ $(call change_relative_path, $(AL_SDK_ROOT), $(CURDIR), $(C_OBJS)) $(call change_relative_path, $(AL_SDK_ROOT), $(CURDIR), $(ASM_OBJS))

#########################################################################
dasm: $(TARGET_ELF)
	$(OBJDUMP) -S -d --all-headers --demangle --line-numbers --wide $< > $(TARGET_PATH)/build/$(TARGET).dump
	$(OBJDUMP) -d $< > $(TARGET_PATH)/build/$(TARGET).dasm
	$(OBJCOPY) $< -O ihex $(TARGET_PATH)/build/$(TARGET).hex
	$(OBJCOPY) $< -O verilog $(TARGET_PATH)/build/$(TARGET).verilog
	$(OBJCOPY) $< -O binary $(TARGET_PATH)/build/$(TARGET).bin


#########################################################################
hpf:
	@$(ECHO) "Update Platform header"
	$(Q)unzip -o $(HPF_PATH) -d $(AL_SDK_ROOT)/hpf_tmp
	$(Q)cp $(AL_SDK_ROOT)/hpf_tmp/HPFs/soc_plat.h $(AL_PLAT_DIR)/inc
	$(Q)cp $(AL_SDK_ROOT)/hpf_tmp/HPFs/soc_plat.c $(AL_PLAT_DIR)/src
	$(Q)export LD_LIBRARY_PATH=$(AL_SDK_ROOT)/tools/ci && export BSP_RESOURCE_PATH=$(AL_SDK_ROOT)/ && $(ASCT_TOOL) $(DR1X90_TOOL) update_platform_header_from_hpf -plat_h $(PLAT_H_PATH) -hpf $(HPF_PATH)
	$(Q)rm -r $(AL_SDK_ROOT)/hpf_tmp/
	@$(ECHO) "Platform header updated successfully"

#########################################################################
clean:
	@$(ECHO) "Clean all build objects"
	$(RM) -rf $(CLEAN_OBJS)
# vim: syntax=make
