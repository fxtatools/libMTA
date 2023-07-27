// chartable.mq4 (prototype)

#ifndef _CHARTABLE_MQ4
#define _CHARTABLE_MQ4 1

#include <libMql4.mq4>


union Timeframe // for purpose of testing
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
public:
    const string symbol;
    const int timeframe;
    const double points_ratio;

    Chartable(const string _symbol = NULL, const int _timeframe = EMPTY) : symbol(_symbol == NULL ? _Symbol : _symbol), timeframe(_timeframe == EMPTY ? _Period : _timeframe), points_ratio(_symbol == NULL ? _Point :  SymbolInfoDouble(_symbol, SYMBOL_POINT)) {};
    
    double pointsPrice(const double marketPoints) {
        return marketPoints * points_ratio;
    };

    double pricePoints(const double marketPrice) {
        return marketPrice / points_ratio;
    };

};

#endif