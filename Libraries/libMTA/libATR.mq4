//+------------------------------------------------------------------+
//|                                                        libTR.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#ifndef _LIBATR_MQ4
#define _LIBATR_MQ4 1

#property library
#property strict

#include "libMQL4.mq4"

#include "indicator.mq4"

/**
 * Indicator for Average True Range
 *
 * References
 *
 * [ATR] https://www.investopedia.com/terms/a/atr.asp
 * [Wik] https://en.wikipedia.org/wiki/Average_true_range
 *
 * See Also
 *
 * [ADX] https://www.investopedia.com/terms/a/adx.asp
 *
 * - Note, this third page appears to recommend further smoothing for TR within the 
 *   ATR period, in a manner similar to that used in the original MT4 ATR indicator.
 *   The ATR page at [Wik] may not appear to suggest quite the same, but using only
 *   the same exponential  moving average calculation as used for the final ADX
 *   calculation
 *
 */
class ATRData : public PriceIndicator
{
protected:
    double adata_in[];
    double adata_out[];


    const int shift_factor;

    static int shiftFor(const int p) {
        // calculate a value to be used as the static initialization period
        return 4 * p;
    }


public:
    const int ma_period;         // ATR MA period
    const double ema_factor;     // Applied EMA factor
    const int price_mode;        // Price mode for True Range
    const bool indicator_points; // Boolean flag for ATR indicator

    ValueBuffer<double> *atr_buffer;

    ATRData(const int _ma_period,
            const int _price_mode = PRICE_CLOSE,
            const bool use_points = false,
            const string _symbol = NULL,
            const int _timeframe = EMPTY,
            const bool _managed = true,
            const string _name = "ATR++",
            const int _data_shift = EMPTY,
            const int _nr_buffers = EMPTY) : ma_period(_ma_period),
                                             shift_factor(shiftFor(_ma_period)),
                                             ema_factor(sqrt(_ma_period)), // obsolete
                                             price_mode(_price_mode),
                                             indicator_points(use_points),
                                             PriceIndicator(_managed,
                                                            _name,
                                                            _nr_buffers == EMPTY ? classBufferCount() : _nr_buffers,
                                                            _symbol,
                                                            _timeframe,
                                                            _data_shift == EMPTY ? shiftFor(_ma_period) + 1 : _data_shift
                                                            )
    {
        atr_buffer = data_buffers.get(0);
        ArrayResize(adata_in, ma_period);
        ArrayResize(adata_out, ma_period);
    };
    ~ATRData()
    {
        // base class dtor should free the buffer manager & buffers
        atr_buffer = NULL;
        ArrayFree(adata_in);
        ArrayFree(adata_out);
    }

    double atrAt(const int idx)
    {
        return atr_buffer.get(idx);
    }

    virtual string indicatorName()
    {
        return StringFormat("%s(%d)", name, ma_period);
    };

    virtual int classBufferCount()
    {
        // return the number of buffers used directly for this indicator.
        // should be incremented internally, in derived classes
        return 1;
    };


    /// @brief calculate a smoothed series of true range for the current index
    /// @param idx index for the calculation
    /// @param o_cur_0 the most recent previous calculation, in units of points
    /// @param o_cur_1 the next earlier previous calculation, in units of points
    /// @param rates array of rates structures
    /// @return the smoothed true range value for this index, in units of points.
    double calcSmoothedRng(const int idx, const double o_cur_0, const double o_cur_1, MqlRates &rates[])
    {
        const double i_cur_0 = pricePoints(trueRange(idx, rates, price_mode, ma_period));
        const double i_cur_1 = pricePoints(trueRange(idx+1, rates, price_mode, ma_period));
        const double s = smoothed(ma_period, i_cur_0, i_cur_1, o_cur_0, o_cur_1);
        return s; // in, out: points
    }

    virtual int calcInitial(const int _extent, MqlRates &rates[])
    {
        int idx = _extent - ma_period - 3;
        const int calc_idx = idx - data_shift;

        /// scaling from price to points

        double pre = pricePoints(trueRange(idx--, rates, price_mode, ma_period));
        double cur = pricePoints(trueRange(idx--, rates, price_mode, ma_period));
        double earliest = DBLZERO;
        for (int shift = idx; shift >= calc_idx - 1; shift--)
        {
            earliest = pre;
            pre = cur;
            cur = calcSmoothedRng(shift, pre, earliest, rates);
            FDEBUG(DEBUG_CALC, ("ATR Cur %f %s", cur, toString(rates[idx].time)));
        }
        const double _pre = indicator_points ? pre : pointsPrice(pre);
        atr_buffer.storeState(calc_idx + 1, _pre);
        const double _cur = indicator_points ? cur : pointsPrice(cur);
        atr_buffer.setState(_cur);
        return calc_idx;
    };

    virtual void calcMain(const int idx, MqlRates &rates[]) {
        const double o_cur_0 = atr_buffer.getState(); // the stored value at idx + 1
        const double o_cur_1 = atr_buffer.get(idx + 2);
        const double cur = calcSmoothedRng(idx, (indicator_points ? o_cur_0 : pricePoints(o_cur_0)), (indicator_points ? o_cur_1 : pricePoints(o_cur_1)), rates);
        FDEBUG(DEBUG_CALC, ("ATR 0: %f 1: %f Cur: %f %s", o_cur_0, o_cur_1, cur, toString(rates[idx].time)));
        const double _cur = indicator_points ? cur : pointsPrice(cur);
        atr_buffer.setState(_cur);
    }

    virtual int initIndicator(const int start = 0)
    {
        if (!PriceIndicator::initIndicator())
        {
            return -1;
        }
        if (!initBuffer(start, atr_buffer.data, "ATR"))
        {
            return -1;
        }
        return start + 1;
    };
};

#endif
