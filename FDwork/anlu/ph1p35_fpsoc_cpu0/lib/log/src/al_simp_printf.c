
#include <stdarg.h>
#include <stdint.h>
#include <limits.h>
#include "al_simp_printf.h"
#include "al_log.h"

void al_simp_putchar(char c) {
    AlLog_Write((unsigned char*)&c, 1);
}

static void printf_c(int c)
{
    al_simp_putchar(c);
}

static void printf_s(char *p)
{
    while (*p)
        al_simp_putchar(*(p++));
}

static void printf_u(unsigned int val)
{
    char buffer[32];
    char *p = buffer;

    // 处理 0 的情况
    if (val == 0) {
        printf_c('0');
        return;
    }

    do {
        *(p++) = '0' + (val % 10);
        val /= 10;
    } while (val);

    // 倒序输出
    while (p != buffer) {
        printf_c(*(--p));
    }
}

static void printf_d(int val)
{
    char buffer[32];
    char *p = buffer;
    if (val < 0) {
        printf_c('-');
        val = -val;
    }
    while (val || p == buffer) {
        *(p++) = '0' + val % 10;
        val = val / 10;
    }
    while (p != buffer)
        printf_c(*(--p));
}
static void printf_x(unsigned int val)
{
    char buffer[32];
    const char lut[]={'0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'};
    char *p = buffer;
    while (val || p == buffer) {
        *(p++) = lut[val & 0x0000000F];
        val = val >>4 ;
    }
    while (p != buffer)
        printf_c(*(--p));
}
static void printf_llu(unsigned long long val)
{
    char buffer[32];  // 2^64 ~ 1.8e19 → 最多 20 位 + '\0'
    char *p = buffer;

    // 处理 0 的情况
    if (val == 0) {
        printf_c('0');
        return;
    }

    // 从低位到高位，逐位取余，存入 buffer
    do {
        *(p++) = '0' + (val % 10);
        val /= 10;
    } while (val);

    // 倒序输出
    while (p != buffer) {
        printf_c(*(--p));
    }
}
static void printf_lld(long long val)
{
    if (val < 0) {
        printf_c('-');
        if (val == LLONG_MIN) {
            printf_c('9');
            printf_llu(223372036854775808ULL);
            return;
        }
        val = -val;
    }
    printf_llu((unsigned long long)val);
}

static void printf_f(double val)
{
    int decimal_places = 6;

    // 处理特殊值
    if (val != val) { // NaN
        printf_s("nan");
        return;
    }
    if (val > 1e20) {
        printf_s("inf");
        return;
    }
    if (val < -1e20) {
        printf_s("-inf");
        return;
    }

    // 处理负数
    if (val < 0) {
        printf_c('-');
        val = -val;
    }

    // 四舍五入到指定小数位
    double rounder = 0.5;
    for (int i = 0; i < decimal_places; i++) {
        rounder *= 0.1;
    }
    val += rounder;

    // 整数部分
    long long integer_part = (long long)val;
    printf_lld(integer_part);
    printf_c('.');

    // 小数部分
    double fractional = val - integer_part;
    for (int i = 0; i < decimal_places; i++) {
        fractional *= 10;
        int digit = (int)fractional;
        printf_c('0' + digit);
        fractional -= digit;
    }
}

int al_simp_printf(const char *format, ...)
{
    int i;
    va_list ap;

    va_start(ap, format);

    for (i = 0; format[i]; i++)
        if (format[i] == '%') {
            while (format[++i]) {
                if (format[i] == 'c') {
                    printf_c(va_arg(ap,int));
                    break;
                }
                if (format[i] == 's') {
                    printf_s(va_arg(ap,char*));
                    break;
                }
                if (format[i] == 'd') {
                    printf_d(va_arg(ap,int));
                    break;
                }
                if (format[i] == 'u') {
                    printf_u(va_arg(ap, unsigned int));
                    break;
                }
                if (format[i] == 'x') {
                    printf_x(va_arg(ap,int));
                    break;
                }
                if (format[i] == 'l' && format[i+1] == 'l' && format[i+2] == 'u') {
                    printf_llu(va_arg(ap, unsigned long long));
                    i += 2;
                    break;
                }
                if (format[i] == 'l' && format[i+1] == 'l' && format[i+2] == 'd') {
                    printf_lld(va_arg(ap, long long));
                    i += 2;
                    break;
                }
                if (format[i] == 'f') {
                    printf_f(va_arg(ap,double));
                    break;
                }
            }
        } else
            printf_c(format[i]);

    va_end(ap);

    return 0;
}


int al_simp_puts(char *s){
  while (*s) {
    al_simp_putchar(*s);
    s++;
  }
  al_simp_putchar('\n');
  return 0;
}


