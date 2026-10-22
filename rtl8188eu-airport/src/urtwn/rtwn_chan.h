/*
 * rtwn_chan.h — pengaturan kanal & akses register RF/BB 8188E.
 *
 * Port dari OpenBSD rtwn.c (ISC).
 */

#ifndef RTL8188EU_RTWN_CHAN_H
#define RTL8188EU_RTWN_CHAN_H

#include <stdint.h>
#include <stdbool.h>

#include "rtwn_seq.h"
#include "rtwn_platform.h"

uint32_t rtwn_rf_read_8188e(rtwn_read_fn rd, rtwn_write_fn wr, void *ctx,
    int chain, uint8_t addr);
int      rtwn_rf_write_8188e(rtwn_read_fn rd, rtwn_write_fn wr, void *ctx,
    int chain, uint16_t addr, uint32_t val);
int      rtwn_set_chan_8188e(rtwn_read_fn rd, rtwn_write_fn wr, void *ctx,
    uint8_t chan);

#endif /* RTL8188EU_RTWN_CHAN_H */
