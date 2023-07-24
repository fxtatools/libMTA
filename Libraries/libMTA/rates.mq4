

#ifndef _RATES_MQ4
#define _RATES_MQ4 1

#ifndef QUOTE_PADDING
#define QUOTE_PADDING 128
#endif

class RateBuffer
{
protected:
    int extent_scale_padding(const int ext_diff, const int padding = QUOTE_PADDING)
    {
        return (int)(ceil(ext_diff / padding) * padding);
    }

public:
    int expand_extent;
    int extent;
    double data[];

    RateBuffer(const int _extent = 0, const bool as_series = true)
    {
        expand_extent = 0;
        setExtent(_extent);
        setAsSeries(as_series);
    };
    ~RateBuffer()
    {
        ArrayFree(data);
    };

    // increase the length of the data buffer, for the provdied data length
    // within a factor of QUOTE_PADDING
    bool setExtent(int len, const int padding = EMPTY)
    {
        if (len == extent)
        {
            return true;
        }
        else if (len >= expand_extent)
        {
            const int next = (padding == EMPTY ? (expand_extent + extent_scale_padding(len - expand_extent)) : (len + padding));
            const int rslt = ArrayResize(data, next);
            if (rslt == -1)
            {
                extent = -1;
                return false;
            }
            expand_extent = next;
        }
        extent = len;
        return true;
    }

    // reduce the length of the data buffer, for the provdied data length
    // within a factor of QUOTE_PADDING
    bool reduceExtent(int len, const int padding = EMPTY)
    {
        const int reduced = (padding == EMPTY ? extent_scale_padding(len) : (len + padding));
        const int rslt = ArrayResize(data, reduced);
        if (rslt == -1)
        {
            extent = -1;
            return false;
        }
        else
        {
            extent = len;
            expand_extent = reduced;
            return true;
        }
    }

    // configure the data buffer to be accessed as (or not as) MetaTrader
    // time-series data
    bool setAsSeries(const bool as_series = true)
    {
        return ArraySetAsSeries(data, as_series);
    }
};

#endif