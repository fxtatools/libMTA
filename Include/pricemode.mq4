// pricemode.mq4

#ifndef _PRICEMODE_MQ4
#define _PRICEMODE_MQ4 1

enum ENUM_PRICE_MODE {
    PRICE_MODE_MEDIAN = PRICE_MEDIAN, // Median Price
    PRICE_MODE_TYPICAL = PRICE_TYPICAL, // Typical Price
    PRICE_MODE_WEIGHTED = PRICE_WEIGHTED, // Weighted Price
    PRICE_MODE_TYPICAL_OPEN = PRICE_WEIGHTED + 1, // Typical Price From Open
    PRICE_MODE_WEIGHTED_OPEN = PRICE_MODE_TYPICAL_OPEN + 1, // Open-Weighted Price 
};

double price_for(const int shift,
                 const ENUM_PRICE_MODE mode,
                 const double &open[],
                 const double &high[],
                 const double &low[],
                 const double &close[])
{
    switch (mode)
    {
    /*
    case PRICE_CLOSE:
        // not useful at tick 0
        return close[shift];
    case PRICE_OPEN:
        // not generally useful for indicators
        return open[shift];
    case PRICE_HIGH:
        // not generally useful for indicators
        return high[shift];
    case PRICE_LOW:
        // not generally useful for indicators
        return low[shift];
    */
    case PRICE_MODE_MEDIAN:
        return (high[shift] + low[shift]) / (double)2;
    case PRICE_MODE_TYPICAL:
        // not useful at tick 0, where "close" is indeterminant
        return (high[shift] + low[shift] + close[shift]) / (double)3;
    case PRICE_MODE_WEIGHTED:
        // not useful at tick 0, where "close" is indeterminant
        return (high[shift] + low[shift] + close[shift] * 2) / (double)4;
    case PRICE_MODE_TYPICAL_OPEN:
        return (high[shift] + low[shift] + open[shift]) / (double)3;
    case PRICE_MODE_WEIGHTED_OPEN:
        return (high[shift] + low[shift] + open[shift] * 2) / (double)4;
    default:
        return __dblzero__;
    }
}

#endif