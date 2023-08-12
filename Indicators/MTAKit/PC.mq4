//+------------------------------------------------------------------+
//|                                                          OCPc.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#property strict

#property description "Average Change of Price, Volume-Weighted, in Points"

#property indicator_buffers 1
#property indicator_color1 clrDodgerBlue
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

#property indicator_separate_window

extern int pc_period = 10;                               // Period for Moving Average
extern ENUM_APPLIED_PRICE pc_price_mode = PRICE_TYPICAL; // Applied Price

#include <../Libraries/libMTA/indicator.mq4>

/// @brief An Indicator for Mean Percentage Change in Price
///
/// @par Known Limitations
//
//  This indicator does not provide any price adjustment for rate of change in price.
//
//  Thus, a point A with a higher rate of change in price, R<sub>a</sub>, at a lower 
//  overall price, P<sub>a</sub> will be represented in the indicator with a higher 
//  peak than indicated at a point B, when point B features a lower change in price 
//  R<sub>b</sub>, but at a significantly higher overall price P<sub>b</sub>. 
//
//  In this representation, Change(B) < Change(A) does not imply Price(B) < Price(A)
//
class PCData : public PriceIndicator
{
protected:
    PriceBuffer *pc_data;

public:
    const int pc_period;
    const int pc_price_mode;

    PCData(const int period = 10,
           const int price_mode = PRICE_TYPICAL,
           const string _symbol = NULL,
           const int _timeframe = NULL,
           const string _name = "PC",
           const int _nr_buffers = 1,
           const int _data_shift = EMPTY) : pc_period(period),
                                            pc_price_mode(price_mode),
                                            PriceIndicator(_name, _nr_buffers, _symbol, _timeframe, _data_shift == EMPTY ? (period + 1) : data_shift)
    {
        pc_data = price_mgr.primary_buffer;
    };
    ~PCData()
    {
        FREEPTR(pc_data);
    }

    string indicatorName()
    {
        return StringFormat("%s(%d)", name, pc_period);
    }

    double chgAt(const int idx, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[], const int period = 1)
    {
        // from libRVI.mq4
        double diff = DBLZERO;
        double weights = DBLZERO;
        for (int n = idx + period - 1, p_k = 0; n >= idx; n--, p_k++)
        {
            const double wfactor = weightFor(p_k, period) * (double)volume[n];
            const double p_far = priceFor(n + 1, pc_price_mode, open, high, low, close);
            const double p_near = priceFor(n, pc_price_mode, open, high, low, close);
            // diff += (p_far - p_near) * wfactor;
            diff += (p_near - p_far) * wfactor; // not in libRVI
            weights += wfactor;
        }
        if (weights == DBLZERO)
        {
            return DBLZERO;
        }
        else
        {
            return diff / weights;
        }
    }

    double chgAt(const int idx, MqlRates &rates[], const int period = 1)
    {
        // from libRVI.mq4
        //
        // ported for MqlRates this is seemingly useless
        double diff = DBLZERO;
        double weights = DBLZERO;
        for (int n = idx + period - 1, p_k = 0; n >= idx; n--, p_k++)
        {
            const double wfactor = weightFor(p_k, period) * (double)rates[n].tick_volume;
            const double p_far = priceFor(n + 1, pc_price_mode, rates);
            const double p_near = priceFor(n, pc_price_mode, rates);
            // diff += (p_far - p_near) * wfactor;
            diff += (p_near - p_far) * wfactor; // not in libRVI
            weights += wfactor;
        }
        if (weights == DBLZERO)
        {
            return DBLZERO;
        }
        else
        {
            return diff / weights;
        }
    }

    void calcMain(const int idx, MqlRates &rates[])
    {
        const double chg = pricePoints(chgAt(idx, rates, pc_period));
        DEBUG("mean price change (points) [%d] %f", idx, chg);
        
        // EMA smoothing for the indicator
        const double pre = pc_data.getState();
        if (pre == EMPTY_VALUE || dblZero(pre)) {
            pc_data.setState(chg);
        } else {
            const double nxt = ema(pre, chg, pc_period);
            pc_data.setState(nxt);
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

        int curbuf = 0;
        if (!initBuffer(start, pc_data.data, "Chg P")) {
            return -1;
        }
        return start + 1;
    }
};

PCData *pc_data;

// Using a non-const MqlRates[]
// part of a normative API for providing quote data to indicators,
// with or without the call placed in an indicator event function
//
// MqlRates rateinfo[];

int OnInit()
{
    pc_data = new PCData(pc_period, pc_price_mode, _Symbol, _Period);

    if (pc_data.initIndicator() == -1) {
        return INIT_FAILED;
    }
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

    return pc_data.calculate(rates_total, prev_calculated);
}

void OnDeinit(const int dicode)
{
    FREEPTR(pc_data);
    // ArrayFree(rateinfo);
}
