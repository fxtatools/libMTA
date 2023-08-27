#ifndef _LIBULT_MQ4
#define _LIBULT_MQ4

#property library
#property strict

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#include "indicator.mq4"

// Ultimate Oscillator
//
// @par Description
//
// The Ultimate Oscillator applies a moving average of three
// distinct periods, in factoring a coefficient of buying power
// over true range.
//
// By convention, the first period A=28, the second period B = A/2 = 14,
// and the third period C = A/4 = 7. These periods A, B, and C are denoted
// here as the primary, intermediate, and short periods of the oscillator.
//
// After calculating the linear weighted moving average for each component
// period, this implementation will sum the value of each component multiplied
// its scale factor, respectively 1, 2, and 4. The sum will be divided by the
// total weight, 7, then the value converted to percentage.
//
// In this implementation, the current percentage will be applied for the
// first calculation point. Subsequent calculation points will be recorded
// using a linear weighted moving average of the current and previous values.
//
// @par Adaptations
//
// - Support for periods other than 28. A period representing a multiple
//   of four would be preferred. For periods not a multiple of four, the
//   short and intermediate scale factors will applied as the integral
//   ceiling of (period / 4) and (period / 2) respectively.
//
// - Support for an applied price other than close, for determining the
//   true range and buying power components of the three respective periods
//   of the Ultimate Oscillator.
//
// - Utilizing a volume-weighted linear moving average for current and
//   previous Ultimate Oscillator values, when calculating a value to be
//   recorded in the indicator
//
// @par References
//
//   Kaufman, P. J. (2013). Momentum and Oscillators.
//     In Trading Systems and Methods Wiley. 402-403
//
//   Ultimate Oscillator: Definition, Formula, and Strategies (n.d)
//     Investopedia. https://www.investopedia.com/terms/u/ultimateoscillator.asp
//
class UltData : public PriceIndicator
{
protected:
    ValueBuffer<double> *ult_buffer;

public:
    const int period_main;
    const int period_half;    // scale factor 2
    const int period_quarter; // scale factor 4
    const int price_mode;

    UltData(const int period = 28,
            const int _price_mode = PRICE_CLOSE,
            const string _symbol = NULL,
            const int _timeframe = EMPTY,
            const bool _managed = true,
            const string _name = "Ult",
            const int _nr_buffers = EMPTY,
            const int _data_shift = EMPTY) : period_main(period),
                                             period_half((int)ceil((double)period / 2.0)),
                                             period_quarter((int)ceil((double)period / 4.0)),
                                             price_mode(_price_mode),
                                             PriceIndicator(_managed,
                                                            _name,
                                                            _nr_buffers == EMPTY ? classBufferCount() : _nr_buffers,
                                                            _symbol,
                                                            _timeframe,
                                                            // 1 additional for true range weighting
                                                            _data_shift == EMPTY ? period + 2 : _data_shift)
    {
        ult_buffer = data_buffers.get(0);
    }
    ~UltData()
    {
        FREEPTR(ult_buffer)
    }

    int classBufferCount() {
        return 1;
    }

    virtual string indicatorName()
    {
        return StringFormat("%s(%d)", name, period_main);
    }

    // True Low, adapted for previous price other than close after the Ultimate Oscillator
    double tlow(const int idx, MqlRates &rates[])
    {
        return fmin(rates[idx].low, priceFor(idx + 1, price_mode, rates));
    }

    // Buying Power, adapted for previous price other than close after the Ultimate Oscillator
    double bpow(const int idx, MqlRates &rates[])
    {
        return priceFor(idx, price_mode, rates) - tlow(idx, rates);
    }


    // Calculate a factored component of the Ultimate Oscillator
    double factor(const int period, const int idx, MqlRates &rates[], const double scale = EMPTY)
    {
        double sbpow = DBLZERO;
        double strng = DBLZERO;
        for (int n = idx + period - 1; n >= idx; n--)
        {
            sbpow += bpow(n, rates);
            /// using a mean of true range introduces a lot of volatility to the indicator
            strng += trueRange(n, price_mode, rates);
        }
        if (dblZero(strng))
        {
            return DBLZERO;
        }
        else if (scale == EMPTY)
        {
            return sbpow / strng;
        }
        else
        {
            return scale * sbpow / strng;
        }
    }

    virtual void calcMain(const int idx, MqlRates &rates[])
    {
        const MqlRates cur_rate = rates[idx];
        const double fact_a = factor(period_main, idx, rates);
        const double fact_b = factor(period_half, idx, rates, 2.0);
        const double fact_c = factor(period_quarter, idx, rates, 4.0);
        const double factored = (fact_a + fact_b + fact_c) / 7.0; // investopedia shows six here
        const double fact_p = (factored * 100.0);
        ///
        /// alternate scaling to percentage
        ///
        /// the Ult(28) value for this implementation will still oscillate
        /// within a narrow range - mainly, the 30 percentile range
        /// juxtaposed to the 50 percentile range with the previous
        // const double fact_p = 100.0 - (100.0 / (1.0 + factored));

        // ult_buffer.setState(fact_p);

        const double pre = ult_buffer.getState();
        if (pre == EMPTY_VALUE)
        {
            ult_buffer.setState(fact_p);
            return;
        }

        const double cur_weight = weightFor(period_main, period_main);
        const double pre_weight = weightFor(period_main - 1, period_main);

        double sum = (fact_p * cur_weight) + (pre * pre_weight);
        double weights = cur_weight + pre_weight;
        const int stop = idx + 1; // stop before previous
        for (int n = idx + period_main - 1, p_k = 1; n > stop; n--, p_k++)
        {
            const double early = ult_buffer.get(n);
            if (early != EMPTY_VALUE)
            {
                const double wfactor = weightFor(p_k, period_main);
                sum += (early * wfactor);
                weights += wfactor;
            }
        }
        /// further normalization with EMA
        const double cur = ema(pre, sum / weights, period_half);
        ult_buffer.setState(cur);
    }

    virtual int
    calcInitial(const int _extent, MqlRates &rates[])
    {
        const int calc_idx = _extent - 1 - period_main;
        ult_buffer.setState(DBLEMPTY);
        calcMain(calc_idx, rates);
        return calc_idx;
    }

    virtual int initIndicator(const int start = 0)
    {
        if (!PriceIndicator::initIndicator())
        {
            return -1;
        }
        int idx = start;
        if (!initBuffer(idx++, ult_buffer.data, "Ult"))
        {
            return -1;
        }
        return idx;
    }
};

#endif
