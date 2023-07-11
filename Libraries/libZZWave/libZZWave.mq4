//+------------------------------------------------------------------+
//|                                                    libZZWave.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

// MQL implementation inspired by the free/open source ZigZag implementation
// for Cython, by @jbn https://github.com/jbn/ZigZag/

#property library
#property strict

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

enum ZZ_EXTENT {
    ZZ_EXTENT_TROUGH = -1,
    ZZ_EXTENT_NONE = 0,
    ZZ_EXTENT_CREST = 1
};

extern const double zz_slope = 0.2; // Relative change for ZZWave extent analysis

const double neg_zz_slope = -zz_slope;


int zz_nearest(double &values[], int len, int start = 0) {
    // return an enum flag indicating the trend value in &values
    // starting at start, proceeding no further than len
    if (len <= start) {
        return 0;
    }
    double first = values[start];
    double cur = first;
    double next;
    double min = first;
    double max = first;
    int min_offset = start;
    int max_offset = start;
    for(int n = start + 1; n < len; n ++) {
        next = values[n];
        if (next / min >= zz_slope)
            return min_offset == start ? ZZ_EXTENT_TROUGH : ZZ_EXTENT_CREST;
        if (next / max <= neg_zz_slope)
            return min_offset == start ? ZZ_EXTENT_CREST : ZZ_EXTENT_TROUGH;
        if (next > max)  {
            max = next;
            max_offset = n;
        } 
        if (next < min) {
            min = next;
            min_offset = n;
        }
        double last = values[len - 1];
        return first < last ? ZZ_EXTENT_TROUGH : ZZ_EXTENT_CREST;
    }
}

void zz_fill_extents(double &extents[], double &values[], int len, int start = 0) {
    int trend = -zz_nearest(values, len, start);
    int last_offset = start;
    double last_extent = values[start];
    double cur, ratio;
    double thresh_crest = zz_slope + 1;
    double thresh_trough = neg_zz_slope + 1;

    for (int n = start; n < len; n++ ) {
        extents[n] = ZZ_EXTENT_NONE;
        cur = value[n];
        ratio = cur / last_extent;
        switch(trend) {
            case ZZ_EXTENT_TROUGH:
                if (ratio >= thresh_crest) {
                    extents[last_offset] = ZZ_EXTENT_TROUGH;
                    trend = ZZ_EXTENT_CREST;
                    last_extent = cur;
                    last_offset = n;
                } else if (cur < last_extent) {
                    last_extent = cur;
                    last_offset = n;
                }
            default:
                if (ratio <= thresh_trough {
                    extents[last_offset] = ZZ_EXTENT_CREST;
                    trend = ZZ_EXTENT_TROUGH;
                    last_extent = cur;
                    last_offset = n 
                } else if (cur > last_extent) {
                    last_extent = cur;
                    last_offset = n;
                }

        }
    }
}
