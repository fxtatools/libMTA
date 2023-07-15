// chartable.mq4 (prototype)

#ifndef _CHARTABLE_MQ4
#define _CHARTABLE_MQ4 1

#include <libMql4.mq4>

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

#endif