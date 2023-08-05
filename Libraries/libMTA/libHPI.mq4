#ifndef _LIBUO_MQ4
#define _LIBUO_MQ4

#property library
#property strict

#include "indicator.mq4"

// Herrick Payoff Index, adapted for FX markets
// - using price in place of HPI's open interest
// - using Weighted EMA for indicator
// - weighting MA values for volume
//
// Considerations for application:
//
// Noticing the relative minimum and maximum values produced with this
// adaptation of the HPI indicator, it may be applied to locatie the
// extents of any number of signifcant reversals in market price at the
// time frame of the indicator.
//
// The visual presentation of this indicator may be significantly affected
// by any large and short-term changes in market price -- such as may
// typically occur within some trading symbols, during a short time frame
// before the end of the market week i.e before 00:00 GMT Saturday.
//
// Though the presentation of the indicator as a graph may be visually
// affected, the numeric performace the indicator should be generally
// unaffected by such "market spike" events, outside of the reversal
// denoting any recent "market spike"
//
// Relative to any earlier reversal period in trends of market price,
// the indicator's performance should be normally consistent.
//
// Implementation Notes
//
// - The original HPI indicator, in an application for futures markets,
//   may be generally demonstrated with a period of 10.
//
//   This FX adaptation of the HPI indictor may be applicable within shorter
//   periods, and has been defined here with a default period of 6.
//
// References:
//
// Kaufman, Perry. J. (2013). Momentum and Oscillators. In Trading Systems
//   and Methods (5th ed.). Wiley. 410-411
//
class HPIGraph : public PriceIndicator
{
protected:
    PriceBuffer *hpi_buf; // buffer for HPI EMA

public:
    const int hpi_period;     // HPI EMA period
    const int hpi_price_mode; // Price mode for the FX adpated HPI

    HPIGraph(const int period = 6,
             const int price_mode = PRICE_TYPICAL,
             const string _symbol = NULL,
             const int _timeframe = EMPTY,
             const string _name = "HPI",
             const int _nr_buffers = 2) : hpi_period(period),
                                          hpi_price_mode(price_mode),
                                          PriceIndicator(_name, _nr_buffers, _symbol, _timeframe)
    {
        hpi_buf = price_mgr.primary_buffer;
    }
    ~HPIGraph()
    {
        // buffer deletion is managed under the buffer manager protocol
        hpi_buf = NULL;
    }

    virtual string indicatorName() const
    {
        return StringFormat("%s(%d)", name, hpi_period);
    }

    virtual int dataBufferCount()
    {
        return 1;
    }

    virtual int dataShift()
    {
        // one for previous, one for EMA, one for recalc, plus period
        return 3 + hpi_period;
    }

    virtual int indicatorUpdateShift(const int idx)
    {
        // 1 for recalculating previous after advance in time index
        return idx + 1 + dataShift();
    };

    void calcMain(const int idx, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
    {
        // Implementation Notes:
        //
        // - In the following implementation, values from the indicator will
        //   scale geometrically by the chart period. This appears to be a
        //   side effect of using the market points ratio as an HPI conversion
        //   factor.
        //
        // - Visually, this may resemble an RSI indicator line, albeit volume-
        //   adjusted and producing values at a substantially different numeric
        //   scale.
        //
        //   This indicator may often lead the RSI trend at least slightly, as an
        //   indicator of relative trends in market price.
        //
        // - In a visual analysis of relative trends in indicator values, this
        //   indicator may also resemble the CCI signal line, though differently
        //   affected for changes in market price.
        //
        // - If the HPI indicator line would be produced using only the current
        //   HPI's moving average, then when applied as overlayed with an RSI
        //   indicator of the same period - with the relative scale of the graphs
        //   adjusted visually - the combined graph may generally resemble, the
        //   RVI indicator,  as applied in this project with a signal line of the
        //   RVI moving average.
        //
        //   Albeit this similarity may seem effectively moot. The RSI and HPI
        //   values cannot be usefully applied in the same indicator, without
        //   some normal way to scale down the HPI into the numeric range of
        //   the RSI indicator.
        //
        // - This implementation uses the inverse of the market points ratio as
        //   an HPI conversion factor.
        //

        double ma = DBLZERO;
        double weights = DBLZERO;
        const double p_dbl = (double)hpi_period;

        for (int n = idx + hpi_period - 1, p_k = 1; n >= idx; n--, p_k++)
        {
            const double wfactor = (double)p_k / p_dbl;
            // mdiff: difference to previous median price
            const double mdiff = price_for(n, PRICE_MEDIAN, open, high, low, close) - price_for(n + 1, PRICE_MEDIAN, open, high, low, close);
            //// mdiff == 0 happens not rarely in FX symbols
            if (!dblZero(mdiff))
            {
                const double p_cur = price_for(n, hpi_price_mode, open, high, low, close);
                const double p_pre = price_for(n + 1, hpi_price_mode, open, high, low, close);
                // pdiff: difference to previous applied price
                const double pdiff = p_cur - p_pre;
                // The initial value may not represent an actual price value.
                //
                // This applies the inverse of the market points ratio as an HPI
                // conversion factor, in the adaptation for FX markets.
                const double cur = pricePoints(volume[n] * mdiff * (1 + (mdiff / fabs(mdiff)) * ((2 * fabs(pdiff)) / fmin(p_pre, p_cur))));
                ma += (cur * wfactor);
            }
            weights += wfactor;
        }
        ma /= weights;

        const double pre = hpi_buf.getState();
        if (pre == EMPTY_VALUE)
        {
            hpi_buf.setState(ma);
        }
        else
        {
            const double rslt = emaShifted(pre, ma, hpi_period);
            hpi_buf.setState(rslt);
        }
    }

    int calcInitial(const int _extent, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
    {
        const int calc_idx = _extent - 1 - HPIGraph::dataShift();
        hpi_buf.setState(EMPTY_VALUE);
        calcMain(calc_idx, open, high, low, close, volume);
        return calc_idx;
    }

    void initIndicator()
    {
        IndicatorShortName(indicatorName());

        const int nrbuf = dataBufferCount();
        IndicatorBuffers(nrbuf);

        const int curbuf = 0;
        SetIndexBuffer(curbuf, hpi_buf.data);
        SetIndexLabel(curbuf, "HPI");
        SetIndexStyle(curbuf, DRAW_LINE);
    }
};

#endif