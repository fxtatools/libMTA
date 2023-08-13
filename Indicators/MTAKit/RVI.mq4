//+------------------------------------------------------------------+
//|                                                          RVI.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#property strict

#property description "An adaptation of John Ehlers' Relative Vigor Index (John F. Ehlers, 2002)"

#property indicator_buffers 3

#property indicator_separate_window

// #property indicator_minimum    -100
// #property indicator_maximum    100

// RVI primary data
#property indicator_color1 clrDarkSlateBlue
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID
// RVI signal data
#property indicator_color2 clrFireBrick
#property indicator_width2 1
#property indicator_style2 STYLE_SOLID
// SMA of rate at crossover
#property indicator_color3 clrGold
#property indicator_width3 1
#property indicator_style3 STYLE_DOT

// #property indicator_level1 0.0
// #property indicator_level2 - 50.0
// #property indicator_level3 50.0
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle 2

extern const int rvi_fill_period = 10; // Main period
extern const int rvi_signal_period = 5; // Signal Period
extern const ENUM_APPLIED_PRICE rvi_price_mode = PRICE_TYPICAL; // Applied Price


#include <../Libraries/libMTA/libRVI.mq4>

RVIData *rvi_in;

int OnInit()
{
    rvi_in = new RVIData(rvi_fill_period, rvi_signal_period, rvi_price_mode,  _Symbol, _Period);
    if (rvi_in.initIndicator() == -1) {
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
   return rvi_in.calculate(rates_total, prev_calculated);
}

void OnDeinit(const int dicode)
{
    FREEPTR(rvi_in);
}
