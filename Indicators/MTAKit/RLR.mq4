//+------------------------------------------------------------------+
//|                                                          OCPc.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#property strict

#property description "Rate of Change in Linear Regression for Price"

#property indicator_buffers 3
#property indicator_color1 clrSkyBlue
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

#property indicator_color2 clrMediumBlue
#property indicator_width2 1
#property indicator_style2 STYLE_SOLID

// #property indicator_chart_window
#property indicator_separate_window

#property indicator_levelcolor clrDarkSlateGray
#property indicator_level1 0.0
#property indicator_level2 - 10.0
#property indicator_level3 10.0
#property indicator_levelstyle 2

extern int rlr_period = 10;                               // Period for Least Squares
extern ENUM_APPLIED_PRICE rlr_price_mode = PRICE_TYPICAL; // Price Mode

#include <../Libraries/libMTA/libLR.mq4>

class RLRData : public LRData
{

protected:
    ValueBuffer<double> *rlr_data;
    ValueBuffer<double> *lrev_data;
    const double ema_factor;
    PriceReversal revinfo;

public:
    RLRData(const int period = 10,
            const int _price_mode = PRICE_TYPICAL,
            const string _symbol = NULL,
            const int _timeframe = NULL,
            const bool _managed = true,
            const string _name = "RLR",
            const int _nr_buffers = EMPTY,
            const int _data_shift = EMPTY) : ema_factor(sqrt(lr_period)),
                                             revinfo(),
                                             LRData(period, _price_mode,
                                                    _symbol, _timeframe,
                                                    _managed, _name,
                                                    _nr_buffers == EMPTY ? classBufferCount() : _nr_buffers,
                                                    _data_shift)
    {
        rlr_data = data_buffers.get(1);
        lrev_data = data_buffers.get(2);
    };

    virtual int classBufferCount()
    {
        return LRData::classBufferCount() + 2;
    };

    void calcMain(const int idx, MqlRates &rates[])
    {
        const double lr_pre = lr_data.getState();
        LRData::calcMain(idx, rates);
        if (lr_pre == EMPTY_VALUE || dblZero(lr_pre))
        {
            rlr_data.setState(DBLZERO);
        }
        else
        {
            const double lr_cur = lr_data.getState();
            // const double chg = 100.0 - (100.0 / (1.0 + (lr_cur / lr_pre)));
            // const double chg = (lr_cur / lr_pre);
            const double chg = pricePoints(lr_cur - lr_pre);
            // rlr_data.setState(chg);
            const double pre = rlr_data.getState();
            if (pre == EMPTY_VALUE)
            {
                rlr_data.setState(chg);
            }
            else
            {
               const double _ema = ema(pre, chg, ema_factor);
                rlr_data.setState(_ema);
            }
        }

        ///
        /// LR reversal state
        ///
        /// presenting a partial illustration of LR rate change
        /// between relative minimum/maximum LR rate extents

        const bool minp = bindMin(revinfo);
        if (!minp)
        {
            lrev_data.setState(DBLEMPTY);
            return;
        }
        const double min_rate = revinfo.minmaxVal();
        const datetime min_dt = revinfo.nearTime();

        const bool maxp = bindMax(revinfo);
        if (!maxp)
        {
            lrev_data.setState(DBLEMPTY);
            return;
        }
        const double max_rate = revinfo.minmaxVal();
        const datetime max_dt = revinfo.nearTime();

        const bool bearish = max_dt > min_dt;

        const double lr_cur = lr_data.getState();
        const double chg = pricePoints(bearish ? (max_rate - lr_cur) : (lr_cur - min_rate));
        // lrev_data.setState();
        const double pre = lrev_data.getState();
        if (pre == EMPTY_VALUE)
        {
            lrev_data.setState(chg);
        }
        else
        {
            const double _ema = ema(pre, chg, ema_factor);
            lrev_data.setState(_ema);
        }
    }

    virtual int initIndicator(const int start = 0)
    {
        if (start == 0 && !PriceIndicator::initIndicator())
        {
            return -1;
        }
        // IndicatorDigits(6);

        int count = start;

        if (!initBuffer(count++, rlr_data.data, start == 0 ? "RLR" : NULL))
        {
            return -1;
        }
        if (!initBuffer(count++, lrev_data.data, start == 0 ? "LRev" : NULL, DRAW_NONE))
        {
            return -1;
        }
        return LRData::initIndicator(count);
    }
};

RLRData *rlr_in;

int OnInit()
{
    rlr_in = new RLRData(rlr_period, rlr_price_mode, _Symbol, _Period);

    if (rlr_in.initIndicator() == -1)
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

    return rlr_in.calculate(rates_total, prev_calculated);
}

void OnDeinit(const int dicode)
{
    FREEPTR(rlr_in);
}
