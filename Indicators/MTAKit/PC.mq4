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
class PCData : public PriceIndicator
{
protected:
    ValueBuffer<double> *pc_data;

public:
    const int pc_period;
    const int pc_price_mode;

    PCData(const int period = 10,
           const int price_mode = PRICE_TYPICAL,
           const string _symbol = NULL,
           const int _timeframe = NULL,
           const bool _managed = true,
           const string _name = "PC",
           const int _nr_buffers = EMPTY,
           const int _data_shift = EMPTY) : pc_period(period),
                                            pc_price_mode(price_mode),
                                            PriceIndicator(_managed, _name,
                                                           _nr_buffers == EMPTY ? classBufferCount() : _nr_buffers,
                                                           _symbol, _timeframe,
                                                           _data_shift == EMPTY ? (period + 1) : data_shift)
    {
        pc_data = data_buffers.get(0);
    };
    ~PCData()
    {
        FREEPTR(pc_data);
    }

    int classBufferCount()
    {
        return 1;
    }

    string indicatorName()
    {
        return StringFormat("%s(%d)", name, pc_period);
    }

    double chgAt(const int idx, MqlRates &rates[], const int period = 1)
    {
        /// inspired after RVI
        // double sum = DBLZERO;
        double s_high = DBLZERO;
        double s_low = DBLZERO;
        double s_diff = DBLZERO;
        double weights = DBLZERO;
        for (int n = idx + period - 1, p_k = 1; n >= idx; n--, p_k++)
        {
            const MqlRates r_near = rates[idx];
            const MqlRates r_far = rates[idx + 1];
            const double wfactor = weightFor(p_k, period) * (double)r_near.tick_volume / (double) r_far.tick_volume;
            const double p_near = priceFor(r_near, pc_price_mode);
            const double p_far = priceFor(r_far, pc_price_mode);
            /// limitation: after a steep change in market price having a wide high/low range
            /// but an open/close range opposite the general direction of that high/low range,
            /// in effect this may illustrate a shadow of the earlier steep change, projected
            /// to the opposite direction, at some number of later ticks in the moving average
            const double p_hl = r_near.high - r_near.low;
            // if (!dblZero(p_hl))
            {
                // const double ohdiff = r_near.high - r_near.open;
                // const double oldiff = r_near.open - r_near.low;
                // const double signum = oldiff > ohdiff ? -1.0 : 1.0;
                const double diff = (p_near - p_far); // * signum;
                s_diff += diff * wfactor;
                s_high += r_near.high * wfactor;
                s_low += r_near.low * wfactor;
                weights += wfactor;
            }
        }
        const double s_hl = s_high - s_low;
        if (dblZero(weights) || dblZero(s_hl))
        {
            return DBLZERO;
        }
        else
        {
            return (s_diff / s_hl) / weights;
        }
    }

    void calcMain(const int idx, MqlRates &rates[])
    {
        const double chg = pricePoints(chgAt(idx, rates, pc_period));
        DEBUG("mean price change (points) [%d] %f", idx, chg);

        // EMA smoothing for the indicator
        const double pre = pc_data.getState();
        if (pre == EMPTY_VALUE || dblZero(pre))
        {
            pc_data.setState(chg);
        }
        else
        {
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
        if (!PriceIndicator::initIndicator())
        {
            return -1;
        }

        int curbuf = 0;
        if (!initBuffer(start, pc_data.data, "Chg P"))
        {
            return -1;
        }
        return start + 1;
    }
};

PCData *pc_data;


int OnInit()
{
    pc_data = new PCData(pc_period, pc_price_mode, _Symbol, _Period);

    if (pc_data.initIndicator() == -1)
    {
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
}
