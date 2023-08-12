// pricemode.mq4

// FIXME move to libMTA

#ifndef _PRICEMODE_MQ4
#define _PRICEMODE_MQ4 1

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

double price_for(const int idx,
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
        printf("Unknown price mode %d", mode);
        return __dblzero__;
    }
}

// calculate Welles Wilder's True Range for a provided offset and price mode
//
// This returns the difference of A, the maximum of the current high quote
// and previousprice and B, the minimum of current low and previous price, 
// using the provided price mode and quote data.
double trueRange(const int idx, const int price_mode, const double &open[], const double &high[], const double &low[], const double &close[])
{
    const double prev_price = price_for(idx + 1, price_mode, open, high, low, close);
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

#endif
