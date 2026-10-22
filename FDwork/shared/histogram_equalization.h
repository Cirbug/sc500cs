#ifndef HISTOGRAM_EQUALIZATION_H
#define HISTOGRAM_EQUALIZATION_H
/* HEQ1 APB peripheral. No framebuffer, heap allocation or polling wait loop.
 * Each service call performs at most 16 histogram reads/LUT writes. */
#define HE_BASE 0x3000u
#define HE_ID 0x48455131u
#define HE_INTERVAL_MS 250u
#define HE_BATCH 16u
/* min/total are count bounds for CDF; AUTO reuses them as luma bounds once
 * its percentile scan is complete. Keep state together for compact accesses
 * in the 48 KiB TCM; no extra histogram or scratch buffer is allocated. */
static struct {
    uint32_t index,cdf,min,total,last_ms,mode,state,history;
    uint8_t lut[256];
} he;
volatile struct {uint32_t updates,samples,state,status;} g_he_debug;

static uint8_t he_mapping(unsigned i,uint32_t cdf,uint32_t first,uint32_t total,unsigned mode)
{
    uint32_t denominator=total-first;
    unsigned value=denominator ? (cdf>first ? ((cdf-first)*255u+denominator/2u)/denominator : 0u) : i;
    if(value>255u)value=255u;
    return (uint8_t)(mode==1 ? (value+i+1u)/2u : value);
}
static void histogram_poll(MenuState *s)
{
    unsigned n,status,mode=s->histogram_mode;
    uint32_t now;
    if(!s->histogram_available)return;
    now=ui_now_ms();
    status=ui_read(HE_BASE+4);g_he_debug.status=status;
    if(mode!=he.mode) {
        he.mode=mode;he.state=0;he.history=0;he.last_ms=now-HE_INTERVAL_MS;
        ui_write(HE_BASE+0x1c,0);
    }
    if(!mode)return;
    if(status&16u) {
        if(!(status&2u)) {ui_write(HE_BASE+0x10,0);he.state=0;he.history=0;}
        return;
    }
    g_he_debug.state=he.state;
    switch(he.state) {
    case 0:
        if((status&3u) || now-he.last_ms<HE_INTERVAL_MS)return;
        ui_write(HE_BASE+8,1);he.state=1;break;
    case 1:
        if((status&1u) || !(status&4u))return;
        he.total=ui_read(HE_BASE+8);g_he_debug.samples=he.total;
        if(!he.total || he.total>32400u) {he.state=0;he.last_ms=now;return;}
        he.index=0;he.cdf=0;he.min=0;he.state=2;break;
    case 2:
        // Hardware holds the snapshot for both bounded scans.
        for(n=0;n<HE_BATCH && he.index<256;n++,he.index++) {
            unsigned bin=ui_read(HE_BASE+0x400u+4u*he.index);
            if(mode==3u) {
                unsigned trim=he.total/100u;
                he.cdf+=bin;
                // Discard up to 1% at either tail, including exact-cut bins.
                if(he.cdf<=trim)he.min=he.index+1u;
                if(he.cdf<he.total-trim)continue;
                he.total=he.index;
                if(he.total-he.min<16u) {
                    // Flat / near-flat scenes: keep identity, not boosted noise.
                    he.min=0;he.total=255;
                } else if(he.total-he.min<128u) {
                    // Widen about the midpoint to cap contrast gain below 2x.
                    unsigned middle=he.min+he.total;
                    he.min=middle>128u?(middle-128u)/2u:0u;
                    if(he.min>127u)he.min=127u;
                    he.total=he.min+128u;
                }
            } else {
                if(!bin)continue;
                he.min=bin;
            }
            he.cdf=0;he.index=0;he.state=3;
            ui_write(HE_BASE+0x10,0);break;
        }
        if(he.index==256) {he.state=0;he.last_ms=now;}
        break;
    case 3:
        for(n=0;n<HE_BATCH && he.index<256;n++,he.index++) {
            unsigned value;
            if(mode==3u)he.cdf=he.index;
            else he.cdf+=ui_read(HE_BASE+0x400u+4u*he.index);
            value=he_mapping(he.index,he.cdf,he.min,he.total,mode);
            if(he.history)value=(3u*he.lut[he.index]+value+2u)/4u;
            he.lut[he.index]=(uint8_t)value;
            ui_write(HE_BASE+0x14,value);
        }
        if(he.index==256) {ui_write(HE_BASE+0x18,1);he.state=4;}
        break;
    case 4:
        if((status&2u) || !(status&8u))return;
        ui_write(HE_BASE+0x1c,1);
        he.history=1;he.last_ms=now;he.state=0;++g_he_debug.updates;
        break;
    }
}
#endif
