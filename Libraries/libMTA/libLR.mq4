// Linear Regression for Price

#ifndef _LIBLR_MQ4
#define _LIBLR_MQ4 1

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#property strict
#property library

#include "indicator.mq4"
#include "trend.mq4"

/// @brief Linear Regression for Price
///
/// @par References
///
/// Kaufman, P. J. (2013). Regression Analysis. In Trading Systems and Methods
/// (5th ed., pp. 279–308). Wiley.

class LRData : public PriceIndicator
{
protected:
    ValueBuffer<double> *lr_data;

public:
    const int lr_period;
    const int price_mode;

    LRData(const int period = 10,
           const int _price_mode = PRICE_TYPICAL,
           const string _symbol = NULL,
           const int _timeframe = NULL,
           const bool _managed = true,
           const string _name = "LR",
           const int _nr_buffers = EMPTY,
           const int _data_shift = EMPTY) : lr_period(period),
                                            price_mode(_price_mode),
                                            PriceIndicator(_managed, _name,
                                                           _nr_buffers == EMPTY ? classBufferCount() : _nr_buffers,
                                                           _symbol, _timeframe,
                                                           _data_shift == EMPTY ? (period + 1) : data_shift)
    {
        lr_data = data_buffers.get(0);
    };
    ~LRData()
    {
        FREEPTR(lr_data);
    }

    int classBufferCount()
    {
        return 1;
    }

    string indicatorName()
    {
        return StringFormat("%s(%d)", name, lr_period);
    }

    void calcMain(const int idx, MqlRates &rates[])
    {
        // leastSquares(idx, lr_period, rates, lr_data.data, price_mode);

        for (int n = idx + lr_period - 1, nth = 1; n >= idx; n--, nth++)
        {
            const double cur = lr_data.get(n);
            if (cur == EMPTY_VALUE)
            {
                const double lr = leastSquaresD(idx, lr_period, rates, price_mode, nth);
                lr_data.storeState(n, lr);
            }
        }
        const double last = lr_data.get(idx);
        lr_data.setState(last);
    }

    int calcInitial(const int _extent, MqlRates &rates[])
    {
        const int calc_idx = _extent - data_shift;
        lr_data.setState(DBLEMPTY);
        return calc_idx;
    }

    virtual int initIndicator(const int start = 0)
    {
        if (start == 0 && !PriceIndicator::initIndicator())
        {
            return -1;
        }

        int curbuf = start;
        if (!initBuffer(curbuf, lr_data.data, start == 0 ? "LR" : NULL))
        // if (!initBuffer(curbuf, lr_data.data, "LR", start == 0 ? DRAW_LINE : DRAW_NONE))
        {
            return -1;
        }
        return curbuf + 1;
    }

    /// overriding these here wil also override in subclasses
    ///
    /// The LR indicator, in itself, does not use buffer state values
    ///
    // virtual void storeState(const int idx)
    // {
    //     /// NOP. This indicator produces a stateful calculation
    //     /// as a function of market price, requiring no additional
    //     /// variables for storage of state.
    // }

    // virtual void restoreFrom(const int idx)
    // {
    //     /// NOP. See previous
    // }

    bool bindMax(PriceReversal &_revinfo, const int begin = 0, const int end = EMPTY, const double limit = DBL_MAX)
    {
        return _revinfo.bindMax(lr_data, this, begin, end, limit);
    }

    bool bindMin(PriceReversal &_revinfo, const int begin = 0, const int end = EMPTY, const double limit = DBL_MIN)
    {
        return _revinfo.bindMin(lr_data, this, begin, end, limit);
    }
};

#endif
