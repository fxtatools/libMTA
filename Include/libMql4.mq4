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

#ifndef dbg
#define dbg Alert
#endif

extern bool debug = false;

union Timeframe
{
    ENUM_TIMEFRAMES timeframe;
    int period;

public:
    Timeframe() : period(_Period){};
    Timeframe(int duration) : period(duration){};
    Timeframe(ENUM_TIMEFRAMES tframe) : timeframe(tframe){};
};

class Chartable
{
protected:
    string symbol;
    Timeframe timeframe;

public:
    Chartable() : symbol(_Symbol), timeframe(_Period)
    {
        if (debug) dbg(StringFormat("Initialized charatble: %s %d", symbol, timeframe.period));
    };
    Chartable(ENUM_TIMEFRAMES tframe) : symbol(_Symbol), timeframe(tframe){};
    Chartable(string s) : symbol(s), timeframe(_Period){};
    Chartable(string s, ENUM_TIMEFRAMES tframe) : symbol(s), timeframe(tframe){};
};

/**
 * Return the time at a given offset, as a single datetime value
 **/    
datetime offset_time(const int shift, const int timeframe)
{

    static datetime dtbuff[1];
    CopyTime(_Symbol, timeframe, shift, 1, dtbuff);
    return dtbuff[0];
}


bool rates_at(const int offset, const ENUM_TIMEFRAMES timeframe, double &buffer[]) {
    static MqlRates rates[1];
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
