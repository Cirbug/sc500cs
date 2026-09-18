#include "al_core.h"
#include "al_rv_core.h"
#include "al_backtrace.h"

/* Note:Add -fno-omit-frame-pointer to the CFLAGS in the makefile to print the all call stack */
struct StackFrame {
    AL_INTPTR s_fp;
    AL_INTPTR s_ra;
};

extern AL_S8 _text_start[], _etext[];

static AL_S32 AlStack_IsText(AL_INTPTR addr)
{
    if (addr >= (AL_INTPTR)_text_start &&
        addr < (AL_INTPTR)_etext) {
            return 1;
         }
#ifdef DEBUG_RISCVSTACK
        printf("_etext:0x%016lx\r\n", (AL_INTPTR)_etext);
        printf("pc:0x%016lx\r\n", addr);
        printf("_text:0x%016lx\r\n", (AL_INTPTR)_text_start);
#endif
    return 0;
}

static AL_VOID AlStack_WalkStackFrame(unsigned long sp_func, unsigned long fp_func)
{
    AL_INTPTR sp, fp, pc;
    struct StackFrame *frame;
    AL_INTPTR low;

#ifndef USE_RTOS
    const register AL_INTPTR current_sp __asm__ ("sp");
    sp = current_sp;
    pc = (AL_INTPTR)AlStack_WalkStackFrame;
    fp = (AL_INTPTR)__builtin_frame_address(0);
#else
    // const register AL_INTPTR current_sp = ARCH_SYSREG_READ(CSR_MSCRATCH);
    // sp = current_sp;
    // pc = ARCH_SYSREG_READ(CSR_MEPC);
    // fp = (AL_INTPTR)((struct StackFrame *)sp + 2);

    /* Due to the abnormal situation where sp was not exchanged, it was temporarily set */
    sp = sp_func + 20 * REGBYTES;
    pc = (AL_INTPTR)AlStack_WalkStackFrame;
    fp = fp_func;
#endif

    while (1) {
        if (!AlStack_IsText(pc))
        {
#ifdef DEBUG_RISCVSTACK
            frame = (struct StackFrame *)fp - 1;
            sp = fp;
            fp = frame->s_fp;
            pc = frame->s_ra - 4;
            printf("debug next frame:[0x%016lx - 0x%016lx]  pc 0x%016lx\r\n", sp, fp, pc);
            printf("pc leave text section so stackdump break\r\n");
#endif
            break;
        }
        /* 检查fp是否有效 */
        low = sp + sizeof(struct StackFrame);//
        if ((fp < low) || (fp & 0x7)) {
#ifdef DEBUG_RISCVSTACK
            if(fp < low) {
                printf("low:0x%016lx\r\n", low);
                printf("sp:0x%016lx\r\n", low - sizeof(struct StackFrame));
            }
            printf("fp:0x%016lx\n", fp);
            frame = (struct StackFrame *)fp - 1;
            sp = fp;
            fp = frame->s_fp;
            pc = frame->s_ra - 4;
            printf("debug next frame:[0x%016lx - 0x%016lx]  pc 0x%016lx\r\n", sp, fp, pc);
#endif
            break;
        }
        /*
         * fp 指向上一级函数的栈底
         * 减去16个字节，正好是struct StackFrame
         */
        frame = (struct StackFrame *)fp - 1;
        sp = fp;
        fp = frame->s_fp;

        pc = frame->s_ra - 4;
        if (AlStack_IsText(pc))
            printf("[0x%016lx - 0x%016lx]  pc 0x%016lx\r\n", sp, fp, pc);
    }
}

AL_VOID AlStack_Dump(unsigned long sp, unsigned long fp)
{
    printf("Call Frame:\r\n");
    AlStack_WalkStackFrame(sp,fp);
    while (1) {

    }
}
