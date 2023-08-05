//+------------------------------------------------------------------+
//|                                                          Ult.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#property strict

#property description "Ultimate Oscillator"

#property indicator_buffers 1
#property indicator_color1 clrDodgerBlue
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

#property indicator_separate_window

/// original calculation uses periods 7, 14, 28
/// adapted: 5, 10, 30

extern const int ult_scale_a = 4;                             // Scale A
extern const int ult_period_a = 5;                            // Period A

extern const int ult_scale_b = 2;                             // Scale B
extern const int ult_period_b = 10;                           // Period B

extern const int ult_scale_c = 1;                             // Scale C
extern const int ult_period_c = 30;                           // Period C

extern const ENUM_APPLIED_PRICE ult_price_mode = PRICE_CLOSE; // Applied Price

#include <../Libraries/libMTA/libUlt.mq4>

UltOsc *ult;

int OnInit()
{
    ult = new UltOsc(ult_period_a, ult_period_b, ult_period_c, ult_scale_a, ult_scale_b, ult_scale_c, ult_price_mode, _Symbol, _Period);
 
    //// FIXME update API : initIndicator => bool
    // return ult.initIndicator();
    ult.initIndicator();
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
    if (prev_calculated == 0)
    {
        ult.initVars(rates_total, open, high, low, close, tick_volume, 0);
    }
    else
    {
        ult.updateVars(open, high, low, close, tick_volume, EMPTY, 0);
    }

    return (rates_total);
}

void OnDeinit(const int dicode)
{
    FREEPTR(ult);
}
