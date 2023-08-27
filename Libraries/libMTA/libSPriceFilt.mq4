// libSPriceFilt.mq4

#ifndef _LIBSPRICEFILT_MQ4
#define _LIBSPRICEFILT_MQ4 1

#property library
#property strict

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#include "indicator.mq4"
#include "filter.mq4"

/// @brief Smoothed Price Indicator, an application of John F. Ehlers' Super Smoother.
///
/// @par Implementation Notes
///
/// This implementation provides a prototype in application of the new filters API.
///
/// @par Observations in Implementation
///
/// Applications: This indicator produces a summary of market price, without the lag
/// of a moving average or the volatility of a direct price graph.
///
/// Probably not a limitation: This implementation provides a significantly less
/// smoothed output than the earlier SPrice indicator, both of which are avaialble
/// in this codebase. Both indicators will produce an index of market price values,
/// with each applying the actual market price data as filtered by a Super Smoother
/// algorithm.
///
/// The output of the original SPrice indicator may be substantially more smoothed
/// than this indicator, in a visual sense. As a concern for applications within
/// algorithmic trading systems, the other indicator's data may also be at least
/// slightly laggy, in comparision to this indicator's application. For these two
/// simimilar applications of the same input values and same processing function,
/// the exact cause of the difference in output values has yet to be determined.
///
/// Possibly a bug: The output projection for price, with this indicator, may be somewhat
/// more smoothed within shorter periods. It will typically not provide a near match to the
/// output from any SPrice indicator of any shorter (when possible) or longer period, except
/// for when both indicators are using a period in the range [2..4] (inclusive). A
/// period of 6 is recommended for the present indicator.
///
/// For calculations in the leading chart area, i.e at each new index 0, the price
/// index produced with this indicator may closely follow the market bid price, within
/// a certain gap varying generally with the rate of change in the immediate market
/// bid price.
///
/// Initial Design: This implementation was developed as an initial prototype in applying
/// the litMTA filters API for Indicator programs in the MetaTrader platform.
//
class SPFData : public PriceIndicator
{
protected:
    ValueBuffer<double> *sprice_data;

    datetime earliest_dt;

public:
    const int period;     // period for the Super Smoother system
    const int price_mode; // applied price

    PriceFilter *pf;   // price source for the Super Smoother
    SmoothedPrice *sp; // filter linkage for the Super Smoother applied to price

    SPFData(const int _period = 14,
            const int _price_mode = PRICE_TYPICAL,
            const string _symbol = NULL,
            const int _timeframe = NULL,
            const bool _managed = true,
            const string _name = "SPF") : period(_period),
                                          price_mode(_price_mode),
                                          earliest_dt(0),
                                          PriceIndicator(_managed, _name, 0)
    {
        pf = new PriceFilter(price_mode, THIS_CAST(Chartable), "PF", true, managed_p);
        sp = new SmoothedPrice(period, "SP", pf);
        data_buffers.push(pf);
        data_buffers.push(sp);
    };
    ~SPFData()
    {
        FREEPTR(sp);
        FREEPTR(pf);
    }

    int classBufferCount()
    {
        return 1;
    }

    string indicatorName()
    {
        return StringFormat("%s(%d)", name, period);
    }

    void storeState(const int idx)
    {
        // libMTA indicator method, not used in the filters API
    }

    void restoreFrom(const int idx)
    {
        // libMTA indicator method, not used in the filters API
    }

    void calcMain(const int idx, MqlRates &rates[])
    {
        if (idx == 0)
        {
            /// rudimentary backtrack, to ensure tick 0 is updated
            const datetime predt = rates[idx + 1].time;
            sp.recalcNewer(predt, rates);
        }
        const datetime curdt = rates[idx].time;
        sp.update(curdt, rates, earliest_dt);
    }

    int calcInitial(const int _extent, MqlRates &rates[])
    {
        setExtent(_extent);
        const int calc_idx = _extent - 5;
        sp.initialize(calc_idx, rates);

        earliest_dt = sp.getInitialDt();
        const datetime latest = sp.getLatestDt();
        const int s = iBarShift(symbol, timeframe, latest);
        // printf("THUNK %d", s);
        return s;
    }

    virtual int initIndicator(const int start = 0)
    {
        if (start == 0 && !PriceIndicator::initIndicator())
        {
            return -1;
        }

        int curbuf = start;

        // if (!initBuffer(curbuf++, wma.data, start == 0 ? "SPW" : NULL))
        // {
        //     return -1;
        // }
        if (!initBuffer(curbuf++, sp.data, start == 0 ? "SPF" : NULL))
        {
            return -1;
        }
        // if (!initBuffer(curbuf++, sp.data, NULL))
        // {
        //         return -1;
        // }

        if (!initBuffer(curbuf++, pf.data, NULL))
        {
            return -1;
        }

        return curbuf;
    }

    /// assorted cross-API hacks (FIXME)

    /// should not be necessary if the filters are added to data_buffers
    // bool setExtent(const int ext)
    // {
    //     pf.setExtent(ext);
    //     sp.setExtent(ext);
    //     return true;
    // }
    //
    // bool shiftExtent(const int count) {
    //     pf.shiftExtent(count);
    //     sp.shiftExtent(count);
    //     return true;
    // }
};

#endif