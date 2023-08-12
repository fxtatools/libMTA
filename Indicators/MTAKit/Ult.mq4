//+------------------------------------------------------------------+
//|                                                          Ult.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#property strict

#property description "An adaptation of Larry Williams' Ultimate Oscillator"

#property indicator_buffers 2
#property indicator_color1 clrGoldenrod
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

#property indicator_color2 clrGray
#property indicator_width2 1
#property indicator_style2 STYLE_DOT


#property indicator_separate_window

#property indicator_level1     50.0
#property indicator_levelcolor clrDarkSlateGray

extern const int ult_period = 32;                             // Period, favoring a multiple of 4
extern const ENUM_APPLIED_PRICE ult_price_mode = PRICE_CLOSE; // Applied Price

#include <../Libraries/libMTA/libUlt.mq4>

UltData *ult;

int OnInit()
   {
    ult = new UltData(ult_period, ult_price_mode, _Symbol, _Period);

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
    return ult.calculate(rates_total, prev_calculated);
}

void OnDeinit(const int dicode)
{
    FREEPTR(ult);
}
