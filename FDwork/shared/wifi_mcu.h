/* Included after the UI commit boundary in both RAM and Flash applications. */
#ifndef WIFI_MCU_H
#define WIFI_MCU_H
#include "wifi_transport.h"
#include "wifi_calendar.h"
#if !defined(WIFI_MCU_HOST_TEST) || defined(WIFI_MCU_UART_TEST)
#include "al_misc_ll.h"
#ifndef WIFI_MCU_UART_TEST
#include "al_simp_printf.h"
#endif
#endif
static WifiTransport wifi_link;
static unsigned wifi_enabled,wifi_in_service,wifi_polling;
static uint32_t wifi_boot_id,wifi_rtc_start,wifi_rtc_seq;
/* Retained only across warm MCU resets; cold-boot seed also uses RTC/timer.
 * This is a reset discriminator, not a cryptographic identity. */
static volatile uint32_t wifi_boot_record[3] __attribute__((section(".wifi_noinit")));
static volatile uint8_t wifi_rx[128];
static volatile unsigned wifi_rx_head,wifi_rx_tail,wifi_rx_fault;
static volatile unsigned wifi_tx_started;
typedef struct {
    uint8_t id[16],args[5],state,code,used;
    uint32_t saved;
    uint8_t photo[16];
} WifiCommand;
/* Server IDs strictly increase as big-endian 128-bit values. Results may expire
 * from this bounded cache, but high-water prevents any old action replay. */
#define WIFI_HISTORY 8
static WifiCommand wifi_commands[WIFI_HISTORY];
static uint8_t wifi_command_highwater[16];
static uint32_t wifi_ms(void) {return (uint32_t)(AlSys_GetTimerTickCount()/(PH1P35_MCU_TIMER_CLOCK/1000u));}
static int wifi_error(unsigned type,unsigned code,uint8_t *out,uint8_t *response) {
    *response=255;out[0]=type;out[1]=code;return 2;
}
static void wifi_commands_poll(void) {
    if(wifi_in_service) return; /* mount/write may yield before state changes */
    for(unsigned i=0;i<WIFI_HISTORY;i++) {
        WifiCommand *c=&wifi_commands[i];if(!c->used || c->state) continue;
        unsigned busy=recorder_wifi_flags()&8;
        if(c->args[0]==1) {
            if(g_rec_saved!=c->saved) {recorder_last_photo_id(c->photo);c->state=1;}
            else if(!busy) {c->state=2;c->code=WF_IO_ERROR;}
        } else if(c->args[0]==4 && !busy) c->state=1;
    }
}
static int wifi_dispatch(unsigned type,const uint8_t *in,unsigned n,uint8_t *out,uint8_t *response) {
    unsigned status=WF_OK;
    if(type==1 && n==0) {
        wf_put32(out,wifi_boot_id);wf_put32(out+4,15);return 8;
    }
    if(type==2 && n==0) {
        wf_put16(out,record_ui->exposure);wf_put16(out+2,record_ui->gain);
        wf_put32(out+4,recorder_interval());
        uint32_t r=ui_read(0x68);unsigned flags=recorder_wifi_flags()|(wifi_in_service?8u:0u);
        if((r&0x86)==2) flags|=2;
        wf_put16(out+8,flags);wf_put16(out+10,127);return 12;
    }
    if(type==3 && (n==17 || n==21)) {
        unsigned op=in[16],slot=WIFI_HISTORY;uint8_t args[5]={0};
        memcpy(args,in+16,n-16);
        for(unsigned i=0;i<WIFI_HISTORY;i++) {
            WifiCommand *c=&wifi_commands[i];
            if(c->used && !memcmp(c->id,in,16)) {
                status=memcmp(args,c->args,5)?WF_CONFLICT:WF_OK;goto ack;
            }
            if(!c->used && slot==WIFI_HISTORY) slot=i;
        }
        if(memcmp(in,wifi_command_highwater,16)<=0) {status=WF_UNKNOWN_ID;goto ack;}
        unsigned sum=0;for(unsigned i=0;i<16;i++) sum|=in[i];
        unsigned a=n==21?wf_get16(in+17):0,b=n==21?wf_get16(in+19):0;
        uint32_t seconds=n==21?wf_get32(in+17):0;
        if(!sum || op<1 || op>4 || n!=((op==2 || op==3)?21u:17u) ||
           (op==2 && (a<3 || a>3990 || b<16 || b>143)) ||
           (op==3 && seconds!=2 && seconds!=5 && seconds!=10 && seconds!=30 && seconds!=60)) {
            status=WF_BAD_ARGUMENT;goto ack;
        }
        if(slot==WIFI_HISTORY) {
            for(unsigned i=0;i<WIFI_HISTORY;i++) if(wifi_commands[i].state &&
               (slot==WIFI_HISTORY || memcmp(wifi_commands[i].id,wifi_commands[slot].id,16)<0)) slot=i;
        }
        if(slot==WIFI_HISTORY) {status=WF_BUSY;goto ack;}
        if(op!=2 && !recorder_available()) {status=WF_UNSUPPORTED;goto ack;}
        if((op==1 || op==3) && (wifi_in_service || (recorder_wifi_flags()&9))) {status=WF_BUSY;goto ack;}
        WifiCommand *c=&wifi_commands[slot];memset(c,0,sizeof *c);
        memcpy(c->id,in,16);memcpy(c->args,args,5);c->used=1;c->saved=g_rec_saved;
        memcpy(wifi_command_highwater,in,16);
        MenuState old=*record_ui;unsigned actions=0;
        if(op==1) actions=MENU_PHOTO;
        if(op==2) {record_ui->auto_exposure=0;record_ui->exposure=a;record_ui->gain=b;}
        if(op==3) {
            static const unsigned intervals[5]={2,5,10,30,60};
            for(unsigned i=0;i<5;i++) if(intervals[i]==seconds) record_ui->record_interval=i;
            actions=MENU_RECORD|MENU_INTERVAL;
        }
        if(op==4) actions=MENU_STOP;
        menu_commit(record_ui,&old,actions);
        if(op==2) {c->state=record_ui->exposure==a && record_ui->gain==b?1:2;c->code=c->state==1?0:WF_IO_ERROR;}
        if(op==3) c->state=1; /* scheduling enabled; individual captures can still fail */
ack:   memcpy(out,in,16);out[16]=status;return 17;
    }
    if(type==4 && n==16) {
        wifi_commands_poll();memcpy(out,in,16);memset(out+16,0,19);out[16]=3;wf_put16(out+17,WF_UNKNOWN_ID);
        for(unsigned i=0;i<WIFI_HISTORY;i++) {
            WifiCommand *c=&wifi_commands[i];if(c->used && !memcmp(in,c->id,16)) {
                out[16]=c->state;wf_put16(out+17,c->code);memcpy(out+19,c->photo,16);break;
            }
        }
        return 35;
    }
    if(type==5 && n==10) {
        uint64_t epoch=wf_get32(in)|((uint64_t)wf_get32(in+4)<<32);unsigned v[6];
        if(!wf_epoch_calendar(epoch,(int16_t)wf_get16(in+8),v)) status=WF_BAD_ARGUMENT;
        else if(ui_read(0x84)!=0x52544332u) status=WF_UNSUPPORTED;
        else if(rtc_set_wait || (ui_read(0x80)&1)) status=WF_BUSY;
        else {
            char date[20]="0000-00-00 00:00:00";const uint8_t pos[6]={0,5,8,11,14,17};
            for(unsigned i=0;i<6;i++) {unsigned val=v[i],digits=i?2:4;for(unsigned j=digits;j;j--) {date[pos[i]+j-1]='0'+val%10;val/=10;}}
            uint32_t t0,t1;
            if(!rtc_parse(date,&t0,&t1)) status=WF_BAD_ARGUMENT;
            else {
                rtc_set_wait=2;wifi_rtc_seq=ui_read(0x80)>>16;wifi_rtc_start=wifi_ms();
                ui_write(0x78,t0);ui_write(0x7c,t1);ui_write(0x80,0x53455431u);return -1;
            }
        }
        out[0]=status;out[1]=0;return 2;
    }
    if(type==6 && n==0) {
        unsigned len=1;status=recorder_photo_next(out,&len);
        if(status) {out[0]=status;len=1;}return len;
    }
    if(type==7 && n==22) {
        if(wifi_in_service) return wifi_error(type,WF_BUSY,out,response);
        unsigned len=wf_get16(in+20);
        status=recorder_photo_read(in,wf_get32(in+16),len,out+22);
        if(status) return wifi_error(type,status,out,response);
        memcpy(out,in,22);return 22+len;
    }
    if(type==8 && n==24) {
        status=wifi_in_service?WF_BUSY:recorder_photo_commit(in,wf_get32(in+16),wf_get32(in+20));
        memcpy(out,in,16);out[16]=status;return 17;
    }
    return wifi_error(type,type>=1 && type<=8?WF_BAD_ARGUMENT:WF_UNSUPPORTED,out,response);
}
static void wifi_pending_poll(void) {
    if(!wifi_link.pending) return;
    uint32_t s=ui_read(0x80);unsigned code=WF_IN_PROGRESS;
    if(!(s&1) && (s>>16)!=wifi_rtc_seq && (s&2)) code=s&4?WF_RTC_VERIFY_FAILED:WF_OK;
    if(code!=WF_IN_PROGRESS || (uint32_t)(wifi_ms()-wifi_rtc_start)>3500) {
        wifi_link.reply[14]=code;wifi_link.reply[15]=code==WF_OK;rtc_set_wait=0;
        wifi_reply(&wifi_link,0x85,2);
    }
}
#if !defined(WIFI_MCU_HOST_TEST) || defined(WIFI_MCU_UART_TEST)
static void wifi_uart_irq(void *unused) {
    (void)unused;unsigned s=AlUsart_ll_GetStatus(USART0_BASE_ADDR);
    wifi_rx_fault|=s&0x330u;AL_REG32_WRITE(USART0_BASE_ADDR+USART_UART_STATUS_ADDR,s&0x20330u);
    for(unsigned i=0;i<32 && !(AlUsart_ll_GetStatus(USART0_BASE_ADDR)&(1u<<15));i++) {
        uint8_t c=AlUsart_ll_RecvData(USART0_BASE_ADDR);unsigned next=(wifi_rx_head+1)&127;
        if(next==wifi_rx_tail) wifi_rx_fault=1;else {wifi_rx[wifi_rx_head]=c;wifi_rx_head=next;}
    }
    if(s&(1u<<17)) AlUsart_ll_SetRxSize(USART0_BASE_ADDR,0xfffffu);
    if(wifi_tx_started && (s&1)) {
        const uint8_t *p=wifi_link.error_tx?wifi_link.error:wifi_link.reply;
        for(unsigned i=0;i<32 && wifi_link.tx_pos<wifi_link.tx_len &&
            !(AlUsart_ll_GetStatus(USART0_BASE_ADDR)&(1u<<14));i++)
            AlUsart_ll_SendData(USART0_BASE_ADDR,p[wifi_link.tx_pos++]);
        if(wifi_link.tx_pos==wifi_link.tx_len) AlUsart_ll_EnableIntr(USART0_BASE_ADDR,AL_USART_TXIE,AL_FALSE);
    }
}
static void wifi_mcu_init(void) {
    if(ui_read(0x90)!=0x57494631u) {
        al_simp_printf("WIFI: FPGA_WIF1_REQUIRED\r\n");return;
    }
    uint32_t counter=wifi_boot_record[0]==0x57464231u && wifi_boot_record[2]==~wifi_boot_record[1]?wifi_boot_record[1]+1:
        (uint32_t)AlSys_GetTimerTickCount()^ui_read(0x60)^(ui_read(0x64)*2654435761u);
    if(!counter) counter=1;
    wifi_boot_record[0]=0x57464231u;wifi_boot_record[1]=counter;wifi_boot_record[2]=~counter;
    wifi_boot_id=counter;
    ui_write(0x88,0); /* release RST and GPIO0; never enter ROM download mode */
    /* USART0 was not enabled by the original BSP. Complete clock/reset writes
     * and allow reset synchronization before even the first IRQ-disable store.
     * Without this, the board trapped on USART0+0x10 before touch polling. */
    ECLIC_DisableIRQ(SOC_USART0_IRQn);
    AlMisc_ll_SetClkEn(AL_MISC_USART0,1);
    __RWMB();AlSys_UDelay(50);
    AlMisc_ll_SetReset(AL_MISC_USART0,0);
    __RWMB();AlSys_UDelay(50);
    AlMisc_ll_SetReset(AL_MISC_USART0,1);
    __RWMB();AlSys_UDelay(50);
    al_simp_printf("WIFI: UART0 pre-access clk=%x rst=%x div=%x\r\n",
        AL_REG32_READ(MISC_CTRL_BASE_ADDR+SOC_MISC_CTRL__SUBM_CLK_CTRL0__ADDR),
        AL_REG32_READ(MISC_CTRL_BASE_ADDR+SOC_MISC_CTRL__SUBM_RESET_CTRL0__ADDR),
        AL_REG32_READ(MISC_CTRL_BASE_ADDR+SOC_MISC_CTRL__CLK_CTRL3_USART0_CLK_I__ADDR));
    AlUsart_ll_DisableAllIntr(USART0_BASE_ADDR);
    AlUsart_ll_EnableTx(USART0_BASE_ADDR,AL_FALSE);AlUsart_ll_EnableRx(USART0_BASE_ADDR,AL_FALSE);
    AlUsart_ll_CleanRxFifo(USART0_BASE_ADDR,AL_TRUE);AlUsart_ll_CleanRxFifo(USART0_BASE_ADDR,AL_FALSE);
    AlUsart_ll_EnableFractionBaud(USART0_BASE_ADDR,AL_FALSE);
    AlUsart_ll_SetBaudDiv(USART0_BASE_ADDR,(PH1P35_MCU_USART_CLOCK+57600u)/115200u-1u);
    AlUsart_ll_SetWordLength(USART0_BASE_ADDR,AL_USART_CHAR_8_BITS);
    AlUsart_ll_SetStopBit(USART0_BASE_ADDR,AL_USART_STOP_1_BIT);
    AlUsart_ll_EnableParity(USART0_BASE_ADDR,AL_FALSE);AlUsart_ll_SetParity(USART0_BASE_ADDR,AL_USART_NO_PARITY);
    AlUsart_ll_SetCts(USART0_BASE_ADDR,AL_FALSE);AlUsart_ll_SetRts(USART0_BASE_ADDR,AL_FALSE);
    AlUsart_ll_EnableSeparate(USART0_BASE_ADDR,AL_TRUE);AlUsart_ll_SetDmaEn(USART0_BASE_ADDR,AL_FALSE);
    AlUsart_ll_SetRxDmaEn(USART0_BASE_ADDR,AL_FALSE);
    AlUsart_ll_SetTxDataSize(USART0_BASE_ADDR,AL_USART_BYTE);AlUsart_ll_SetRxDataSize(USART0_BASE_ADDR,AL_USART_BYTE);
    AlUsart_ll_SetRxFifoWm(USART0_BASE_ADDR,0);AlUsart_ll_SetRxSize(USART0_BASE_ADDR,0xfffffu);
    AlUsart_ll_SetTxFifoWm(USART0_BASE_ADDR,8);
    AlUsart_ll_EnableRxDmaReload(USART0_BASE_ADDR,AL_TRUE);
    AL_REG32_WRITE(USART0_BASE_ADDR+USART_UART_STATUS_ADDR,0x33330u);
    AlUsart_ll_EnableTx(USART0_BASE_ADDR,AL_TRUE);AlUsart_ll_EnableRx(USART0_BASE_ADDR,AL_TRUE);
    AlIntr_RegHandler(SOC_USART0_IRQn,AL_NULL,wifi_uart_irq,AL_NULL);
    AlUsart_ll_EnableIntr(USART0_BASE_ADDR,AL_USART_RXIE,AL_TRUE);
    AlUsart_ll_EnableIntr(USART0_BASE_ADDR,AL_USART_RX_EOT_IRQ_EN,AL_TRUE);
    wifi_enabled=1;
    al_simp_printf("WIFI: UART0 v1 115200 boot=%x\r\n",wifi_boot_id);
}
static void wifi_mcu_poll(unsigned in_service) {
    if(!wifi_enabled || wifi_polling) return;
    wifi_polling=1;wifi_in_service=in_service;wifi_commands_poll();
    wifi_pending_poll();
    /* Do not overwrite a pending response/cached wire buffer mid-transmit. */
    if(!wifi_link.pending && wifi_link.tx_pos==wifi_link.tx_len && !wifi_tx_started) {
        if(wifi_rx_fault) {
            ECLIC_DisableIRQ(SOC_USART0_IRQn);wifi_rx_tail=wifi_rx_head;wifi_rx_fault=0;
            ECLIC_EnableIRQ(SOC_USART0_IRQn);wifi_transport_reset_rx(&wifi_link);
        }
        for(unsigned i=0;i<128 && wifi_rx_tail!=wifi_rx_head && !wifi_rx_fault;i++) {
            uint8_t b=wifi_rx[wifi_rx_tail];wifi_rx_tail=(wifi_rx_tail+1)&127;
            wifi_transport_byte(&wifi_link,b,wifi_ms(),wifi_dispatch);
            if(wifi_link.pending || wifi_link.tx_pos<wifi_link.tx_len) break;
        }
    }
    if(wifi_link.tx_pos<wifi_link.tx_len) {
        if(!wifi_tx_started) {
            AlUsart_ll_ClrStatus(USART0_BASE_ADDR,AL_USART_STATUS_TX_EOT);
            AlUsart_ll_SetTxSize(USART0_BASE_ADDR,wifi_link.tx_len);wifi_tx_started=1;
            AlUsart_ll_EnableIntr(USART0_BASE_ADDR,AL_USART_TXIE,AL_TRUE);
        }
    }
    if(wifi_tx_started && wifi_link.tx_pos==wifi_link.tx_len &&
       (AlUsart_ll_GetStatus(USART0_BASE_ADDR)&(1u<<16))) wifi_tx_started=0;
    wifi_polling=0;
}
#endif
#endif
