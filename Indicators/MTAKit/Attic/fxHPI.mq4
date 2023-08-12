//+------------------------------------------------------------------+
//|                                                          HPI.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#property strict

// FIXME rename file => fxHPI.mq4

#property description "Herrick Payoff Index, adapted for FX markets"

#property indicator_buffers 1
#property indicator_color1 clrDodgerBlue
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

#property indicator_separate_window

#property indicator_level1 0.0
#property indicator_levelcolor clrDarkSlateGray

extern const int hpi_period = 6;                              // HPI Period
extern const ENUM_APPLIED_PRICE hpi_price_mode = PRICE_CLOSE; // Applied Price

#include <../Libraries/libMTA/libHPI.mq4>

HPIData *hpi;

int OnInit()
{
    hpi = new HPIData(hpi_period, hpi_price_mode, _Symbol, _Period);
    if (hpi.initIndicator() == -1) {
        return INIT_FAILED;
    };
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
    return hpi.calculate(rates_total, prev_calculated);
}

void OnDeinit(const int dicode)
{
    FREEPTR(hpi);
}
