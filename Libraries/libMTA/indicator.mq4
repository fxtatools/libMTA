#ifndef _INDICATOR_MQ4
#define _INDICATOR_MQ4 1

#include "chartable.mq4"
#include "rates.mq4"
#include "quotes.mq4"
#include <pricemode.mq4>

#property library

// initial prototype for a generalized, abstract base class for price-oriented indicators
class PriceIndicator : public Chartable
{
protected:
    const string name;
    const int nr_buffers;
    PriceMgr *price_mgr; // should be defined in the protected section, except for testing

public:
    datetime latest_quote_dt;

    PriceIndicator(const string _symbol, const int _timeframe, const string _name, const int _nr_buffers = 1) : name(_name), latest_quote_dt(0), nr_buffers(_nr_buffers), Chartable(_symbol, _timeframe)
    {
        const int linked_buffers = nr_buffers - 1;
        if (linked_buffers >= 0)
        {
            price_mgr = new PriceMgr(0, true, linked_buffers);
        }
        else
        {
            price_mgr = NULL;
        }
    };
    ~PriceIndicator()
    {
        FREEPTR(price_mgr);
    }

    virtual int nDataBuffers() const
    {
        // return the number of buffers used directly for this indicator.
        // should be incremented internally, in derived classes
        return nr_buffers;
    };

    virtual string indicator_name() const
    {
        return name;
    }

    virtual int latest_quote_offset()
    {
        return iBarShift(symbol, timeframe, latest_quote_dt);
    }

    virtual bool setExtent(const int len, const int padding = EMPTY)
    {
        return price_mgr.setExtent(len, padding);
    };

    virtual bool reduceExtent(const int len, const int padding = EMPTY)
    {
        return price_mgr.reduceExtent(len, padding);
    };

    virtual int indicatorUpdateOffset(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        // initial support for backtracking during indicator update
        //
        // default behavior: Backtrack to the index previous to the last calculated
        return idx + 1;
    };

    // calculate variables for the indicator and set state in all buffers used by this indicator
    virtual void calcMain(const int idx, const double &open[], const double &high[], const double &low[], const double &close[]) = 0;

    // initialize variables used by this indicator, and return the offset for subsequent calculation
    virtual int calcInitial(const int extent, const double &open[], const double &high[], const double &low[], const double &close[]) = 0;

    virtual void storeState(const int idx)
    {
        PriceBuffer *buffer = price_mgr.primary_buffer;
        for (int n = 0; n < nr_buffers; n++)
        {
            const double state = buffer.getState();
            // FIXME ATR++ impl needs optional price=>points conversion here
            buffer.data[idx] = state;
            buffer = buffer.next();
        }
    };

    virtual void restoreState(const int idx)
    {
        PriceBuffer *buffer = price_mgr.primary_buffer;
        for (int n = 0; n < nr_buffers; n++)
        {
            const double state = buffer.data[idx];
            // FIXME ATR++ impl needs optional points=>price conversion here
            buffer.setState(state);
            buffer = buffer.next();
        }
    };

    virtual void fillState(const int start, const int end, const double value = EMPTY_VALUE)
    {
        for (int idx = end; idx >= start; idx--)
        {
            PriceBuffer *buffer = price_mgr.primary_buffer;
            for (int n = 0; n < nr_buffers; n++)
            {
                const double state = buffer.getState();
                // FIXME ATR++ impl needs optional price=>points conversion here
                buffer.set(idx, value);
                buffer = buffer.next();
            }
        }
    };

    // run calcMain and transfer calculation state into data buffers
    virtual datetime updateVars(const double &open[], const double &high[], const double &low[], const double &close[], const int initial_index = EMPTY, const int padding = EMPTY)
    {
        // initial_index is used here for purpose of applying this for indicator initialization,
        // there using the index returned by calcInitial()

        const int __latest__ = 0;

        // some indicators will need to backtrack here
        // thus the implementation of indicatorUpdateOffset()
        const int update_idx = initial_index == EMPTY ? indicatorUpdateOffset(latest_quote_offset(), open, high, low, close) : initial_index;
        if (update_idx > price_mgr.extent)
        {
            setExtent(update_idx, padding);
        }

        restoreState(update_idx + 1); // FIXME +1 backtrack for restore should always be sufficient

        // PriceBuffer *buffer = NULL; // FIXME TBD
        for (int idx = update_idx; idx >= __latest__; idx--)
        {
            calcMain(idx, open, high, low, close);
            storeState(idx);
        }
        latest_quote_dt = iTime(symbol, timeframe, __latest__);
        return latest_quote_dt;
    };

    virtual datetime updateVars(QuoteMgrOHLC &quote_mgr, const int initial_index = EMPTY, const int padding = EMPTY)
    {
        return updateVars(quote_mgr.open_buffer.data, quote_mgr.high_buffer.data, quote_mgr.low_buffer.data, quote_mgr.close_buffer.data, initial_index, padding);
    };

    virtual datetime initVars(const int _extent, const double &open[], const double &high[], const double &low[], const double &close[], const int padding = EMPTY)
    {
        if (!setExtent(_extent, padding))
        {
            printf("%s: Unable to set initial extent %d", indicator_name(), _extent);
            return EMPTY;
        }
        DEBUG("%s: Bind intial value in %d", indicator_name(), _extent);
        latest_quote_dt = 0;
        const int calc_idx = calcInitial(_extent, open, high, low, close);
        DEBUG("%s: Initializing data [%d/%d]", indicator_name(), calc_idx, _extent);

        storeState(calc_idx);

        return updateVars(open, high, low, close, calc_idx - 1, padding);
    };

    virtual datetime initVars(const int _extent, QuoteMgrOHLC &quote_mgr, const int padding = EMPTY)
    {
        return initVars(_extent, quote_mgr.open_buffer.data, quote_mgr.high_buffer.data, quote_mgr.low_buffer.data, quote_mgr.close_buffer.data, padding);
    };

    // Initialize any indicator display for this indicator implementation
    //
    // Prototyped with RSIpp, for each of nr_buffers
    virtual void initIndicator() = 0;
};

#endif