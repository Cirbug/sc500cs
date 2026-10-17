#include <assert.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "al_printf.h"
#include "al_simp_printf.h"
static char output[1024];static unsigned count;
void AlLog_WriteByte(char c) {assert(count<sizeof output-1);output[count++]=c;output[count]=0;}
void AlLog_Write(unsigned char *p,unsigned n) {while(n--) AlLog_WriteByte(*p++);}
int main(void) {
    al_printf("%08x %u %d %s",0x1234u,4294967295u,-123,"RTC");
    assert(!strcmp(output,"00001234 4294967295 -123 RTC"));
    const uint64_t cases[]={0,1,9,10,0xffffffffULL,0x100000000ULL,0x123456789abcdef0ULL,UINT64_MAX};
    for(unsigned i=0;i<sizeof cases/sizeof cases[0];i++) {
        char expected[80];snprintf(expected,sizeof expected,"%llu %llX",(unsigned long long)cases[i],(unsigned long long)cases[i]);
        count=0;output[0]=0;al_printf("%llu %llx",(unsigned long long)cases[i],(unsigned long long)cases[i]);
        assert(!strcmp(output,expected));
        snprintf(expected,sizeof expected,"%llu",(unsigned long long)cases[i]);
        count=0;output[0]=0;al_simp_printf("%llu",(unsigned long long)cases[i]);assert(!strcmp(output,expected));
    }
    count=0;output[0]=0;al_simp_printf("%lld",(long long)INT64_MIN);assert(!strcmp(output,"-9223372036854775808"));
    // RV32 exception arguments are 32-bit even with the original %lx format.
    count=0;output[0]=0;al_simp_printf("MCAUSE : 0x%lx",0x8000000bu);assert(!strcmp(output,"MCAUSE : 0x8000000B"));
#ifdef AL_CAMERA_SHARED_PRINTF
    count=0;output[0]=0;al_simp_printf("WIFI: clk=%x rst=%x div=%x",0u,0xabcdefu,255u);
    assert(!strcmp(output,"WIFI: clk=0 rst=ABCDEF div=FF"));
    count=0;output[0]=0;al_simp_printf("%04u-%02u-%02u %s %c %%",2026u,10u,6u,"OK",'!');
    assert(!strcmp(output,"2026-10-06 OK ! %"));
    count=0;output[0]=0;al_simp_printf("%lx %llu %llx",0x12345678u,UINT64_MAX,UINT64_MAX);
    assert(!strcmp(output,"12345678 18446744073709551615 FFFFFFFFFFFFFFFF"));
#endif
    puts("PASS compact diagnostics: integer padding, RV32 exception hex, full uint64 range, signed minimum");
}
