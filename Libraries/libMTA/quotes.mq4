
#ifndef _QUOTES_MQ4
#define _QUOTES_MQ4 1

#include "rates.mq4"

// Quote Manager constants
#define QUOTE_TIME 1
#define QUOTE_OPEN (1 << 1)
#define QUOTE_HIGH (1 << 2)
#define QUOTE_LOW (1 << 3)
#define QUOTE_CLOSE (1 << 4)
#define QUOTE_VOLUME (1 << 5) // cf. CopyTickVolume
// #define QUOTE_SPREAD (1 << 6) // cf. MqlRates
// #define QUOTE_REAL_VOLUME (1 << 7) cf. MqlRates

class QuoteMgrOHLC : public Chartable
{
public:
    PriceBuffer *open_buffer;
    PriceBuffer *high_buffer;
    PriceBuffer *low_buffer;
    PriceBuffer *close_buffer;
    int extent;

    ~QuoteMgrOHLC()
    {
        if (open_buffer != NULL)
            delete open_buffer;
        if (high_buffer != NULL)
            delete high_buffer;
        if (low_buffer != NULL)
            delete low_buffer;
        if (close_buffer != NULL)
            delete close_buffer;
    };

    QuoteMgrOHLC(const int _extent, const int quote_kind, const bool as_series = true, const string _symbol = NULL, const int _timeframe = EMPTY) : extent(_extent), Chartable(_symbol, _timeframe)
    {
        if ((quote_kind & QUOTE_OPEN) != 0)
        {
            open_buffer = new PriceBuffer(_extent);
            if (open_buffer.extent == -1 || !open_buffer.setAsSeries(as_series))
            {
                open_buffer = NULL; // FIXME error
            }
        }
        else
            open_buffer = NULL;

        if ((quote_kind & QUOTE_HIGH) != 0)
        {
            high_buffer = new PriceBuffer(_extent);
            if (high_buffer.extent == -1 || !high_buffer.setAsSeries(as_series))
            {
                high_buffer = NULL; // FIXME error
            }
        }
        else
            high_buffer = NULL;

        if ((quote_kind & QUOTE_LOW) != 0)
        {
            low_buffer = new PriceBuffer(_extent);
            if (low_buffer.extent == -1 || !low_buffer.setAsSeries(as_series))
            {
                low_buffer = NULL; // FIXME error
            }
        }
        else
            low_buffer = NULL;

        if ((quote_kind & QUOTE_CLOSE) != 0)
        {
            close_buffer = new PriceBuffer(_extent);
            if (close_buffer.extent == -1 || !close_buffer.setAsSeries(as_series))
            {
                close_buffer = NULL; // FIXME error
            }
        }
        else
            close_buffer = NULL;
    };

    bool setExtent(int _extent)
    {
        if (open_buffer != NULL)
        {
            if (!open_buffer.setExtent(_extent))
                return false;
        }
        if (high_buffer != NULL)
        {
            if (!high_buffer.setExtent(_extent))
                return false;
        }
        if (low_buffer != NULL)
        {
            if (!low_buffer.setExtent(_extent))
                return false;
        }
        if (close_buffer != NULL)
        {
            if (!close_buffer.setExtent(_extent))
                return false;
        }
        extent = _extent;
        return true;
    };

    bool reduceExtent(int len)
    {
        if (open_buffer != NULL)
        {
            if (!open_buffer.reduceExtent(len))
                return false;
        }
        if (high_buffer != NULL)
        {
            if (!high_buffer.reduceExtent(len))
                return false;
        }
        if (low_buffer != NULL)
        {
            if (!low_buffer.reduceExtent(len))
                return false;
        }
        if (close_buffer != NULL)
        {
            if (!close_buffer.reduceExtent(len))
                return false;
        }
        extent = len;
        return true;
    }

    // copy rates to the provided extent for this Quote Manager, for any initialized
    // open, high, low, and close buffers
    bool copyRates(const int _extent)
    {
        if (!setExtent(_extent))
            return false;
        if (open_buffer != NULL)
        {
            int rslt = CopyOpen(symbol, timeframe, 0, _extent, open_buffer.data);
            if (rslt == -1)
                return false;
        }
        if (high_buffer != NULL)
        {
            int rslt = CopyHigh(symbol, timeframe, 0, _extent, high_buffer.data);
            if (rslt == -1)
                return false;
        }
        if (low_buffer != NULL)
        {
            int rslt = CopyLow(symbol, timeframe, 0, _extent, low_buffer.data);
            if (rslt == -1)
                return false;
        }
        if (close_buffer != NULL)
        {
            int rslt = CopyClose(symbol, timeframe, 0, _extent, close_buffer.data);
            if (rslt == -1)
                return false;
        }
        return true;
    };
};

class QuoteMgrHLC : public QuoteMgrOHLC
{
public:
    QuoteMgrHLC(const int _extent, const string _symbol = NULL, const int _timeframe = EMPTY) : QuoteMgrOHLC(_extent, QUOTE_HIGH | QUOTE_LOW | QUOTE_CLOSE, true, _symbol, _timeframe){};
};

#endif
