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

extern bool debug = true;

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
        if (debug) Alert(StringFormat("Initialized charatble: %s %d", symbol, timeframe.period));
    };
    Chartable(ENUM_TIMEFRAMES tframe) : symbol(_Symbol), timeframe(tframe){};
    Chartable(string s) : symbol(s), timeframe(_Period){};
    Chartable(string s, ENUM_TIMEFRAMES tframe) : symbol(s), timeframe(tframe){};
};

/**
 * Return the time at a given offset, as a single datetime value
 **/
datetime offset_time(int shift)
{
    ENUM_TIMEFRAMES timeframe = cur_timeframe;
    string symbol = cur_symbol;

    datetime dtbuff[1];
    CopyTime(symbol, timeframe, shift, 1, dtbuff);
    return dtbuff[0];
}
