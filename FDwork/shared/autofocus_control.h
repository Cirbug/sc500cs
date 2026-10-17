#ifndef AUTOFOCUS_CONTROL_H
#define AUTOFOCUS_CONTROL_H

/* Included after the UI register helpers and lens diagnostics. The host test
 * supplies the same boundary with a timed lens model. No FPGA changes needed.
 * Samples are time spaced, NOT frame-tagged: the current APB metric has no
 * camera-frame sequence number. */
#define AF_POS_MAX        16383u
#define AF_COARSE_STEP      512u
#define AF_FINE_STEP         64u
#define AF_FINE_RADIUS      512u
#define AF_SETTLE_MS         80u
#define AF_SAMPLE_GAP_MS     40u
#define AF_SAMPLES            3u
#define AF_LENS_TIMEOUT_MS 1000u

enum { AF_START, AF_COARSE, AF_FINE, AF_IDLE, AF_RETURN, AF_RECOVER };
enum { AF_REASON_IDLE, AF_REASON_QUEUED, AF_REASON_WAIT_LENS,
       AF_REASON_RECOVER, AF_REASON_COARSE, AF_REASON_FINE,
       AF_REASON_RETURN, AF_REASON_DONE, AF_REASON_I2C_ERROR,
       AF_REASON_TIMEOUT, AF_REASON_MANUAL, AF_REASON_ROI_UNSUPPORTED,
       AF_REASON_MANUAL_REJECTED };

/* FD Expressions: requests counts recognized AF actions (not raw taps).
 * diag retains the I2C failure even if the one bounded retry succeeds. */
volatile struct {
    uint32_t requests, reason, lens_status, diag;
} g_af_debug;

static uint32_t af_state = AF_IDLE;
static uint32_t af_wait_ms, af_position, af_scan_end, af_scan_step;
static uint32_t af_best_position, af_best_metric, af_metric_sum, af_metric_count;
static uint8_t af_retried, af_move_pending;

static void autofocus_stop(uint32_t reason)
{
    af_state=AF_IDLE;
    g_af_debug.reason=reason;
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

static void autofocus_restart(void)
{
    /* Keep the request through startup, a background read or recovery. */
    ++g_af_debug.requests;
    g_af_debug.reason=AF_REASON_QUEUED;
    g_af_debug.diag=0;
    af_state=AF_START;
    af_wait_ms=ui_now_ms();
    af_retried=af_move_pending=0;
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
    position=delta>0 ? (position>=AF_POS_MAX-AF_FINE_STEP ? AF_POS_MAX : position+AF_FINE_STEP)
                     : (position<=AF_FINE_STEP ? 0u : position-AF_FINE_STEP);
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
        /* Recovery resets the lens to 8192: rescan instead of mixing samples
         * collected at different physical positions. */
        af_scan_end=AF_POS_MAX;
        af_scan_step=AF_COARSE_STEP;
        af_best_position=af_best_metric=0;
        af_state=AF_COARSE;
        autofocus_command(0);
        return;
    }
    if(af_move_pending) {
        /* Start the mechanical settling interval after observed bus idle. */
        af_move_pending=0;
        af_wait_ms=ms;
        return;
    }
    g_af_debug.reason=af_state==AF_RETURN ? AF_REASON_RETURN :
                      af_state==AF_COARSE ? AF_REASON_COARSE : AF_REASON_FINE;
    if(elapsed < (af_metric_count ? AF_SAMPLE_GAP_MS : AF_SETTLE_MS)) return;
    if(af_state==AF_RETURN) {
        autofocus_stop(AF_REASON_DONE);
        return;
    }
    metric=ui_read(UI_FOCUS_METRIC);
    af_metric_sum+=metric;
    ++af_metric_count;
    af_wait_ms=ms;
    if(af_metric_count<AF_SAMPLES) return;
    metric=af_metric_sum/AF_SAMPLES;
    focus_plot(af_position,metric,status);
    if(metric>af_best_metric) {af_best_metric=metric;af_best_position=af_position;}
    if(af_position>=af_scan_end) {
        if(af_state==AF_COARSE) {
            af_scan_end=af_best_position+AF_FINE_RADIUS;
            if(af_scan_end>AF_POS_MAX) af_scan_end=AF_POS_MAX;
            af_scan_step=AF_FINE_STEP;
            af_state=AF_FINE;
            next=af_best_position>AF_FINE_RADIUS ? af_best_position-AF_FINE_RADIUS : 0u;
        } else {
            next=af_best_position;
            af_state=AF_RETURN;
        }
    } else {
        next=af_position+af_scan_step;
        if(next>af_scan_end) next=af_scan_end;
    }
    autofocus_command(next);
}
#endif
