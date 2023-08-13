#ifndef _LIBULT_MQ4
#define _LIBULT_MQ4

#property library
#property strict

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
    PriceBuffer *ult_buffer;

    /// state data for reversal detection

    // reversal data
    PriceBuffer *ult_rev; /// TBD
    // tick time for any previous reversal
    datetime last_rev_dt;
    // does the previous reversal begin a bearish trend?
    bool bearish;
    // highest previous reversal
    double rev_highest;
    // tick time for highest previous reversal
    datetime rev_highest_dt;
    // lowest previous reversal
    double rev_lowest;
    // tick time for lowest prevous reversal
    datetime rev_lowest_dt;

    // next previous lowest reversal
    double rev_lowest_pre;
    // next previous highest reversal
    double rev_highest_pre;
    // tick time for next previous lowest reversal
    datetime rev_lowest_pre_dt;
    // tick time for next previous highest reversal
    datetime rev_highest_pre_dt;

public:
    const int period_main;
    const int period_b; // scale factor 2
    const int period_c; // scale factor 4
    const int price_mode;

    UltData(const int period = 28,
            const int _price_mode = PRICE_CLOSE,
            const string _symbol = NULL,
            const int _timeframe = EMPTY,
            const string _name = "Ult",
            const int _nr_buffers = 2,
            const int _data_shift = EMPTY) : period_main(period),
                                             period_b((int)ceil((double)period / 2.0)),
                                             period_c((int)ceil((double)period / 4.0)),
                                             price_mode(_price_mode),
                                             // initialize state for reversal detection
                                             last_rev_dt(EMPTY),
                                             rev_highest(EMPTY),
                                             rev_highest_dt(EMPTY),
                                             rev_lowest(EMPTY),
                                             rev_lowest_dt(EMPTY),
                                             /// TBD
                                             rev_highest_pre(EMPTY),
                                             rev_lowest_pre(EMPTY),
                                             rev_highest_pre_dt(EMPTY),
                                             rev_lowest_pre_dt(EMPTY),
                                             // .
                                             bearish(false),
                                             // call base class ctor
                                             PriceIndicator(_name,
                                                            _nr_buffers,
                                                            _symbol,
                                                            _timeframe,
                                                            _data_shift == EMPTY ? period + 1 : _data_shift)
    {
        ult_buffer = dynamic_cast<PriceBuffer *>(price_mgr.primary_buffer);
        ult_rev = dynamic_cast<PriceBuffer *>(ult_buffer.next_buffer);
    }
    ~UltData()
    {
        FREEPTR(ult_buffer)
        FREEPTR(ult_rev)
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

    // True Range, adapted for previous price other than close after the Ultimate Oscillator
    double trange(const int idx, MqlRates &rates[])
    {
        const MqlRates cur = rates[idx];
        const double cur_high = cur.high;
        const double cur_low = cur.low;
        const double price_pre = priceFor(idx + 1, price_mode, rates);
        return fmax(cur_high - cur_low, fmax(cur_high - price_pre, price_pre - cur_low));
    }

    // Calculate a factored component of the Ultimate Oscillator
    double factor(const int period, const int idx, MqlRates &rates[], const double scale = EMPTY)
    {
        double sbpow = DBLZERO;
        double strng = DBLZERO;
        for (int n = idx + period - 1; n >= idx; n--)
        {
            sbpow += bpow(n, rates);
            strng += trange(n, rates);
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
        const double fact_b = factor(period_b, idx, rates, 2.0);
        const double fact_c = factor(period_c, idx, rates, 4.0);
        const double factored = (fact_a + fact_b + fact_c) / 7.0; // investopedia shows six here
        const double fact_p = factored * 100;

        // ult_buffer.setState(fact_p);

        const double pre = ult_buffer.getState();
        /* EMA
        if (pre == EMPTY_VALUE)
        {
            ult_buffer.setState(fact_p);
            return;
        } else {
            ult_buffer.setState(ema(pre, fact_p, period_main / 2));
        }
        return;
        */

        const MqlRates pre_rate = rates[idx + 1];

        // volume-weighted LWMA at 1/4 the main period
        const double cur_weight = 2 * (double)cur_rate.tick_volume;
        const double pre_weight = (double)pre_rate.tick_volume;
        double sum = (fact_p * cur_weight) + (pre * pre_weight);
        double weights = cur_weight + pre_weight;
        const int stop = idx + 1; // stop before previous
        for (int n = idx + period_c - 1, p_k = 1; n > stop; n--, p_k++)
        {
            const double early = ult_buffer.get(n);
            if (early == EMPTY_VALUE)
            {
                ult_buffer.setState(fact_p);
                return;
            }
            else
            {
                const double wfactor = weightFor(p_k, period_c) * (double)rates[n].tick_volume;
                sum += (early * wfactor);
                weights += wfactor;
            }
        }
        // ult_buffer.setState(sum/weights);
        //// further smoothing
        const double cur = ema(pre, sum / weights, period_c);
        ult_buffer.setState(cur);

        /// next: reversal detection

        bool rev = false;
        const datetime pre_dt = pre_rate.time;
        /// most recent is always empty with this buffer
        ult_rev.setState(EMPTY_VALUE);

        double far = ult_buffer.get(idx + 2);
        if (far == EMPTY_VALUE)
        {
            return;
        }

        if ((far <= pre) && (pre > cur))
        {
            /// pre is at a crest,
            /// marking the beginning (or continuation) of a bearish indicator reversal
            bearish = true;
            rev = true;
        }
        else if ((far >= pre) && (pre < cur))
        {
            /// pre is at a trough,
            /// marking the beginning (or continuation) of a bullish indicator reversal
            bearish = false;
            rev = true;
        }

        if (rev)
        {
            if (last_rev_dt == EMPTY)
            {
                last_rev_dt = pre_dt;
                ult_rev.set(idx + 1, pre);
                return;
            }
            else
            {
                const int rev_shift = iBarShift(symbol, timeframe, last_rev_dt);
                const double rev_val = ult_buffer.get(rev_shift);

                if ((bearish && (pre <= rev_val)) || (!bearish && (pre >= rev_val)))
                {
                    // update reversal buffer data within a continuing trend

                    // clear buffer data for previous reversal
                    ult_rev.set(rev_shift, EMPTY_VALUE);
                    if (bearish)
                    {
                        if (pre <= rev_lowest)
                        {
                            const int lowest_shift = iBarShift(symbol, timeframe, rev_lowest_dt);
                            ult_rev.set(lowest_shift, EMPTY_VALUE);
                            // update lowest
                            rev_lowest = pre;
                            rev_lowest_dt = pre_dt;
                        }
                        else
                        {
                            // ult_rev.set(idx + 1, 50.0); // DEBUG (reached when adding new chart bars)
                            return;
                        }
                    }
                    else /// when ! bearish
                    {
                        if (pre >= rev_highest)
                        {
                            const int highest_shift = iBarShift(symbol, timeframe, rev_highest_dt);
                            ult_rev.set(highest_shift, EMPTY_VALUE);
                            // update highest
                            rev_highest = pre;
                            rev_highest_dt = pre_dt;
                        }
                        else
                        {
                            // ult_rev.set(idx + 1, 50.0); // DEBUG (reached when adding new chart bars)
                            return;
                        }
                    }
                    // ...
                    last_rev_dt = pre_dt;
                    ult_rev.set(idx + 1, pre);
                }
                else
                {
                    // update reversal data for 'pre' at an inflection point

                    const bool scan_check = (rev_highest_dt != EMPTY) && (rev_lowest_dt != EMPTY) && (rev_highest_pre_dt != EMPTY) && (rev_lowest_pre_dt != EMPTY);

                    if (scan_check)
                    {
                        // Implementation Notes
                        //
                        // this would now simplify the reversal/trend line despite some
                        // albeit relatively minor intermediate crests and troughs
                        //
                        // the reversal detection still retains some intermediate crests
                        // and troughs, regardless
                        //
                        // at the newest trend in the chart, this function fails to draw
                        // a continuous line, within a majority of the time
                        //
                        // this  might be addressed with a more comprehensive scanback
                        // iterator, for a purpose of producing a consistent and accurate
                        // reversal series within the indicator itself.

                        if (bearish ? ((rev_highest < pre) && (rev_lowest < pre) && (rev_highest_pre >= pre)) : ((rev_highest > pre) && (rev_lowest > pre) && (rev_lowest_pre <= pre)))
                        {
                            const int highest_shift = iBarShift(symbol, timeframe, rev_highest_dt);
                            const int lowest_shift = iBarShift(symbol, timeframe, rev_lowest_dt);
                            DEBUG("RESET (%s, %s) ... %s", offset_time_str(highest_shift, symbol, timeframe), offset_time_str(lowest_shift, symbol, timeframe), offset_time_str(idx + 1, symbol, timeframe)); // reached

                            if (bearish)
                            {
                                ult_rev.set(highest_shift, EMPTY_VALUE);
                                rev_highest = rev_highest_pre;
                                rev_highest_dt = rev_highest_pre_dt;
                            }
                            else
                            {
                                ult_rev.set(lowest_shift, EMPTY_VALUE);
                                rev_lowest = rev_lowest_pre;
                                rev_lowest_dt = rev_lowest_pre_dt;
                            }
                        }
                    }

                    if (bearish)
                    {
                        rev_highest_pre = rev_highest;
                        rev_highest_pre_dt = rev_highest_dt;
                        rev_highest = pre;
                        rev_highest_dt = pre_dt;
                    }
                    else
                    {
                        rev_lowest_pre = rev_lowest;
                        rev_lowest_pre_dt = rev_lowest_dt;
                        rev_lowest = pre;
                        rev_lowest_dt = pre_dt;
                    }

                    last_rev_dt = pre_dt;
                    ult_rev.set(idx + 1, pre);
                }

                // const double revma = ema(...)
            }
        }
    }

    virtual int
    calcInitial(const int _extent, MqlRates &rates[])
    {
        const int calc_idx = _extent - 1 - period_main;
        ult_buffer.setState(EMPTY_VALUE);
        ult_rev.setState(EMPTY_VALUE);
        calcMain(calc_idx, rates);
        return calc_idx;
    }

    virtual int initIndicator(const int start = 0)
    {
        // FIXME update API : initIndicator => bool

        if (!PriceIndicator::initIndicator())
        {
            return -1;
        }
        int idx = start;
        if (!initBuffer(idx++, ult_buffer.data, "Ult"))
        {
            return -1;
        }
        if (!initBuffer(idx++, ult_rev.data, "UltRev", DRAW_SECTION))
        {
            return -1;
        }
        return idx;
    }
};

#endif
