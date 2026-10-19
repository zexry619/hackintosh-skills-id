#!/bin/bash
# Probe frekuensi CPU aktual — untuk memverifikasi Intel Turbo Boost / membandingkan frekuensi inti nyata pada berbagai model mesin atau pengaturan BIOS
# Prinsip: mulsd (perkalian skalar presisi ganda) memiliki latensi tetap 4 siklus pada CPU Intel generasi terbaru;
#       menulis perkalian ke dalam assembly inline => kompilator tidak dapat melipat kodenya, sehingga yang diukur murni jumlah siklus rantai dependensi.
#       ★ Jangan gunakan loop C biasa untuk mengukur frekuensi: clang -O2 akan melipat dependensi penjumlahan dan menghasilkan nilai konyol (pernah menghasilkan 8.34/11.03 GHz)
# Cara pakai: bash cpu-freq-probe.sh          (memerlukan Xcode command line tools yang menyediakan clang)
# Referensi: i7-12700K turbo boost 1 inti 5.0 GHz / semua inti sekitar 4.7 GHz / frekuensi dasar 3.6 GHz
# Cross-check dengan CPU-S (lihat "status turbo boost saat ini") dan Intel Power Gadget
set -u
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/fb.c" <<'EOF'
#include <stdio.h>
#include <time.h>
#define S __asm__ __volatile__("mulsd %1, %0" : "+x"(d) : "x"(k));
int main(void){
    struct timespec t0,t1; const unsigned long long L=20000000ULL;
    volatile double sink; double d=1.0, k=1.0000000001;
    clock_gettime(CLOCK_MONOTONIC,&t0);
    for(unsigned long long i=0;i<L;i++){
        S S S S S S S S S S S S S S S S
        S S S S S S S S S S S S S S S S
    }
    clock_gettime(CLOCK_MONOTONIC,&t1); sink=d;
    double sec=(t1.tv_sec-t0.tv_sec)+(t1.tv_nsec-t0.tv_nsec)/1e9;
    double cyc=(double)L*32.0*4.0;
    printf("%.2f", cyc/sec/1e9);
    return 0;
}
EOF
clang -O2 -o "$TMP/fb" "$TMP/fb.c" || { echo "Kompilasi gagal (memerlukan Xcode command line tools)"; exit 1; }
echo "Model: $(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Model Identifier/{print $2}')"
echo -n "Frekuensi inti terukur single-thread: "; "$TMP/fb"; echo " GHz"
echo "8 thread paralel (per thread):"
for i in 1 2 3 4 5 6 7 8; do printf '  '; "$TMP/fb"; echo ' GHz'; done
echo "Referensi: i7-12700K turbo boost 1 inti 5.0 GHz / semua inti sekitar 4.7 GHz"
