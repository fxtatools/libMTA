// pricemode.mq4

// FIXME move to libMTA

#ifndef _PRICEMODE_MQ4
#define _PRICEMODE_MQ4 1

enum ENUM_PRICE_MODE {
    PRICE_MODE_CLOSE = PRICE_CLOSE, // Quote Close Price
    PRICE_MODE_OPEN = PRICE_OPEN, // Quote Open Price
    PRICE_MODE_HIGH = PRICE_HIGH, // Quote High Price
    PRICE_MODE_LOW = PRICE_LOW, // Quote Low Price
    PRICE_MODE_MEDIAN = PRICE_MEDIAN, // Median Price
    PRICE_MODE_TYPICAL = PRICE_TYPICAL, // Typical Price
    PRICE_MODE_WEIGHTED = PRICE_WEIGHTED, // Weighted Price
    PRICE_MODE_TYPICAL_OPEN = PRICE_WEIGHTED + 1, // Typical Price From Open
    PRICE_MODE_WEIGHTED_OPEN = PRICE_MODE_TYPICAL_OPEN + 1, // Open-Weighted Price 
};

double price_for(const int idx,
                 const int mode, // ENUM_PRICE_MODE
                 const double &open[],
                 const double &high[],
                 const double &low[],
                 const double &close[])
{
    switch (mode)
    {    
    case PRICE_CLOSE:
        // not generally useful at tick 0 ...
        return close[idx];
    case PRICE_OPEN:
        return open[idx];
    case PRICE_HIGH:
        return high[idx];
    case PRICE_LOW:
        return low[idx];
    case PRICE_MODE_MEDIAN:
        return (high[idx] + low[idx]) / (double)2;
    case PRICE_MODE_TYPICAL:
        // not useful at tick 0, where "close" is indeterminant
        return (high[idx] + low[idx] + close[idx]) / (double)3;
    case PRICE_MODE_WEIGHTED:
        // not useful at tick 0, where "close" is indeterminant
        return (high[idx] + low[idx] + (close[idx] * 2)) / (double)4;
    case PRICE_MODE_TYPICAL_OPEN:
        return (high[idx] + low[idx] + open[idx]) / (double)3;
    case PRICE_MODE_WEIGHTED_OPEN:
        return (high[idx] + low[idx] + (open[idx] * 2)) / (double)4;
    default: // FIXME reached for int values ?
        printf("Unknown price mode %d", mode);
        return __dblzero__;
    }
}

#endif