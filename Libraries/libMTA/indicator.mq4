#ifndef _INDICATOR_MQ4
#define _INDICATOR_MQ4 1

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#include "chartable.mq4"
#include "rates.mq4"
// #include "quotes.mq4"
#include "libMql4.mq4"

#include <dlib/Collection/HashMap.mqh>
#include <dlib/Utils/File.mqh>

#property library
#property strict

/// @brief string input for earliest chart bar, part of a hack for the limitations
/// of the strategy tester.
///
/// The MT4 Strategy Tester typically uses at most 1002 bars during analysis - less
/// than a day's time at M1. This can present some difficulties for analyzing the
/// behaviors of an expert advisor, insofar as ensuring parity between the indicators
/// as displayed and the indicator data available to the advisor at runtime.
///
/// The idea then: To start the indicator as displayed at the same time as the
/// earliest chart tick available to the expert advisor within the strategy tester.
///
/// This is then complicated with the absence of a datetime input ....
extern datetime analysis_start = 0; // Earliest Quote Time (Optional)

// template <typename T>
class RatesCallback
{
protected:
    // const T binding; //  an issuematic declaration, must be managed in a subclass

public:
    // RatesCallback(T bind) : binding(bind) {} // N/A

    // FIXME add
    // - preUpdate
    // - preInitialize

    virtual void initialized(const int idx, MqlRates &rates[]) const = 0;

    virtual void updated(const int idx, MqlRates &rates[]) const = 0;

    virtual void extentChanged(const int next) const = 0;
};

class RatesContext : public Chartable
{
protected:
    DataBufferList *data_buffers;
    const bool managed_p;
    int extent;

public:
    RatesContext(const int nr_buffers,
                 const string _symbol = NULL,
                 const int _timeframe = EMPTY,
                 const bool managed = true) : data_buffers(NULL),
                                              managed_p(managed),
                                              extent(0),
                                              Chartable(_symbol, _timeframe)
    {
        data_buffers = new DataBufferList(true, nr_buffers, managed_p);
    }
    ~RatesContext()
    {
        FREEPTR(data_buffers);
    }

    bool getManagedP()
    {
        return managed_p;
    }

    virtual int getExtent()
    {
        return data_buffers.getExtent();
    }

    virtual bool setExtent(const int ext)
    {
        ResetLastError();
        const bool rslt = managed_p ? true : data_buffers.setExtent(ext);
        if (!rslt)
        {
            const int errno = GetLastError();
            printf(__FUNCSIG__ + ": Unable to storeState buffer extent %d", ext);
            printf("[%d] %s", errno, ErrorDescription((errno)));
            return false;
        }
        extent = ext;
        return true;
    }

    virtual bool shiftExtent(const int count)
    {
        ResetLastError();
        const bool rslt = managed_p ? true : data_buffers.shiftExtent(count);
        if (!rslt)
        {
            const int errno = GetLastError();
            printf(__FUNCSIG__ + ": Unable to shift buffer extent %d", count);
            printf("[%d] %s", errno, ErrorDescription((errno)));
            return false;
        }
        extent = data_buffers.getExtent();
        return true;
    }

    bool addBuffer(ValueBuffer<double> *buf)
    {
        return data_buffers.addBuffer(buf);
    }

    ValueBuffer<double> *firstBuffer()
    {
        return data_buffers.first();
    }

    ValueBuffer<double> *nthBuffer(const int n)
    {
        return data_buffers.nth(n);
    }
};

// generalized abstract base class for technical indicators
class PriceIndicator : public RatesContext
{
protected:
    const string name;
    const int data_shift;
    // callback support modeled after dlib's IndicatorDriver
    LinkedList<RatesCallback *> *callbacks;
    /// @brief return a value for geometric weighting, with weights produced in the
    //   form of a quadrant of an ellipse
    /// @param n initial index for the weights sequence, generally beginning with 1
    /// @param period period for the containing moving average
    /// @param b_factor elliptical 'b' factor. Higher values will result in wider
    ///  scaling. The largest scaled weight will not be greater than one plus this value.
    /// @return the numeric weight for the provided input factors
    virtual double weightFor(const int n, const int period, const double b_factor = 1.1)
    {
        // generally weight = sqrt(B^2 ( 1 - ( ( N  - P/2 )^2 ) / (P/2)^2 )) + 1

        if (debugLevel(DEBUG_PROGRAM) && (n > period))
        {
            printf(__FUNCSIG__ + " Received index value %d greater than period %d", n, period);
        }
        /// convention in the codebase has been to begin the weight index at 1,
        /// for index <= period
        ///
        /// this method of geometric scaling begins with an initial index 0
        /// for index < period
        const double n_zero = n - 1;
        // const double a_factor = period/2; // providing a higher weight to middle values
        const double a_factor = period; // providing an increasing to most recent values
        return sqrt(pow(b_factor, 2) * (1 - pow((n_zero - a_factor), 2) / pow((a_factor), 2))) + 1;
    }

    /// geometric x true range weighting
    virtual double weightFor(const int idx, MqlRates &rates[], const int price_mode, const int p, const int period)
    {
        const double trng = trueRange(idx, price_mode, rates);
        return weightFor(p, period) * (dblZero(trng) ? DBL_EPSILON : pricePoints(trng));
    }

public:
    datetime latest_quote_dt;

    // FIXME provide a constant display_name field,
    // initializing in ctor then using in the default
    // indicatorName() method

    // return the number of buffers used directly for this indicator.
    //
    // This value should be incremented internally, in classes
    // derived from an indicator implementation
    virtual int classBufferCount()
    {
        // might work out as static, if the method being applied here
        // was for the method defined in the derived class
        return 1;
    };

    virtual int usedBufferCount()
    {
        return data_buffers.size();
    }

    PriceIndicator(const bool managed,
                   const string _name,
                   const int _nr_buffers = EMPTY,
                   const string _symbol = NULL,
                   const int _timeframe = EMPTY,
                   const int _data_shift = 1) : name(_name),
                                                latest_quote_dt(0),
                                                data_shift(_data_shift),
                                                callbacks(NULL),
                                                RatesContext(_nr_buffers == EMPTY ? classBufferCount() : _nr_buffers, _symbol, _timeframe, managed){};
    ~PriceIndicator()
    {
        // FREEPTR(price_mgr);
        FREEPTR(callbacks);
    }

    // return the number of quotes processed by this indicator
    virtual int getRatesCount()
    {
        // return price_mgr.extent;
        return data_buffers.getExtent();
    };

    // return the indicator's display name
    virtual string indicatorName()
    {
        return name;
    };

    virtual string indicatorBasename()
    {
        return name;
    }

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
        if (!data_buffers.setExtent(len))
            return false;
        extent = len;
        cbExtentChanged(len);
        return true;
    };

    virtual bool addBuffer(ValueBuffer<double> *buffer)
    {
        // price_mgr.addBuffer(buffer);
        return data_buffers.addBuffer(buffer);
    }

    virtual double getValue(const int bufidx, const int dataidx)
    {
        ValueBuffer<double> *buf = data_buffers.get(bufidx);
        return buf.get(dataidx);
    }

    virtual double getState(const int bufidx)
    {
        ValueBuffer<double> *buf = data_buffers.get(bufidx);
        return buf.getState();
    }

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
        int n = 0;
        ValueBuffer<double> *buf = data_buffers.get(n++);
        while (buf != NULL)
        {
            buf.storeState(idx);
            buf = data_buffers.get(n++);
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
    virtual void restoreFrom(const int idx)
    {
        int n = 0;
        ValueBuffer<double> *buf = data_buffers.get(n++);
        while (buf != NULL)
        {
            const double state = buf.get(idx);
            buf.setState(state);
            buf = data_buffers.get(n++);
        }
    };

    // utility method: Set the provided value into a range
    // within the buffer's data array.
    virtual void fillState(const int start, const int end, const double value = EMPTY_VALUE)
    {
        for (int idx = end; idx >= start; idx--)
        {
            int n = 0;
            ValueBuffer<double> *buf = data_buffers.get(n++);
            while (buf != NULL)
            {
                buf.storeState(idx, value);
                buf = data_buffers.get(n++);
            }
        }
    };

    virtual void writeCSVHeader(CsvFile &file)
    {
        /// for extensibility, newline will be written in the calling function
        const int nrbuf = data_buffers.size();
        const int nrdelim = nrbuf - 1;
        for (int n = 0; n < nrdelim; n++)
        {
            file.writeString(StringFormat("Buffer %d", n));
            file.writeDelimiter();
        }
        file.writeString(StringFormat("Buffer %d", nrdelim));
    }

    virtual void writeCSVRow(const int idx, CsvFile &file)
    {
        const int nrbuf = data_buffers.size();
        const int nrdelim = nrbuf - 1;
        for (int n = 0; n < nrdelim; n++)
        {
            ValueBuffer<double> *buf = data_buffers.get(n);
            const double bval = buf.get(idx);
            if (dblEql(bval, (double)EMPTY_VALUE))
            {
                file.writeString("");
            }
            else
            {
                file.writeNumber(bval);
            }
            file.writeDelimiter();
        }
        ValueBuffer<double> *lastbuf = data_buffers.get(nrdelim);
        file.writeNumber(lastbuf.get(idx));
        /// for extensibility, newline will be written in the calling function
    }

    virtual void writeCSV(const string filename, const ushort delim = ',', const int cp = CP_UTF8)
    {
        CsvFile *csv = new CsvFile(filename, FILE_WRITE, delim, cp);
        writeCSV(csv);
        /// the file will be closed in the dtor
        delete csv;
    }

    virtual void writeCSV(CsvFile &file)
    {
        const int nrbuf = data_buffers.size();
        const int nrdelim = nrbuf - 1;

        file.writeString("Timestamp");
        file.writeDelimiter();
        writeCSVHeader(file);
        file.writeNewline();
        for (int idx = extent - 1; idx >= 0; idx--)
        {
            /// no additional rates[] param needed for this much ..
            /// writeDateTime produces essentially a string of the datetime
            file.writeDateTime(offset_time(idx, symbol, timeframe));
            file.writeDelimiter();
            writeCSVRow(idx, file);
            file.writeNewline();
        }
        file.flush();
    }

    // Initialize basic features of the indicator display for this
    // indicator implementation
    //
    // Default implementation:
    // - sets the indicator name
    // - sets the indicator's display accuracy in digits, to match that
    //   of the selected market symbol
    // - sets the number of indicator buffers to the value returned
    //   by the implementing class' classBufferCount() method
    //
    // @return false if indicator buffers could not be allocated, else true
    virtual bool
    initIndicator()
    {
        FDEBUG(DEBUG_PROGRAM, (indicatorName() + ": Initializing indicator"));
        // const int count = nrbuffers == EMPTY ? classBufferCount() : nrbuffers;
        // const int count = classBufferCount(); // FIXME classBufferCount() is now obsolete ...
        const int count = usedBufferCount();
        if (!IndicatorBuffers(count))
        {
            printf(indicatorName() + " " + __FUNCSIG__ + ": Failed to initialize indicator for %d buffers", count);
            return false;
        }
        IndicatorShortName(indicatorName());
        IndicatorDigits(symbol_digits);
        return true;
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

        FDEBUG(DEBUG_PROGRAM, ("Initializing %s buffer [%d]", (label == NULL ? "(Unnamed)" : label), index));
        if (!SetIndexBuffer(index, data, _kind))
        {
            printf(indicatorName() + ": Unable to storeState %s indicator buffer for index %d", (label == NULL ? "(Unnamed)" : name), index);
            return false;
        }
        SetIndexLabel(index, label);
        SetIndexStyle(index, _style);
        return true;
    };

    // calculate any variables for the indicator at the provided
    // data index, and storeState local state to all buffers used by this
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
        const int update_idx = initial_index == EMPTY ? latestQuoteShift() : initial_index;

        FDEBUG(DEBUG_PROGRAM, (indicatorName() + " Updating to index %d, %s",
                               update_idx,
                               toString(rates[update_idx].time)));

        // restore previous calculation state
        restoreFrom(update_idx + 1);

        for (int idx = update_idx; idx >= nearest; idx--)
        {
            calcMain(idx, rates);
            storeState(idx);
            latest_quote_dt = rates[idx].time;
            cbUpdated(idx, rates);
        }
        latest_quote_dt = rates[0].time;
        return latest_quote_dt;
    };

    // run calcInitial() then storing each buffer's state
    // to the buffer's data array, finally dispatching to
    // updateVars() for the index returned from calcInitial()
    virtual datetime initVars(const int _extent, MqlRates &rates[], const int nearest = 0)
    {
        FDEBUG(DEBUG_PROGRAM, (indicatorName() + ": Bind initial value in %d", _extent));
        latest_quote_dt = 0;
        const int calc_idx = calcInitial(_extent, rates);
        FDEBUG(DEBUG_PROGRAM, (indicatorName() + ": Storing data state [%d/%d]", calc_idx, _extent));
        storeState(calc_idx); // store buffer state after initial calculation
        cbInitialized(calc_idx, rates);

        const int next = calc_idx - 1;
        if (calc_idx >= nearest)
        {
            FDEBUG(DEBUG_PROGRAM, (indicatorName() + ": Updating [%d ... %d]", next, nearest));
            // dispatch to call calcMain() and store state, updating to nearest rate point
            latest_quote_dt = updateVars(rates, next, nearest);
            FDEBUG(DEBUG_PROGRAM, (indicatorName() + ": Returning from initVars()"));
            return latest_quote_dt;
        }
        else
        {
            FDEBUG(DEBUG_PROGRAM, (indicatorName() +
                                       ": Initialized to %d at %s/%s",
                                   calc_idx, offset_time_str(calc_idx, symbol, timeframe),
                                   toString(rates[calc_idx].time)));
            latest_quote_dt = rates[0].time;
            return latest_quote_dt;
        }
    };

    virtual int calculate(const int rates_total, const int prev_calculated = EMPTY);

    bool addCallback(RatesCallback *callback)
    {
        if (callbacks == NULL)
        {
            callbacks = new LinkedList<RatesCallback *>(true, NULL);
        }
        if (callback == NULL)
        {
            /// e.g after a failed dynamic cast
            printf(__FUNCSIG__ + ": Received null callback %d", callbacks.size());
            return false;
        }
        callbacks.push(callback);
        return true; // FIXME update prototypes, use void return
    }

    int callbackCount()
    {
        return callbacks.size();
    }

    /*
     void clearCallbacks()
     {
         callbacks.clear();
     }
     */

    void cbInitialized(const int calc_idx, MqlRates &rates[])
    {
        if (callbacks != NULL)
        {
            int n = 0;
            RatesCallback *cb = callbacks.get(n++);
            while (cb != NULL)
            {
                cb.initialized(calc_idx, rates);
                cb = callbacks.get(n++);
            }
        }
    }

    void cbUpdated(const int idx, MqlRates &rates[])
    {
        if (callbacks != NULL)
        {
            // const LinkedList<RatesCallback<PriceIndicator *> *> cb_till = callbacks;
            const int count = callbacks.size();
            for (int n = 0; n < count; n++)
            {
                const RatesCallback *cb = callbacks.get(n);
                if (cb == NULL)
                {
                    // FIXME should not be reached.
                    FDEBUG(DEBUG_CALC, (__FUNCSIG__ + ": NULL Callback %d", n));
                    return;
                }
                FDEBUG(DEBUG_CALC, (__FUNCSIG__ + ": Callback %d", n));
                cb.updated(idx, rates);
            }
        }
    }

    void cbExtentChanged(const int next)
    {
        if (callbacks != NULL)
        {
            int n = 0;
            RatesCallback *cb = callbacks.get(n++);
            while (cb != NULL)
            {
                cb.extentChanged(next);
                cb = callbacks.get(n++);
            }
        }
    }
};

string toString(PriceIndicator &indicator)
{
    return indicator.indicatorName();
};

template <typename T>
class IndicatorCallback : public RatesCallback
{
protected:
    const T indicator;

public:
    IndicatorCallback(T in) : indicator(in){};

    virtual void initialized(const int idx, MqlRates &rates[]) const
    {
        // virtual NOP
    }

    virtual void updated(const int idx, MqlRates &rates[]) const
    {
        // virtual NOP
    }

    virtual void extentChanged(const int next) const
    {
        // virtual NOP
    }
};

int PriceIndicator::calculate(const int rates_total, const int prev_calculated = EMPTY)
{
    // uniformal API for indicator rates data
    //
    // FIXME when not managed, use a DataManager here with only this indicator added
    // - when not managed, apply the data mgr to call shiftExtent in each
    //   (the single) indicator, for the difference of rates_total and prev_calculated

    FDEBUG(DEBUG_PROGRAM, ("Calculate for %d rates, previous %d", rates_total, prev_calculated));

    // HACK:
    const datetime astart = analysis_start;
    /// TBD iBarShift when fetching a new timeseries e.g H1
    /// while e.g M1 data was previously displayed
    int applied_rates = astart == 0 ? rates_total : MathMin(iBars(symbol, timeframe), iBarShift(symbol, timeframe, astart));
    if (astart != 0)
    {
        /// bit of a hack for the limitations of the strategy tester
        ///
        /// not necc. useful for testing any disparity between indicator data
        /// as displayed in chart, and indicator data as applied during live test,
        /// given:
        /// - indicator displayed in chart will use full history data
        /// - indicator during live test will receive at most 1002 ticks before
        ///   the start of the testing period
        /// - indicator during live test will receive ask, bid and OHLC information
        ///   produced in a sense of streaming from the strategy tester implementation
        ///
        /// additional limitations, observed:
        /// - quotes data from the broker's trade server at M1 timeframe may have as much
        ///   as a 6 minute gap around 00:00 market time, e.g 3 minutes before and 3 minutes
        ///   after, seen with one Oanda MT4 demo account
        printf("Limiting analysis to initial time (parsed) %s with %d applied rates", toString(astart), applied_rates);
    }
    if (applied_rates == 0 || applied_rates == 1)
    {
        /// applied_rates == 0
        /// - if the user entered a time string that MT4 was not able to parse, it may
        ///   result in unexpected behavior here
        ///
        /// applied_rates == 1, rates_total == 1
        /// - may be reached when fetching a new series of data, e.g H1, while e.g
        ///   M1 was previously displayed
        printf("%d applied rates, deferring to %d", applied_rates, rates_total, toString(astart));
        applied_rates = rates_total <= 1 ? iBars(symbol, timeframe) : rates_total;
    }

    static MqlRates rateinfo[];
    ArraySetAsSeries(rateinfo, true);

    // const int prev = prev_calculated == EMPTY ? extent : prev_calculated;

    ArrayResize(rateinfo, applied_rates);
    const int copied = ArrayCopyRates(rateinfo, symbol, timeframe);
    ///
    /// alternately - the resize would be managed in the following
    ///
    // const int copied = CopyRates(symbol, timeframe, 0, applied_rates == 0 ? rates_total : applied_rates, rateinfo);

    if (copied == -1)
    {
        printf(indicatorName() + ": Unable to copy %d rates", applied_rates);
        return 0;
    }
    else if (copied != applied_rates)
    {
        printf(indicatorName() + ": Rates copied not equal to rates requested: %d, %d", copied, applied_rates);
    }
    if (prev_calculated == 0)
    {
        printf("initialize for %d rates", applied_rates);
        initVars(applied_rates, rateinfo);
    }
    else
    {
        updateVars(rateinfo);
    }
    return applied_rates;
};

#endif
