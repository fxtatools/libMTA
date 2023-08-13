//+------------------------------------------------------------------+
//|                                                          OCPc.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#property strict

#property description "Adaptation of Welles Wilder's Swing Index"

#property indicator_buffers 1
#property indicator_color1 clrDodgerBlue
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

#property indicator_separate_window

extern int si_in_offset = 1;             // Offset for previous rates
extern int si_in_period = 10;            // Period for Moving Average
extern bool si_in_weight_volume = false; // Weight the SI MA for volume?

#include <../Libraries/libMTA/indicator.mq4>

/// @brief An adaptation of Welles Wilder's Swing Index
///
/// @par Overview
//
///  Applied here with a linear weighted moving average, the
///  Swing Index may provide a general indicator of changes
///  in market volatility over time.
///
///  Generally, this adaptation of the Swing Index may resemble
///  a graph of relative changes in price, adjusted for a scale
///  of average market volatility.
///
/// @par Adaptations
///
///  This indicator provides an option for applying tick volume as 
///  a coefficient in the weighting factor for the moving average 
///  of SI. For this indicator, the option for volume weighting will
///  produce a substantially different indicator line. The option for
///  volume weighting is false, by default.
///
///  This adaptation of the Swing Index is generally scaled from
///  to a rate of market points.
///
/// @par References
///
/// Kaufman, P. J. (2013). Event-Driven Trends. In Trading
///   Systems and Methods (5th ed.). Wiley. 192-194
///
class SIData : public PriceIndicator
{
protected:
    PriceBuffer *si_data;

public:
    const int si_offset;
    const int si_period;
    const bool si_weight_volume;

    SIData(const int offset = 1,
           const int period = 10,
           const bool weight_volume = false,
           const string _symbol = NULL,
           const int _timeframe = NULL,
           const string _name = "SI",
           const int _nr_buffers = 1,
           const int _data_shift = EMPTY) : si_offset(offset),
                                            si_period(period),
                                            si_weight_volume(weight_volume),
                                            PriceIndicator(_name, _nr_buffers, _symbol, _timeframe, _data_shift == EMPTY ? (period + 1) : data_shift)
    {
        si_data = price_mgr.primary_buffer;
    };
    ~SIData()
    {
        FREEPTR(si_data);
    }

    string indicatorName()
    {
        return StringFormat("%s(%d, %d)", name, si_offset, si_period);
    }

    void calcMain(const int idx, MqlRates &rates[])
    {
        // same calculation as the local trueRange() function
        // except using only the previous close price as the
        // mode price.
        const MqlRates pre = rates[idx + si_offset];
        const MqlRates cur = rates[idx];
        const double pre_close = pre.close;
        const double cur_close = cur.close;
        const double cur_high = cur.high;
        const double cur_low = cur.low;
        const double trange = MathMax(cur_high, pre_close) - MathMin(cur_low, pre_close);

        const double si_k = MathMax(cur_high - pre_close, cur_low - pre_close);
        // const double si_m = points_ratio; // TBD - adaptation for FX markets
        const double si_m = 100; // a conventional M for the calclation, in reference

        const double si = dblZero(trange) ? DBLZERO : pricePoints(5000 * (((cur_close - pre.close) + (0.5 * (cur_close - cur.open)) + (0.25 * (pre_close - pre.open))) / trange) * (si_k / si_m));

        // EMA smoothing for the indicator
        const double pre_si = si_data.getState();
        if (pre_si == EMPTY_VALUE || dblZero(pre_si))
        {
            si_data.setState(si);
        }
        else
        {
            double si_ma = si;
            double si_weights = si_in_weight_volume ? (double) cur.tick_volume : 1.0;
            for (int n = idx + si_period - 1, p_k = 1; n > idx; n--, p_k++)
            {
                // volume weighting will produce a substantially different indicator graph, here
                const double n_si = si_data.get(n);
                if (n_si == EMPTY_VALUE)
                    continue;
                const double rweight = weightFor(p_k, si_period);
                const double wfactor = si_in_weight_volume ? rweight * (double) rates[n].tick_volume : rweight;
                si_ma += (n_si * wfactor);
                si_weights += wfactor;
            }
            si_ma /= si_weights;

            const double si_ema = ema(pre_si, si_ma, si_period);
            si_data.setState(si_ema);
            //si_data.setState(si_ma);
        }
    }

    int calcInitial(const int _extent, MqlRates &rates[])
    {
        const int calc_idx = _extent - data_shift;
        calcMain(calc_idx, rates);
        return calc_idx;
    }

    virtual int initIndicator(const int start = 0)
    {
        if (!PriceIndicator::initIndicator()) {
            return -1;
        }
        if (!initBuffer(start, si_data.data, "SI")) {
            return -1;
        }
        return start + 1;
    }
};

SIData *si_data;

// Using a non-const MqlRates[]
// part of a normative API for providing quote data to indicators,
// with or without the call placed in an indicator event function
//
// MqlRates rateinfo[];

int OnInit()
{
    si_data = new SIData(si_in_offset, si_in_period, si_in_weight_volume, _Symbol, _Period);

    // ArraySetAsSeries(rateinfo, true);

    //// FIXME update API : initIndicator => bool
    // return si_data.initIndicator();
    si_data.initIndicator();
    return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{

    return si_data.calculate(rates_total, prev_calculated);
}

void OnDeinit(const int dicode)
{
    FREEPTR(si_data);
    // ArrayFree(rateinfo);
}
