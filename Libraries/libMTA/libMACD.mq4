// libMACD.mq4: MACD Indicator

#ifndef _LIBMACD_MQ4
#define _LIBMACD_MQ4 1

#include "indicator.mq4"

#property library
#property strict

/// @brief MACD Indicator
///
/// @see https://www.investopedia.com/terms/m/macd.asp
/// @see Pruitt, G. (2016). Chapter 2: Stochastics and Averages and RSI! Oh, My.
///     In The Ultimate Algorithmic Trading System Toolbox + Website (pp. 25–76).
///     John Wiley & Sons, Inc. https://doi.org/10.1002/9781119262992.ch2
///
class MACDData : public PriceIndicator
{

protected:
public:
    const int fast_p;
    const int slow_p;
    const bool fast_p_larger; // just in case ...
    const int signal_p;
    const int price_mode;

    // local reference for indicator data buffers
    PriceBuffer *fast_ema_buf;
    PriceBuffer *slow_ema_buf;
    PriceBuffer *macd_buf;
    PriceBuffer *signal_buf;
    // graphing buffers for macd/signal difference
    PriceBuffer *splus_buf;
    PriceBuffer *sminus_buf;

    MACDData(const int fast_ema,
             const int slow_ema,
             const int signal_ema,
             const int _price_mode,
             const string _symbol = NULL,
             const int _timeframe = EMPTY,
             const string _name = "MACD++",
             const int _data_shift = EMPTY,
             const int _nr_buffers = 6) : fast_p(fast_ema),
                                          slow_p(slow_ema),
                                          fast_p_larger(fast_ema > slow_ema),
                                          signal_p(signal_ema),
                                          price_mode(_price_mode),
                                          PriceIndicator(_name,
                                                         _nr_buffers,
                                                         _symbol,
                                                         _timeframe,
                                                         (_data_shift == EMPTY ? signal_p + (fast_p_larger ? fast_p : slow_p) : _data_shift))
    {
        fast_ema_buf = dynamic_cast<PriceBuffer *>(price_mgr.primary_buffer);
        slow_ema_buf = dynamic_cast<PriceBuffer *>(fast_ema_buf.next_buffer);
        macd_buf = dynamic_cast<PriceBuffer *>(slow_ema_buf.next_buffer);
        signal_buf = dynamic_cast<PriceBuffer *>(macd_buf.next_buffer);
        splus_buf = dynamic_cast<PriceBuffer *>(signal_buf.next_buffer);
        sminus_buf = dynamic_cast<PriceBuffer *>(splus_buf.next_buffer);
    };
    ~MACDData()
    {
        // buffer deletion will be managed under PriceIndicator
        fast_ema_buf = NULL;
        slow_ema_buf = NULL;
        macd_buf = NULL;
        signal_buf = NULL;
        splus_buf = NULL;
        sminus_buf = NULL;
    };

    string indicatorName() const
    {
        return StringFormat("%s(%d, %d, %d)", name, fast_p, slow_p, signal_p);
    }

    virtual int dataShift()
    {
        return data_shift;
    }

    double mean(const int period, const int idx, MqlRates &rates[])
    {
        // plain average, for EMA at (start - slowest_period)
        //
        // assumes time-series data
        int n = idx;
        int p_k = 0;
        double sum = DBLZERO;
        while (p_k < period)
        {
            const double p = priceFor(n++, price_mode, rates);
            DEBUG("mean price %f at %s", p, offset_time_str(n - 1));
            sum += p;
            p_k++;
        }
        return (sum / period);
    }

    // calculate Weighted MA for price, forward to a provided index, given period
    double wma(const double prev, const int period, const int idx, MqlRates &rates[])
    {
        // FIXME previous value is presently unused here.
        double cur_wema = __dblzero__;
        double weights = __dblzero__;
        const double double_p = double(period);
        for (int p_k = 1, n = idx + period; n >= idx; p_k++, n--)
        {
            // using a forward-weighted MA, starting the oldest 'k' factor at 1
            const double cur_price = priceFor(n, price_mode, rates);
            // const double wfactor = (double)p_k / double_p;
            const double wfactor = weightFor(p_k, period); // * (double) rates[n].tick_volume // TBD in MACD
            weights += wfactor;
            cur_wema += (cur_price * wfactor);
        }
        const double _wma = cur_wema / weights;
        DEBUG("WMA %d [%d] %f/%f => %f", period, idx, cur_wema, weights, _wma);
        return _wma;
        // return ema(prev, _wma, period);
    };

    virtual double bindFast(const int idx, MqlRates &rates[])
    {
        const double prev = fast_ema_buf.getState();
        DEBUG("Begin Fast WMA [%d] %f", idx, prev);
        const double rslt = wma(prev, fast_p, idx, rates);
        DEBUG("Bind Fast WMA [%d] %f => %f", idx, prev, rslt);
        fast_ema_buf.setState(rslt);
        return rslt;
    };

    virtual double bindSlow(const int idx, MqlRates &rates[])
    {
        const double prev = slow_ema_buf.getState();
        DEBUG("Begin Slow WMA [%d] %f", idx, prev);
        const double rslt = wma(prev, slow_p, idx, rates);
        DEBUG("Bind Slow WMA [%d] %f => %f", idx, prev, rslt);
        slow_ema_buf.setState(rslt);
        return rslt;
    };

    virtual double bindMacd(const int idx, MqlRates &rates[])
    {
        DEBUG("Begin MACD [%d]", idx);
        const double fast = bindFast(idx, rates);
        const double slow = bindSlow(idx, rates);
        const double diff = fast - slow;
        DEBUG("Bind MACD [%d] %f - %f = %f", idx, fast, slow, diff);
        macd_buf.setState(diff);
        return diff;
    };

    // Primary MACD calculation - bind MACD, MACD signal, and component values
    virtual void calcMain(const int idx, MqlRates &rates[])
    {
        DEBUG("Begin Signal EMA [%d]", idx);
        // EMA of MACD
        const double prev = signal_buf.getState();
        // sets slow, fast EMA and MACD by side effect
        const double cur = bindMacd(idx, rates);
        // const double rslt = prev == DBL_MIN ? cur : ema(prev, cur, signal_p);
        const double rslt = ema(prev, cur, signal_p);
        DEBUG("Bind Signal EMA [%d] %f", idx, rslt);
        signal_buf.setState(rslt);
    };

    // Initial MACD calculation - bind a simple average for MACD component values
    virtual int calcInitial(const int _extent, MqlRates &rates[])
    {
        // bind initial indicator component values using average
        const int slowest_p = fast_p_larger ? fast_p : slow_p;
        const int start_idx = _extent - (slowest_p + signal_p + 1);
        // fillState(start_idx + 1, extent - 1, EMPTY_VALUE);
        // bindMacd(start_idx, open, high, low, close);
        splus_buf.setState(EMPTY_VALUE);
        sminus_buf.setState(EMPTY_VALUE);
        fast_ema_buf.setState(mean(fast_p, start_idx, rates));
        slow_ema_buf.setState(mean(slow_p, start_idx, rates));
        // macd_buf.setState(_avg);
        macd_buf.setState(DBLZERO);
        signal_buf.setState(DBLZERO);
        DEBUG("Binding initial values [%d .. %d] %s", _extent, start_idx, offset_time_str(start_idx));
        return start_idx;
    };

    // restore buffer state, converting points values from data buffers to price values
    virtual void restoreState(const int idx)
    {
        fast_ema_buf.setState(fast_ema_buf.get(idx));
        slow_ema_buf.setState(slow_ema_buf.get(idx));
        macd_buf.setState(pointsPrice(macd_buf.get(idx)));
        signal_buf.setState(pointsPrice(signal_buf.get(idx)));
    }

    // store buffer state in indicator data buffers, adding MACD/signal difference
    // and converting price values to points
    virtual void storeState(const int idx)
    {
        fast_ema_buf.set(idx, fast_ema_buf.getState());
        slow_ema_buf.set(idx, slow_ema_buf.getState());
        const double macd = pricePoints(macd_buf.getState());
        const double signal = pricePoints(signal_buf.getState());
        macd_buf.set(idx, macd);
        signal_buf.set(idx, signal);
        const double sdiff = macd - signal;
        if (sdiff >= 0)
        {
            splus_buf.set(idx, sdiff);
            sminus_buf.set(idx, EMPTY_VALUE);
        }
        else
        {
            sminus_buf.set(idx, sdiff);
            splus_buf.set(idx, EMPTY_VALUE);
        }
    };

    virtual int dataBufferCount() const
    {
        // return the number of buffers used directly for this indicator.
        // should be incremented internally, in derived classes
        return 6;
    };

    // initialize indicator buffers
    virtual int initIndicator(const int start = 0)
    {
        PriceIndicator::initIndicator();
        int idx = start;
        if (!initBuffer(idx++, splus_buf.data, "Signal+", DRAW_HISTOGRAM)) {
            return -1;
        }
        if (!initBuffer(idx++, sminus_buf.data, "Signal-", DRAW_HISTOGRAM)) {
            return -1;
        }
        if (!initBuffer(idx++, macd_buf.data, "MACD")) {
            return -1;
        }
        if (!initBuffer(idx++, signal_buf.data, "Signal")) {
            return -1;
        }
        ///
        /// non-drawn buffers
        ///
        if (!initBuffer(idx++, slow_ema_buf.data, NULL)) {
            return -1;
        }
        if (!initBuffer(idx++, fast_ema_buf.data, NULL)) {
            return -1;
        }
        return idx;
    };
};

#endif
