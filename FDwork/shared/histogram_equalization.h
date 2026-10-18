#ifndef HISTOGRAM_EQUALIZATION_H
#define HISTOGRAM_EQUALIZATION_H
/* HEQ1 APB peripheral. No framebuffer, heap allocation or polling wait loop.
 * Each service call performs at most 16 histogram reads/LUT writes. */
#define HE_BASE 0x3000u
#define HE_ID 0x48455131u
#define HE_INTERVAL_MS 250u
#define HE_BATCH 16u
static uint8_t he_lut[256];
static uint32_t he_index,he_cdf,he_min,he_total,he_last_ms;
static unsigned he_mode,he_state,he_history;
volatile struct {uint32_t updates,samples,state,status;} g_he_debug;

static uint8_t he_mapping(unsigned i,uint32_t cdf,uint32_t first,uint32_t total,unsigned mode)
{
    uint32_t denominator=total-first;
    unsigned value=denominator ? (cdf>first ? ((cdf-first)*255u+denominator/2u)/denominator : 0u) : i;
    return (uint8_t)(mode==1 ? (value+i+1u)/2u : value);
}
static void histogram_poll(MenuState *s)
{
    unsigned n,status,mode=s->histogram_mode;
    uint32_t now;
    if(!s->histogram_available)return;
    now=ui_now_ms();
    status=ui_read(HE_BASE+4);g_he_debug.status=status;
    if(mode!=he_mode) {
        he_mode=mode;he_state=0;he_history=0;he_last_ms=now-HE_INTERVAL_MS;
        ui_write(HE_BASE+0x1c,0);
    }
    if(!mode)return;
    if(status&16u) {
        if(!(status&2u)) {ui_write(HE_BASE+0x10,0);he_state=0;he_history=0;}
        return;
    }
    g_he_debug.state=he_state;
    switch(he_state) {
    case 0:
        if((status&3u) || now-he_last_ms<HE_INTERVAL_MS)return;
        ui_write(HE_BASE+8,1);he_state=1;break;
    case 1:
        if((status&1u) || !(status&4u))return;
        he_total=ui_read(HE_BASE+8);g_he_debug.samples=he_total;
        if(!he_total || he_total>32400u) {he_state=0;he_last_ms=now;return;}
        he_index=0;he_state=2;break;
    case 2:
        // Find CDF_min without a second MCU histogram buffer. Hardware holds it.
        for(n=0;n<HE_BATCH && he_index<256;n++,he_index++) {
            he_min=ui_read(HE_BASE+0x400u+4u*he_index);
            if(he_min) {
                he_cdf=0;he_index=0;he_state=3;
                ui_write(HE_BASE+0x10,0);break;
            }
        }
        if(he_index==256) {he_state=0;he_last_ms=now;}
        break;
    case 3:
        for(n=0;n<HE_BATCH && he_index<256;n++,he_index++) {
            unsigned value;
            he_cdf+=ui_read(HE_BASE+0x400u+4u*he_index);
            value=he_mapping(he_index,he_cdf,he_min,he_total,mode);
            if(he_history)value=(3u*he_lut[he_index]+value+2u)/4u;
            he_lut[he_index]=(uint8_t)value;
            ui_write(HE_BASE+0x14,value);
        }
        if(he_index==256) {ui_write(HE_BASE+0x18,1);he_state=4;}
        break;
    case 4:
        if((status&2u) || !(status&8u))return;
        ui_write(HE_BASE+0x1c,1);
        he_history=1;he_last_ms=now;he_state=0;++g_he_debug.updates;
        break;
    }
}
#endif
