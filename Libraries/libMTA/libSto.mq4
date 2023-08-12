#ifndef _LIBSTO_MQ4
#define _LIBSTO_MQ4

#property library
#property strict

#property description "An adaptation of John Ehlers' Relative Vigor Index (John F. Ehlers, 2002)"

#include "indicator.mq4"
#include "trend.mq4"
#include <libMql4.mq4>

// Stochastic Oscilator
// refs:
// Pruitt, G. (2016). Stochastics and Averages and RSI! Oh, My. In The Ultimate Algorithmic Trading System Toolbox + Website (pp. 25–76). John Wiley & Sons, Inc. https://doi.org/10.1002/9781119262992.ch2

double highest(const int idx, const int period, MqlRates &rates[])
{
    double p_ext = DBLZERO;
    for (int n = idx + period - 1; n >= idx; n--)
    {
        const double p = rates[n].high;
        if (p > p_ext)
        {
            p_ext = p;
        }
    }
    return p_ext;
}

double lowest(const int idx, const int period, MqlRates &rates[])
{
    double p_ext = DBLZERO;
    for (int n = idx + period - 1; n >= idx; n--)
    {
        const double p = rates[n].low;
        if (p < p_ext)
        {
            p_ext = p;
        }
    }
    return p_ext;
}

double stoK(const int idx,
            const int period,
            const int price_mode,
            MqlRates &rates[],
            const double scale = 100.0)
{
    const double p = priceFor(idx, price_mode, rates);
    const double l = lowest(idx, period, rates);
    const double h = highest(idx, period, rates);
    return (p - l) / (h - l) * scale;
}

class StoData : public PriceIndicator
{
protected:
    PriceBuffer *k_buf; // STO buffer
    PriceBuffer *d_buf; // STO signal buffer
    PriceBuffer *d_slow_buf; // TBD
    PriceXOver *xover;

public:
    const int period_k;
    const int period_d;
    const int period_d_slow;
    const int price_mode;

    StoData(const int k = 14,
          const int d = 3,
          const int d_slow = 3,
          const int _price_mode = PRICE_CLOSE,
          const string _symbol = NULL,
          const int _timeframe = EMPTY,
          const string _name = "Sto",
          const int _data_shift = EMPTY,
          const int _nr_buffers = 3) : period_k(k), period_d(d), period_d_slow(d_slow),
                                       PriceIndicator(_name,
                                                      _nr_buffers,
                                                      _symbol,
                                                      _timeframe,
                                                      _data_shift == EMPTY ? ((k * 2) + d + d_slow) : _data_shift)
    {
        k_buf = price_mgr.primary_buffer;
        d_buf = dynamic_cast<PriceBuffer*>(k_buf.next_buffer);
        d_slow_buf = dynamic_cast<PriceBuffer*>(d_buf.next_buffer);
        xover = new PriceXOver();
    }
    ~StoData()
    {
        // buffer deletion is managed under the buffer manager protocol
        k_buf = NULL;
        d_buf = NULL;
        d_slow_buf = NULL;
        FREEPTR(xover);
    }

    virtual string indicatorName() const
    {
        //// D slow might be removed here
        // return StringFormat("%s(%d, %d, %d)", name, period_k, period_d, period_d_slow);
        return StringFormat("%s(%d, %d)", name, period_k, period_d);
    }

    virtual int dataBufferCount()
    {
        return 4;
    }

    void calcKMA(const int idx, MqlRates &rates[])
    {
        // calculate the current weighted mean of K, for subsequent EMA factoring
        double weights = DBLZERO;
        double k_cur = DBLZERO;
        for (int n = idx + period_k - 1, p_k = 1; n >= idx; n--, p_k++)
        {
            DEBUG(indicatorName() + " Calculate K [%d] at %d", p_k, n);
            const double wfactor = weightFor(p_k, period_k) * (double) rates[n].tick_volume;
            weights += wfactor;
            const double k = stoK(n, period_k, price_mode, rates);
            k_cur += (k * wfactor);
        }
        k_cur /= weights;
        DEBUG(indicatorName() + " K [%d] %f", idx, k_cur);

        const double k_pre = k_buf.getState();
        if (k_pre == EMPTY_VALUE)
        {
            k_buf.setState(k_cur);
            return;
        }
        const double k_ema = ema(k_pre, k_cur, period_k);
        k_buf.setState(k_ema);
        DEBUG(indicatorName() + " K EMA [%d] %f", idx, k_ema);
    }

    void calcDMA(const int idx, MqlRates &rates[])
    {
        double weights = DBLZERO;
        double d_cur = DBLZERO;
        for (int n = idx + period_d - 1, p_k = 1; n >= idx; n--, p_k++)
        {
            const double wfactor = weightFor(p_k, period_d) * (double) rates[n].tick_volume;
            weights += wfactor;
            const double kval = k_buf.get(n);
            if (kval == EMPTY_VALUE)
            {
                printf(indicatorName() + " K undefined at %d", n);
                return;
            }
            d_cur += (kval * wfactor);
        }
        d_cur /= weights;
        DEBUG(indicatorName() + " D [%d] %f", idx, d_cur);
        const double d_pre = d_buf.getState();
        if (d_pre == EMPTY_VALUE)
        {
            d_buf.setState(d_cur);
            return;
        }
        const double d_ema = ema(d_pre, d_cur, period_d);
        DEBUG(indicatorName() + " D EMA [%d] %f", idx, d_ema);
        d_buf.setState(d_ema);
    }

    void calcDsMA(const int idx, MqlRates &rates[])
    {
        double weights = DBLZERO;
        double d_s_cur = DBLZERO;
        for (int n = idx + period_d_slow - 1, p_k = 1; n >= idx; n--, p_k++)
        {
            const double wfactor = weightFor(p_k, period_d_slow) * (double) rates[n].tick_volume;
            weights += wfactor;
            const double dval = d_buf.get(n);
            if (dval == EMPTY_VALUE)
            {
                printf("D slow undefined at %d", n);
                return;
            }
            d_s_cur += (dval * wfactor);
        }
        d_s_cur /= weights;
        DEBUG(indicatorName() + " Ds [%d] %f", idx, d_s_cur);
        const double d_s_pre = d_slow_buf.getState();
        if (d_s_pre == EMPTY_VALUE)
        {
            d_slow_buf.setState(d_s_cur);
            return;
        }
        const double d_s_ema = ema(d_s_pre, d_s_cur, period_d_slow);
        DEBUG(indicatorName() + " Ds EMA [%d] %f", idx, d_s_ema);
        d_slow_buf.setState(d_s_ema);
    }

    void calcMain(const int idx, MqlRates &rates[])
    {

        calcKMA(idx, rates);
        k_buf.set(idx, k_buf.getState());
        calcDMA(idx, rates);
        d_buf.set(idx, d_buf.getState());
        calcDsMA(idx, rates);
        d_slow_buf.set(idx, d_slow_buf.getState());
    }

    int calcInitial(const int _extent, MqlRates &rates[])
    {
        int calc_idx = _extent - 1 - dataShift();

        k_buf.setState(EMPTY_VALUE);
        d_buf.setState(EMPTY_VALUE);
        d_slow_buf.setState(EMPTY_VALUE);

        DEBUG(indicatorName() + " Calculate initial K from %d", calc_idx);
        for (int n = calc_idx + (2 * period_k); n >= calc_idx; n--)
        {
            calcKMA(calc_idx, rates);
            k_buf.set(n, k_buf.getState());
        }
        d_buf.setState(k_buf.getState());
        for (int n = calc_idx + period_d; n >= calc_idx; n--)
        {
            calcDMA(calc_idx, rates);
            d_buf.set(n, d_buf.getState());
        }
        d_slow_buf.setState(d_buf.getState());
        for (int n = calc_idx + period_d_slow; n >= calc_idx; n--)
        {
            calcDsMA(calc_idx, rates);
            d_slow_buf.set(n, d_slow_buf.getState());
        }
        return calc_idx;
    }

    virtual int initIndicator(const int start = 0)
    {
        if (!PriceIndicator::initIndicator()) {
            return -1;
        }
        int idx = start;
        if (!initBuffer(idx++, k_buf.data, "K")) {
            return -1;
        }
        if (!initBuffer(idx++, d_buf.data, "D")) {
            return -1;
        }
        if (!initBuffer(idx++, d_slow_buf.data, "Ds")) {
            // TBD removing removing d_slow here.
            // It's not useful here, other than for interest of convention
            return -1;
        }
        return idx;
    }
};

#endif