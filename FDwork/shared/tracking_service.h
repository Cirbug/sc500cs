#ifndef TRACKING_SERVICE_H
#define TRACKING_SERVICE_H

/* ---------------------------------------------------------------------------
 * 在菜单里选中"追踪红色/蓝色/绿色"的那一刻，自动开始对焦。
 *
 * 为什么要"进档就对"、而不是"等锁定了再对"：
 *   伺服的锁定门限是 ACQUIRE_MIN = 画面的 5%（约 323x323 px）。比这小的目标
 *   永远锁不上 —— 如果等 locked 才对焦，小目标就永远不对焦。所以进挡立刻对一次。
 *
 * 对焦区域怎么定：
 *   ① 进档后先等目标锁定（最多 1 秒）—— 锁上了就用目标位置：
 *          质心 X = 960 + error_x     质心 Y = 540 + error_y
 *      跟踪邮箱里没有包围盒，但这两个偏移就够定位了。
 *   ② 1 秒内没锁上（目标太小或画面里没有）就对画面中心，保证"点了就开始对"。
 *   写进 0x94（focus_metric 的 ROI，bit31 是有效标志），FPGA 的 0x34 读回的清晰度
 *   就只统计这一小块，于是对焦扫描朝着"这一块最清楚"走。
 *
 * 之后每个新目标再对一次（目标丢失 >2 秒才算新目标，外加 3 秒冷却防拉风箱）。
 * --------------------------------------------------------------------------- */
static uint32_t g_af_entry_ms;     /* 进追踪档的时刻 */
static uint8_t  g_af_mode_prev;    /* 上一轮是否在追踪档 */
static uint8_t  g_af_lock_done;    /* 本次进档已经扫过了 */
static uint8_t  g_af_ever_focused; /* 本次进档是否已经对过焦 */
static int32_t  g_roi_x=-1, g_roi_y=-1;   /* 上次写进 0x94 的区域中心 */

/* ---- 对焦框自动隐藏 ----------------------------------------------------
 * ui_osd 靠 0x94 的 bit31 决定画不画那个绿框；而 focus_metric **根本不看这一位**
 * —— 它只用框的位置和 0xfc 的尺寸。所以"把框藏起来"只要把 bit31 清掉：
 * 清晰度统计的窗口一点没变，阈值重对焦照常工作，只是屏幕上干净了。
 * 规则：正在扫描时一直亮，扫完/触摸后 AF_BOX_SHOW_MS 之内还亮，之后自动藏。
 * （现场要求："这个绿色的框能不能过一会直接消失掉"。） */
#define AF_BOX_SHOW_MS 3000u
/* 最近一次写进 0x94 的整字 —— 藏框时要原样写回（只清 bit31），
 * 所以必须记住它，不能在隐藏时自己重新算位置。初值 = APB 复位值。 */
static uint32_t g_roi_word = 0x01e00370u;
static uint32_t g_af_box_until;     /* 绿框显示到这个时刻 */
static uint8_t  g_af_box_on;

/* 所有对 0x94 的写入都走这里，顺便记住位置 */
static void af_roi_write_word(uint32_t w)
{
    g_roi_word=w;
    ui_write(0x94, g_af_box_on ? (w|0x80000000u) : (w&0x7fffffffu));
}

/* 点亮（并延长显示时间）。写位置之前先调它，这一次写入才会带 bit31。 */
static void af_roi_box_show(unsigned hold_ms)
{
    g_af_box_on=1;
    g_af_box_until=ui_now_ms()+hold_ms;
    af_roi_write_word(g_roi_word);
}

/* 到点就藏。扫描期间一直续期，所以整个对焦过程框都在。 */
static void af_roi_box_tick(void)
{
    if(autofocus_active()) {
        g_af_box_on=1;
        g_af_box_until=ui_now_ms()+AF_BOX_SHOW_MS;
        return;
    }
    if(g_af_box_on && (int32_t)(ui_now_ms()-g_af_box_until)>=0) {
        g_af_box_on=0;
        af_roi_write_word(g_roi_word);      /* 只清 bit31，窗口原地不动 */
    }
}

/* 追踪时用的对焦窗口尺寸（APB 0xfc）。
 * 160x120 是 focus_metric 的默认值，遇到"比窗口大的目标"时**整个窗口落在目标
 * 内部**——现场那块红晕约 430x467，窗口里全是平的红，测不到任何边缘，清晰度
 * 曲线变成一条水平线，对焦就永远找不到峰值（现场就是"一直对不上焦"）。
 * 960x720 能把这个量级的目标连同它的边缘一起包住。 */
#define TRACK_AF_W 960u
#define TRACK_AF_H 720u

/* 设置对焦窗口尺寸。w=h=0 表示"用默认 160x120"（退出追踪档时还原，
 * 这样触摸对焦还是原来的行为）。 */
static void af_roi_size(unsigned w,unsigned h)
{
    ui_write(0xfc,(((unsigned)h&0x7ffu)<<16)|((unsigned)w&0x7ffu));
}

/* 写 ROI 位置。注意 0x94 里存的是**左上角**，而 touch_focus_roi() 是按固定的
 * 160x120 扣偏移的 —— 尺寸一变那个偏移就不对了，所以这里按中心点自己算。 */
static void af_roi_write(int cx,int cy)
{
    int ox,oy;
    ox=cx-(int)(TRACK_AF_W/2); oy=cy-(int)(TRACK_AF_H/2);
    if(ox<0)ox=0; if(oy<0)oy=0;
    if(ox>(int)(1920u-TRACK_AF_W))ox=(int)(1920u-TRACK_AF_W);
    if(oy>(int)(1080u-TRACK_AF_H))oy=(int)(1080u-TRACK_AF_H);
    af_roi_write_word(0x80000000u|((unsigned)oy<<16)|(unsigned)ox);
}

/* 目标移动时让对焦区域跟着走。
 * 不跟的话：对焦完成后伺服会把目标拉到画面中心，而 ROI 还停在老位置
 * （那里现在是背景），清晰度自然掉下去，AF_HOLD 就会误判成"失焦"反复重爬。 */
static void tracking_roi_follow(uint32_t errors)
{
    int cx,cy;
    if(autofocus_active()) return;                  /* 正在扫描，别动 ROI */
    cx=960+red_track_error(errors);
    cy=540+red_track_error(errors>>16);
    if(cx<0)cx=0; else if(cx>1919)cx=1919;
    if(cy<0)cy=0; else if(cy>1079)cy=1079;
    if(g_roi_x>=0 &&
       touch_distance((unsigned)cx,(unsigned)g_roi_x)<=48u &&
       touch_distance((unsigned)cy,(unsigned)g_roi_y)<=48u) return;   /* 没怎么动就不写 */
    g_roi_x=cx; g_roi_y=cy;
    if(ui_read(0x98)!=0x41465231u) return;          /* AFR1 */
    /* 每次都把尺寸一起写：触摸对焦会把尺寸清成默认，这里负责恢复，
     * 保证"尺寸"和下面这个"位置"永远是配套的。 */
    af_roi_size(TRACK_AF_W,TRACK_AF_H);
    af_roi_write(cx,cy);
}

static void af_focus_at(int cx, int cy)
{
    if(ui_read(0x98)!=0x41465231u) return;              /* AFR1：没有 ROI 支持就别动 */
    if(cx<0) cx=0; else if(cx>1919) cx=1919;
    if(cy<0) cy=0; else if(cy>1079) cy=1079;
    af_roi_box_show(AF_BOX_SHOW_MS);                    /* 扫描期间框要亮着 */
    af_roi_write(cx,cy);
    autofocus_restart();
    g_af_lock_done=1;
}

static void tracking_autofocus(const MenuState *s,uint32_t word,uint32_t errors,uint32_t ms)
{
    unsigned has_target;
    if(g_track_capability!=RED_TRACK_ID) return;
    if(!tracking_mode(s)) {                             /* 退出追踪档，清状态 */
        g_af_mode_prev=0;
        g_af_lock_done=0;
        g_af_ever_focused=0;
        g_roi_x=g_roi_y=-1;
        af_roi_size(0,0);                               /* 还原成默认 160x120 */
        return;
    }
    /* word[15]=enable word[14]=valid：只要这一帧报出有效目标就用它的位置，
     * **不要求已经"锁定"** —— 锁定的门限是画面 5%，小目标永远锁不上，
     * 原来那样会退化成"对画面中心"，等于对到背景上，所以现场会"有时候对不上焦"。 */
    has_target=((word & 0xc000u)==0xc000u);

    if(!g_af_mode_prev) {                               /* 进档边沿：重新武装 */
        g_af_mode_prev=1;
        g_af_entry_ms=ms;
        g_af_lock_done=0;
        g_af_ever_focused=0;
        af_roi_size(TRACK_AF_W,TRACK_AF_H);             /* 换成大窗口 */
        af_roi_box_show(AF_BOX_SHOW_MS);
    }
    if(g_af_lock_done) {
        /* 已经对过一次了：**从此不再自动对焦**，只让对焦区域跟着目标走。
         * 现场结论：与其在目标闪烁时反复重扫（上一版加了"目标消失 2 秒就
         * 重新武装"，目标一抖就会再来一轮 4 秒的全扫），不如就停在已经对好的
         * 位置上。想重新对焦有三个入口，都走 MENU_AF：
         *   ① 再点一次那个追踪档（进档边沿会重新武装）
         *   ② 菜单关着时按硬件 OK 键
         *   ③ 双击画面（触摸对焦）
         */
        if(has_target) tracking_roi_follow(errors);
        return;
    }
    if(has_target) {                                    /* 有目标：对着它扫一遍 */
        af_focus_at(960+red_track_error(errors),540+red_track_error(errors>>16));
        g_af_ever_focused=1;
    } else if(!g_af_ever_focused && (uint32_t)(ms-g_af_entry_ms)>1000u) {
        af_focus_at(960,540);                           /* 进档后 1 秒没目标：对中心扫一次 */
        g_af_ever_focused=1;
    }
}

/* MCU hardware boundary, included after autofocus_control.h and UI helpers.
 * Both the main loop and cooperative SD service use this same arbitration. */
static void tracking_service(MenuState *s)
{
    af_roi_box_tick();              /* 对焦框到点自动隐藏（每轮都跑，任何档位都管） */
    if(autofocus_active()) {
        /* Leave PWM targets untouched. Forget queued camera feedback so that
         * resume requires a fresh result and the normal 200 ms acquisition. */
        g_track_control.primed=0;
        g_track_control.reason=TRACK_FOCUS;
        return;
    }
    uint32_t word=0,errors=0;
    if(g_track_capability==RED_TRACK_ID) {
        unsigned attempt;
        /* status/errors/status: both axes must belong to the same result.
         * Retry once, then hold; never spin waiting for the camera. */
        for(attempt=0;attempt<2;++attempt) {
            word=ui_read(UI_TRACK_STATUS);
            errors=ui_read(UI_TRACK_ERRORS);
            if(word==ui_read(UI_TRACK_STATUS)) break;
        }
        if(attempt==2) {
            g_track_control.primed=0;g_track_control.reason=TRACK_STALE;
            return;
        }
    }
    /* 锁定目标就自动对一次焦（不依赖触摸） */
    tracking_autofocus(s,word,errors,ui_now_ms());
    unsigned changed=red_track_update(&g_track_control,word,errors,
        ui_now_ms(),
        /* 三个追踪档都要能闭环：5=追踪红色 6=追踪蓝色 7=追踪绿色。
         * 这里原来写死 ==5，结果绿/蓝档选得上、框也画，但伺服不动。 */
        g_track_capability==RED_TRACK_ID && s->servo_menu_available && tracking_mode(s),
        s->servo_touch_active!=0, &g_track_config, &s->servo_pan_us, &s->servo_tilt_us);
    if(changed&1u) ui_write(UI_SERVO_PAN_US,s->servo_pan_us);
    if(changed&2u) ui_write(UI_SERVO_TILT_US,s->servo_tilt_us);
}
#endif