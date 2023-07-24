// chartable.mq4 (prototype)

#ifndef _CHARTABLE_MQ4
#define _CHARTABLE_MQ4 1

#include <libMql4.mq4>

/*
union Timeframe
{
    ENUM_TIMEFRAMES timeframe;
    int period;

public:
    Timeframe() : period(_Period){};
    Timeframe(int duration) : period(duration){};
    Timeframe(ENUM_TIMEFRAMES tframe) : timeframe(tframe){};
};
*/

class Chartable
{
public:
    const string symbol;
    const int timeframe;

    Chartable(const string _symbol = NULL, const int _timeframe = EMPTY) : symbol(_symbol == NULL ? _Symbol : _symbol), timeframe(_timeframe == EMPTY ? _Period : _timeframe){};
};

#endif