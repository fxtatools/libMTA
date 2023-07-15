//+------------------------------------------------------------------+
//|                                                        libTR.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#ifndef _LIBTR_MQ4
#define _LIBTR_MQ4 1

#property library
#property strict

#include <libMQL4.mq4>

/**
 * Iterator for Average True Range calculation
 *
 * Implementation Notes
 *
 * - The results of this iterator will vary with relation to the MetaTrader 4 ATR indicator.
 *
 *   The MT4 ATR indicator will smooth later ATR values across the defined ATR period,
 *   throughout the duration of ATR values calculation.
 *
 *   Subsequent of the initial period in market quotes, the following implementation
 *   will use only the exponential moving average for each individual ATR value. Per
 *   references cited below, this is believed to represent an adequate method for
 *   calculating ATR.
 *
 * - The interface to this iterator varies with relation to the MT4 ATR indicator.
 *
 *   The following implementation uses a time-series traversal of market high, low,
 *   and close quotes. This assumes that the caller has not configured the quote
 *   arrays for non-time-series access.
 *
 * - The following implementation uses units of market price, internally.
 *
 *   The `initialize_points()` method will set the ATR value into the provided data
 *   buffer, using units of points for ATRIter as initialized. This is believed
 *   to represent a methodology for establishing a helpful magnitude for values
 *   from ATR calculations.
 *
 *   Any calling function will need to re-translate each data buffer value from
 *   units of points to units of market price, before providing the price value
 *   to the `next_atr_price()` method. This may be called, for instance, during
 *   indicator update.
 *
 * - The methods `points_to_price()` and `price_to_points()` are provided for
 *   utility in converting output point and input price values for an `ATRIter`.
 * 
 *   These methods will use the points ratio initialized to the `ATRIter`, unless
 *   that points ratio is provided as `NULL`, in which case the methods will return
 *   the input value without mathematical translation.
 *
 * - If the `ATRIter` is being initialized for a market symbol other than the
 *   current symbol, the constructor `ATRIter(int atr_period, const double points)`
 *   should be used. Provided with the points ratio for the other market symbol, 
 *   this should serve to ensure a correct translation of price values to points
 *   values and conversely.
 *
 *   Otherwise, the constructor `ATRIter(int atr_period)` may be sufficient.
 * 
 * - To initialize an `ATRIter` without price-to-points conversion, call the
 *   constructor `ATRIter(int atr_period, const double points)` with a `NULL`
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
 */
class ATRIter
{
    const int atr_period_minus;
    const double points_ratio;

public:
    int atr_period;

    // FIXME if atr_period < 2, fail w/ a custom errno
    ATRIter(int _atr_period) : atr_period(_atr_period), atr_period_minus(atr_period - 1), points_ratio(_Point){};
    ATRIter(int _atr_period, double _points_ratio) : atr_period(_atr_period), atr_period_minus(atr_period - 1), points_ratio(_points_ratio){};

    double points_to_price(const double points)
    {
        if (points_ratio == NULL)
        {
            return points;
        }
        else
        {
            return points * points_ratio;
        }
    }

    double price_to_points(const double price)
    {
        if (points_ratio == NULL)
        {
            return price;
        }
        else
        {
            return price / points_ratio;
        }
    }

    double next_tr_price(const int idx, const double &high[], const double &low[], const double &close[])
    {
        // not applicable for the first True Range value
        const double prev_close = close[idx + 1];
        const double cur_high = high[idx];
        const double cur_low = low[idx];
        //// simplified calculation [Wik]
        return MathMax(cur_high, prev_close) - MathMin(cur_low, prev_close);
    }

    double next_atr_price(const int idx, const double prev_price, const double &high[], const double &low[], const double &close[])
    {
        // not applicable if extent < atr_period

        // by side effect, the next_tr_price() call will update extent to current

        // see implementation notes, above
        return (prev_price * atr_period_minus + next_tr_price(idx, high, low, close)) / atr_period;
    }

    double next_atr_points(const int idx, const double prev_points, const double &high[], const double &low[], const double &close[])
    {
        return next_atr_price(idx, points_to_price(prev_points), high, low, close);
    }

    void initialize_points(int extent, double &atr[], const double &high[], const double &low[], const double &close[])
    {
        //// if extent < atr_period , fail (FIXME)

        double last_atr = high[--extent] - low[extent--];

        for (int n = 1; n < atr_period; n++)
        {
            last_atr += next_tr_price(extent--, high, low, close);
        }
        last_atr = last_atr / atr_period;
        DEBUG("Initial ATR (%d) %f", extent, last_atr);
        atr[extent] = last_atr / points_ratio;

        while (extent != 0)
        {
            last_atr = next_atr_price(--extent, last_atr, high, low, close);
            atr[extent] = price_to_points(last_atr);
        }
    };
};

#endif
