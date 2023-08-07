#ifndef _INDICATOR_MQ4
#define _INDICATOR_MQ4 1

#include "chartable.mq4"
#include "rates.mq4"
#include "quotes.mq4"
#include <pricemode.mq4>

#property library
#property strict

// generalized abstract base class for technical indicators
class PriceIndicator : public Chartable
{
protected:
    const string name;
    const int nr_buffers;
    PriceMgr *price_mgr;
    const int data_shift;

public:
    datetime latest_quote_dt;

    PriceIndicator(const string _name,
                   const int _nr_buffers,
                   const string _symbol = NULL,
                   const int _timeframe = EMPTY,
                   const int _data_shift = 1) : name(_name),
                                                latest_quote_dt(0),
                                                nr_buffers(_nr_buffers),
                                                data_shift(_data_shift),
                                                Chartable(_symbol, _timeframe)
    {
        const int linked_buffers = _nr_buffers - 1;
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

    // return the number of buffers used directly for this indicator.
    //
    // This value should be incremented internally, in classes
    // derived from an indicator implementation
    virtual int dataBufferCount() const
    {
        return nr_buffers;
    };

    // return the number of quotes processed by this indicator
    virtual int getRatesCount() const
    {
        return price_mgr.extent;
    };

    // return the indicator's display name
    virtual string indicatorName() const
    {
        return name;
    };

    // return the current chart shift of the nearest quote
    // processed by the indicator
    virtual int latestQuoteShift()
    {
        return iBarShift(symbol, timeframe, latest_quote_dt);
    };

    // Default implementation: Set the extent of all linked
    // buffers to the provided length, with optional padding,
    // by way of the indicator's price manager.
    virtual bool setExtent(const int len, const int padding = EMPTY)
    {
        return price_mgr.setExtent(len, padding);
    };

    // Default implementation: Reduce the extent of all linked
    // buffers to the provided length, with optional padding,
    // by way of the indicator's price manager.
    virtual bool reduceExtent(const int len, const int padding = EMPTY)
    {
        return price_mgr.reduceExtent(len, padding);
    };

    // utility method - return the number of chart quotes used
    // internally for the indicator
    virtual int dataShift()
    {
        return data_shift;
    }

    // return the number of chart quotes required for indicator update
    // to the provided index
    virtual int indicatorUpdateShift(const int idx)
    {
        return dataShift() + 1;
    };

    // Default implementation: For each buffer linked to the
    // primary, transfer any value from the buffer's state
    // variable to the provided index in the buffer's data
    // array.
    //
    // For any value equal to EMPTY_VALUE, the value
    // will be transferred equivalently to the buffer's
    // data array
    virtual void storeState(const int idx)
    {
        PriceBuffer *buffer = price_mgr.primary_buffer;
        for (int n = 0; n < nr_buffers; n++)
        {
            const double state = buffer.getState();
            buffer.data[idx] = state;
            buffer = buffer.next();
        }
    };

    // Default implementation: For each buffer linked to the
    // primary, transfer a value from the buffer's data array
    // at the provided index, storing the value in the buffer's
    // state variable
    //
    // For any value equal to EMPTY_VALUE, the value
    // will be transferred equivalently from the buffer's
    // data array
    virtual void restoreState(const int idx)
    {
        PriceBuffer *buffer = price_mgr.primary_buffer;
        for (int n = 0; n < nr_buffers; n++)
        {
            const double state = buffer.data[idx];
            buffer.setState(state);
            buffer = buffer.next();
        }
    };

    // utility method: Set the provided value into a range
    // within the buffer's data array.
    virtual void fillState(const int start, const int end, const double value = EMPTY_VALUE)
    {
        for (int idx = end; idx >= start; idx--)
        {
            PriceBuffer *buffer = price_mgr.primary_buffer;
            for (int n = 0; n < nr_buffers; n++)
            {
                const double state = buffer.getState();
                buffer.set(idx, value);
                buffer = buffer.next();
            }
        }
    };

    // Initialize any indicator display for this indicator implementation
    //
    // Default implementation:
    // - set the indicator name
    // - set the indicator's display accuracy in digits to match that
    //   of the selected market symbol
    // - set the number of indicator buffers to the value returned
    //   by the indicator's dataBufferCount() method
    virtual void initIndicator()
    {
        IndicatorShortName(indicatorName());
        IndicatorDigits(market_digits);
        IndicatorBuffers(dataBufferCount());
    };

    // calculate any variables for the indicator at the provided
    // data index, and set local state to all buffers used by this
    // indicator
    virtual void calcMain(const int idx, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[]) = 0;

    // initialize data buffers and local state for variables used
    // by this indicator, and return the offset for subsequent
    // calculation by calcMain()
    virtual int calcInitial(const int extent, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[]) = 0;

    // run calcMain() and transfer calculation state into each
    // buffer's data arrays
    virtual datetime updateVars(const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[], const int initial_index = EMPTY, const int padding = EMPTY, const int nearest = 0)
    {
        // some indicators will need to backtrack here,
        // thus the implementation of latestQuoteShift()
        const int update_idx = initial_index == EMPTY ? latestQuoteShift() : initial_index; // ! latestQuoteShift() ...
        DEBUG(indicatorName() + " Updating to index %d", update_idx);
        if (update_idx > price_mgr.extent)
        {
            setExtent(update_idx, padding);
        }

        // restore previous calculation state
        restoreState(update_idx + 1);

        for (int idx = update_idx; idx >= nearest; idx--)
        {
            calcMain(idx, open, high, low, close, volume);
            storeState(idx);
        }
        latest_quote_dt = iTime(symbol, timeframe, nearest);
        return latest_quote_dt;
    };

    // call updatevars() for quote buffers provided by the QuoteMgr
    virtual datetime updateVars(QuoteMgr &quote_mgr, const int initial_index = EMPTY, const int padding = EMPTY)
    {
        return updateVars(quote_mgr.open_buffer.data, quote_mgr.high_buffer.data, quote_mgr.low_buffer.data, quote_mgr.close_buffer.data, quote_mgr.vol_buffer.data, initial_index, padding);
    };

    // run calcInitial() then storing each buffer's state
    // to the buffer's data array, finally dispatching to
    // updateVars() for the index returned from calcInitial()
    virtual datetime initVars(const int _extent, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[], const int padding = EMPTY, const int nearest = 0)
    {
        if (!setExtent(_extent, padding))
        {
            printf(indicatorName() + "%s: Unable to set initial extent %d", _extent);
            return EMPTY;
        }
        DEBUG(indicatorName() + ": Bind intial value in %d", _extent);
        latest_quote_dt = 0;
        const int calc_idx = calcInitial(_extent, open, high, low, close, volume);
        DEBUG(indicatorName() + ": Initializing data [%d/%d]", calc_idx, _extent);

        storeState(calc_idx);
        const int next = calc_idx - 1;
        if (calc_idx >= nearest) {
            DEBUG(indicatorName() + ": Updating [%d ... %d]", next, nearest);
            // dispatch to call calcMain() and store state, updating to nearest rate point
            const datetime dt = updateVars(open, high, low, close, volume, next, padding, nearest);
            DEBUG(indicatorName() + ": Returning from initVars()");
            return dt;
        } else {
            DEBUG(indicatorName() + ": Initialized to %d at %s", calc_idx, offset_time_str(calc_idx, symbol, timeframe));
            latest_quote_dt = iTime(symbol, timeframe, calc_idx);
            return latest_quote_dt;
        }
    };

    // dispatch to initVars() for quote buffers provided by the QuoteMgr
    virtual datetime initVars(const int _extent, QuoteMgr &quote_mgr, const int padding = EMPTY)
    {
        return initVars(_extent, quote_mgr.open_buffer.data, quote_mgr.high_buffer.data, quote_mgr.low_buffer.data, quote_mgr.close_buffer.data, quote_mgr.vol_buffer.data, padding);
    };
};

#endif
