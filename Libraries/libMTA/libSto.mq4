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
    ValueBuffer<double> *k_buf; // STO buffer (series K)
    ValueBuffer<double> *d_buf; // STO signal buffer (series D)
    const int shift_max;
    const int shift_min;

public:
    const int period_k;
    const int period_d;
    const int price_mode;

    StoData(const int k = 10,
            const int d = 6,
            const int _price_mode = PRICE_CLOSE,
            const string _symbol = NULL,
            const int _timeframe = EMPTY,
            const bool _managed = true,
            const string _name = "Sto",
            const int _data_shift = EMPTY,
            const int _nr_buffers = EMPTY) : period_k(k), period_d(d),
                                             shift_max(fmax(k, d)),
                                             shift_min(shift_max - fmin(k, d)),
                                             PriceIndicator(_managed, _name,
                                                            _nr_buffers == EMPTY ? classBufferCount() : _nr_buffers,
                                                            _symbol, _timeframe,
                                                            _data_shift == EMPTY ? ((k * 2) + d) : _data_shift)
    {
        // FIXME use nthBuffer() for this part of the ctor - throughout the indicator base -
        // with the updated API
        k_buf = nthBuffer(0);
        d_buf = nthBuffer(1);
    }
    ~StoData()
    {
        // buffer deletion is managed under the buffer manager protocol
        k_buf = NULL;
        d_buf = NULL;
    }

    int classBufferCount()
    {
        return 2;
    }

    double valueK(const int idx)
    {
        return k_buf.get(idx);
    }
    double valueD(const int idx)
    {
        return d_buf.get(idx);
    }
    double valueK(const int idx) const
    {
        return k_buf.get(idx);
    }
    double valueD(const int idx) const
    {
        return d_buf.get(idx);
    }

    void bindMax(PriceReversal &_revinfo, const int begin = 0, const int end = EMPTY, const double limit = DBL_MAX)
    {
        //_revinfo.bindMax(k_buf, this, begin, end, limit == DBL_MAX ? DBLZERO : limit);
        _revinfo.bindMax(k_buf, this, begin, end, limit);
    }

    void bindMin(PriceReversal &_revinfo, const int begin = 0, const int end = EMPTY, const double limit = DBL_MIN)
    {
        // _revinfo.bindMin(k_buf, this, begin, end, limit == DBL_MIN ? DBLZERO : limit);
        _revinfo.bindMin(k_buf, this, begin, end, limit);
    }

    virtual string indicatorName()
    {
        return StringFormat("%s(%d, %d)", name, period_k, period_d);
    }

    void calcKMA(const int idx, MqlRates &rates[])
    {
        /// calculate the volume-weighted LWMA of Sto K factors
        double weights = DBLZERO;
        double k_cur = DBLZERO;
        for (int n = idx + period_k - 1, p_k = 1; n >= idx; n--, p_k++)
        {
            DEBUG(indicatorName() + " Calculate K [%d] at %d", p_k, n);
            // const double wfactor = weightFor(p_k, period_k) * (double)rates[n].tick_volume;
            /// TBD weighting the MA on true range - also in the local CCI implementation
            const double wfactor = weightFor(idx, rates, price_mode, p_k, period_k);
            weights += wfactor;
            const double k_r = stoK(n, period_k, price_mode, rates, 1.0);
            // const double k_calc = k_r; // [C]
            const double k_calc = priceAdjusted(k_r, idx, price_mode, rates, period_k); // [A]
            // const double k_calc =  100.0 - (100.0 / (1.0 + k_r)); // oscillates below 50 [B]
            /// 150, for translating the oscillator's range towards zero [A]
            k_cur += k_calc * wfactor * 150.0; // [A]
            // k_cur += k_calc * wfactor; // [D]
        }
        k_cur /= weights;

        /// further translating the data to oscillate around zero
        k_cur -= 50.0; // [A]
        // k_cur -= 100.0; // [E]
        /// implementation note: this implementation of the Stochastic Oscillator
        /// may sometimes produce values such that fabs(value) > 100
        ///
        /// this may be due to the feature of price-change adjustment
        DEBUG(indicatorName() + " K [%d] %f", idx, k_cur);
        const double k_pre = k_buf.getState();
        if (k_pre == EMPTY_VALUE || dblZero(k_pre))
        {
            k_buf.setState(k_cur);
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
        // calculate the non-volume-weighted LWMA of the Sto K line,
        // then the shifted EMA of this LWMA and the previous D value
        // as current D.
        //
        // the max of the K and D periods is used as the EMA period,
        // here, while the difference between the max of the K and D
        // periods and the min of the K and D periods is used as the
        // EMA shift, in this shifted EMA calculation
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
        k_buf.storeState(idx, k_rate);
        calcDMA(idx, rates);
    }

    int calcInitial(const int _extent, MqlRates &rates[])
    {
        int calc_idx = _extent - 1 - dataShift();

        k_buf.setState(DBLEMPTY);
        d_buf.setState(DBLEMPTY);

        DEBUG(indicatorName() + " Calculate initial K from %d", calc_idx + (2 * period_k));
        for (int n = calc_idx + (2 * period_k); n >= calc_idx; n--)
        {
            calcKMA(calc_idx, rates);
            const double _k = k_buf.getState();
            k_buf.storeState(n, _k);
        }
        const double _last_k = k_buf.getState(); 
        d_buf.setState(_last_k);
        DEBUG(indicatorName() + " Calculate initial D from %d", calc_idx + period_d);
        for (int n = calc_idx + period_d; n >= calc_idx; n--)
        {
            calcDMA(calc_idx, rates);
            const double _d = d_buf.getState();
            d_buf.storeState(n, _d);
        }
        return calc_idx;
    }

    int initIndicator(const int start = 0)
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
