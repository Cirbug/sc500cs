ifneq ($(MAKELEVEL),0)

# (0) include config file

# (1.1) add submodule resource file
SRC_DIR += .

# (1.2) add submodule include
INC_DIR += .

# (3) set specificity FLAGS
LIBNAME := semihost

include $(AL_SDK_ROOT)/tools/make/rules.mk

else

MODULE_DIR := $(dir $(lastword $(MAKEFILE_LIST)))

$(eval PUBLIC_INC_DIR += $(MODULE_DIR))

endif