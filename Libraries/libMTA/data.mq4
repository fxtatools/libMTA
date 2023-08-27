// Data Manager for MT4

#ifndef _DATA_MQ4
#define _DATA_MQ4 1

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#include "indicator.mq4"
#include "ratesbuffer.mq4"

class DataManager : public Chartable
{
    /// Convention: One DataManager per {symbol, timeframe} pair,
    /// for any number of indicators in that same symbol and timeframe

protected:
    LinkedList<PriceIndicator *> *indicators;
    LinkedList<CsvFile *> *in_datafiles;
    RatesBuffer *rbuff;
    const bool managed;
    int extent; // localized value for indicator data extent
    datetime latest_quote_dt;
    datetime first_quote_dt;
    const datetime initialized;

    int getUpdateShift(const int start)
    {
        int n = 0;
        PriceIndicator *in = indicators.get(n++);
        int shift = start + 1;
        while (in != NULL)
        {
            const int ishift = in.indicatorUpdateShift(start);
            if (ishift > shift)
            {
                shift = ishift;
            }
            in = indicators.get(n++);
        }
        return shift;
    }

    bool setExtent(const int newext)
    {
        /// Implementation Note:
        /// The following iterator will endeavor to storeState extent for all
        /// linked indicators, regardless of failure in any one indicator

        if (managed || (newext == extent))
        {
            return true;
        }
        int n = 0;
        PriceIndicator *in = indicators.get(n++);
        bool success = true;
        while (in != NULL)
        {
            const bool snxt = in.setExtent(newext);
            if (!snxt)
            {
                printf(__FUNCSIG__ + " " + chart_name + " Failed to storeState extent %d for indicator %s", newext, in.indicatorName());
            }
            if (success)
                success = snxt;
            in = indicators.get(n++);
        }
        if (success)
        {
            extent = newext;
            return true;
        }
        else
        {
            return false;
        }
    };

    bool shiftExtent(const int count)
    {
        DEBUG(__FUNCSIG__ + " shift extent %d", count);

        /// Implementation Note:
        /// The following iterator will endeavor to shift extent for all
        /// linked indicators, regardless of failure in any one indicator

        if (managed || (count == 0))
        {
            return true;
        }
        int n = 0;
        int inext = extent;
        PriceIndicator *in = indicators.get(n++);
        bool success = true;
        while (in != NULL)
        {
            const bool snxt = in.shiftExtent(count);
            if (!snxt)
            {
                printf(__FUNCSIG__ + " " + chart_name + " Failed to shift extent %d for indicator %s", count, in.indicatorName());
            }
            if (success)
            {
                success = snxt;
                inext = in.getExtent();
            }
            in = indicators.get(n++);
        }
        if (success)
        {
            /// using the indicator buffer extent from the last bound indicator
            /// as the data manager's buffer extent
            extent = inext;
            return true;
        }
        else
        {
            return false;
        }
    };

public:
    // static DataManager* getThunk() {
    //     return thunk;  // DNW. MT4 compiler is unable to resolve the reference here
    // }
    // static void setThunk(DataManager* mgr) {
    //     thunk = mgr;
    // }

    DataManager(const bool _managed = false,
                const string _symbol = NULL,
                const int _timeframe = EMPTY) : managed(_managed), extent(0),
                                                latest_quote_dt(0), first_quote_dt(0),
                                                initialized(TimeLocal()), // strategy tester reuses this somehow ??
                                                in_datafiles(NULL),
                                                Chartable(_symbol, _timeframe)
    {
        // setThunk(this); // DNW. TBD prototype for EA/Indicator interop via static class methods?

        indicators = new LinkedList<PriceIndicator *>(true, NULL);
        // initializing a rates buffer for indicators using (only) this symbol and timeframe
        rbuff = new RatesBuffer(0, true, symbol, timeframe);
    }
    ~DataManager()
    {
        FREEPTR(indicators);
        FREEPTR(rbuff);
        if (CheckPointer(in_datafiles) == POINTER_DYNAMIC) {
            /// CSV files will be closed in dtor
            int n = 0;
            CsvFile *csv = in_datafiles.get(n++);
            while(csv != NULL) {
                FREEPTR(csv);
                csv = in_datafiles.get(n++);
            }
            delete(in_datafiles);
        }
    }

    // DNW in MQL4, no pointer to struct here
    MqlRates ratesAt(const int idx)
    {
        return rbuff.get(idx);
    }

    datetime timeAt(const int idx)
    {
        return ratesAt(idx).time;
    }

    int getExtent()
    {
        return extent;
    }

    MqlRates rateAt(const int idx)
    {
        return rbuff.get(idx);
    }

    bool initWrite(string filesdir)
    {
        if (in_datafiles != NULL)
        {
            printf("Data writing already initialized, unable to initialize for writing to %s", filesdir);
            return false;
        }
        const ushort delim = ',';
        const int cp = CP_UTF8;
        in_datafiles = new LinkedList<CsvFile *>(true, NULL);
        int n = 0;
        PriceIndicator *in = indicators.get(n++);
        const datetime latest_mkt = offset_time(0, symbol, timeframe);
        /// strategy tester may have manged so much as the GMT and local time functions
        const string session_str = StringFormat("%s\\Data_%s_%02d%02d_%02d_%s_%d_%s_%02d%02d_%02d", filesdir, toString(initialized, TIME_DATE), TimeHour(initialized), TimeMinute(initialized), TimeSeconds(initialized), symbol, timeframe, toString(latest_mkt, TIME_DATE), TimeHour(latest_mkt), TimeMinute(latest_mkt), TimeSeconds(latest_mkt));
        while (in != NULL)
        {
            const string fname = StringFormat("%s\\in_%d_%s.csv", session_str, n, in.indicatorBasename());
            CsvFile *csv = new CsvFile(fname, FILE_WRITE, delim, cp);
            csv.writeString("Timestamp");
            csv.writeDelimiter();
            in.writeCSVHeader(csv);
            csv.writeNewline();
            csv.flush();
            in_datafiles.add(csv);
            in = indicators.get(n++);
        }
        return true;
    }

    bool writeData(const int idx = 0)
    {
        if (in_datafiles == NULL)
        {
            return false;
        }
        int n = 0;
        PriceIndicator *in = indicators.get(n);
        CsvFile *csv = in_datafiles.get(n++);
        bool wrote_p = false;
        while (csv != NULL)
        {
            in.writeCSVRow(idx, csv);
            wrote_p = true;
            csv = in_datafiles.get(n);
            in = indicators.get(n++);
        }
        return wrote_p;
    }

    template <typename T>
    bool bind(T indicator)
    {
        if (first_quote_dt != 0)
        {
            Print(__FUNCSIG__ + " " + chart_name + " Unable to add indicator to running instance: " + indicator.indicatorName());
            return false;
        }

        if (indicator.getSymbol() != symbol || indicator.getTimeframe() != timeframe)
        {
            printf(__FUNCSIG__ + " " + chart_name + " Called to add indicator %s with non-matching symbol or timeframe %s %d",
                   symbol, timeframe,
                   indicator.indicatorName(),
                   indicator.getSymbol(),
                   indicator.getTimeframe());
            return false;
        }
        if (indicator.getManagedP())
        {
            printf(__FUNCSIG__ + " " + chart_name + " Adding extenrally managed indicator %s",
                   symbol, timeframe,
                   indicator.indicatorName());
        }
        /// the next call may be assumed to ensure that the indicator is a member
        /// of the linked list, at normal points of operation. The return value
        /// is reused here, as a matter of convention.
        const bool rslt = indicators.add(dynamic_cast<PriceIndicator *>(indicator));
        return rslt;
    };

    template <typename T>
    bool unbind(T indicator)
    {
        if (first_quote_dt != 0)
        {
            Print(__FUNCSIG__ + " " + chart_name + " Unable to remove indicator from running instance: " + indicator.indicatorName());
            return false;
        }
        return indicators.remove(dynamic_cast<PriceIndicator *>(indicator));
    };

    datetime update(const int rates_total, const int prev_calculated)
    {
        /// TBD skipping the indicator-like API here and just using times
        /// for determining "previous calculated"

        const bool initialize = (prev_calculated == 0);
        const int prev_applied = (latest_quote_dt == 0 || first_quote_dt == 0) ? 0 : iBarShift(symbol, timeframe, first_quote_dt) - iBarShift(symbol, timeframe, latest_quote_dt);

        DEBUG(__FUNCSIG__ + " " + chart_name + " " + (initialize ? "Initializing" : "Updating") + " rates for %d rates, %d/%d previous", rates_total, prev_applied, prev_calculated);

        // const int nrquotes = initialize ? quotes_shift : getUpdateShift(quotes_shift);
        const int nrquotes = rates_total;
        DEBUG(__FUNCSIG__ + " " + chart_name + " Fetching %d quotes for update", nrquotes);
        if (!rbuff.getRates(nrquotes))
        {
            printf(__FUNCSIG__ + " " + chart_name + " unable to fetch %d rates", nrquotes);
            return EMPTY;
        }

        if (initialize)
        {
            first_quote_dt = rbuff.data[nrquotes - 1].time;
        }

        const int quotes_shift = initialize ? rates_total : iBarShift(symbol, timeframe, latest_quote_dt);

        DEBUG(__FUNCSIG__ + " " + chart_name + " " + (initialize ? "Initializing" : "Updating") + " indicators for %d quotes", quotes_shift);

        if (!managed && quotes_shift != 0)
        {
            // Implementation note: This assumes nothing else has called setExtent()
            // or shiftExtent() on the data mgr or any managed objects.
            //
            if (!(initialize ? setExtent(quotes_shift) : shiftExtent(quotes_shift)))
            {
                printf(__FUNCSIG__ + " " + chart_name + " unable to %s indicator extent %d",
                       (initialize ? "storeState" : "shift"),
                       quotes_shift);
                return EMPTY;
            }
        }

        int n = 0;
        PriceIndicator *in = indicators.get(n);
        CsvFile *csv = (in_datafiles == NULL ? NULL : in_datafiles.get(n++));
        while (in != NULL)
        {
            if (initialize)
            {
                in.initVars(rates_total, rbuff.data);
            }
            else
            {
                in.updateVars(rbuff.data, quotes_shift);
            }
            if (in_datafiles != NULL)
            {
                // if the csv pointer is null here, it's a bug
                if (csv == NULL)
                {
                    printf(__FUNCSIG__ + " Null CSV pointer for indicator %d %s", n - 1, in.indicatorName());
                }
                else
                {
                    // Known limitation: After update, this will not re-write any changed data in the indicator 
                    // data arrays, such that would be oustide of the limits of the quotes_shift
                    for (int shift = initialize ? rates_total - 1 : quotes_shift; shift > 0; shift--)
                    {
                        // csv.writeDateTime(timeAt(shift));
                        csv.writeString(toString(timeAt(shift), TIME_DATE | TIME_MINUTES | TIME_SECONDS));
                        // csv.writeInteger((int) timeAt(shift));
                        csv.writeDelimiter();
                        in.writeCSVRow(shift, csv);
                        csv.writeNewline();
                    }
                    /// using MqlTick.time for index 0
                    MqlTick tick();
                    SymbolInfoTick(symbol, tick);
                    // csv.writeDateTime(tick.time);
                    /// regardless of the format, this may write successive timestamps of an equal value
                    csv.writeString(toString(tick.time, TIME_DATE | TIME_MINUTES | TIME_SECONDS));
                    // csv.writeInteger((int) tick.time);
                    csv.writeDelimiter();
                    in.writeCSVRow(0, csv);
                    csv.writeNewline();
                    csv.flush();
                }
            }
            in = indicators.get(n);
            csv = (in_datafiles == NULL ? NULL : in_datafiles.get(n++));
        }
        latest_quote_dt = rbuff.get(0).time;
        extent = rates_total;
        return latest_quote_dt;
    }

    datetime update(const int count = EMPTY)
    {
        /// TBD: iBars for a symbol and timeframe not used in an active chart
        const int total = count == EMPTY ? iBars(symbol, timeframe) : count;

        // const int pre = latest_quote_dt == 0 ? 0 : extent - 1 - iBarShift(symbol, timeframe, latest_quote_dt);
        //// TBD with the following, for indicator application under the strategy tester
        const int pre = (latest_quote_dt == 0 || first_quote_dt == 0) ? 0 : iBarShift(symbol, timeframe, first_quote_dt) - iBarShift(symbol, timeframe, latest_quote_dt);
        // ^ FIXME pre should be 0 after a change in the timestamp of the first chart bar
        // and in which case, all data needs to be reinitialized ...

        const datetime rslt = update(total, pre);
        if (rslt == EMPTY)
        {
            printf(__FUNCSIG__ + " " + chart_name + ": Unable to update %d total, %d previous", total, pre);
        }
        else
        {
            latest_quote_dt = rslt;
        }
        return rslt;
    }
};

#endif