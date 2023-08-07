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
 *   buffer, using units of points for the `ATRData` as initialized. This is believed
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
 *   utility in converting point and price values for an `ATRData`.
 *
 *   These methods will use the points ratio initialized to the `ATRData`, unless
 *   that points ratio is provided as `NULL`, in which case the methods will return
 *   the input value without mathematical translation.
 *
 * - If the `ATRData` is being initialized for a market symbol other than the
 *   current symbol, the constructor `ATRData(int ema_period, const double points)`
 *   should be used. Provided with the points ratio for the other market symbol,
 *   this should serve to ensure a correct translation of price values to points
 *   values and conversely.
 *
 *   Otherwise, the constructor `ATRData(int ema_period)` may be sufficient.
 *
 * - To initialize an `ATRData` without price-to-points conversion, call the
 *   constructor `ATRData(int ema_period, const double points)` with a `NULL`
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
class ATRData : public PriceIndicator
{
protected:
    const int ema_shifted_period;

    // for the ADX Avg implementation
    ATRData(const int _price_mode,
            const string _symbol = NULL,
            const int _timeframe = EMPTY,
            const string _name = "ATR",
            const int _nr_buffers = 1) : ema_period(0),
                                         ema_shift(0),
                                         ema_shifted_period(0),
                                         indicator_points(false),
                                         price_mode(_price_mode),
                                         PriceIndicator(_name, _nr_buffers, _symbol, _timeframe)
    {
        atr_buffer = price_mgr.primary_buffer;
    };

public:
    const int ema_period;        // ATR MA period
    const int ema_shift;         // EMA shift (FIXME no longer used)
    const int price_mode;        // Price mode for True Range
    const bool indicator_points; // Boolean flag for ATR indicator

    PriceBuffer *atr_buffer;

    ATRData(const int _ema_period,
            const int _ema_shift = 1,
            const int _price_mode = PRICE_CLOSE,
            const bool use_points = false,
            const string _symbol = NULL,
            const int _timeframe = EMPTY,
            const string _name = "ATR++",
            const int _data_shift = EMPTY,
            const int _nr_buffers = 1) : ema_period(_ema_period),
                                         ema_shift(_ema_shift),
                                         ema_shifted_period(_ema_period - _ema_shift),
                                         price_mode(_price_mode),
                                         indicator_points(use_points),
                                         PriceIndicator(_name,
                                                        _nr_buffers,
                                                        _symbol,
                                                        _timeframe,
                                                        _data_shift == EMPTY ? ema_period : _data_shift)
    {
        atr_buffer = price_mgr.primary_buffer;
    };
    ~ATRData()
    {
        // base class dtor should free the buffer manager & buffers
        atr_buffer = NULL;
    }

    virtual string indicatorName() const
    {
        return StringFormat("%s(%d, %d)", name, ema_period, ema_shift);
    };

    virtual int dataBufferCount() const
    {
        // return the number of buffers used directly for this indicator.
        // should be incremented internally, in derived classes
        return 1;
    };


    virtual int calcInitial(const int _extent, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
    {
        // calculate mean of True Range for first ATR
        int idx = _extent - 1;
        double wsum = high[idx] - low[idx];
        if (indicator_points) {
            wsum = pricePoints(wsum);
        }
        atr_buffer.setState(wsum);
        atr_buffer.set(idx);
        DEBUG(indicatorName() + " ATR: Initial True Range sum [%d] %f", idx + 1, wsum);
        //// initialize the series calculation for volume-weighted mean
        double weights = (double) volume[idx--];
        wsum *= weights;
        //// calcualte initial volume-weighted mean calculation for ATR
        for (int n = 2; n < ema_period; n++)
        {
            const int ndx = idx--;
            const double cur = trueRange(ndx, price_mode, open, high, low, close);
            const double cadj = indicator_points ? pricePoints(cur) : cur;
            const double vol = (double) volume[ndx];
            weights += vol;
            wsum += (cadj * vol) ;
            const double mean = wsum / weights;
            atr_buffer.setState(mean);
            atr_buffer.set(idx);
            DEBUG(indicatorName() + " ATR: Initial True Range Current, Mean [%d] %f, %f", ndx, cadj, mean);
        }       
        // fill for ATR EMA, using calcMain()
        for (int n = 0; n < ema_period; n++, idx--) {
             DEBUG(indicatorName() + " ATR: Fill EMA to %d", idx);
             ATRData::calcMain(idx, open, high, low, close, volume);
             atr_buffer.set(idx);
        }
        // return current idx, as incremented after final idx--
        return idx + 1;
    };

    /// @brief calculate the current true range and current ATR
    virtual void calcMain(const int idx, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
    {    
        /// preweight the LWMA sum and weights with nearest true range and nearest volume
        const double cur = trueRange(idx, price_mode, open, high, low, close);
        double lwma = indicator_points ? pricePoints(cur) : cur;
        double weights = (double)volume[idx];
        lwma *= weights;

        // calculate the volume-weighted LWMA
        const double ema_period_dbl = (double)ema_period;
        const int stop = idx + 1; // ! stop before current
        for (int n = idx + ema_period - 1, p_k = 1; n > stop; n--, p_k++)
        {
            const double pre = atr_buffer.get(n);
            if (pre != EMPTY_VALUE)
            {
                const double wfactor = ((double)p_k / ema_period_dbl) * (double) volume[n];
                DEBUG(indicatorName() + " ATR: Previous ATR at %d: %f", n, pre);
                weights += wfactor;
                lwma += (pre * wfactor);
            }
        }
        lwma /= weights;
        atr_buffer.setState(lwma);
        DEBUG(indicatorName() + " ATR: New ATR [%d] %f", idx, lwma);
    };

    virtual void initIndicator()
    {
        PriceIndicator::initIndicator();
        IndicatorDigits(Digits);
        const int __start__ = 0;
        SetIndexBuffer(__start__, atr_buffer.data, INDICATOR_DATA);
        SetIndexLabel(__start__, "ATR");
        SetIndexStyle(__start__, DRAW_LINE);
    };
};

#endif
