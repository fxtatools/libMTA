// pricemode.mq4

#property library
#property strict

#ifndef _PRICEMODE_MQ4
#define _PRICEMODE_MQ4 1

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

double trueRange(const int idx, const int price_mode, const double &open[], const double &high[], const double &low[], const double &close[], const int offset = 1)
{
    const double prev_price = priceFor(idx + offset, price_mode, open, high, low, close);
    const double cur_high = high[idx];
    const double cur_low = low[idx];
    // max/min simplified calculation. reference:
    // Pruitt, G. (2016). Stochastics and Averages and RSI! Oh, My.
    //   In The Ultimate Algorithmic Trading System Toolbox + Website (pp. 25–76).
    //   John Wiley & Sons, Inc. https://doi.org/10.1002/9781119262992.ch2
    //
    // adapted to add an option for using a price other than close,
    // for previous price
    return MathMax(cur_high, prev_price) - MathMin(cur_low, prev_price);
};

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
    const double prev_price = priceFor(idx + offset, price_mode, rates);
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
    return MathMax(cur_high, prev_price) - MathMin(cur_low, prev_price);
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
    return MathMax(cur_high, prev_price) - MathMin(cur_low, prev_price);
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
double priceChange(const int idx, const int price_mode, MqlRates &rates[], const int period)
{
    double diff = DBLZERO;
    double weights = DBLZERO;
    const double p_dbl = (double)period;
    for (int n = idx + period - 1, p_k = 1; n >= idx; n--, p_k++)
    {
        const MqlRates cur = rates[n];
        const double wfactor = ((double)p_k * (double)cur.tick_volume) / p_dbl;
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
    /// Originally ...
    /*
        const double chg = priceChange(idx, price_mode, rates, period);
        const double p = priceFor(idx, price_mode, rates);
        return ((value_weight * value) + (change_weight * ((p + chg) / (p - chg)))) / (value_weight + change_weight);
    */
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
        const double wfactor = ((double)p_k * (double) r_cur.tick_volume) / p_dbl;
        // cavg += r_cur.close - r_pre.close;
        cavg += priceFor(r_cur, price_mode) - priceFor(r_pre, price_mode);
        ravg += r_cur.high - r_cur.low;
        weights += wfactor;
    }
    cavg /= weights;
    ravg /= weights;
    const double cfactor = cavg / ravg;
    const double p = priceFor(idx, price_mode, rates);   
    // return ((value_weight * value) + (change_weight * ((p + cfactor) / (p - cfactor)))) / (value_weight + change_weight);
    return ((value_weight * value) + (change_weight * cfactor)) / (value_weight + change_weight);
}

#endif
