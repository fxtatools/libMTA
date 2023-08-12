//+------------------------------------------------------------------+
//|                                                          OCPc.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#property strict

#property description "Adaptation of William Blau's True Strength Index"

#property indicator_buffers 1
#property indicator_color1 clrDodgerBlue
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

#property indicator_separate_window

extern int tsi_r = 10; // First Smoothing Period
extern int tsi_s = 6;  // Second Smoothing Period
// ^ TBD 6
extern ENUM_APPLIED_PRICE tsi_price_mode = PRICE_TYPICAL; // Applied Price

#include <../Libraries/libMTA/indicator.mq4>

/// @brief Adaptation of William Blau's True Strength Index
///
/// @par Known Limitations
//
//  ...
//
// @par References
//
// Kaufman, P. J. (2013). Momentum and Oscillators. In Trading Systems
//  and Methods (5th ed.). Wiley. 404-405
//
class TSIData : public PriceIndicator
{
protected:
    PriceBuffer *tsi_data;
    PriceBuffer *tsi_rev;

public:
    const int r_period;
    const int s_period;
    const int price_mode;

    TSIData(const int r = 10,
            const int s = 6,
            const int _price_mode = PRICE_TYPICAL,
            const string _symbol = NULL,
            const int _timeframe = NULL,
            const string _name = "TSI",
            const int _nr_buffers = 2,
            const int _data_shift = EMPTY) : r_period(r),
                                             s_period(s),
                                             price_mode(_price_mode),
                                             PriceIndicator(_name, _nr_buffers, _symbol, _timeframe,
                                                            _data_shift == EMPTY ? (r + s + 1) : data_shift)
    {
        tsi_data = price_mgr.primary_buffer;
        tsi_rev = dynamic_cast<PriceBuffer *>(tsi_data.next_buffer);
    };
    ~TSIData()
    {
        FREEPTR(tsi_data);
        FREEPTR(tsi_rev);
    }

    string indicatorName()
    {
        return StringFormat("%s(%d, %d)", name, r_period, s_period);
    }

    void calcMain(const int idx, MqlRates &rates[])
    {
        // the method of averaging applied in the Ultimate Oscillator
        // may be more generally more effective

        double s_ma = DBLZERO;
        double s_abs_ma = DBLZERO;
        double s_weights = DBLZERO;
        for (int n_s = idx + s_period - 1, f_s = 1; n_s >= idx; n_s--, f_s++)
        {
            const double wfactor_s = weightFor(f_s, s_period); // * rates[n_s].tick_volume;

            double r_sum = DBLZERO;
            double r_abs_sum = DBLZERO;
            double r_weights = DBLZERO;
            for (int n_r = n_s + r_period - 1, f_r = 1; n_r >= idx; n_r--, f_r++)
            {
                const MqlRates cur = rates[n_r];
                const MqlRates pre = rates[n_r + 1];
                const double wfactor = weightFor(f_r, r_period); // * (double) cur.tick_volume;
                const double rchg = priceFor(cur, price_mode) - priceFor(pre, price_mode);
                const double rfactored = rchg * wfactor;
                r_sum += rfactored;
                r_abs_sum += fabs(rfactored);
                r_weights += wfactor;
            }
            s_ma += wfactor_s * (r_sum / r_weights);
            s_abs_ma += wfactor_s * (r_abs_sum / r_weights);
            s_weights += wfactor_s;
        }
        s_ma /= s_weights;
        s_abs_ma /= s_weights;

        const double tsi = (100 * s_ma) / s_abs_ma;

        DEBUG("TSI [%d] %f", idx, tsi);

        tsi_data.setState(tsi);

        const double pre = tsi_data.getState();
        // EMA smoothing for the indicator (FIXME insufficient in itself - use LWMA)
        /*
        if (pre == EMPTY_VALUE || dblZero(pre))
        {
            tsi_data.setState(tsi);
        }
        else
        {
            const double nxt = ema(pre, tsi, ema_period);
            tsi_data.setState(nxt);
        }
        */

        // volume-weighted LWMA at half the main period, or half + 1 if main period is odd.
        const int period_ma = (int) ceil(r_period + s_period / 2.0);
        const double cur_weight = 2 * (double) rates[idx].tick_volume;
        const double pre_weight = (double) rates[idx + 1].tick_volume;
        double sum = (tsi * cur_weight) + (pre * pre_weight);
        double weights = cur_weight + pre_weight;
        const int stop = idx + 1; // stop before previous
        for (int n = idx + period_ma - 1, p_k = 1; n > stop; n--, p_k++)
        {
            const double early = tsi_data.get(n);
            if (early == EMPTY_VALUE) {
                tsi_data.setState(tsi);
                return;
            }
            else  {
                const double wfactor = weightFor(p_k, period_ma) * (double) rates[n].tick_volume;
                sum += (early * wfactor);
                weights += wfactor;
            }
        }
        tsi_data.setState(sum / weights);

        return;

        // Reversal indication (TBD)
        const double tsi_far = tsi_data.get(idx + 2);
        if (tsi_far == EMPTY_VALUE)
            return;
        const double tsi_mid = tsi_data.get(idx + 1);
        if (tsi_mid == EMPTY_VALUE)
            return;
        const double rev_pre = tsi_rev.getState();  
        if (((tsi_far <= tsi_mid) && (tsi_mid > tsi)) || ((tsi_far >= tsi_mid) && (tsi_mid < tsi)))
        {
            const double rev_cur = (tsi_far + tsi_mid + tsi) / 3.0;
            if (rev_pre == EMPTY_VALUE)
            {
                tsi_rev.setState(rev_cur);
            }
            else
            {
                tsi_rev.setState(ema(rev_pre, rev_cur, 10));
            }
        } // else TBD
    }

    int calcInitial(const int _extent, MqlRates &rates[])
    {
        const int calc_idx = _extent - data_shift - 1;
        tsi_rev.setState(EMPTY_VALUE);
        calcMain(calc_idx, rates);
        return calc_idx;
    }

    virtual int initIndicator(const int start = 0)
    {
        if (!PriceIndicator::initIndicator()) {
            return -1;
        }
        if (!initBuffer(start, tsi_data.data, "TSI")) {
            return -1;
        }
        return start + 1;
    }
};

TSIData *tsi_data;

// Using a non-const MqlRates[]
// part of a normative API for providing quote data to indicators,
// with or without the call placed in an indicator event function
//
// MqlRates rateinfo[];

int OnInit()
{
    tsi_data = new TSIData(tsi_r, tsi_s, tsi_price_mode, _Symbol, _Period);

    // ArraySetAsSeries(rateinfo, true);

    //// FIXME update API : initIndicator => bool
    // return tsi_data.initIndicator();
    tsi_data.initIndicator();
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

    return tsi_data.calculate(rates_total, prev_calculated);
}

void OnDeinit(const int dicode)
{
    FREEPTR(tsi_data);
    // ArrayFree(rateinfo);
}
