#ifndef _LIBUO_MQ4
#define _LIBUO_MQ4

#property library
#property strict

#include "indicator.mq4"

// @brief Herrick Payoff Index, adapted for FX markets
//
// @par Adaptations
// - Using the inverse of the market points ratio as an HPI conversion factor
// - Using price in place of HPI's open interest
// - Using Weighted EMA for the indicator
// - Using the current tick volume as a weighting factor when calculating the
//   linear weighted moving average of current HPI
//
// @par Considerations for Application
//
// This indicator produces values relative to a single symbol, generally
// in oscillation around naught (0.0)
//
// Noticing the relative maximum and minimum values produced with this
// adaptation of the HPI indicator, the indicator may be applied to locate
// the extents of any number of signifcant reversals in market price, at
// the time frame of the indicator.
//
// @par Comparison to Other Technical Indicators
//
// - In a visual representation, this indicator may resemble an RSI
//   indicator line, albeit volume-adjusted and producing values at
//   a numeric scale differing by some order of magnitude.
//
// - In a visual analysis of relative trends in indicator values, this
//   indicator may also resemble an EMA signal line for CCI, though
//   differently affected for changes in market price.
//
// - If the source code for this implementation would be adapted to
//   produce an HPI indicator line using only the current HPI's moving
//   average, then when applied as overlayed with an RSI indicator of
//   the same period - with the relative scale of the graphs adjusted
//   visually, in the graph presentation - the combined graph of relative
//   HPI and RSI values may generally resemble the RVI indicator, applied
//   in this project with a signal line of a moving average of the RVI
//   indicator value.
//
//   Albeit, the RSI and HPI values may not be usefully applied in the same
//   indicator, if without some normal way to scale the HPI value into the
//   numeric range of the RSI indicator.
//
// @par Known Limitations
//
// Values from this HPI implementation will scale geometrically by the chart
// period.
//
// The visual presentation of this indicator may be significantly affected
// by any large and short-term changes in market price -- such as may
// typically occur within some trading symbols, during a short time frame
// before the end of the market week (not actually 00:00 GMT Saturday ????)
//
// Though the presentation of the indicator as a graph may be visually
// affected, the functional/numerical performace of the indicator should
// be generally unaffected by any abrupt "rate spike" event, outside of
// any reversal period immediately following the abrupt shift in market
// price.
//
// Relative to any earlier reversal period in trends of market price,
// the indicator's performance should be normally consistent.
//
// Implementation Notes
//
// - The original HPI indicator is applied for futures markets, and
//   may be generally demonstrated with an EMA period of 10.
//
//   This FX adaptation of the HPI indictor may be applicable within
//   shorter rate periods, and has been defined here with a default
//   period of 6.
//
// References:
//
// Kaufman, Perry. J. (2013). Momentum and Oscillators. In Trading
//   Systems and Methods (5th ed.). Wiley. 410-411
//
class HPIData : public PriceIndicator
{
protected:
    PriceBuffer *hpi_buf; // buffer for HPI EMA
    const int ema_shift;

public:
    const int hpi_period;     // HPI EMA period
    const int hpi_price_mode; // Price mode for the FX adpated HPI

    HPIData(const int period = 6,
            const int price_mode = PRICE_TYPICAL,
            const int _ema_shift = EMPTY,
            const string _symbol = NULL,
            const int _timeframe = EMPTY,
            const string _name = "HPI",
            const int _nr_buffers = 1) : hpi_period(period),
                                         hpi_price_mode(price_mode),
                                         ema_shift(_ema_shift == EMPTY ? (int) floor(period / 2) : _ema_shift),
                                         PriceIndicator(_name, _nr_buffers, _symbol, _timeframe)
    {
        hpi_buf = price_mgr.primary_buffer;
    }
    ~HPIData()
    {
        // buffer deletion is managed under the buffer manager protocol
        hpi_buf = NULL;
    }

    virtual string indicatorName()
    {
        return StringFormat("%s(%d, %d)", name, hpi_period, ema_shift);
    }

    virtual int dataBufferCount()
    {
        return 1;
    }

    virtual int dataShift()
    {
        // one for EMA-previous, plus EMA period
        return 1 + hpi_period;
    }

    virtual int indicatorUpdateShift(const int idx)
    {
        // 1 for recalculating previous after advance in time index
        return idx + 1 + dataShift();
    };

    void calcMain(const int idx, MqlRates &rates[])
    {

        double ma = DBLZERO;
        double weights = DBLZERO;
        const double p_dbl = (double)hpi_period;

        for (int n = idx + hpi_period - 1, p_k = 1; n >= idx; n--, p_k++)
        {
            //// including immediate volume in the MA weighting factor
            const double wfactor = weightFor(p_k, hpi_period) * (double)rates[n].tick_volume;
            const MqlRates r_cur = rates[n];
            const MqlRates r_pre = rates[n + 1];
            const MqlRates r_far = rates[n + 2];

            // mdiff: difference to previous median price
            const double mdiff = priceFor(r_cur, PRICE_MEDIAN) - priceFor(r_pre, PRICE_MEDIAN);

            //// mdiff == 0 happens not rarely in FX symbols
            if (!dblZero(mdiff))
            {
                const double p_cur = priceFor(r_cur, hpi_price_mode);
                const double p_pre = priceFor(r_pre, hpi_price_mode);
                const double p_far = priceFor(r_far, hpi_price_mode);
                const double f_cur = p_cur / p_pre;
                const double f_pre = p_pre / p_far;

                // pdiff: difference to previous applied price
                const double pdiff = f_cur - f_pre;
                // The current HPI value may not represent an actual price value.
                //
                // This applies the inverse of the market's point ratio as an HPI
                // conversion factor, in the adaptation for FX markets. This
                // conversion is managed thorugh the pricePoints() function.
                const double cur = pricePoints((double)r_cur.tick_volume * mdiff * (1 + (mdiff / fabs(mdiff)) * ((2 * fabs(pdiff)) / fmin(f_pre, f_cur))));
                ma += (cur * wfactor);
            }
            weights += wfactor;
        }
        ma /= weights;

        const double pre = hpi_buf.getState();
        if (pre == EMPTY_VALUE || dblZero(pre))
        {
            hpi_buf.setState(ma);
        }
        else
        {
            // shifted EMA retains some of the actual volatility of the initial value
            const double rslt = emaShifted(pre, ma, hpi_period, ema_shift);
            hpi_buf.setState(rslt);
        }
    }

    int calcInitial(const int _extent, MqlRates &rates[])
    {
        const int calc_idx = _extent - 1 - HPIData::dataShift();
        hpi_buf.setState(EMPTY_VALUE);
        calcMain(calc_idx, rates);
        return calc_idx;
    }

    virtual int initIndicator(const int start = 0)
    {
        if (!PriceIndicator::initIndicator())
        {
            return -1;
        }
        int idx = start;
        if (!initBuffer(idx++, hpi_buf.data, "HPI"))
        {
            return -1;
        }
        return idx;
    }
};

#endif
