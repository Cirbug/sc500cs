#ifndef TOUCH_FOCUS_H
#define TOUCH_FOCUS_H
#include "menu_input.h"

/* Milliseconds from the hardware timer, not main-loop iterations. A tap is
 * committed on release; moving away and back is still a drag. */
typedef struct {
    uint32_t down_ms, up_ms;
    uint16_t x, y, last_x, last_y;
    uint8_t down, pending, second;
} TouchFocus;
static inline unsigned touch_distance(unsigned a, unsigned b) {
    return a>b ? a-b : b-a;
}
static inline unsigned touch_focus(TouchFocus *g, const TouchEvent *e,
                                   uint32_t ms, int blocked)
{
    if(e->type==TOUCH_CANCEL || blocked) {
        g->down=g->pending=g->second=0; return 0;
    }
    if(e->type==TOUCH_DOWN) {
        g->second=g->pending && ms-g->up_ms<=350u &&
            touch_distance(e->x,g->last_x)<=48u &&
            touch_distance(e->y,g->last_y)<=48u;
        g->pending=0; g->down=1; g->down_ms=ms; g->x=e->x; g->y=e->y;
        return 0;
    }
    if(!g->down) return 0;
    if(ms-g->down_ms>250u || touch_distance(e->x,g->x)>16u ||
       touch_distance(e->y,g->y)>16u) {
        g->down=g->pending=g->second=0; return 0;
    }
    if(e->type!=TOUCH_UP) return 0;
    g->down=0;
    if(g->second) {g->second=0; return MENU_AF;}
    g->pending=1;g->up_ms=ms;g->last_x=g->x;g->last_y=g->y;
    return 0;
}
/* 160x120 rectangle, kept entirely within the 1920x1080 panel. */
static inline uint32_t touch_focus_roi(unsigned x, unsigned y) {
    x=x<80u?0u:x>1840u?1760u:x-80u;
    y=y<60u?0u:y>1020u?960u:y-60u;
    return 0x80000000u | (y<<16) | x;
}
#endif