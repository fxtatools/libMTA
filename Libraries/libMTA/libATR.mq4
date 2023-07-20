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
class ATRIter
{
protected:
    const int ema_shifted_period;
    const double points_ratio;

public:
    const string symbol;
    const int timeframe;

    int ema_period;
    int ema_shift;
    datetime latest_quote_dt;

    ATRIter(int _ema_period, int _ema_shift = 1, string _symbol = NULL, int _timeframe = EMPTY) : ema_period(_ema_period), ema_shift(_ema_shift), ema_shifted_period(_ema_period - _ema_shift), points_ratio(_Point), symbol(symbol == NULL ? _Symbol : _symbol), timeframe(_timeframe == EMPTY ? _Period : _timeframe), latest_quote_dt(0){};

    ATRIter(int _ema_period, double _points_ratio, int _ema_shift = 1, string _symbol = NULL, int _timeframe = EMPTY) : ema_period(_ema_period), ema_shift(_ema_shift), ema_shifted_period(_ema_period - _ema_shift), points_ratio(_points_ratio), symbol(symbol == NULL ? _Symbol : _symbol), timeframe(_timeframe == EMPTY ? _Period : _timeframe), latest_quote_dt(0){};

    const int latest_quote_offset()
    {
        return iBarShift(symbol, timeframe, latest_quote_dt, false);
    };

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
    };

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
    };

    double next_tr_price(const int idx, const double &high[], const double &low[], const double &close[])
    {
        // not applicable for the first True Range value
        const double prev_close = close[idx + 1];
        const double cur_high = high[idx];
        const double cur_low = low[idx];
        //// simplified calculation [Wik]
        return MathMax(cur_high, prev_close) - MathMin(cur_low, prev_close);
    };

    double initial_atr_price(int extent, const double &high[], const double &low[], const double &close[])
    {
        double atr_sum = high[extent] - low[extent];
        DEBUG("initial atr sum [%d] %f", extent, atr_sum);
        for (int n = 1; n < ema_period; n++)
        {
            atr_sum += next_tr_price(--extent, high, low, close);
            DEBUG("initial atr sum [%d] %f", extent, atr_sum);
        }
        return atr_sum / ema_period;
    };

    double initial_atr_points(int extent, const double &high[], const double &low[], const double &close[])
    {
        return price_to_points(initial_atr_price(extent, high, low, close));
    };

    double next_atr_price(const int idx, const double prev_price, const double &high[], const double &low[], const double &close[])
    {
        return ((prev_price * ema_shifted_period) + (next_tr_price(idx, high, low, close) * ema_shift)) / ema_period;
    };

    double next_atr_points(const int idx, const double prev_points, const double &high[], const double &low[], const double &close[])
    {
        return price_to_points(next_atr_price(idx, points_to_price(prev_points), high, low, close));
    };

    void initialize_atr_points(int extent, double &atr[], const double &high[], const double &low[], const double &close[])
    {
        const int __latest__ = 0;
        double last_atr = initial_atr_price(--extent, high, low, close);
        extent -= ema_period;
        atr[extent] = price_to_points(last_atr);
        DEBUG("Initial ATR at %s: %f", offset_time_str(extent), price_to_points(last_atr));
        while (extent != __latest__)
        {
            last_atr = next_atr_price(--extent, last_atr, high, low, close);
            atr[extent] = price_to_points(last_atr);
        }
        latest_quote_dt = iTime(symbol, timeframe, __latest__);
    };

    void update_atr_points(double &atr[], const double &high[], const double &low[], const double &close[])
    {
        // plus one, plus two to ensure the previous ATR is recalculated from final market quote,
        // mainly when the previous ATR was calculated at offset 0
        int extent = latest_quote_offset() + 1;
        double latest_atr = atr[extent + 1];
        while (extent != -1)
        {
            latest_atr = next_atr_points(extent, latest_atr, high, low, close);
            atr[extent] = latest_atr;
            extent--;
        }
        latest_quote_dt = iTime(symbol, timeframe, 0);
    };
};

#endif
