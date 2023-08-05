// RatesBuffer prototype - MqlRates interface

#ifndef _RATESBUFFER_MQ4
#define _RATESBUFFER_MQ4 1

#property library
#property strict

#include "rates.mq4"
#include "chartable.mq4"


template <typename T>
class ObjectBuffer : public DataBuffer<T>
{ // FIXME used singularly for ratesbuffer

public:
    ObjectBuffer(const int _extent = 0, const bool as_series = true) : DataBuffer(_extent, as_series){};

    T get(const int idx)
    {
        // this assumes a value has been initialized at idx
        return data[idx];
    };

    T getState()
    {
        return initial_state;
    }

    void set(const int idx, T &datum)
    {
        // this assumes the buffer's extent is already > idx
        //
        // method definition unusable for RatesBuffer
        data[idx] = datum;
    };

    void setState(T &datum)
    {
        // method definition unusable for RatesBuffer
        initial_state = datum;
    }
};

class RatesBuffer : public ObjectBuffer<MqlRates>
{
    // no multiple inheritance for C++-like classes defined in MQL.
    // This class stores a Chartable locally, rather than inheriting
    // from Chartable.

protected:
    Chartable *chartInfo;

public:
    RatesBuffer(const int _extent = 0, const bool as_series = true, const string symbol = NULL, const int timeframe = EMPTY) : ObjectBuffer<MqlRates>(_extent, as_series)
    {
        chartInfo = new Chartable(symbol == NULL ? _Symbol : symbol, timeframe == EMPTY ? _Period : timeframe);
    };
    ~RatesBuffer()
    {
        FREEPTR(chartInfo);
    };

    /// TBD b.c MQL is broken in nearly all of C++ pointer handling
    void set(const int idx, const MqlRates &datum)
    {
        data[idx] = datum;
    };

    void setState(const MqlRates &datum) {
        initial_state = datum;
    }

    void setChartInfo(const string symbol = NULL, const int timeframe = EMPTY)
    {
        // not thread-safe
        Chartable *pre = chartInfo;
        const bool pre_p = (CheckPointer(pre) == POINTER_DYNAMIC);
        const string _symbol = symbol == NULL ? (pre_p ? pre.symbol : _Symbol) : symbol;
        const int _timeframe = timeframe == EMPTY ? (pre_p ? pre.timeframe : _Period) : timeframe;
        chartInfo = new Chartable(_symbol, _timeframe);
        if (pre_p)
            delete pre;
    };

    string symbol()
    {
        return chartInfo.symbol;
    };

    int timeframe()
    {
        return chartInfo.timeframe;
    }

    // TBD: latest_quote_dt here
    bool getRates(const int count = EMPTY, const int start = 0, const int padding = EMPTY)
    {
        const int nr_rates = count == EMPTY ? extent : count;
        if(!setExtent(nr_rates, padding))
            return false;
        const int rslt = CopyRates(chartInfo.symbol, chartInfo.timeframe, start, nr_rates, this.data);
        if (rslt == -1)
            return false;
        else
            return true;
    };
};

/* MQL4 compiler doesn't parse this
typedef void *__voidptr__ ;
*/

/* MQL4 compiler fails to compile this
typedef MqlRates *thunk[];
*/

/* MQL4 compiler fails to compile this
using std::nullptr_t;
*/


class RatesMgr : public BufferMgr<RatesBuffer>
{
protected:
    // a bit of indirection presently, for a novel prototype
    // - provides operator[] for open, high, etc.
    // - does not provide const double[] access to the same data
    // - succinct, though by-in-large utterly useless in MQL
    //
    class VirtRatesBuffer {
    public:
        const RatesMgr *mgr;
        VirtRatesBuffer(RatesMgr *_mgr) : mgr(_mgr) {};
    };

    class VirtOpenBuffer : VirtRatesBuffer {
    public:
        VirtOpenBuffer(RatesMgr *_mgr) : VirtRatesBuffer(_mgr) {};
        double operator[](const int idx) const {
            return mgr.primary_buffer.data[idx].open;
        };
    };

    class VirtHighBuffer : VirtRatesBuffer {
    public:
        VirtHighBuffer(RatesMgr *_mgr) : VirtRatesBuffer(_mgr) {};
        double operator[](const int idx) const {
            return mgr.primary_buffer.data[idx].high;
        };
    };

    class VirtLowBuffer : VirtRatesBuffer {
    public:
        VirtLowBuffer(RatesMgr *_mgr) : VirtRatesBuffer(_mgr) {};
        double operator[](const int idx) const {
            return mgr.primary_buffer.data[idx].low;
        };
    };

    class VirtCloseBuffer : VirtRatesBuffer {
    public:
        VirtCloseBuffer(RatesMgr *_mgr) : VirtRatesBuffer(_mgr) {};
        double operator[](const int idx) const {
            return mgr.primary_buffer.data[idx].close;
        };
    };

    class VirtTimeBuffer : VirtRatesBuffer {
    public:
        VirtTimeBuffer(RatesMgr *_mgr) : VirtRatesBuffer(_mgr) {};
        datetime operator[](const int idx) const {
            return mgr.primary_buffer.data[idx].time;
        };
    };

  class VirtVolBuffer : VirtRatesBuffer {
    public:
        VirtVolBuffer(RatesMgr *_mgr) : VirtRatesBuffer(_mgr) {};
        long operator[](const int idx) const {
            return mgr.primary_buffer.data[idx].tick_volume;
        };
    };


public:

    VirtOpenBuffer *open;
    VirtHighBuffer *high;
    VirtLowBuffer *low;
    VirtCloseBuffer *close;
    VirtTimeBuffer *time;
    VirtVolBuffer *volume;

    RatesMgr(const int _extent = 0, const bool as_series = true, const string symbol = NULL, const int timeframe = EMPTY) : BufferMgr<RatesBuffer>(_extent, as_series)
    {
        primary_buffer.setChartInfo(symbol, timeframe);
        open = new VirtOpenBuffer(&this);
        high = new VirtHighBuffer(&this);
        low = new VirtLowBuffer(&this);
        close = new VirtCloseBuffer(&this);
        time = new VirtTimeBuffer(&this);
        volume = new VirtVolBuffer(&this);
    };
    ~RatesMgr() {
        FREEPTR(primary_buffer);
        FREEPTR(open);
        FREEPTR(high);
        FREEPTR(low);
        FREEPTR(close);
        FREEPTR(time);
        FREEPTR(volume);
    }

    bool getRates(const int count = EMPTY, const int start = 0, const int padding = EMPTY)
    {
        // uses the last configured extent if count is EMPTY.
        //
        // initial extent is 0, by default
        return primary_buffer.getRates(count, start);
    }

};

#endif
