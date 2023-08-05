// chartable.mq4

#ifndef _CHARTABLE_MQ4
#define _CHARTABLE_MQ4 1

#property library
#property strict

#include <libMql4.mq4>
#include <pricemode.mq4>

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
protected:
    const string symbol;
    const int timeframe;
    const double points_ratio;
    const int market_digits;

    static double symbolPoints(const string _symbol = NULL)
    {
        return _symbol == NULL ? _Point : SymbolInfoDouble(_symbol, SYMBOL_POINT);
    }

    static int symbolDigits(const string _symbol = NULL) {
        return  _symbol == NULL ? _Digits : (int)SymbolInfoInteger(_symbol, SYMBOL_DIGITS);
    }

public:
    Chartable(const string _symbol = NULL,
              const int _timeframe = EMPTY) : symbol(_symbol == NULL ? _Symbol : _symbol),
                                              timeframe(_timeframe == EMPTY ? _Period : _timeframe),
                                              points_ratio(symbolPoints(_symbol)),
                                              market_digits(symbolDigits(_symbol)){};

    double pointsPrice(const double marketPoints)
    {
        return marketPoints * points_ratio;
    };

    double pricePoints(const double marketPrice)
    {
        return marketPrice / points_ratio;
    };

    string getSymbol() const
    {
        return symbol;
    };

    int marketDigits()
    {
        return market_digits;
    }

    int getTimeframe() const
    {
        return timeframe;
    };

    double getPointsRatio() const
    {
        return points_ratio;
    }
};

#endif