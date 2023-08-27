// pricemode.mq4

#property library
#property strict

#ifndef _PRICEMODE_MQ4
#define _PRICEMODE_MQ4 1

/// including the weightFor() definition
#ifndef _LIBMQL4_MQ4
#include "libMql4.mq4"
#endif

#ifndef DBLZERO_DEFINED
#define DBLZERO_DEFINED 1
const int __dblzero__ = 0.0;
#ifndef DBLZERO
#define DBLZERO __dblzero__
#endif
#endif

enum ENUM_PRICE_MODE
{
    PRICE_MODE_CLOSE = PRICE_CLOSE,                         // Quote Close Price
    PRICE_MODE_OPEN = PRICE_OPEN,                           // Quote Open Price
    PRICE_MODE_HIGH = PRICE_HIGH,                           // Quote High Price
    PRICE_MODE_LOW = PRICE_LOW,                             // Quote Low Price
    PRICE_MODE_MEDIAN = PRICE_MEDIAN,                       // Median Price
    PRICE_MODE_TYPICAL = PRICE_TYPICAL,                     // Typical Price
    PRICE_MODE_WEIGHTED = PRICE_WEIGHTED,                   // Weighted Price
    PRICE_MODE_TYPICAL_OPEN = PRICE_WEIGHTED + 1,           // Typical Price From Open
    PRICE_MODE_WEIGHTED_OPEN = PRICE_MODE_TYPICAL_OPEN + 1, // Open-Weighted Price
};

double priceFor(const int idx,
                const int mode,
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[])
{
    switch (mode)
    {
    case PRICE_CLOSE:
        return close[idx];
    case PRICE_OPEN:
        return open[idx];
    case PRICE_HIGH:
        return high[idx];
    case PRICE_LOW:
        return low[idx];
    case PRICE_MODE_MEDIAN:
        return (high[idx] + low[idx]) / 2.0;
    case PRICE_MODE_TYPICAL:
        return (high[idx] + low[idx] + close[idx]) / 3.0;
    case PRICE_MODE_WEIGHTED:
        return (high[idx] + low[idx] + (close[idx] * 2)) / 4.0;
    case PRICE_MODE_TYPICAL_OPEN:
        return (high[idx] + low[idx] + open[idx]) / 3.0;
    case PRICE_MODE_WEIGHTED_OPEN:
        return (high[idx] + low[idx] + (open[idx] * 2)) / 4.0;
    default:
    {
        printf("Unknown price mode %d", mode);
        return __dblzero__;
    }
    }
}

double priceFor(const MqlRates &rinfo, const int mode)
{
    switch (mode)
    {
    case PRICE_CLOSE:
        return rinfo.close;
    case PRICE_OPEN:
        return rinfo.open;
    case PRICE_HIGH:
        return rinfo.high;
    case PRICE_LOW:
        return rinfo.low;
    case PRICE_MODE_MEDIAN:
        return (rinfo.high + rinfo.low) / 2.0;
    case PRICE_MODE_TYPICAL:
        return (rinfo.high + rinfo.low + rinfo.close) / 3.0;
    case PRICE_MODE_WEIGHTED:
        return (rinfo.high + rinfo.low + (2.0 * rinfo.close)) / 4.0;
    case PRICE_MODE_TYPICAL_OPEN:
        return (rinfo.high + rinfo.low + rinfo.open) / 3.0;
    case PRICE_MODE_WEIGHTED_OPEN:
        return (rinfo.high + rinfo.low + (2.0 * rinfo.open)) / 4.0;
    default:
    {
        printf(__FUNCSIG__ + ": Unknown price mode %d", mode);
        return __dblzero__;
    }
    }
}
double priceFor(const int idx,
                const int mode,
                MqlRates &rates[])
{
    const MqlRates rateinfo = rates[idx];
    return priceFor(rateinfo, mode);
}

//
//
//

/// @brief calculate True Range for a provided offset and price mode
/// @param idx offset for the true range
/// @param price_mode price mode for previous price
/// @param open open quotes
/// @param high high quotes
/// @param low low quotes
/// @param close close quotes
/// @param offset offset from index for previous price
/// @return true range
//
/// @par Overview
//
// Given:
// - A, the maximum of the current high rate and previous price
// - B, the minimum of the current low rate and previous price,
//
// This function calculates the difference of B subtracted from A/
//
// @par Adaptations after Welles Wilder's True Range
//
// This uses the price calculated per price_mode, in lieu of the offset
// close price. Welles Wilder's True Range may generally be emulated
// with this function, provding a price_mode of PRICE_CLOSE.
//
// This function provides support for using an offset other than one,
// for previous price.
double trueRange(const int idx, const int price_mode, MqlRates &rates[], const int offset = 1)
{
    const int realoff = offset == 0 ? 1 : offset;
    const double prev_price = priceFor(idx + realoff, price_mode, rates);
    const MqlRates cur = rates[idx];
    const double cur_high = cur.high;
    const double cur_low = cur.low;
    // max/min simplified calculation. reference:
    // Pruitt, G. (2016). Stochastics and Averages and RSI! Oh, My.
    //   In The Ultimate Algorithmic Trading System Toolbox + Website (pp. 25–76).
    //   John Wiley & Sons, Inc. https://doi.org/10.1002/9781119262992.ch2
    //
    // adapted to add an option for using a price other than close,
    // for previous price
    return fmax(cur_high, prev_price) - fmin(cur_low, prev_price);
}

double atr(const int idx, const int price_mode, MqlRates &rates[], const int offset = 1)
{
    if (offset == 1 || offset == 0)
    {
        const double prev_price = priceFor(idx + 1, price_mode, rates);
        const MqlRates cur = rates[idx];
        const double cur_high = cur.high;
        const double cur_low = cur.low;
        // max/min simplified calculation. reference:
        // Pruitt, G. (2016). Stochastics and Averages and RSI! Oh, My.
        //   In The Ultimate Algorithmic Trading System Toolbox + Website (pp. 25–76).
        //   John Wiley & Sons, Inc. https://doi.org/10.1002/9781119262992.ch2
        //
        // adapted to add an option for using a price other than close,
        // for previous price

        return fmax(cur_high, prev_price) - fmin(cur_low, prev_price);
    }
    // return a linear volume-weighted moving average of true range
    double ma = DBLZERO;
    double weights = DBLZERO;
    double off_dbl = (double)offset;
    for (int shift = idx + offset - 1, p_k = 1; shift >= idx; shift--, p_k++)
    {
        const MqlRates cur_rate = rates[shift];
        const MqlRates pre_rate = rates[shift + 1];
        const double weight = ((double)p_k / off_dbl) * cur_rate.tick_volume;
        const double rng = trueRange(pre_rate, cur_rate, price_mode);
        ma += (rng * weight);
        weights += weight;
    }
    return ma / weights;
}

double trueRange(const MqlRates &previous, const MqlRates &current, const int price_mode)
{
    const double prev_price = priceFor(previous, price_mode);
    const double cur_high = current.high;
    const double cur_low = current.low;
    // max/min simplified calculation. reference:
    // Pruitt, G. (2016). Stochastics and Averages and RSI! Oh, My.
    //   In The Ultimate Algorithmic Trading System Toolbox + Website (pp. 25–76).
    //   John Wiley & Sons, Inc. https://doi.org/10.1002/9781119262992.ch2
    //
    // adapted to add an option for using a price other than close,
    // for previous price
    return fmax(cur_high, prev_price) - fmin(cur_low, prev_price);
}

double trueRange(const int idx, MqlRates &rates[], const int price_mode, const int period = 1)
{
    double rng = DBLZERO;
    double weights = DBLZERO;
    const int start = idx + period - 1;
    // printf("THUNK P %d", idx);
    MqlRates pre = rates[start + 1];
    // FIXME needs test with period 1
    for (int n = start, p_k = 1; n >= idx; n--, p_k++)
    {
        const MqlRates cur = rates[n];
        const double wfactor = weightFor(p_k, period) * (double)cur.tick_volume;
        const double curng = trueRange(pre, cur, price_mode);
        rng += (curng * wfactor);
        weights += wfactor;
        pre = cur;
    }
    if (dblZero(weights))
    {
        return DBLZERO;
    }
    else
    {
        return rng / weights;
    }
}

/// @brief return the average change in price over a provided period
///
/// @param idx index for the most recent chart point in the period
/// @param price_mode integer denoting the mode for applied price
/// @param rates array of current rate structures
/// @param period period for the linear-weighted moving average
//
/// @return the volume-weighted linear moving average of change
//   in price, from (idx - period - 1) to (idx)
double priceChange(const int idx, const int price_mode, MqlRates &rates[], const int period = 1)
{
    double diff = DBLZERO;
    double weights = DBLZERO;
    for (int n = idx + period - 1, p_k = 1; n >= idx; n--, p_k++)
    {
        const MqlRates cur = rates[n];
        const double wfactor = weightFor(p_k, period) * (double)cur.tick_volume;
        const double p_near = priceFor(cur, price_mode);
        const double p_far = priceFor(n + 1, price_mode, rates);
        diff += (p_near - p_far) * wfactor;
        weights += wfactor;
    }
    if (weights == DBLZERO)
    {
        return DBLZERO;
    }
    else
    {
        return diff / weights;
    }
}

/// @brief return a value as adjusted for the volume-weighted linear mean of change in price
///   to a provided chart point
/// @param value generalized value to be adjusted for change in price
/// @param idx effective index for the value, within rates data
/// @param price_mode mode for applied price, in calculating change in price
/// @param rates array of current rate structures
/// @param period period for the calculation of change in price
/// @param change_weight weight for change in price, in calculating the adjustment
/// @param value_weight weight for the provided value, in calculating the adjustment
/// @return the value as adjusted for change in price
///
/// @par References
///
/// "An Oscillator to Distinguish between Trending and Sideways Markets", by Perry J. Kaufman, from (2013).
///   Momentum and Oscillators. In Trading Systems and Methods (5th ed.). Wiley. 408
///
double priceAdjusted(const double value, const int idx, const int price_mode, MqlRates &rates[], const int period, const double change_weight = 2.0, const double value_weight = 1.0)
{
    /// Earlier implementation - this will scale the input value
    // const double chg = priceChange(idx, price_mode, rates, period);
    // const double p = priceFor(idx, price_mode, rates);
    // return ((value_weight * value) + (change_weight * ((p + chg) / (p - chg)))) / (value_weight + change_weight);

    /// useful maybe but this adjustment really messes with the RVI graph
    // return ((value_weight * value) + (change_weight * ((p + chg) / (p - chg)))) /  ((value_weight * value) - (change_weight * ((p + chg) / (p - chg))));

    /// TBD
    const double p_dbl = (double)period;
    double cavg = DBLZERO;
    double ravg = DBLZERO;
    double weights = DBLZERO;
    for (int n = idx + period - 1, p_k = 1; n >= idx; n--, p_k++)
    {
        // change factor : moving average of current close, previous close differences
        // over the moving average of current high, current low differences
        //
        // or generally using a specified price mode, other than close
        const MqlRates r_cur = rates[n];
        const MqlRates r_pre = rates[n + 1];
        const double wfactor = ((double)p_k * (double)r_cur.tick_volume) / p_dbl;
        cavg += priceFor(r_cur, price_mode) - priceFor(r_pre, price_mode);
        // ravg += r_cur.high - r_cur.low;
        ravg += trueRange(r_pre, r_cur, price_mode);
        weights += wfactor;
    }
    cavg /= weights;
    ravg /= weights;
    if (dblZero(ravg))
    { // TBD
        return value;
    }
    const double cfactor = cavg / ravg;
    // const double p = priceFor(idx, price_mode, rates);
    // return ((value_weight * value) + (change_weight * ((p + cfactor) / (p - cfactor)))) / (value_weight + change_weight);
    return ((value_weight * value) + (change_weight * cfactor)) / (value_weight + change_weight);
}

double momentum(const MqlRates &previous, const MqlRates &current, const int price_mode)
{
    /// reference:
    /// Kaufman, P. J. (2013). Momentum and Oscillators. In Trading Systems
    /// and Methods (5th ed.). Wiley. 408
    ///
    const double cur_price = priceFor(current, price_mode);
    const double prev_price = priceFor(previous, price_mode);
    const double denom = (current.high - current.low);
    return (cur_price - prev_price) / (dblZero(denom) ? cur_price : denom);
}

double momentum(const int idx, MqlRates &rates[], const int price_mode, const int period = 1)
{
    double rng = DBLZERO;
    double weights = DBLZERO;
    const int start = idx + period - 1;
    MqlRates pre = rates[start + 1];
    for (int n = start, p_k = 1; n >= idx; n--, p_k++)
    {
        const MqlRates cur = rates[n];
        const double wfactor = weightFor(p_k, period) * (double)cur.tick_volume;
        const double curng = momentum(pre, cur, price_mode);
        rng += (curng * wfactor);
        weights += wfactor;
        pre = cur;
    }
    if (dblZero(weights))
    {
        return DBLZERO;
    }
    else
    {
        return rng / weights;
    }
}

double leastSquaresD(const int idx, const int period, MqlRates &rates[], const int price_mode = PRICE_TYPICAL, const int nth = 1)
{
    const double pdbl = (double)period;
    double nsum = DBLZERO;
    double nsqsum = DBLZERO;
    double nrsum = DBLZERO;
    double rsum = DBLZERO;
    double rsqsum = DBLZERO;
    for (int shift = idx + period - 1, n = 1; shift >= idx; shift--, n++)
    {
        const double p = priceFor(rates[shift], price_mode);
        nsum += n;
        nsqsum += pow(n, 2);
        nrsum += (n * p);
        rsum += p;
        rsqsum += pow(p, 2);
    }

    const double b = ((pdbl * nrsum) - (nsum * rsum)) / ((pdbl * nsqsum) - pow(nsum, 2));
    const double a = (1.0 / pdbl) * (rsum - (b * nsum));

    return a + (b * (double)nth);
}

double leastSquaresD(const int idx, const int period, double &in[], const int nth = 1)
{
    const double pdbl = (double)period;
    double nsum = DBLZERO;
    double nsqsum = DBLZERO;
    double nrsum = DBLZERO;
    double rsum = DBLZERO;
    double rsqsum = DBLZERO;
    for (int shift = idx + period - 1, n = 1; shift >= idx; shift--, n++)
    {
        const double p = in[shift];
        if (p != EMPTY_VALUE)
        {
            nsum += n;
            nsqsum += pow(n, 2);
            nrsum += (n * p);
            rsum += p;
            rsqsum += pow(p, 2);
        }
    }

    const double b_div = ((pdbl * nsqsum) - pow(nsum, 2));
    const double b = ((pdbl * nrsum) - (nsum * rsum)) / (dblZero(b_div) ? DBL_EPSILON : b_div);
    const double a = (1.0 / pdbl) * (rsum - (b * nsum));
    return a + (b * (double)nth);
}

void leastSquares(const int idx, const int period, MqlRates &rates[], double &out[], const int price_mode = PRICE_TYPICAL, const int oidx = EMPTY)
{
    const double pdbl = (double)period;
    double nsum = DBLZERO;
    double nsqsum = DBLZERO;
    double nrsum = DBLZERO;
    double rsum = DBLZERO;
    double rsqsum = DBLZERO;
    for (int shift = idx + period - 1, n = 1; shift >= idx; shift--, n++)
    {
        const double p = priceFor(rates[shift], price_mode);
        nsum += n;
        nsqsum += pow(n, 2);
        nrsum += (n * p);
        rsum += p;
        rsqsum += pow(p, 2);
    }

    const double b = ((pdbl * nrsum) - (nsum * rsum)) / ((pdbl * nsqsum) - pow(nsum, 2));
    const double a = (1.0 / pdbl) * (rsum - (b * nsum));

    const int ostart = oidx == EMPTY ? (idx + period - 1) : (oidx + period - 1);
    const int olast = oidx == EMPTY ? idx : oidx;
    for (int shift = ostart, n = 1; shift >= olast; shift--, n++)
    {
        /// printf("oidx %d, ostart %d, olast %d, shift %d", oidx, ostart, olast, shift);
        const double lr_y = a + (b * n);
        /// by some coincidence, if always setting the value here
        /// then it may appear as if to lead the actual market rate.
        /// The tradeoff would be that the indicator's n-period leading ticks
        /// would never be consistently set.
        ///
        /// This sets each value only once.
        ///
        /// This may not require an application of EMA smoothing
        if (out[shift] == EMPTY_VALUE)
        {
            out[shift] = lr_y;
        }
    }
}

void leastSquares(const int idx, const int period, double &in[], double &out[], const int oidx = EMPTY)
{
    const double pdbl = (double)period;
    double nsum = DBLZERO;
    double nsqsum = DBLZERO;
    double nrsum = DBLZERO;
    double rsum = DBLZERO;
    double rsqsum = DBLZERO;
    for (int shift = idx + period - 1, n = 1; shift >= idx; shift--, n++)
    {
        const double p = in[shift];
        nsum += n;
        nsqsum += pow(n, 2);
        nrsum += (n * p);
        rsum += p;
        rsqsum += pow(p, 2);
    }

    const double b = ((pdbl * nrsum) - (nsum * rsum)) / ((pdbl * nsqsum) - pow(nsum, 2));
    const double a = (1.0 / pdbl) * (rsum - (b * nsum));

    const int ost = oidx == EMPTY ? idx : oidx;

    for (int shift = ost + period - 1, n = 1; shift >= ost; shift--, n++)
    {
        const double lr_y = a + (b * n);
        /// by some coincidence, if always setting the value here
        /// then it may appear as if to lead the actual market rate.
        /// The tradeoff would be that the indicator's n-period leading ticks
        /// would never be consistently set.
        ///
        /// This sets each value only once.
        ///
        /// This may not require an application of EMA smoothing
        if (out[shift] == EMPTY_VALUE)
        {
            out[shift] = lr_y;
        }
    }
}

#endif
