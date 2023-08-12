
#ifndef _QUOTES_MQ4
#define _QUOTES_MQ4 1

#property strict
#property library

#include "rates.mq4"
#include "chartable.mq4"
#include "libMql4.mq4"

// Quote Manager constants (FIXME no longer used)
#define QUOTE_TIME 1
#define QUOTE_OPEN (1 << 1)
#define QUOTE_HIGH (1 << 2)
#define QUOTE_LOW (1 << 3)
#define QUOTE_CLOSE (1 << 4)
#define QUOTE_VOLUME (1 << 5) // cf. CopyTickVolume
// #define QUOTE_SPREAD (1 << 6) // cf. MqlRates
// #define QUOTE_REAL_VOLUME (1 << 7) cf. MqlRates

template <typename T>
class QuotedBuffer : public LinkedBuffer<T>
{
    // for compatibility with MT's trim-in-copy-rates behaviors,
    // padding will be ignored here

public:
    QuotedBuffer(const int _extent = 0,
                 const bool as_series = true) : LinkedBuffer<T>(_extent, as_series){};

    virtual bool setExtent(int len, const int padding = EMPTY)
    {
        if (len == extent)
            return true;
        const int rslt = ArrayResize(data, len);
        if (rslt == -1)
        {
            extent = -1;
            expand_extent = -1;
            return false;
        }
        extent = len;
        expand_extent = len;
        return true;
    };
    virtual bool reduceExtent(int len, const int padding = EMPTY)
    {
        return setExtent(len);
    };
};

class QuotedPriceBuffer : public QuotedBuffer<double>
{
public:
    // ctor implementation is internally the same as with PriceBuffer
    QuotedPriceBuffer(const int _extent = 0, const bool as_series = true, const int n_more = 0) : QuotedBuffer<double>(_extent, as_series)
    {
        if (n_more == 0)
        {
            // this.setNext(NULL);
            next_buffer = NULL;
        }
        else
        {
            QuotedPriceBuffer *nxt = new QuotedPriceBuffer(_extent, as_series, n_more - 1);
            this.setNext(nxt);
        }
    };
};

class QuotedVolBuffer : public QuotedBuffer<long>
{
public:
    // at most one volume buffer per quote manager
    QuotedVolBuffer(const int _extent = 0, const bool as_series = true, const int n_more = 0) : QuotedBuffer<long>(_extent, as_series){};
};

class QuotedTimeBuffer : public QuotedBuffer<datetime>
{
public:
    // at most one time buffer per quote manager
    QuotedTimeBuffer(const int _extent = 0, const bool as_series = true) : QuotedBuffer<datetime>(_extent, as_series){};
};

class QuoteMgr : LinkedBufferMgr<QuotedPriceBuffer>
{
protected:
    Chartable *chartInfo;
    datetime latest_quote_dt;
    const bool store_volume;

public:
    QuotedPriceBuffer *open_buffer;  // quote open buffer (primary buffer)
    QuotedPriceBuffer *high_buffer;  // quote high buffer
    QuotedPriceBuffer *low_buffer;   // quote low buffer
    QuotedPriceBuffer *close_buffer; // quote close buffer
    QuotedTimeBuffer *time_buffer;   // quote time buffer
    QuotedVolBuffer *vol_buffer;     // quote tick volume buffer, if used

    QuoteMgr(const int _extent,
             const bool as_series = true,
             const string _symbol = NULL,
             const int _timeframe = EMPTY,
             const bool volume = true) : store_volume(volume),
                                         latest_quote_dt(EMPTY_VALUE),
                                         LinkedBufferMgr<QuotedPriceBuffer>(_extent, as_series, 4)
    {
        chartInfo = new Chartable(_symbol, _timeframe);

        open_buffer = dynamic_cast<QuotedPriceBuffer*>(primary_buffer);
        high_buffer = dynamic_cast<QuotedPriceBuffer*>(open_buffer.next_buffer);
        low_buffer = dynamic_cast<QuotedPriceBuffer*>(high_buffer.next_buffer);
        close_buffer = dynamic_cast<QuotedPriceBuffer*>(low_buffer.next_buffer);
        // typed as other than a PriceBuffer, the QuotedTimeBuffer will be managed
        // independent to the linked price buffer structure
        time_buffer = new QuotedTimeBuffer(_extent, as_series);
        if (volume)
            vol_buffer = new QuotedVolBuffer(_extent, as_series);
        else
            vol_buffer = NULL;
    };
    ~QuoteMgr()
    {
        FREEPTR(chartInfo);
        // Delete local buffers
        // - Linked price buffers will be deleted under the base class DTOR
        FREEPTR(time_buffer);
        FREEPTR(vol_buffer);
    };

    string getSymbol() const
    {
        return chartInfo.getSymbol();
    };

    int getTimeframe() const
    {
        return chartInfo.getTimeframe();
    };

    virtual bool setExtent(const int _extent, const int padding = EMPTY)
    {
        if (!LinkedBufferMgr<QuotedPriceBuffer>::setExtent(_extent, padding))
            return false;
        if (!time_buffer.setExtent(_extent, padding))
            return false;
        if (store_volume && !vol_buffer.setExtent(_extent, padding))
            return false;
        return true;
    }

    virtual bool reduceExtent(const int _extent, const int padding = EMPTY)
    {
        if (!LinkedBufferMgr<QuotedPriceBuffer>::reduceExtent(_extent, padding))
            return false;
        if (!time_buffer.reduceExtent(_extent, padding))
            return false;
        if (store_volume && !vol_buffer.reduceExtent(_extent, padding))
            return false;
        return true;
    }

    virtual bool updateExtent(const int _extent)
    {
        if (_extent > extent)
        {
            DEBUG("Quote Manager %s, %d: Expanding extent => %d", chartInfo.getSymbol(), chartInfo.getTimeframe(), _extent);
            if (!setExtent(_extent))
                return false;
        }
        else if (_extent < extent)
        {
            DEBUG("Quote Manager %s, %d: Reducing extent => %d", chartInfo.getSymbol(), chartInfo.getTimeframe(), _extent);
            if (!reduceExtent(_extent))
                return false;
        }
        DEBUG("Quote Manager %s, %d: New extent (%d, %d, %d %d) %d", chartInfo.getSymbol(), chartInfo.getTimeframe(), ArraySize(time_buffer.data), ArraySize(open_buffer.data), time_buffer.extent, time_buffer.expand_extent, extent);
        return true;
    }

    virtual int latestQuoteShift()
    {
        if (latest_quote_dt == EMPTY_VALUE)
            return 0;
        else
            // FIXME internal time buffer (not necessarily time-series) is unused here
            return iBarShift(chartInfo.getSymbol(), chartInfo.getTimeframe(), latest_quote_dt);
    };

    // Copy all rate and time information for quotes from latest to the provided
    // extent, in number of quotes.
    //
    virtual bool fetchQuotes(const int _extent)
    {
        const string symbol = chartInfo.getSymbol();
        const int timeframe = chartInfo.getTimeframe();
        DEBUG("Quote Manager %s, %d: Fetching %d quotes", symbol, timeframe, _extent);
        if (!updateExtent(_extent))
        {
            DEBUG("Quote Manager %s, %d: Failed to set extent", symbol, timeframe);
            return false;
        }

        // These will shrink the buffer, regardless of side effect.
        //
        // Thus, this buffer model does not pad the data arrays.
        // The padding would be lost here.
        //
        int rslt = CopyOpen(symbol, timeframe, 0, _extent, open_buffer.data);
        if (rslt == -1)
            return false;
        rslt = CopyHigh(symbol, timeframe, 0, _extent, high_buffer.data);
        if (rslt == -1)
            return false;
        rslt = CopyLow(symbol, timeframe, 0, _extent, low_buffer.data);
        if (rslt == -1)
            return false;
        rslt = CopyClose(symbol, timeframe, 0, _extent, close_buffer.data);
        if (rslt == -1)
            return false;
        rslt = CopyTime(symbol, timeframe, 0, _extent, time_buffer.data);
        if (rslt == -1)
            return false;
        if (store_volume)
        {
            rslt = CopyTickVolume(symbol, timeframe, 0, _extent, vol_buffer.data);
            if (rslt == -1)
                return false;
        }

        //// This would assume time-series application:
        // latest_quote_dt = time_buffer.get(0);
        //// This however does not:
        latest_quote_dt = offset_time(0, chartInfo.getSymbol(), chartInfo.getTimeframe());
        DEBUG("Quote Manager %s, %d: Fetched %d quotes", chartInfo.getSymbol(), chartInfo.getTimeframe(), time_buffer.extent);
        return true;
    };

    /// @brief fetch quotes up to the latest update offset, or to some provided number of quotes
    /// @param nrquotes number of quotes, if provided
    /// @return a boolean flag indicating whether quote data was succesfully transferred
    virtual bool updateQuotes(const int nrquotes = EMPTY)
    {
        // an indicator may need any additional number of quotes on update,
        // previous to the latest. Thus the handling for updateOffset() here.
        const int count = (nrquotes == EMPTY ? (latestQuoteShift() + 1) : nrquotes);
        DEBUG("Quote Manager %s, %d: Fetching %d quotes", chartInfo.getSymbol(), chartInfo.getTimeframe(), nrquotes);
        return fetchQuotes(count);
    }
};

#endif
