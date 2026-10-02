set(CMAKE_SYSTEM_NAME               Generic)
set(CMAKE_SYSTEM_PROCESSOR          arm)

set(CMAKE_C_COMPILER_ID GNU)
set(CMAKE_CXX_COMPILER_ID GNU)

# Use the compiler shipped with the Anlogic FD installation when it exists.
# This avoids requiring VS Code/cube-cmake to inherit a modified PATH.
set(ANLOGIC_GCC_BIN
    "F:/AnlogicFpga/FD_2026.1/toolchain/gcc/aarch32/bin"
    CACHE PATH "Directory containing arm-none-eabi-gcc")

if(EXISTS "${ANLOGIC_GCC_BIN}/arm-none-eabi-gcc.exe")
    set(CMAKE_C_COMPILER   "${ANLOGIC_GCC_BIN}/arm-none-eabi-gcc.exe" CACHE FILEPATH "C compiler" FORCE)
    set(CMAKE_CXX_COMPILER "${ANLOGIC_GCC_BIN}/arm-none-eabi-g++.exe" CACHE FILEPATH "C++ compiler" FORCE)
    set(CMAKE_LINKER       "${ANLOGIC_GCC_BIN}/arm-none-eabi-g++.exe" CACHE FILEPATH "Linker" FORCE)
    set(CMAKE_OBJCOPY      "${ANLOGIC_GCC_BIN}/arm-none-eabi-objcopy.exe" CACHE FILEPATH "Objcopy" FORCE)
    set(CMAKE_SIZE         "${ANLOGIC_GCC_BIN}/arm-none-eabi-size.exe" CACHE FILEPATH "Size tool" FORCE)
else()
    # Fallback for another installation: arm-none-eabi-* must be in PATH.
    set(TOOLCHAIN_PREFIX   arm-none-eabi-)
    set(CMAKE_C_COMPILER   ${TOOLCHAIN_PREFIX}gcc)
    set(CMAKE_CXX_COMPILER ${TOOLCHAIN_PREFIX}g++)
    set(CMAKE_LINKER       ${TOOLCHAIN_PREFIX}g++)
    set(CMAKE_OBJCOPY      ${TOOLCHAIN_PREFIX}objcopy)
    set(CMAKE_SIZE         ${TOOLCHAIN_PREFIX}size)
endif()

set(CMAKE_ASM_COMPILER    ${CMAKE_C_COMPILER})

set(CMAKE_EXECUTABLE_SUFFIX_ASM     ".elf")
set(CMAKE_EXECUTABLE_SUFFIX_C       ".elf")
set(CMAKE_EXECUTABLE_SUFFIX_CXX     ".elf")

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# MCU specific flags
set(TARGET_FLAGS "-mcpu=cortex-m3 ")

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${TARGET_FLAGS}")
set(CMAKE_ASM_FLAGS "${CMAKE_C_FLAGS} -x assembler-with-cpp -MMD -MP")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -fdata-sections -ffunction-sections -fstack-usage")

# The cyclomatic-complexity parameter must be defined for the Cyclomatic complexity feature in STM32CubeIDE to work.
# However, most GCC toolchains do not support this option, which causes a compilation error; for this reason, the feature is disabled by default.
# set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fcyclomatic-complexity")

set(CMAKE_C_FLAGS_DEBUG "-O0 -g3")
set(CMAKE_C_FLAGS_RELEASE "-Os -g0")
set(CMAKE_CXX_FLAGS_DEBUG "-O0 -g3")
set(CMAKE_CXX_FLAGS_RELEASE "-Os -g0")

set(CMAKE_CXX_FLAGS "${CMAKE_C_FLAGS} -fno-rtti -fno-exceptions -fno-threadsafe-statics")

set(CMAKE_EXE_LINKER_FLAGS "${TARGET_FLAGS}")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -T \"${CMAKE_SOURCE_DIR}/STM32F103xx_FLASH.ld\"")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} --specs=nano.specs")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,-Map=${CMAKE_PROJECT_NAME}.map -Wl,--gc-sections")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--print-memory-usage")
set(TOOLCHAIN_LINK_LIBRARIES "m")
