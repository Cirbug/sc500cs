#ifndef AUTOFOCUS_CONTROL_H
#define AUTOFOCUS_CONTROL_H

/* 全程粗扫 + 峰值附近细扫（现场要求的策略）
 *
 * 演进过程，别再走回头路：
 *   ① 最早：粗扫全行程(512 步, 32 点) + 细扫峰值±512(64 步, 17 点) ≈ 10 秒 —— 太慢
 *   ② 改成爬山：2 秒，但**不可靠** —— 起始方向是盲选的、清晰度曲线有噪声，
 *      会卡在局部峰或者被单次抖动带偏；现场"有时候对不上焦"就是这么来的
 *   ③ 现在：全程粗扫 + 附近细扫。慢一点(≈4 秒)但**每次都能找到全局峰**，
 *      而且只在"目标出现/重新出现"时扫一次，不是一直扫。
 *
 * 参数怎么定的：
 *   粗扫 0..16383 步长 2048 → 9 个点，覆盖全程；粗扫的不确定度就是 ±2048。
 *   细扫 峰值±2048 步长 256 → 最多 17 个点，正好把粗扫的不确定度吃干净，
 *   最终分辨率 256 计数。按音圈全行程约 300um/16384 计数折算，256 计数 ≈ 5um，
 *   比景深小一个量级，够用。
 *   每个点：稳定 80ms + 3 次采样(间隔 40ms) = 160ms。
 *   合计 (9+17) × 160ms ≈ 4.2 秒。
 *
 * 扫完之后就停在峰值上不动了（AF_HOLD），**不再周期重扫**。
 * 目标消失后由 tracking_service.h 重新武装，下次目标出现再扫一遍。
 *
 * 曲线保护：如果整条曲线的峰谷差不到 12.5%（对着没有纹理的色块就是这种），
 * 说明这个场景没有可用信息 —— 与其停在噪声选出来的点上，不如把镜头放回
 * 开始扫描前的位置。
 *
 * 注意：AF_HOLD **不算"正在对焦"**（autofocus_active() 为假），
 * 否则 tracking_service() 会一直提前返回，颜色追踪的伺服就永远不动了。
 *
 * 采样是时间间隔的，不带帧序号：当前 APB 的 metric 没有相机帧号。
 */
#define AF_POS_MAX           16383u
#define AF_COARSE_STEP        2048u   /* 粗扫步长（全程 9 个点） */
#define AF_FINE_STEP           384u   /* 细扫步长（原 256，改 384 把下面的时间省回来） */
#define AF_FINE_RADIUS        2048u   /* 细扫范围 = 粗扫步长（覆盖粗扫的不确定度） */
/* 稳定时间 80ms -> 160ms（2026-10-27 采纳 gege 的现场复盘）。
 * **这是“有时候找不到对焦点”的主要结构性原因**：视频链路（相机曝光 + MIPI/DDR +
 * 显示）本身有 100~150ms 延迟，所以写完位置过 80ms 时，画面里还是**上一个位置**的
 * 图像 —— 采样采到的是别人家的清晰度，整条曲线的点都串位、峰被抹掉，最后只能挑到
 * 噪声。160ms 稳稳盖住这段延迟，采到的才是“这个位置”的画面。
 * 注意：160ms 必须与下面的 AF_SAMPLES=2、AF_FINE_STEP=384 一起改 —— 只改稳定时间
 * 会让每轮扫描从约 4 秒变成约 9.6 秒。 */
#define AF_SETTLE_MS           160u
#define AF_SAMPLE_GAP_MS        40u   /* 同一位置两次采样的间隔 */
/* 3 -> 2：稳定时间加长以后，不需要靠多采样硬扛抖动；
 * 每个扫描点用时 160+40 = 200ms，点数 9+11 = 20 -> 合计约 4.0 秒（和原来一样快）。 */
#define AF_SAMPLES               2u
/* 手动对焦每按一下走的步数。原来借用 AF_FINE_STEP（256），按满全程要 64 下，
 * 现场做“手动扫一遍看看到底有没有清楚的位置”这个判定太累。1024 -> 16 下。 */
#define AF_MANUAL_STEP         1024u
#define AF_FLAT_DIV              8u    /* 峰谷差 < 峰值/8 就算"曲线太平" */
/* 停在峰值之后的重对阈值（现场要求："简单弄个阈值，超过就重新对焦"）。
 * 掉到峰值的 60% 以下才算真失焦；单次采样本来就有抖动，阈值太松会一直重对。
 * 两次自动重对至少隔 15 秒，防止在"刚好卡在阈值上"的场景里反复来回。 */
#define AF_REFOCUS_PCT          60u
#define AF_REFOCUS_MIN_MS    15000u
#define AF_RECHECK_MS         2000u   /* 停在峰值上时每隔这么久看一眼 */
#define AF_LENS_TIMEOUT_MS    1000u
#define AF_GIMBAL_SETTLE_MS    200u

/* AF_HOLD 追加在最后：af_state 只在固件内部用，不对外暴露，
 * 所以编号变化没有兼容问题。 */
enum { AF_START, AF_COARSE, AF_FINE, AF_IDLE, AF_RETURN, AF_RECOVER, AF_HOLD };
/* 原有取值一个都不改，只往后追加，免得 FD Expressions 里的数字错位。
 *   4=COARSE 5=FINE 7=DONE 13=WAIT_GIMBAL 14=HOLD 16=FLAT 18=PEAK_END */
enum { AF_REASON_IDLE, AF_REASON_QUEUED, AF_REASON_WAIT_LENS,
       AF_REASON_RECOVER, AF_REASON_COARSE, AF_REASON_FINE,
       AF_REASON_RETURN, AF_REASON_DONE, AF_REASON_I2C_ERROR,
       AF_REASON_TIMEOUT, AF_REASON_MANUAL, AF_REASON_ROI_UNSUPPORTED,
       AF_REASON_MANUAL_REJECTED, AF_REASON_WAIT_GIMBAL,
       AF_REASON_HOLD, AF_REASON_SEEK, AF_REASON_FLAT, AF_REASON_REFOCUS,
       /* 18：最高点落在行程两端 —— 峰在行程外面（镜头/机芯够不到），串口 AFDONE 会报 18 */
       AF_REASON_PEAK_END };

/* FD Expressions: requests counts recognized AF actions (not raw taps).
 * diag retains the I2C failure even if the one bounded retry succeeds. */
volatile struct {
    uint32_t requests, reason, lens_status, diag;
} g_af_debug;

static uint32_t af_state = AF_IDLE;
static uint32_t af_wait_ms, af_position, af_scan_end, af_scan_step;
static uint32_t af_best_position, af_best_metric, af_min_metric;
static uint32_t af_metric_sum, af_metric_count;
static uint32_t af_start_position;      /* 开始扫描前的镜头位置，供"曲线太平"回退用 */
static uint32_t af_last_focus_ms;       /* 上次扫完停下的时刻，供重对冷却用 */
static uint32_t af_hold_ms;             /* 停在峰值后上次"看一眼"的时刻 */
static uint8_t af_retried, af_move_pending, af_no_refocus;

/* 徘徊不算"正在对焦"：这样 tracking_service() 才能在镜头不动的时候照常跟目标 */
static int autofocus_active(void) { return af_state!=AF_IDLE && af_state!=AF_HOLD; }

static void autofocus_stop(uint32_t reason)
{
    af_state=AF_IDLE;
    g_af_debug.reason=reason;
    /* 2026-10-27：放弃也要打一行。以前因 I2C 错误放弃时一行都不打，
     * 现场看串口会以为“对焦请求根本没生效”，其实是镜头没应答。
     * 8=I2C_ERROR 9=TIMEOUT 10=MANUAL 11=ROI_UNSUPPORTED 12=MANUAL_REJECTED */
    al_printf("AFSTOP:%u\\r\\n",reason);
}

static void autofocus_command(uint32_t position)
{
    af_position=position & AF_POS_MAX;
    ui_write(UI_LENS_POS,af_position);
    ui_write(UI_LENS_CMD,1u);
    af_wait_ms=ui_now_ms();
    af_move_pending=1;
    af_metric_sum=af_metric_count=0;
}

/* 停在峰值上。曲线太平就退回"开始扫描前的位置"（见文件头说明）。
 * 曲线太平时顺便关掉自动重对 —— 否则会陷入"每 15 秒重扫一遍、每次都判定
 * 太平、镜头来回跑"的循环。想再对焦只能手动触发。 */
static void autofocus_park(uint32_t ms, uint32_t reason)
{
    /* 最高点落在行程两端 -> 峰在行程**外面**（镜头/机芯够不到这个距离），再怎么搜
     * 也没用，单独报出来（串口 AFDONE 最后那个数会是 18）。
     * 注意这里多一个保护条件：**全无纹理**时所有 metric 都是 0、af_best_position
     * 从未被刷新（停在初值 0），若照搬 gege 的原逻辑会被判成 PEAK_END、把镜头开到
     * 行程端并且不关重对。加了“确实存在峰”这个条件后，那种情形继续走下面的 FLAT
     * 处理（退回原位 + 关重对），更安全。 */
    if((af_best_position==0u || af_best_position>=AF_POS_MAX) &&
       af_best_metric > af_min_metric + (af_min_metric>>AF_FLAT_DIV)) {
        g_af_debug.reason=AF_REASON_PEAK_END;
        af_last_focus_ms=ms; af_hold_ms=ms; af_state=AF_HOLD;
        autofocus_command(af_best_position);
        al_printf("AFDONE:%u,%u,%u\\r\\n",af_best_position,af_best_metric,g_af_debug.reason);
        return;
    }
    if(af_best_metric <= af_min_metric + (af_min_metric>>AF_FLAT_DIV)) {
        af_best_position=af_start_position;
        af_no_refocus=1;
        g_af_debug.reason=AF_REASON_FLAT;
    } else {
        g_af_debug.reason=reason;
    }
    af_last_focus_ms=ms;
    af_hold_ms=ms;
    af_state=AF_HOLD;
    autofocus_command(af_best_position);
    /* 落点单独打一行，带 reason，便于和扫描过程中的 AF: 行对照：
     * 14=HOLD（正常停住） 16=FLAT（曲线太平，已退回原位） */
    al_printf("AFDONE:%u,%u,%u\r\n",af_best_position,af_best_metric,g_af_debug.reason);
}

static void autofocus_restart(void)
{
    /* Keep the request through startup, a background read or recovery. */
    ++g_af_debug.requests;
    g_af_debug.reason=AF_REASON_QUEUED;
    g_af_debug.diag=0;
    af_state=AF_START;
    af_wait_ms=ui_now_ms();
    af_retried=af_move_pending=0;
    af_no_refocus=0;                    /* 手动/进档触发的对焦，重新允许阈值重对 */
}

static void manual_focus_step(int32_t delta)
{
    uint32_t status=ui_read(UI_LENS_STAT);
    uint32_t position=ui_read(UI_LENS_POS) & AF_POS_MAX;
    autofocus_stop(AF_REASON_MANUAL);
    g_af_debug.lens_status=status;
    if((status & 7u)!=2u) {
        g_af_debug.reason=AF_REASON_MANUAL_REJECTED;
        lens_diag_report();
        return;
    }
    position=delta>0 ? (position>=AF_POS_MAX-AF_MANUAL_STEP ? AF_POS_MAX : position+AF_MANUAL_STEP)
                     : (position<=AF_MANUAL_STEP ? 0u : position-AF_MANUAL_STEP);
    ui_write(UI_LENS_POS,position);
    ui_write(UI_LENS_CMD,1u);
    focus_plot(position,ui_read(UI_FOCUS_METRIC),status);
}

static void autofocus_task(void)
{
    uint32_t status,ms,elapsed,metric,next;
    if(af_state==AF_IDLE) return;
    ms=ui_now_ms();
    elapsed=ms-af_wait_ms;
    status=ui_read(UI_LENS_STAT);
    g_af_debug.lens_status=status;
    /* Allow the APB retry pulse to reach the controller before interpreting
     * its previous error bit as a failure of the new initialization. */
    if(af_state==AF_RECOVER && elapsed<2u) return;
    if(status & 1u) {
        g_af_debug.reason=AF_REASON_WAIT_LENS;
        if(elapsed>=AF_LENS_TIMEOUT_MS) autofocus_stop(AF_REASON_TIMEOUT);
        return;
    }
    if((status & 6u)!=2u) {
        if(status & 4u) g_af_debug.diag=ui_read(UI_LENS_DIAG);
        if(af_state==AF_RECOVER && !(status & 4u)) {
            if(elapsed>=AF_LENS_TIMEOUT_MS) autofocus_stop(AF_REASON_TIMEOUT);
            return;
        }
        if(lens_diag_available!=3u || af_retried) {
            autofocus_stop(AF_REASON_I2C_ERROR);
            return;
        }
        af_retried=1;
        af_state=AF_RECOVER;
        af_wait_ms=ms;
        g_af_debug.reason=AF_REASON_RECOVER;
        ui_write(UI_LENS_POS,8192u);
        ui_write(UI_LENS_CMD,2u);
        return;
    }
    if(af_state==AF_START || af_state==AF_RECOVER) {
        /* 自动追踪已经从"请求受理"那一步起被挡住。保持当前云台目标，
         * 先让云台稳下来再开始扫。恢复流程也在这里等，快速重试不能绕过。 */
        if(elapsed<AF_GIMBAL_SETTLE_MS) {
            g_af_debug.reason=AF_REASON_WAIT_GIMBAL;
            return;
        }
        /* 记下"开始扫描前的位置"：曲线太平时要退回这里。
         * 恢复流程刚把镜头复位到 8192，就从那里算起。 */
        af_start_position = (af_state==AF_RECOVER) ? 8192u:(ui_read(UI_LENS_POS)&AF_POS_MAX);
        af_scan_end   = AF_POS_MAX;         /* 全程扫：0 .. AF_POS_MAX */
        af_scan_step  = AF_COARSE_STEP;
        af_best_metric= 0u;
        af_min_metric = 0xffffffffu;
        af_state=AF_COARSE;
        autofocus_command(0u);              /* 从行程 0 端开始 */
        return;
    }
    if(af_move_pending) {
        /* Start the mechanical settling interval after observed bus idle. */
        af_move_pending=0;
        af_wait_ms=ms;
        return;
    }
    /* ---- AF_HOLD：已经对好了。**不做任何扫描**，只按阈值看一眼 ----
     * 镜头停着不动；清晰度掉到峰值的 AF_REFOCUS_PCT% 以下，而且距上次对焦
     * 够久，才重新走一遍全程粗扫+细扫。单次采样有抖动，所以阈值取 60% 而不是
     * 卡在峰值附近；曲线太平的场景在 autofocus_park 里已经把自动重对关掉了。 */
    if(af_state==AF_HOLD) {
        if(af_no_refocus) return;
        if((uint32_t)(ms-af_hold_ms)<AF_RECHECK_MS) return;
        if(elapsed < (af_metric_count ? AF_SAMPLE_GAP_MS : AF_SETTLE_MS)) return;
        metric=ui_read(UI_FOCUS_METRIC);
        af_metric_sum+=metric;
        ++af_metric_count;
        af_wait_ms=ms;
        if(af_metric_count<AF_SAMPLES) return;
        metric=af_metric_sum/AF_SAMPLES;
        af_hold_ms=ms;
        g_af_debug.reason=AF_REASON_HOLD;
        if(metric>af_best_metric) {
            af_best_metric=metric;                  /* 变得更清楚：更新基准 */
        } else if(metric*100u < af_best_metric*AF_REFOCUS_PCT &&
                  (uint32_t)(ms-af_last_focus_ms)>=AF_REFOCUS_MIN_MS) {
            g_af_debug.reason=AF_REASON_REFOCUS;
            autofocus_restart();                    /* 掉太多：重新全程扫一遍 */
        }
        return;
    }
    g_af_debug.reason = (af_state==AF_FINE) ? AF_REASON_FINE :
                        (af_state==AF_RETURN)? AF_REASON_RETURN : AF_REASON_COARSE;
    if(elapsed < (af_metric_count ? AF_SAMPLE_GAP_MS : AF_SETTLE_MS)) return;
    metric=ui_read(UI_FOCUS_METRIC);
    af_metric_sum+=metric;
    ++af_metric_count;
    af_wait_ms=ms;
    if(af_metric_count<AF_SAMPLES) return;
    metric=af_metric_sum/AF_SAMPLES;
    focus_plot(af_position,metric,status);
    if(metric>af_best_metric) {af_best_metric=metric;af_best_position=af_position;}
    if(metric<af_min_metric)    af_min_metric=metric;
    if(af_position>=af_scan_end) {
        if(af_state==AF_COARSE) {
            /* 粗扫完 → 在峰值附近细扫 */
            af_scan_end = af_best_position+AF_FINE_RADIUS;
            if(af_scan_end>AF_POS_MAX) af_scan_end=AF_POS_MAX;
            af_scan_step=AF_FINE_STEP;
            af_state=AF_FINE;
            next = af_best_position>AF_FINE_RADIUS ? af_best_position-AF_FINE_RADIUS : 0u;
        } else {
            autofocus_park(ms,AF_REASON_DONE);      /* 细扫完 → 停在峰值 */
            return;
        }
    } else {
        next=af_position+af_scan_step;
        if(next>af_scan_end) next=af_scan_end;
    }
    autofocus_command(next);
}
#endif