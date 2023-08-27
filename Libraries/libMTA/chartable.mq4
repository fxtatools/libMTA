// chartable.mq4

#ifndef _CHARTABLE_MQ4
#define _CHARTABLE_MQ4 1

#property library
#property strict

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

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
    const int symbol_digits;
    const string chart_name;

    static double symbolPoints(const string _symbol = NULL)
    {
        return _symbol == NULL ? _Point : SymbolInfoDouble(_symbol, SYMBOL_POINT);
    }

    static int symbolDigits(const string _symbol = NULL)
    {
        return _symbol == NULL ? _Digits : (int)SymbolInfoInteger(_symbol, SYMBOL_DIGITS);
    }

public:
    Chartable(const string _symbol = NULL,
              const int _timeframe = EMPTY) : symbol(_symbol == NULL ? _Symbol : _symbol),
                                              timeframe(_timeframe == EMPTY ? _Period : _timeframe),
                                              chart_name(StringFormat("%s %d", symbol, timeframe)),
                                              points_ratio(symbolPoints(symbol)),
                                              symbol_digits(symbolDigits(symbol)){};
    
    double pointsPrice(const double marketPoints)
    {
        return marketPoints * points_ratio;
    };

    double pointsPrice(const double marketPoints) const
    {
        return marketPoints * points_ratio;
    };

    double pricePoints(const double marketPrice)
    {
        return marketPrice / points_ratio;
    };

    double pricePoints(const double marketPrice) const
    {
        return marketPrice / points_ratio;
    };

    string getChartName()
    {
        return chart_name;
    };

    string getChartName() const
    {
        return chart_name;
    };

    string getSymbol()
    {
        return symbol;
    };

    string getSymbol() const
    {
        return symbol;
    };

    int getSymbolDigits()
    {
        return symbol_digits;
    }

    int getSymbolDigits() const
    {
        return symbol_digits;
    }

    bool symbolTickInfo(MqlTick &tick)
    {
        const bool updated = SymbolInfoTick(symbol, tick);
        if (!updated)
        {
            Print(__FUNCSIG__ + ": Unable to update tick information");
            return false;
        }
        else
        {
            return true;
        }
    }

    int getTimeframe() const
    {
        return timeframe;
    };


    int getTimeframe()
    {
        return timeframe;
    };


    double getPointsRatio()
    {
        return points_ratio;
    }

    double getPointsRatio() const
    {
        return points_ratio;
    }

    double normalize(const double price)
    {
        return NormalizeDouble(price, getSymbolDigits());
    }

    double normalize(const double price) const
    {
        return NormalizeDouble(price, getSymbolDigits());
    }
};

string toString(Chartable &chartinfo) {
    return chartinfo.getChartName();
}

#endif
