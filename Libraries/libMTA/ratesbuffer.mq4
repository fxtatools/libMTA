// RatesBuffer prototype - MqlRates interface

#ifndef _RATESBUFFER_MQ4
#define _RATESBUFFER_MQ4 1

#property library
#property strict

#include "rates.mq4"
#include "chartable.mq4"
#include <stdlib.mqh>

class RatesBuffer : public SeriesBuffer<MqlRates> // public ObjectBuffer<MqlRates>
{
    // no multiple inheritance for C++-like classes defined in MQL.
    // This class stores a Chartable locally, rather than inheriting
    // from Chartable.

protected:
    datetime latest_quote_dt;
    Chartable *chart_info;

public:
    RatesBuffer(const int _extent = 0,
                const bool as_series = true,
                const string symbol = NULL,
                const int timeframe = EMPTY) : latest_quote_dt(0),
                                               SeriesBuffer<MqlRates>(_extent, as_series)
    // ObjectBuffer<MqlRates>(_extent, as_series)
    {
        chart_info = new Chartable(symbol == NULL ? _Symbol : symbol, timeframe == EMPTY ? _Period : timeframe);
    };
    ~RatesBuffer()
    {
        FREEPTR(chart_info);
    };


    void setChartInfo(const string symbol = NULL, const int timeframe = EMPTY)
    {
        // not thread-safe
        Chartable *pre = chart_info;
        const bool pre_p = (CheckPointer(pre) == POINTER_DYNAMIC);
        const string _symbol = symbol == NULL ? (pre_p ? pre.getSymbol() : _Symbol) : symbol;
        const int _timeframe = timeframe == EMPTY ? (pre_p ? pre.getTimeframe() : _Period) : timeframe;
        chart_info = new Chartable(_symbol, _timeframe);
        if (pre_p)
            delete pre;
    };

    Chartable *getChartInfo()
    {
        return chart_info;
    }

    string symbol()
    {
        return chart_info.getSymbol();
    };

    int timeframe()
    {
        return chart_info.getTimeframe();
    }

    int ratesToCopy()
    {
        return iBars(chart_info.getSymbol(), chart_info.getTimeframe());
    }

    bool getRates(const int count = EMPTY, const int start = 0)
    {
        ResetLastError();
        const int nr_rates = count == EMPTY ? ratesToCopy() : count;
            return false;
        const int rslt = ArrayCopyRates(data, chart_info.getSymbol(), chart_info.getTimeframe());
        if (rslt == -1)
        {
            const int errno = GetLastError();
            printf(__FUNCSIG__ + " Unable to transfer %d rates", nr_rates);
            DEBUG(__FUNCSIG__ + " [%d] %s", errno, ErrorDescription(errno));
            return false;
        }
        else if (rslt < nr_rates)
        {
            /// this may be reached e.g in the strategy tester, which may produce at most
            /// 1002 previous rates at the start of the testing period - much to
            /// the chagrin of any effort to debug the procedural aspects of the EA
            const int errno = GetLastError();
            DEBUG(__FUNCSIG__ + " Received fewer rates than requested requested: %d, %d (%d)", rslt, nr_rates, ArraySize(data));
            DEBUG(__FUNCSIG__ + " [%d] %s", errno, ErrorDescription(errno));
            return false;
        }
        else
        {
            DEBUG(__FUNCSIG__ + " Transferred %d rates => %d", rslt, ArraySize(data));
        }
        extent = rslt;
        latest_quote_dt = data[start].time;
        return true;
    };
};

#endif
