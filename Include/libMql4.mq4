//+------------------------------------------------------------------+
//|                                                      libMql4.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#ifndef _LIBMQL4_MQ4
#define _LIBMQL4_MQ4 1

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#property copyright "Copyright 2023, Sean Champ"
#property link      "https://www.example.com/nop"
#property strict


#ifndef DBLZERO_DEFINED
#define DBLZERO_DEFINED 1
const int __dblzero__ = 0.0;
#ifndef DBLZERO
#define DBLZERO __dblzero__
#endif
#endif

#ifndef DEBUG
extern bool debug = false;
#define DEBUG if(debug) printf
#endif


/**
 * Return the time at a given offset, as a single datetime value
 **/    
datetime offset_time(const int shift, int timeframe = EMPTY)
{
    static datetime dtbuff[1];
    if (timeframe == EMPTY) {
        timeframe = _Period;
    }
    CopyTime(_Symbol, timeframe, shift, 1, dtbuff);
    return dtbuff[0];
};

string offset_time_str(const int shift, int timeframe = EMPTY) {
    if (timeframe == EMPTY) {
        timeframe = _Period;
    }
    return TimeToStr(offset_time(shift, timeframe));
};

bool rates_quote(const int offset, const ENUM_TIMEFRAMES timeframe, double &buffer[]) {
    MqlRates rates[1];
    int rc = CopyRates(_Symbol, timeframe, offset, 1, rates);
    if (rc == -1) {
        return false;
    }
    buffer[0] = rates[0].open;
    buffer[1] = rates[0].high;
    buffer[2] = rates[0].low;
    buffer[3] = rates[0].close;
    return true;
};

// FIXME redefined in adxcommon
bool dblEql(const double d1, const double d2) {
    // for high-precision comparison with float values, see also
    // https://randomascii.wordpress.com/2012/02/25/comparing-floating-point-numbers-2012-edition/
    //// symbol-dependent
    // return NormalizeDouble(fabs(d2 - d1), Digits) == 0;
    //// symbol-independent
    return fabs(d2 - d1) <= DBL_EPSILON;
};

bool dblZero(const double d) {
    return ((d == DBLZERO) || dblEql(d, DBLZERO));
};

//
// EMA
//

double ema_factor(const double period) {
    return (2.0 / (period + 1.0));
};

// calculate the exponential moving average of a previous value and current
double ema(const double pre, const double cur, const double period) {
    // reference: 
    // Pruitt, G. (2016). Stochastics and Averages and RSI! Oh, My. 
    // In The Ultimate Algorithmic Trading System Toolbox + Website (pp. 25–76). 
    // John Wiley & Sons, Inc. https://doi.org/10.1002/9781119262992.ch2
    return ((cur - pre) * ema_factor(period)) + pre;
};

double emaWilder(const double pre, const double cur, const double period, const double shift = 1.0) {
    // an optionally shifted variant of the ADX EMA [Wilder]
    //
    // This differs significantly to the EMA calculation used above, 
    // which is applied in the RSIpp indicator to an effect of
    // substantial smoothing of the RSI line.
    const double shifted_period = period - shift;
    return ((pre * shifted_period) + (cur * shift)) / period;
}


//
// TBD ALERT + StringFormat macros
//

#ifndef ALERTF_1
#define ALERTF_1(_MSG_, _ARG1_) Alert(StringFormat(_MSG_, _ARG1_))
#endif

#ifndef ALERTF_2
#define ALERTF_2(_MSG_, _ARG1_, _ARG2_) Alert(StringFormat(_MSG_, _ARG1_, _ARG2_))
#endif

#ifndef ALERTF_3
#define ALERTF_3(_MSG_, _ARG1_, _ARG2_, _ARG3_) Alert(StringFormat(_MSG_, _ARG1_, _ARG2_, _ARG3_))
#endif

// ...


#endif
