#ifndef _INDICATOR_MQ4
#define _INDICATOR_MQ4 1

#include "chartable.mq4"
#include "rates.mq4"
#include "quotes.mq4"
#include "libMql4.mq4"

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
    int extent;
    // linear weighting
    virtual double weightFor(const int n, const int period)
    {
        return (double)n / (double)period;
    }

public:
    datetime latest_quote_dt;

    // FIXME update API : initIndicator => bool
    // mainly factored onto the return value from
    // IndicatorBuffers() in implementations

    // FIXME provide a constant display_name field,
    // initializing in ctor then using in the default
    // indicatorName() method

    PriceIndicator(const string _name,
                   const int _nr_buffers,
                   const string _symbol = NULL,
                   const int _timeframe = EMPTY,
                   const int _data_shift = 1) : name(_name),
                                                latest_quote_dt(0),
                                                nr_buffers(_nr_buffers),
                                                data_shift(_data_shift),
                                                extent(0),
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
        if (len > extent)
        {
            const bool rslt = price_mgr.setExtent(len, padding);
            if (rslt)
            {
                extent = len;
            }
            else
            {
                return false;
            }
        }
        return true;
    };

    // Default implementation: Reduce the extent of all linked
    // buffers to the provided length, with optional padding,
    // by way of the indicator's price manager.
    virtual bool reduceExtent(const int len, const int padding = EMPTY)
    {
        if (len < extent)
        {
            const bool rslt = price_mgr.reduceExtent(len, padding);
            if (rslt)
            {
                extent = len;
            }
            else
            {
                return false;
            }
        }
        return true;
    };

    // utility method - return the number of chart quotes used
    // internally for the indicator
    virtual int dataShift()
    {
        return data_shift;
    };

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
            buffer.set(idx);
            buffer = dynamic_cast<PriceBuffer *>(buffer.next_buffer);
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
            buffer = dynamic_cast<PriceBuffer *>(buffer.next_buffer);
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
                buffer = dynamic_cast<PriceBuffer *>(buffer.next_buffer);
            }
        }
    };

    // Initialize basic features of the indicator display for this
    // indicator implementation
    //
    // Default implementation:
    // - sets the indicator name
    // - sets the indicator's display accuracy in digits, to match that
    //   of the selected market symbol
    // - sets the number of indicator buffers to the value returned
    //   by the implementing class' dataBufferCount() method
    //
    // @return false if indicator buffers could not be allocated, else true
    virtual bool initIndicator()
    {
        IndicatorShortName(indicatorName());
        IndicatorDigits(market_digits);
        return IndicatorBuffers(dataBufferCount());
    };

    /// @brief Utility method for indicator buffer initialization
    /// @param index indicatur buffer index
    /// @param data data array for the indicator buffer
    /// @param label label for the indicator buffer, NULL if undrawn
    /// @param style style for the indicator buffer. If not provided and label is NULL, DRAW_NONE will be used, else DRAW_LINE.
    /// @param kind indicator buffer type. If not provided and label is NULL, INDICATOR_CALCULATIONS will be used, else INDICATOR_DATA
    /// @return true if an indicator buffer could be bound for the provided index, else false.
    virtual bool initBuffer(const int index, double &data[], const string label, int style = EMPTY, ENUM_INDEXBUFFER_TYPE kind = EMPTY)
    {
        const ENUM_INDEXBUFFER_TYPE _kind = (kind == EMPTY) ? (label == NULL ? INDICATOR_CALCULATIONS : INDICATOR_DATA) : kind;
        const int _style = (style == EMPTY) ? (label == NULL ? DRAW_NONE : DRAW_LINE) : style;

        if (!SetIndexBuffer(index, data, _kind))
        {
            printf(indicatorName() + ": Unable to set %s indicator buffer for index %d", (label == NULL ? "(Unnamed)" : name), index);
            return false;
        }
        SetIndexLabel(index, label);
        SetIndexStyle(index, _style);
        return true;
    };

    // calculate any variables for the indicator at the provided
    // data index, and set local state to all buffers used by this
    // indicator
    virtual void calcMain(const int idx, MqlRates &rates[]) = 0;

    // initialize data buffers and local state for variables used
    // by this indicator, and return the offset for subsequent
    // calculation by calcMain()
    virtual int calcInitial(const int extent, MqlRates &rates[]) = 0;

    // run calcMain() and transfer calculation state into each
    // buffer's data arrays
    virtual datetime updateVars(MqlRates &rates[], const int initial_index = EMPTY, const int nearest = 0)
    {
        // some indicators will need to backtrack here,
        // thus the implementation of latestQuoteShift()
        const int update_idx = initial_index == EMPTY ? latestQuoteShift() : initial_index; // ! latestQuoteShift() ...
        DEBUG(indicatorName() + " Updating to index %d", update_idx);
        if (update_idx > price_mgr.extent)
        {
        }

        // restore previous calculation state
        restoreState(update_idx + 1);

        for (int idx = update_idx; idx >= nearest; idx--)
        {
            calcMain(idx, rates);
            storeState(idx);
        }
        latest_quote_dt = rates[0].time;
        return latest_quote_dt;
    };

    // call updatevars() for quote buffers provided by the QuoteMgr

    // run calcInitial() then storing each buffer's state
    // to the buffer's data array, finally dispatching to
    // updateVars() for the index returned from calcInitial()
    virtual datetime initVars(const int _extent, MqlRates &rates[], const int nearest = 0)
    {
        if (!setExtent(_extent, 0)) // FIXME remove the padding bits altogether
        {                           // FIXME handle this externally
            printf(indicatorName() + ": Unable to set initial extent %d", _extent);
            return EMPTY;
        }
        DEBUG(indicatorName() + ": Bind intial value in %d", _extent);
        latest_quote_dt = 0;
        const int calc_idx = calcInitial(_extent, rates);
        DEBUG(indicatorName() + ": Initializing data [%d/%d]", calc_idx, _extent);

        storeState(calc_idx); // store buffer state after initial calculation

        const int next = calc_idx - 1;
        if (calc_idx >= nearest)
        {
            DEBUG(indicatorName() + ": Updating [%d ... %d]", next, nearest);
            // dispatch to call calcMain() and store state, updating to nearest rate point
            const datetime dt = updateVars(rates, next, nearest);
            DEBUG(indicatorName() + ": Returning from initVars()");
            return dt;
        }
        else
        {
            DEBUG(indicatorName() + ": Initialized to %d at %s", calc_idx, offset_time_str(calc_idx, symbol, timeframe));
            latest_quote_dt = rates[0].time;
            return latest_quote_dt;
        }
    };

    // dispatch to initVars() for quote buffers provided by the QuoteMgr
    virtual int calculate(const int rates_total, const int prev_calculated = EMPTY)
    {
        // uniformal API for indicator rates data

        MqlRates rateinfo[]; // FIXME move this to a quotes manager
        ArraySetAsSeries(rateinfo, true);

        const int prev = prev_calculated == EMPTY ? extent : prev_calculated;
        ArrayResize(rateinfo, rates_total);
        // the following will presumably use all rates for the chart.
        // in this form, with updated MQL4, it should not actually copy the data points
        //
        // and yet that seemingly DNW for accessing the array again in MQL?
        const int copied = ArrayCopyRates(rateinfo, _Symbol, _Period);
        if (copied == -1)
        {
            printf(indicatorName() + ": Unable to copy %d rates", rates_total);
            return 0;
        }
        else if (copied != rates_total)
        {
            printf(indicatorName() + ": Rates copied not equal to rates total: %d, %d", copied, rates_total);
        }
        if (prev_calculated == 0)
        {
            initVars(rates_total, rateinfo);
        }
        else
        {
            updateVars(rateinfo);
        }
        return rates_total;
    }
};

#endif
