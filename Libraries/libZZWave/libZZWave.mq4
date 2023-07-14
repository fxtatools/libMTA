//+------------------------------------------------------------------+
//|                                                    libZZWave.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

// MQL implementation inspired by the free/open source ZigZag implementation
// for Cython, by @jbn https://github.com/jbn/ZigZag/

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#include <libMql4.mq4>

#property library
#property strict

// extern const double zzwave_min;

#define INIT_HL(__HIGHVAR__, __LOWVAR__, __START__, __BID__, __HIGH__, __LOW__)                                  \
    const double __first_h__ = __HIGH__[__START__];                                                              \
    const double __first_l__ = __LOW__[__START__];                                                               \
    const double __HIGHVAR__ = __BID__ == EMPTY ? __first_h__ : (__BID__ > __first_h__ ? __BID__ : __first_h__); \
    const double __LOWVAR__ = __BID__ == EMPTY ? __first_l__ : (__BID__ < __first_l__ ? __BID__ : __first_l__);

double price_for(const int shift,
                 const ENUM_APPLIED_PRICE mode,
                 const double &open[],
                 const double &high[],
                 const double &low[],
                 const double &close[],
                 const double _ask = EMPTY,
                 const double _bid = EMPTY)
{
    switch (mode)
    {
    case PRICE_CLOSE:
        return close[shift];
    case PRICE_OPEN:
        return open[shift];
    case PRICE_HIGH:
        return high[shift];
    case PRICE_LOW:
        return low[shift];
    case PRICE_MEDIAN:
        return (high[shift] + low[shift]) / (double)2;
    case PRICE_TYPICAL:
        return (high[shift] + low[shift] + close[shift]) / (double)3;
    case PRICE_WEIGHTED:
        return (high[shift] + low[shift] + close[shift] * 2) / (double)4;
    default:
        return NULL;
    }
}

static const double __dblzero__ = 0.0;

static const double __crest__ = 1.0;
static const double __trough__ = -1.0;
static const double __none__ = __dblzero__;

#ifndef EMPTY
#define EMPTY -1
#endif

/// @brief Fill extents (price)
/// @param extents Extent value buffer
/// @param statebuff Extent state buffer
/// @param len Number of input points to calculate
/// @param price_mode Price mode
/// @param open Open quote buffer
/// @param high High quote buffer
/// @param low Low quote buffer
/// @param close Close quote buffer
/// @param _ask Tick Ask quote
/// @param _bid Tick Bid quote
/// @param dbg Enable debug messages
void fill_extents_price(double &extents[],
                        double &statebuff[],
                        const int len,
                        const ENUM_APPLIED_PRICE price_mode,
                        const double &open[],
                        const double &high[],
                        const double &low[],
                        const double &close[],
                        const bool dbg = false)
{
    const int __start__ = 0;

    double p_last = price_for(__start__, price_mode, open, high, low, close);
    const double p_initial = p_last;
    double p_next, r_p;
    double r_p_trend = __dblzero__;
    double p_trend = p_last;
    double last_crest = p_last;
    double last_trough = p_last;

    double trend = __none__;
    int last_index_offset = EMPTY;
    bool update, zero_previous;

    extents[__start__] = p_last;

    for (int n = __start__ + 1; n < len; n++)
    {
        p_next = price_for(n, price_mode, open, high, low, close);
        r_p = p_next / p_trend;
        update = false;
        zero_previous = false;

        if (r_p >= 1 && p_next >= p_trend )
        {
            if (trend == __trough__ || trend == __none__)
            {
                if (trend == __none__)
                {
                    // initial trend
                    extents[__start__] = p_initial;
                    statebuff[__start__] = __crest__;
                }
                else
                {
                    // previous trend
                    extents[last_index_offset] = p_trend;
                    statebuff[last_index_offset] = trend;
                }
                update = true;
            }
            else if (r_p >= r_p_trend)
            {
                update = true;
                zero_previous = true;
            }
            trend = __crest__;
        }
        // second analysis
        if (r_p < 1 && p_next <= p_trend)
        {
            if (trend == __crest__ || trend == __none__)
            {
                if (trend == __none__)
                {
                    // initial trend
                    extents[__start__] = p_initial;
                    statebuff[__start__] = __crest__;
                }                
                else if(update == false)
                {
                    // previous trend
                    //
                    // if the first analysis was reached in this iteration,
                    // then update == true and this should not be called
                    //
                    extents[last_index_offset] = p_trend;
                    statebuff[last_index_offset] = trend;
                }
                update = true;
            }
            else if (r_p <= r_p_trend)
            {
                update = true;
                zero_previous = true;
            }
            trend = __trough__;
        }
        if (zero_previous)
        {
            extents[last_index_offset] = __dblzero__;
            statebuff[last_index_offset] = __none__;
        }
        if (update)
        {
            last_index_offset = n;
            extents[n] = p_next;
            statebuff[n] = trend;
            r_p_trend = r_p;
            p_trend = p_next;
        } else {
            extents[n] = __dblzero__;
            statebuff[n] = __none__;
        }
    }
}

/// @brief fill extents (high/low)
/// @param extents ZZWave extents buffer
/// @param statebuff ZZWafe state buffer
/// @param len number of input points to calculate
/// @param price_mode price mode for price ratios
/// @param open open quote buffer
/// @param high high quote buffer
/// @param low low quote buffer
/// @param close close quote buffer
/// @param dbg enable debug messages
void fill_extents_hl(double &extents[],
                     double &statebuff[],
                     const int len,
                     const ENUM_APPLIED_PRICE price_mode,
                     const double &open[],
                     const double &high[],
                     const double &low[],
                     const double &close[],
                     const bool dbg = false)
{

    const int __start__ = 0;

    const double initial_h = high[__start__];
    const double initial_l = low[__start__];

    double last_h = initial_h;
    double last_l = initial_l;
    double last_crest = last_h;
    double last_trough = last_l;
    int last_ext_shift = -1;
    double next_h, next_l, r_h, r_l;
    double r_h_highest = __dblzero__;
    double r_l_highest = __dblzero__;

    double trend = __none__;

    double p_last = price_for(__start__, price_mode, open, high, low, close);
    double p_next, r_p;
    double p_trend = p_last;

    bool update, found;

    for (int n = __start__ + 1; n < len; n++)
    {
        update = false;
        found = false;
        next_l = low[n];
        next_h = high[n];
        p_next = price_for(n, price_mode, open, high, low, close);

        r_l = next_l / last_trough;
        if (r_l_highest == DBL_MAX)
            r_l_highest = r_l;

        r_h = next_h / last_crest;
        if (r_h_highest == DBL_MAX)
            r_h_highest = r_h;

        r_p = p_next / p_last;

        if (r_h > 1 || r_p > 1 /* || next_l <= last_trough */)
        {
            if (trend == __none__ || trend == __crest__)
            {
                if (trend == __none__)
                {
                    extents[__start__] = initial_l;
                    statebuff[__start__] = __trough__;
                }
                else
                {
                    // partial retrace
                    if (statebuff[last_ext_shift] == __trough__)
                    {
                        statebuff[last_ext_shift] = __none__;
                        extents[last_ext_shift] = __dblzero__;
                    }
                }
                extents[n] = next_h;  // ! converse of this trend's effective datum
                statebuff[n] = trend; // previous trend
                last_ext_shift = n;
                last_trough = next_l;
                p_trend = p_next;
            }

            if (next_l <= last_trough || trend == __crest__)
            {
                last_trough = next_l;
                update = true;
            }

            //// common
            trend = __trough__;
            if (update)
            {
                if (statebuff[last_ext_shift] == trend)
                {
                    // partial retrace
                    statebuff[last_ext_shift] = __none__;
                    extents[last_ext_shift] = __dblzero__;
                }
                extents[n] = next_l;
                statebuff[n] = trend;
                last_ext_shift = n;
                p_trend = p_next;
            }
            found = true;
        }

        // second analysis ... (required after the first now ...)
        if (r_l >= 1 /* || next_h >= last_crest*/)
        {
            if (trend == __none__ || trend == __trough__)
            {
                if (trend == __none__)
                {
                    extents[0] = initial_h;
                    statebuff[0] = __crest__;
                }
                else
                {
                    // partial retrace
                    if (statebuff[last_ext_shift] == __crest__)
                    {
                        statebuff[last_ext_shift] = __none__;
                        extents[last_ext_shift] = __dblzero__;
                    }
                }
                extents[n] = next_l;  // ! converse of this trend's effective datum
                statebuff[n] = trend; // previous trend
                last_ext_shift = n;
                last_crest = next_h;
                p_trend = p_next;
            }

            if (next_h >= last_crest || trend == __trough__)
            {
                // trend may be == __trough__ if the previous __trough__ analysis
                // was begun during this iteration
                last_crest = next_h;
                update = true;
            }

            /// common
            trend = __crest__;
            if (update)
            {
                if (statebuff[last_ext_shift] == trend)
                {
                    // partial retrace
                    statebuff[last_ext_shift] = __none__;
                    extents[last_ext_shift] = __dblzero__;
                }
                extents[n] = next_h;
                statebuff[n] = trend;
                last_ext_shift = n;
                p_trend = p_next;
            }
            found = true;
        }

        if (!found)
        {
            extents[n] = __dblzero__;
            statebuff[n] = __none__;
        }

        last_l = next_l;
        last_h = next_h;
        p_last = p_next;
    }
}
