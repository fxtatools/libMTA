// libSPriceFilt.mq4

#ifndef _LIBHPS_MQ4
#define _LIBSPRICEFILT_MQ4 1

#property library
#property strict

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#include "indicator.mq4"
#include "filter.mq4"

class HPSData : public PriceIndicator
{
protected:
    ValueBuffer<double> *sprice_data;

    datetime earliest_dt;

public:
    const int period;     // period for the Super Smoother system
    const int price_mode; // applied price

    HPPrice *hpp;
    SHPPrice *shp; 

    HPSData(const int _period = 14,
            const int _price_mode = PRICE_TYPICAL,
            const string _symbol = NULL,
            const int _timeframe = NULL,
            const bool _managed = true,
            const string _name = "HPS") : period(_period),
                                          price_mode(_price_mode),
                                          earliest_dt(0),
                                          PriceIndicator(_managed, _name, 0)
    {
        // does getChartInfo() not work from here now ?
        hpp = new HPPrice(price_mode, THIS_CAST(Chartable), "HPP", true, _managed);
        shp = new SHPPrice(period, "SHP", hpp);
        data_buffers.push(hpp);
        data_buffers.push(shp);
    };
    ~HPSData()
    {
        FREEPTR(hpp);
        FREEPTR(shp);
    }

    int classBufferCount()
    {
        return 2;
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
            const datetime predt = rates[idx+1].time;
            shp.recalcNewer(predt, rates);
        }
        const datetime curdt = rates[idx].time;
        const bool rslt = shp.update(curdt, rates, earliest_dt);
        if(!rslt) {
            printf(__FUNCTION__ + ": Update failed: %s [%d %s]", shp.getLabel(), idx, toString(rates[idx].time, TIME_COMPLETE));
        }
    }

    int calcInitial(const int _extent, MqlRates &rates[])
    {
        // setExtent(_extent);
        const int lim = fmax(shp.getInitDelay(), hpp.getInitDelay());
        const int calc_idx = _extent - lim;
        shp.initialize(calc_idx, rates);

        earliest_dt = shp.getInitialDt();
        const datetime latest = shp.getLatestDt();
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

        
        if (!initBuffer(curbuf++, shp.data, start == 0 ? "HPS" : NULL))
        {
            return -1;
        }

        if (!initBuffer(curbuf++, hpp.data, NULL))
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
    //     shp.setExtent(ext);
    //     return true;
    // }
    //
    // bool shiftExtent(const int count) {
    //     pf.shiftExtent(count);
    //     shp.shiftExtent(count);
    //     return true;
    // }
};

#endif