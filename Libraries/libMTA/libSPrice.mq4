// libSPrice.mq4

#ifndef _LIBSPRICE_MQ4
#define _LIBSPRICE_MQ4 1

#property library
#property strict

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#include "indicator.mq4"

/// @brief Smoothed Price Indicator, an application of John F. Ehlers' Super Smoother
class SPriceData : public PriceIndicator
{
protected:
    ValueBuffer<double> *sprice_data;

public:
    const int period;     // period for the Super Smoother system
    const int price_mode; // applied price
    const int shift_factor;

    SPriceData(const int _period = 14,
               const int _price_mode = PRICE_TYPICAL,
               const string _symbol = NULL,
               const int _timeframe = NULL,
               const bool _managed = true,
               const string _name = "SPrice",
               const int _nr_buffers = EMPTY,
               const int _data_shift = EMPTY) : period(_period),
                                                price_mode(_price_mode),
                                                PriceIndicator(_managed, _name,
                                                               _nr_buffers == EMPTY ? classBufferCount() : _nr_buffers,
                                                               _symbol, _timeframe,
                                                               _data_shift == EMPTY ? 1 + _period : _data_shift)
    {
        sprice_data = data_buffers.get(0);
    };
    ~SPriceData()
    {
        FREEPTR(sprice_data);
    }

    int classBufferCount()
    {
        return 1;
    }

    string indicatorName()
    {
        return StringFormat("%s(%d)", name, period);
    }

    double calcSmoothed(const int idx, const double o_cur_0, const double o_cur_1, MqlRates &rates[])
    {
        const MqlRates r_cur = rates[idx];
        const MqlRates r_pre = rates[idx + 1];
        const double i_cur_0 = priceFor(r_cur, price_mode);
        const double i_cur_1 = priceFor(r_pre, price_mode);
        return smoothed(period, i_cur_0, i_cur_1, o_cur_0, o_cur_1);
    }

    void calcMain(const int idx, MqlRates &rates[])
    {
        const double o_cur_0 = sprice_data.getState(); // the stored value at idx + 1
        const double o_cur_1 = sprice_data.get(idx + 2);
        const double _sm = calcSmoothed(idx, o_cur_0, o_cur_1, rates);
        sprice_data.setState(_sm);
    }

    int calcInitial(const int _extent, MqlRates &rates[])
    {
        int idx = _extent - 1;
        const int calc_idx = idx - 4;
        DEBUG("Calc IDX %d, DS %d", calc_idx, data_shift);
        double cur = priceFor(idx--, price_mode, rates);
        double pre = priceFor(idx--, price_mode, rates);
        double earliest = EMPTY_VALUE;
        while (idx >= calc_idx)
        {
            /// Implementation note: Not a delay with regards to calculation,
            /// simply a delay as to how soon the values will be stored
            /// in the effective output array of the data buffer
            ///
            /// chart points in the domain [idx, calc_idx) would be empty 
            /// values, though the calculation was performed here for those 
            /// chart points
            earliest = pre;
            pre = cur;
            cur = calcSmoothed(idx--, pre, earliest, rates);
        }
        sprice_data.storeState(calc_idx + 1, pre);
        sprice_data.setState(cur);
        return calc_idx;
    }

    virtual int initIndicator(const int start = 0)
    {
        if (start == 0 && !PriceIndicator::initIndicator())
        {
            return -1;
        }

        int curbuf = start;
        if (!initBuffer(curbuf++, sprice_data.data, start == 0 ? "PS" : NULL))
        {
            return -1;
        }
        return curbuf;
    }
};

#endif