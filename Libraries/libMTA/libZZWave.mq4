//+------------------------------------------------------------------+
//|                                                    libZZWave.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

// MQL implementation inspired by the free/open source ZigZag implementation
// for Cython, by @jbn https://github.com/jbn/ZigZag/

#ifndef _LIBZZWAVE_MQ4
#define _LIBZZWAVE_MQ4 1

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#include "libMql4.mq4"

#property library
#property strict

// extern const double zzwave_min;

/*
#define INIT_HL(__HIGHVAR__, __LOWVAR__, __START__, __BID__, __HIGH__, __LOW__)                                  \
    const double __first_h__ = __HIGH__[__START__];                                                              \
    const double __first_l__ = __LOW__[__START__];                                                               \
    const double __HIGHVAR__ = __BID__ == EMPTY ? __first_h__ : (__BID__ > __first_h__ ? __BID__ : __first_h__); \
    const double __LOWVAR__ = __BID__ == EMPTY ? __first_l__ : (__BID__ < __first_l__ ? __BID__ : __first_l__);
*/

// limitations of this platform. int buffers cannot be used as index buffers.
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
                        const ENUM_PRICE_MODE price_mode,
                        const double &open[],
                        const double &high[],
                        const double &low[],
                        const double &close[],
                        const bool dbg = false)
{
    const int __start__ = 0;

    double p_last = priceFor(__start__, price_mode, open, high, low, close);
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
        p_next = priceFor(n, price_mode, open, high, low, close);
        r_p = p_next / p_trend;
        update = false;
        zero_previous = false;

        if (r_p >= 1 && p_next >= p_last)
        {
            if (trend == __trough__ || trend == __none__)
            {
                if (trend == __none__)
                {
                    // initial trend
                    extents[__start__] = p_initial;
                    // converse of this trend's effective datum:
                    statebuff[__start__] = __trough__;
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
        else if (p_next < p_last)
        {
            if (trend == __crest__ || trend == __none__)
            {
                if (trend == __none__)
                {
                    // initial trend
                    extents[__start__] = p_initial;
                    // converse of this trend's effective datum:
                    statebuff[__start__] = __crest__;
                }
                else // if(update == false)
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
        } else {
            extents[n] = __dblzero__;
            statebuff[n] = __none__;
        }


        if (zero_previous)
        {
            extents[last_index_offset] = __dblzero__;
            statebuff[last_index_offset] = __none__;
        }
        if (update)
        {
            extents[n] = p_next;
            statebuff[n] = trend;
            last_index_offset = n;
            r_p_trend = r_p;
            p_trend = p_next;
        }
        else
        {
            extents[n] = __dblzero__;
            statebuff[n] = __none__;
        }
        p_last = p_next;
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
    int last_index_offset = EMPTY;
    double next_h, next_l, r_h, r_l;
    double r_h_highest = __dblzero__;
    double r_l_highest = __dblzero__;
    double update_p = __dblzero__;

    double trend = __none__;

    // bool update, found;
    bool update, zero_previous;

    for (int n = __start__ + 1; n < len; n++)
    {
        update = false;
        zero_previous = false;

        next_l = low[n];
        next_h = high[n];

        r_h = next_h / last_crest;
        if (r_h_highest == DBL_MAX)
            r_h_highest = r_h;

        r_l = last_trough / next_l;
        if (r_l_highest == DBL_MAX)
            r_l_highest = r_l;

        // first analysis
        if (r_h >= 1)
        {
            if (trend == __trough__ || trend == __none__)
            {
                if (trend == __none__)
                {
                    // ! converse of this trend's effective datum
                    extents[__start__] = initial_l;
                    statebuff[__start__] = __trough__;
                    last_trough = initial_l; // FIXME overwritten in update
                }
                update = true;
                r_l_highest = r_l;
            }
            else if (r_h >= r_h_highest)
            {
                update = true;
                zero_previous = true;
            }
            /// common
            if (update)
            {
                update_p = next_h;
                r_h_highest = r_h;
            }
            trend = __crest__;
        }
        // second analysis
        else if (r_l >= 1) 
        {
            if (trend == __crest__ || trend == __none__)
            {
                if (trend == __none__)
                {
                    // ! converse of this trend's effective datum
                    extents[__start__] = initial_h;
                    statebuff[__start__] = __crest__;
                    last_crest = initial_h; // FIXME overwritten in update
                }
                update = true;
                r_h_highest = r_h;
            }
            else if (r_l >= r_l_highest)
            {
                update = true;
                zero_previous = true;
            }            
            //// common
            if (update)
            {
                update_p = next_l;
                r_l_highest = r_l;
            }
            trend = __trough__;
        } else {
           extents[n] = __dblzero__; 
           statebuff[n] = __none__;
        }


        ///
        /// common
        ///

        if (zero_previous)
        {
            extents[last_index_offset] = __dblzero__;
            statebuff[last_index_offset] = __none__;
        }
        if (update)
        {
            extents[n] = update_p;
            statebuff[n] = trend;
            last_index_offset = n;
        }
        else
        {
            extents[n] = __dblzero__;
            statebuff[n] = __none__;
        }

        last_l = next_l;
        last_h = next_h;
    }
}

#endif
