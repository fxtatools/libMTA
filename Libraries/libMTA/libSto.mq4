#ifndef _LIBSTO_MQ4
#define _LIBSTO_MQ4

#property library
#property strict

#property description "An adaptation of John Ehlers' Relative Vigor Index (John F. Ehlers, 2002)"

#include "indicator.mq4"
#include "trend.mq4"
#include "libMql4.mq4"

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
    return ((p - l) / (h - l)) * scale;
}

class StoData : public PriceIndicator
{
protected:
    PriceBuffer *k_buf; // STO buffer (series K)
    PriceBuffer *d_buf; // STO signal buffer (series D)
    const int shift_max;
    const int shift_min;

public:
    const int period_k;
    const int period_d;
    const int period_d_slow;
    const int price_mode;

    StoData(const int k = 10,
            const int d = 6,
            const int _price_mode = PRICE_CLOSE,
            const string _symbol = NULL,
            const int _timeframe = EMPTY,
            const string _name = "Sto",
            const int _data_shift = EMPTY,
            const int _nr_buffers = 2) : period_k(k), period_d(d),
                                         shift_max(fmax(k, d)), shift_min(fmin(k, d)),
                                         PriceIndicator(_name,
                                                        _nr_buffers,
                                                        _symbol,
                                                        _timeframe,
                                                        _data_shift == EMPTY ? ((k * 2) + d) : _data_shift)
    {
        k_buf = price_mgr.primary_buffer;
        d_buf = dynamic_cast<PriceBuffer *>(k_buf.next_buffer);
    }
    ~StoData()
    {
        // buffer deletion is managed under the buffer manager protocol
        k_buf = NULL;
        d_buf = NULL;
    }

    virtual string indicatorName()
    {
        //// D slow might be removed here
        // return StringFormat("%s(%d, %d, %d)", name, period_k, period_d, period_d_slow);
        return StringFormat("%s(%d, %d)", name, period_k, period_d);
    }

    virtual int dataBufferCount()
    {
        return 2;
    }

    void calcKMA(const int idx, MqlRates &rates[])
    {
        /// calculate the volume-weighted LWMA of Sto K factors
        double weights = DBLZERO;
        double k_cur = DBLZERO;
        for (int n = idx + period_k - 1, p_k = 1; n >= idx; n--, p_k++)
        {
            DEBUG(indicatorName() + " Calculate K [%d] at %d", p_k, n);
            const double wfactor = weightFor(p_k, period_k) * (double)rates[n].tick_volume;
            weights += wfactor;
            const double k_r = stoK(n, period_k, price_mode, rates, 1.0);
            const double k_calc = priceAdjusted(k_r, idx, price_mode, rates, period_k);
            /// 150, for translating the oscillator's range towards zero
            k_cur += k_calc * wfactor * 150.0;
        }
        k_cur /= weights;
        /// further translating the data to oscillate around zero
        k_cur -= 50.0;
        /// implementation note: this implementation of the Stochastic Oscillator
        /// may sometimes produce values such that fabs(value) > 100
        ///
        /// this may be due to the feature of price-change adjustment
        DEBUG(indicatorName() + " K [%d] %f", idx, k_cur);
        const double k_pre = k_buf.getState();
        if (k_pre == EMPTY_VALUE || dblZero(k_pre))
        {
            k_buf.setState(k_cur);
            // k_buf.setState(DBLZERO);
        }
        else
        {
            // const double k_ema = emaShifted(k_pre, k_cur, shift_max, shift_min);
            /// standard EMA is more effectively normal, for this volume-weighted LWMA
            const double k_ema = ema(k_pre, k_cur, period_k);
            DEBUG(indicatorName() + " K EMA [%d] %f", idx, k_ema);
            k_buf.setState(k_ema);
        }
    }

    void calcDMA(const int idx, MqlRates &rates[])
    {
        // calculate the non-volume-weighted LWMA of the Sto K line as D
        double weights = DBLZERO;
        double d_cur = DBLZERO;
        for (int n = idx + period_d - 1, p_k = 1; n >= idx; n--, p_k++)
        {
            const double wfactor = weightFor(p_k, period_d);
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
        const double d_ema = emaShifted(d_pre, d_cur, shift_max, shift_min);
        DEBUG(indicatorName() + " D EMA [%d] %f", idx, d_ema);
        d_buf.setState(d_ema);
    }

    void calcMain(const int idx, MqlRates &rates[])
    {

        calcKMA(idx, rates);
        const double k_rate = k_buf.getState();
        k_buf.set(idx, k_rate);
        calcDMA(idx, rates);
    }

    int calcInitial(const int _extent, MqlRates &rates[])
    {
        int calc_idx = _extent - 1 - dataShift();

        k_buf.setState(EMPTY_VALUE);
        d_buf.setState(EMPTY_VALUE);

        DEBUG(indicatorName() + " Calculate initial K from %d", calc_idx + (2 * period_k));
        for (int n = calc_idx + (2 * period_k); n >= calc_idx; n--)
        {
            calcKMA(calc_idx, rates);
            k_buf.set(n, k_buf.getState());
        }
        d_buf.setState(k_buf.getState());
        DEBUG(indicatorName() + " Calculate initial D from %d", calc_idx + period_d);
        for (int n = calc_idx + period_d; n >= calc_idx; n--)
        {
            calcDMA(calc_idx, rates);
            d_buf.set(n, d_buf.getState());
        }
        return calc_idx;
    }

    virtual int initIndicator(const int start = 0)
    {
        if (!PriceIndicator::initIndicator())
        {
            return -1;
        }
        int idx = start;
        if (!initBuffer(idx++, k_buf.data, "K"))
        {
            return -1;
        }
        if (!initBuffer(idx++, d_buf.data, "D"))
        {
            return -1;
        }
        return idx;
    }
};

#endif