//+------------------------------------------------------------------+
//|                                                      libMql4.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#property copyright "Copyright 2023, Sean Champ"
#property link      "https://www.example.com/nop"
#property strict

static const double __dblzero__ = 0.0;

extern bool debug = false;

#ifndef DEBUG
#define DEBUG if(debug) printf
#endif


/**
 * Return the time at a given offset, as a single datetime value
 **/    
datetime offset_time(const int shift, const int timeframe)
{
    datetime dtbuff[1];
    CopyTime(_Symbol, timeframe, shift, 1, dtbuff);
    return dtbuff[0];
}

/* might be useful for timer-based processing

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
}
*/
