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
class ATRIter : public Chartable
{
protected:
    const int ema_shifted_period;

    // for the ADX Avg implementation
    ATRIter(string _symbol, int _timeframe) : ema_period(EMPTY), ema_shift(EMPTY), ema_shifted_period(EMPTY), latest_quote_dt(0), Chartable(_symbol, _timeframe){};

    class ATRBufferMgr : public BufferMgr
    {
    public:
        RateBuffer *atr_buffer;
        ATRBufferMgr(const int extent = 0)
        {
            atr_buffer = new RateBuffer(extent, true);
            first_buffer = atr_buffer; // for BufferMgr protocol
        }
        ~ATRBufferMgr()
        {
            FREEPTR(atr_buffer);
        }
    };

    ATRBufferMgr *atr_buffer_mgr;

public:
    const int ema_period;
    const int ema_shift;
    const int price_mode;
    datetime latest_quote_dt;

    // points ratio is used in iATR
    ATRIter(const int _ema_period, const int _ema_shift = 1, const int _price_mode = PRICE_CLOSE, string _symbol = NULL, const int _timeframe = EMPTY) : ema_period(_ema_period), ema_shift(_ema_shift), ema_shifted_period(_ema_period - _ema_shift), price_mode(_price_mode), latest_quote_dt(0), Chartable(_symbol, _timeframe)
    {
        atr_buffer_mgr = new ATRBufferMgr(0);
    };
    ~ATRIter()
    {
        FREEPTR(atr_buffer_mgr);
    }

    RateBuffer *atr_buffer() { return atr_buffer_mgr.atr_buffer; };

    bool setExtent(const int extent, const int padding = EMPTY)
    {
        return atr_buffer_mgr.setExtent(extent, padding);
    }

    bool reduceExtent(const int extent, const int padding = EMPTY)
    {
        return atr_buffer_mgr.reduceExtent(extent, padding);
    }

    const int latest_quote_offset()
    {
        return iBarShift(symbol, timeframe, latest_quote_dt, false);
    };

    double tr_price(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
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

    double initial_atr_price(int extent, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        double atr_sum = high[extent] - low[extent];
        DEBUG("initial atr sum [%d] %f", extent, atr_sum);
        for (int n = 1; n < ema_period; n++)
        {
            atr_sum += tr_price(--extent, open, high, low, close);
            DEBUG("initial atr sum [%d] %f", extent, atr_sum);
        }
        return atr_sum / ema_period;
    };

    double initial_atr_points(int extent, const double &open[],const double &high[], const double &low[], const double &close[])
    {
        return pricePoints(initial_atr_price(extent, open, high, low, close));
    };

    double next_atr_price(const int idx, const double prev_price, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        // As a minor point of divergence to Wilder's ATR: For current ATR,
        // this uses a moving weighted average of TR price within the EMA period
        // before calculating the EMA (shifted) price with this current ATR
        const double ema_period_dbl = (double) ema_period;
        double weights = __dblzero__;
        double atr_cur = __dblzero__;
        for(int n = idx + ema_period, p_k = 1; n >= idx; n--, p_k++) {
            const double wfactor = (double)p_k / ema_period_dbl;
            const double tr_cur = tr_price(idx, open, high, low, close);
            atr_cur += (tr_cur * wfactor);
            weights += wfactor;
        }
        atr_cur /= weights;
        return ((prev_price * ema_shifted_period) + (atr_cur * ema_shift)) / ema_period;
    };

    double next_atr_points(const int idx, const double prev_points, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        return pricePoints(next_atr_price(idx, pointsPrice(prev_points), open, high, low, close));
    };

    void initialize_atr_points(int _extent, const double &open[], const double &high[], const double &low[], const double &close[], const int padding = EMPTY)
    {
        setExtent(_extent, padding);
        const int __latest__ = 0;
        double last_atr = initial_atr_price(--_extent, open, high, low, close);
        _extent -= ema_period;
        atr_buffer_mgr.atr_buffer.data[_extent] = pricePoints(last_atr);
        DEBUG("Initial ATR at %s: %f", offset_time_str(_extent), pricePoints(last_atr));
        while (_extent != __latest__)
        {
            last_atr = next_atr_price(--_extent, last_atr, open, high, low, close);
            atr_buffer_mgr.atr_buffer.data[_extent] = pricePoints(last_atr);
        }
        latest_quote_dt = iTime(symbol, timeframe, __latest__);
    };

    void update_atr_points(const double &open[],const double &high[], const double &low[], const double &close[], const int _extent = EMPTY, const int padding = EMPTY)
    {
        if (_extent != EMPTY)
            setExtent(_extent, padding);
        // plus one, plus two to ensure the previous ATR is recalculated from final market quote,
        // mainly when the previous ATR was calculated at offset 0
        int idx = latest_quote_offset() + 1;
        double latest_atr = atr_buffer_mgr.atr_buffer.data[idx + 1];
        while (idx >= 0)
        {
            latest_atr = next_atr_points(idx, latest_atr, open, high, low, close);
            atr_buffer_mgr.atr_buffer.data[idx] = latest_atr;
            idx--;
        }
        latest_quote_dt = iTime(symbol, timeframe, 0);
    };

    void initialize_atr_price(int _extent, const double &open[],const double &high[], const double &low[], const double &close[], const int padding = EMPTY)
    {
        setExtent(_extent, padding);
        const int __latest__ = 0;
        double last_atr = initial_atr_price(--_extent, open, high, low, close);
        _extent -= ema_period;
        atr_buffer_mgr.atr_buffer.data[_extent] = last_atr;
        DEBUG("Initial ATR at %s: %f", offset_time_str(_extent), last_atr);
        while (_extent != __latest__)
        {
            last_atr = next_atr_price(--_extent, last_atr, open, high, low, close);
            atr_buffer_mgr.atr_buffer.data[_extent] = last_atr;
        }
        latest_quote_dt = iTime(symbol, timeframe, __latest__);
    };

    void update_atr_price(const double &open[],const double &high[], const double &low[], const double &close[], const int _extent = EMPTY, const int padding = EMPTY)
    {
        if (_extent != EMPTY)
            setExtent(_extent, padding);
        // plus one, plus two to ensure the previous ATR is recalculated from final market quote,
        // mainly when the previous ATR was calculated at offset 0
        int idx = latest_quote_offset() + 1;
        double latest_atr = atr_buffer_mgr.atr_buffer.data[idx + 1];
        while (idx >= 0)
        {
            latest_atr = next_atr_price(idx, latest_atr, open, high, low, close);
            atr_buffer_mgr.atr_buffer.data[idx] = latest_atr;
            idx--;
        }
        latest_quote_dt = iTime(symbol, timeframe, 0);
    };
};

#endif
