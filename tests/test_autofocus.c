#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#define UI_LENS_POS 0x28u
#define UI_LENS_CMD 0x2cu
#define UI_LENS_STAT 0x30u
#define UI_FOCUS_METRIC 0x34u
#define UI_LENS_DIAG 0x3cu
static uint32_t ms,regs[64],lens_diag_available=3;
static uint32_t moves,retries,reads,last_read_ms,bus_started,bus_duration;
static unsigned bus_pending,retry_fails,move_fails;
static uint32_t ui_now_ms(void) { return ms; }
static uint32_t ui_read(uint32_t offset)
{
    if(bus_pending && ms-bus_started>=bus_duration) {
        regs[UI_LENS_STAT/4]=(bus_pending==2 ? retry_fails : move_fails) ? 6u : 2u;
        bus_pending=0;
    }
    if(offset==UI_FOCUS_METRIC) {
        unsigned p=regs[UI_LENS_POS/4];
        unsigned error=p>7000 ? p-7000 : 7000-p;
        ++reads;last_read_ms=ms;
        return 100000u-error*5u;
    }
    return regs[offset/4];
}
static void ui_write(uint32_t offset,uint32_t value)
{
    regs[offset/4]=value;
    if(offset==UI_LENS_CMD) {
        assert(!(ui_read(UI_LENS_STAT)&1u));
        assert(value==1 || value==2);
        moves+=value==1;retries+=value==2;
        bus_pending=value;bus_started=ms;bus_duration=value==2?23u:3u;
        regs[UI_LENS_STAT/4]=value==2?1u:3u;
    }
}
static void lens_diag_report(void) {}
static void focus_plot(uint32_t p,uint32_t m,uint32_t s) {(void)p;(void)m;(void)s;}
/* gege 8f21399 在 autofocus_control.h 的 autofocus_park() 里新增了 al_printf 诊断，
 * 主机测试没有 SDK 的格式化器，这里补一个最小桩（否则链接期 undefined reference）。 */
static void al_printf(const char *fmt,...) {(void)fmt;}
#include "../FDwork/shared/autofocus_control.h"

static void reset(void)
{
    memset(regs,0,sizeof regs);
    ms=moves=retries=reads=bus_pending=retry_fails=move_fails=last_read_ms=0;
    lens_diag_available=3;
    regs[UI_LENS_STAT/4]=2;regs[UI_LENS_POS/4]=8192;
    regs[UI_LENS_DIAG/4]=0x00130113u;
    g_af_debug.requests=g_af_debug.reason=g_af_debug.lens_status=g_af_debug.diag=0;
    af_state=AF_IDLE;af_retried=af_move_pending=0;
}
static void poll_at(uint32_t now) {ms=now;autofocus_task();}
static void start_scan(void)
{
    unsigned before=moves;
    autofocus_restart();autofocus_task();
    assert(autofocus_active() && moves==before);
    poll_at(ms+AF_GIMBAL_SETTLE_MS);
    assert(af_state==AF_COARSE && moves==before+1);
}
static void finish(unsigned cadence)
{
    /* gege 8f21399：细扫结束不再走 AF_RETURN/autofocus_stop()，而是 autofocus_park()
     * 就地停在峰值上（AF_HOLD，reason 7=DONE 或 16=FLAT）。旧版终点是 AF_IDLE+DONE。 */
    for(unsigned i=0;i<20000 && af_state!=AF_IDLE && af_state!=AF_HOLD;i++) poll_at(ms+cadence);
    assert((af_state==AF_IDLE || af_state==AF_HOLD) &&
           (g_af_debug.reason==AF_REASON_DONE || g_af_debug.reason==AF_REASON_FLAT));
    /* 细扫步长 gege 由 64 改为 256（AF_FINE_STEP），合成曲线的真峰 7000 因此落到最近
     * 的 256 网格点 6912。用"距真峰不超过一个细扫步长"断言，以后再调步长也不会误报。 */
    assert(af_best_position<=7000u+AF_FINE_STEP && 7000u<=af_best_position+AF_FINE_STEP);
    assert(regs[UI_LENS_POS/4]==af_best_position);
}
int main(void)
{
    reset();regs[UI_LENS_STAT/4]=1;
    autofocus_restart();autofocus_task();
    assert(moves==0 && af_state==AF_START && g_af_debug.requests==1);
    regs[UI_LENS_STAT/4]=2;poll_at(25);
    assert(moves==0 && g_af_debug.reason==AF_REASON_WAIT_GIMBAL);
    poll_at(199);assert(moves==0);
    poll_at(200);
    assert(moves==1 && af_state==AF_COARSE);
    puts("PASS AF during startup busy stays queued and scans when ready");

    reset();regs[UI_LENS_STAT/4]=3;
    autofocus_restart();autofocus_task();assert(moves==0);
    regs[UI_LENS_STAT/4]=2;poll_at(10);assert(moves==0);
    poll_at(200);assert(moves==1);
    puts("PASS healthy background busy never receives an overlapping command");

    reset();regs[UI_LENS_STAT/4]=6;
    autofocus_restart();autofocus_task();assert(retries==1 && moves==0);
    poll_at(23);assert(moves==0 && af_state==AF_RECOVER);
    poll_at(200);assert(moves==1 && af_state==AF_COARSE && g_af_debug.diag!=0);
    finish(5);assert(retries==1);
    puts("PASS error -> one retry -> successful init -> complete coarse/fine scan without second tap");

    reset();regs[UI_LENS_STAT/4]=6;retry_fails=1;
    autofocus_restart();autofocus_task();poll_at(23);
    assert(af_state==AF_IDLE && g_af_debug.reason==AF_REASON_I2C_ERROR && retries==1);
    for(unsigned i=0;i<5000;i++) poll_at(ms+1);
    assert(retries==1 && moves==0);
    puts("PASS permanent I2C fault stops after one retry; idle does not move lens");

    reset();start_scan();poll_at(ms+3);
    regs[UI_LENS_STAT/4]=6;autofocus_task();
    assert(retries==1 && af_state==AF_RECOVER);
    poll_at(ms+23);assert(af_state==AF_RECOVER);
    poll_at(ms+177);assert(af_state==AF_COARSE && regs[UI_LENS_POS/4]==0);
    move_fails=1;poll_at(ms+3);
    assert(af_state==AF_IDLE && g_af_debug.reason==AF_REASON_I2C_ERROR && retries==1);
    puts("PASS mid-scan I2C failure restarts from a known position; retry budget covers the whole request");

    reset();start_scan();
    autofocus_restart();autofocus_task();assert(moves==1);
    poll_at(ms+3);assert(moves==1);
    poll_at(ms+197);assert(moves==2 && g_af_debug.requests==2);
    puts("PASS new AF request during a position write waits for completion before restarting");

    reset();regs[UI_LENS_STAT/4]=1;
    autofocus_restart();poll_at(999);assert(af_state==AF_START);
    poll_at(1000);assert(af_state==AF_IDLE && g_af_debug.reason==AF_REASON_TIMEOUT);
    reset();regs[UI_LENS_STAT/4]=0;
    autofocus_restart();autofocus_task();bus_pending=0;regs[UI_LENS_STAT/4]=0;
    poll_at(1000);assert(af_state==AF_IDLE && g_af_debug.reason==AF_REASON_TIMEOUT);
    puts("PASS stuck busy and never-initialized lens time out instead of hanging");

    reset();start_scan();poll_at(203);
    for(unsigned i=0;i<10000;i++) autofocus_task();
    assert(reads==0);
    poll_at(282);assert(reads==0);
    poll_at(283);assert(reads==1 && last_read_ms==283);
    poll_at(322);assert(reads==1);
    poll_at(323);assert(reads==2);
    poll_at(363);assert(reads==3 && moves==2);
    puts("PASS 80 ms after bus idle then 40 ms spacing; rapid SD callbacks cannot accelerate AF");

    reset();ms=0xfffffff0u;start_scan();
    poll_at(ms+3);poll_at(ms+79);assert(reads==0);
    poll_at(ms+1);assert(reads==1);
    finish(5);
    puts("PASS unsigned hardware-timer wrap and cooperative 5 ms service");

    reset();start_scan();
    /* gege 8f21399：细扫结束直接 autofocus_park()->AF_HOLD，AF_RETURN 已不可达；
     * 落点写入改由 park 内的 autofocus_command() 发出，失败仍须报 I2C_ERROR。 */
    for(unsigned i=0;i<20000 && af_state!=AF_HOLD && af_state!=AF_IDLE;i++) poll_at(ms+1);
    assert(af_state==AF_HOLD || af_state==AF_IDLE);
    move_fails=1;lens_diag_available=0;poll_at(ms+3);
    assert(af_state==AF_IDLE && g_af_debug.reason==AF_REASON_I2C_ERROR);
    puts("PASS final best-position write failure is not reported as focus completion");

    reset();start_scan();poll_at(ms+3);
    manual_focus_step(1);assert(af_state==AF_IDLE && g_af_debug.reason==AF_REASON_MANUAL);
    /* manual_focus_step() 走 AF_FINE_STEP（gege 由 64 改为 256），按宏断言。 */
    assert(regs[UI_LENS_POS/4]==AF_FINE_STEP);
    poll_at(ms+3);assert(moves==2);
    puts("PASS manual focus cancels queued/active AF");

    /* 本用例要验证的是"结果与循环节拍无关"，不是写死绝对次数：gege 把粗扫 512->2048、
     * 细扫 64->256，总线事务总数必然改变。改为以第一节拍为基准做一致性比较。 */
    unsigned base_reads=0,base_moves=0;
    for(unsigned cadence=1;cadence<=17;cadence+=4) {
        reset();autofocus_restart();finish(cadence);
        if(!base_reads) { base_reads=reads;base_moves=moves;assert(base_reads && base_moves); }
        else assert(reads==base_reads && moves==base_moves);
    }
    puts("PASS coarse/fine peak and sample count independent of 1/5/9/13/17 ms loop cadence");
}
