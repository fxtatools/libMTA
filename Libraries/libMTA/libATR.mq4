//+------------------------------------------------------------------+
//|                                                        libTR.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#ifndef _LIBATR_MQ4
#define _LIBATR_MQ4 1

#property library
#property strict

#include <libMQL4.mq4>

#include <pricemode.mq4>
#include "chartable.mq4"
#include "rates.mq4"
#include "indicator.mq4"

/**
 * Iterator for Average True Range calculation
 *
 * Implementation Notes
 *
 * - The results of this iterator will vary with relation to the MetaTrader 4 ATR indicator.
 *
 *   The MT4 ATR indicator will smooth later TR values across the defined ATR period,
 *   throughout the duration of ATR values calculation.
 *
 *   Subsequent of the initial ATR period in market quotes, the following implementation
 *   will use only the exponential moving average for each individual ATR value. Per
 *   references cited below, mainly [Wik] this is believed to represent an adequate
 *   method for calculating ATR.
 *
 * - The interface to this iterator varies with relation to the MT4 ATR indicator.
 *
 *   The following implementation uses a time-series traversal of market high, low,
 *   and close quotes. This assumes that the caller has not configured the quote
 *   arrays for non-time-series access.
 *
 * - The following implementation uses units of market price, internally.
 *
 *   The `initialize_atr_points()` method will set the ATR value into the provided data
 *   buffer, using units of points for the `ATRIter` as initialized. This is believed
 *   to represent a methodology for establishing a helpful magnitude for values
 *   from ATR calculations in Forex markets.
 *
 *   Any calling function will need to translate each data buffer value from
 *   units of points to units of market price, if providing the price value
 *   to the `next_atr_price()` method.
 *
 *   Alternately, the original points value may be provided to the method
 *   `next_atr_points()`.  This may be called, for instance, during indicator
 *   update.
 *
 * - The methods `points_to_price()` and `price_to_points()` are provided for
 *   utility in converting point and price values for an `ATRIter`.
 *
 *   These methods will use the points ratio initialized to the `ATRIter`, unless
 *   that points ratio is provided as `NULL`, in which case the methods will return
 *   the input value without mathematical translation.
 *
 * - If the `ATRIter` is being initialized for a market symbol other than the
 *   current symbol, the constructor `ATRIter(int ema_period, const double points)`
 *   should be used. Provided with the points ratio for the other market symbol,
 *   this should serve to ensure a correct translation of price values to points
 *   values and conversely.
 *
 *   Otherwise, the constructor `ATRIter(int ema_period)` may be sufficient.
 *
 * - To initialize an `ATRIter` without price-to-points conversion, call the
 *   constructor `ATRIter(int ema_period, const double points)` with a `NULL`
 *   value for `points`.
 *
 * - For purpose of relative precision in calculation, these methods will not
 *   normalize any point or price value per market scale.
 *
 * References
 *
 * [ATR] https://www.investopedia.com/terms/a/atr.asp
 * [Wik] https://en.wikipedia.org/wiki/Average_true_range
 *
 * See Also
 *
 * [ADX] https://www.investopedia.com/terms/a/adx.asp
 * - Note, this page appears to recommend further smoothing for TR within the ATR
 *   period, in a manner similar to that used in the original MT4 ATR indicator.
 *   The ATR page at [Wik] may not appear to suggest quite the same, but using only
 *   the same exponential  moving average calculation as used for the final ADX
 *   calculation
 *
 */
class ATRIter : public PriceIndicator
{
protected:
    const int ema_shifted_period;

    // for the ADX Avg implementation (FIXME needs price_mode)
    ATRIter(const string _symbol,
            const int _timeframe,
            const string _name,
            const int _nr_buffers = 1) : ema_period(0),
                                         ema_shift(0),
                                         ema_shifted_period(0),
                                         indicator_points(false),
                                         price_mode(PRICE_CLOSE), // not directly used in ADXAvg (FIXME)
                                         PriceIndicator(_symbol, _timeframe, _name, _nr_buffers)
    {
        atr_buffer = price_mgr.primary_buffer;
    };

public:
    const int ema_period;
    const int ema_shift;
    const int price_mode;
    const bool indicator_points; // mainly for the ATR++ indicator

    PriceBuffer *atr_buffer;

    ATRIter(const int _ema_period,
            const int _ema_shift = 1,
            const int _price_mode = PRICE_CLOSE,
            const bool use_points = false,
            string _symbol = NULL,
            const int _timeframe = EMPTY,
            const string _name = "ATR++",
            const int _nr_buffers = 1) : ema_period(_ema_period),
                                         ema_shift(_ema_shift),
                                         ema_shifted_period(_ema_period - _ema_shift),
                                         price_mode(_price_mode),
                                         indicator_points(use_points),
                                         PriceIndicator(_symbol, _timeframe, _name, _nr_buffers)
    {
        atr_buffer = price_mgr.primary_buffer;
    };
    ~ATRIter()
    {
        // base class dtor should free the buffer manager & buffers
        atr_buffer = NULL;
    }

    virtual string indicator_name() const
    {
        return StringFormat("%s(%d, %d)", name, ema_period, ema_shift);
    };

    virtual void storeState(const int idx)
    {
        // This indicator uses only one buffer, storing a 
        // price value for internal state. The price value
        // may need to be converted to points here,
        // corresponding to storage in the indicator data 
        // array.
        //
        // Derived indicators may use more than one buffer, 
        // so there is this indirection in the base class.
        // 
        PriceIndicator::storeState(idx);
        if (indicator_points)
        {
            // remap the transferred ATR data
            const double price = atr_buffer.getState();
            atr_buffer.data[idx] = pricePoints(price);
        }
    };

    virtual void restoreState(const int idx)
    {
        // see notes in store_state()
        PriceIndicator::restoreState(idx);
        if (indicator_points)
        {
            // remap the transferred ATR data
            const double points = atr_buffer.data[idx];
            atr_buffer.setState(pointsPrice(points));
        }
    };

    double trangePrice(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        const double prev_price = price_for(idx + 1, price_mode, open, high, low, close);
        const double cur_high = high[idx];
        const double cur_low = low[idx];
        //// simplified calculation. reference:
        //// Pruitt, G. (2016). Stochastics and Averages and RSI! Oh, My.
        ////   In The Ultimate Algorithmic Trading System Toolbox + Website (pp. 25–76).
        ////   John Wiley & Sons, Inc. https://doi.org/10.1002/9781119262992.ch2
        //// - Locally adapted to use a configurable price other than close,
        ////   for previous price
        return MathMax(cur_high, prev_price) - MathMin(cur_low, prev_price);
    };

    // was double initial_atr_price
    virtual int calcInitial(const int extent, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        int idx = extent - 1;
        double trange_sum = high[idx] - low[idx];
        idx--;
        DEBUG(indicator_name() + " Initial True Range sum [%d] %f", idx, trange_sum);
        for (int n = 1; n < ema_period; n++)
        {
            trange_sum += trangePrice(idx--, open, high, low, close);
            DEBUG(indicator_name() + " Initial True Range sum [%d] %f", idx, trange_sum);
        }
        const double initial_atr = trange_sum / ema_period;
        DEBUG(indicator_name() + " Initial ATR [%d] %f", idx, initial_atr);
        atr_buffer.setState(initial_atr);
        fillState(idx + 1, extent - 1);
        return idx;
    };

    // was double next_atr_price
    virtual void calcMain(const int idx, /* const double prev_price, */ const double &open[], const double &high[], const double &low[], const double &close[])
    {
        const double atr_pre = atr_buffer.getState();
        // As a minor point of divergence to Wilder's ATR: For current ATR,
        // this uses a moving weighted average of TR price within the EMA period
        // before calculating the EMA (shifted) price with this current ATR
        const double ema_period_dbl = (double)ema_period;
        double weights = __dblzero__;
        double atr_cur = __dblzero__;
        for (int n = idx + ema_period, p_k = 1; n >= idx; n--, p_k++)
        {
            const double wfactor = (double)p_k / ema_period_dbl;
            const double tr_cur = trangePrice(idx, open, high, low, close);
            atr_cur += (tr_cur * wfactor);
            weights += wfactor;
        }
        atr_cur /= weights;
        atr_cur = ((atr_pre * ema_shifted_period) + (atr_cur * ema_shift)) / ema_period;
        atr_buffer.setState(atr_cur);
    };

    virtual void initIndicator()
    {
        const int __start__ = 0;
        SetIndexBuffer(__start__, atr_buffer.data, INDICATOR_DATA);
        SetIndexLabel(__start__, "ATR");
        SetIndexStyle(__start__, DRAW_LINE);
    };
};

#endif
