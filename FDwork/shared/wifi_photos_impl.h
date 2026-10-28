/* Sidecar is published only AFTER the complete BMP has been closed. Immutable
 * 40-byte WFP1 metadata has its own CRC. An appended 8-byte commit record is
 * checked separately. If metadata survives a torn commit, the commit is retried;
 * a damaged metadata record is skipped, never treated as uploaded.
 * Legacy BMPs without sidecars remain untouched and are not advertised.
 */
static DIR photo_dir;
static FIL photo_reader;
static uint8_t photo_meta[40];
static uint8_t photo_dir_open,photo_selected,photo_reader_open;
static unsigned photo_mount_id;
/* NEXT never performs storage I/O inside the UART dispatcher. */
static uint8_t photo_work,photo_result;
static char photo_name[13];
static void photo_filename(char *s,uint32_t number,const char *extension) {
    memcpy(s,"T0000000.",9);memcpy(s+9,extension,4);
    for(unsigned p=7;p;p--) {s[p]='0'+number%10;number/=10;}
}
static int photo_publish(void) {
    uint8_t m[40]={0};char name[13];UINT n;FIL f;
    wf_put32(m,0x31504657u);wf_put32(m+4,volume_id);wf_put32(m+8,seq-1);
    wf_put32(m+12,~photo_crc);wf_put32(m+16,photo_stamp);
    wf_put32(m+20,172854);wf_put32(m+24,~photo_crc);
    wf_put32(m+28,wf_fat_epoch(photo_stamp));wf_put32(m+36,wf_crc(m,36));
    photo_filename(name,seq-1,"WFM");
    if(f_open(&f,name,FA_WRITE|FA_CREATE_NEW)!=FR_OK) return 0;
    FRESULT r=f_write(&f,m,sizeof m,&n),c=f_close(&f);
    if(r!=FR_OK || c!=FR_OK || n!=sizeof m) return 0;
    memcpy(last_photo_id,m+4,16);return 1;
}
static int photo_commit_valid(const uint8_t *p,const uint8_t *m) {
    return wf_get32(p)==0x31434d57u && wf_get32(p+4)==wf_crc(m,40);
}
static unsigned photo_storage(void) {
    if(!available) return WF_UNSUPPORTED;
    if(mounted && card_ready) {
        if(photo_mount_id!=fs.id) {photo_dir_open=photo_selected=photo_reader_open=0;photo_mount_id=fs.id;}
        return WF_OK;
    }
    if(g_rec_state || wanted) return WF_BUSY;
    photo_dir_open=photo_selected=photo_reader_open=0;
    if(f_mount(&fs,"",1)!=FR_OK) {mounted=0;return WF_IO_ERROR;}
    mounted=1;photo_mount_id=fs.id;
    if(disk_read(0,buffer,fs.volbase,1)!=RES_OK) {mounted=0;return WF_IO_ERROR;}
    volume_id=wf_get32(buffer+(fs.fs_type==3?67:39));return WF_OK;
}
static unsigned photo_prepare_next(void) {
    unsigned r=photo_storage();if(r) return r;
    if(!photo_selected) {
        if(!photo_dir_open) {
            if(f_opendir(&photo_dir,"")!=FR_OK) return WF_IO_ERROR;
            photo_dir_open=1;
        }
        /* Bound directory work; BUSY means ask again later, not an empty queue. */
        for(unsigned i=0;i<8 && !photo_selected;i++) {
            FILINFO info;FIL f;uint8_t m[48];UINT count;
            if(f_readdir(&photo_dir,&info)!=FR_OK) {photo_dir_open=0;return WF_IO_ERROR;}
            if(!info.fname[0]) {f_closedir(&photo_dir);photo_dir_open=0;return WF_NO_PHOTO;}
            if(info.fattrib&AM_DIR || strlen(info.fname)!=12 || info.fname[0]!='T' || strcmp(info.fname+8,".WFM")) continue;
            if(f_open(&f,info.fname,FA_READ)!=FR_OK) return WF_IO_ERROR;
            FRESULT a=f_read(&f,m,sizeof m,&count),b=f_close(&f);
            if(a!=FR_OK || b!=FR_OK) return WF_IO_ERROR;
            if(count<40 || wf_get32(m)!=0x31504657u || wf_get32(m+36)!=wf_crc(m,36)) continue;
            if(count==48 && photo_commit_valid(m+40,m)) continue;
            uint32_t number=wf_get32(m+8);
            if(!number || number>9999999 || wf_get32(m+20)!=172854) continue;
            photo_filename(photo_name,number,"WFM");
            if(strcmp(photo_name,info.fname)) continue;
            photo_filename(photo_name,number,"BMP");
            memcpy(photo_meta,m,40);photo_selected=1;
        }
        if(!photo_selected) return WF_BUSY;
    }
    return WF_OK;
}
static void photo_prepare_poll(void) {
    if(photo_work!=1 || g_rec_state || wanted) return;
    photo_work=2; /* SD service hooks may answer HELLO/BUSY during this work. */
    photo_result=photo_prepare_next();
    photo_work=photo_result==WF_BUSY?1:3; /* continue next loop, not next RPC */
}
unsigned recorder_photo_next(uint8_t *out,unsigned *length) {
    if(!available) return WF_UNSUPPORTED;
    if(photo_work==3 && photo_result==WF_OK &&
       (!mounted || !card_ready || photo_mount_id!=fs.id || !photo_selected)) photo_work=0;
    if(photo_work!=3) {if(!photo_work) photo_work=1;return WF_BUSY;}
    if(photo_result) {
        unsigned result=photo_result;photo_work=result==WF_BUSY?1:0;return result;
    }
    out[0]=0;memcpy(out+1,photo_meta+4,16);
    memcpy(out+17,photo_meta+20,12);memset(out+29,0,4);
    out[33]=12;memcpy(out+34,photo_name,12);*length=46;return WF_OK;
}
unsigned recorder_photo_read(const uint8_t id[16],uint32_t offset,unsigned length,uint8_t *data) {
    unsigned r=photo_storage();if(r) return r;
    if(!photo_selected || memcmp(id,photo_meta+4,16)) return WF_UNKNOWN_ID;
    uint32_t size=wf_get32(photo_meta+20);
    if(!length || length>512 || offset>=size || length>size-offset) return WF_BAD_ARGUMENT;
    if(!photo_reader_open) {
        if(f_open(&photo_reader,photo_name,FA_READ)!=FR_OK) return WF_IO_ERROR;
        photo_reader_open=1;
    }
    UINT n;FRESULT a=f_lseek(&photo_reader,offset),b=FR_OK;
    if(a==FR_OK) b=f_read(&photo_reader,data,length,&n);else n=0;
    if(a!=FR_OK || b!=FR_OK || n!=length) {
        f_close(&photo_reader);photo_reader_open=0;return WF_IO_ERROR;
    }
    return WF_OK;
}
unsigned recorder_photo_commit(const uint8_t id[16],uint32_t size,uint32_t crc) {
    unsigned r=photo_storage();if(r) return r;
    if(size!=172854 || wf_get32(id+8)!=crc) return WF_CONFLICT;
    uint32_t number=wf_get32(id+4);
    if(!number || number>9999999) return WF_BAD_ARGUMENT;
    char name[13];uint8_t m[48];FIL f;UINT n;
    photo_filename(name,number,"WFM");
    if(f_open(&f,name,FA_READ|FA_WRITE)!=FR_OK) return WF_UNKNOWN_ID;
    FRESULT a=f_read(&f,m,sizeof m,&n);
    unsigned result=WF_IO_ERROR;
    if(a==FR_OK && n>=40 && wf_get32(m)==0x31504657u && wf_get32(m+36)==wf_crc(m,36) &&
       !memcmp(m+4,id,16) && wf_get32(m+20)==size && wf_get32(m+24)==crc) {
        if(n==48 && photo_commit_valid(m+40,m)) result=WF_OK;
        else {
            wf_put32(m+40,0x31434d57u);wf_put32(m+44,wf_crc(m,40));
            if(f_lseek(&f,40)==FR_OK && f_write(&f,m+40,8,&n)==FR_OK && n==8) result=WF_OK;
        }
    }
    if(f_close(&f)!=FR_OK) result=WF_IO_ERROR;
    if(result==WF_OK && photo_selected && !memcmp(id,photo_meta+4,16)) {
        if(photo_reader_open) f_close(&photo_reader);
        photo_selected=photo_reader_open=photo_work=0;
    }
    return result;
}
