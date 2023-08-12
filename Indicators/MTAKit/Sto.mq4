//+------------------------------------------------------------------+
//|                                                          STO.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#property strict

#property description "An adaptation of George Lane's Stochastic Oscillator"

#property indicator_buffers 2

#property indicator_separate_window

// STO primary data
#property indicator_color1 clrMediumBlue
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

// STO signal data
#property indicator_color2 clrFireBrick
#property indicator_width2 1
#property indicator_style2 STYLE_SOLID

#property indicator_color3 clrGold
#property indicator_width3 1
#property indicator_style3 STYLE_DOT

#property indicator_level1 0.0
#property indicator_level2 - 50.0
#property indicator_level3 50.0
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle 2

extern const int sto_k = 14; // K Period
extern const int sto_d = 8;  // D Period
extern const int sto_d_slow = 6;  // D Slow Period
extern const ENUM_APPLIED_PRICE sto_price_mode = PRICE_CLOSE; // Applied Price

#include <../Libraries/libMTA/libSTO.mq4>

StoData *sto_in;

int OnInit()
{
    sto_in = new StoData(sto_k, sto_d, sto_d_slow, sto_price_mode,  _Symbol, _Period);

    //// FIXME update API : initIndicator => bool
    // if(sto_in.initIndicator()) ...
    sto_in.initIndicator();
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
    return sto_in.calculate(rates_total, prev_calculated);
}

void OnDeinit(const int dicode)
{
    FREEPTR(sto_in);
}
