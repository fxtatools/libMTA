//+------------------------------------------------------------------+
//|                                                          STO.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#property strict

#property description "An adaptation of George Lane's Stochastic Oscillator"

#property indicator_buffers 2

#property indicator_separate_window

// STO primary data (Series K)
#property indicator_color1 clrMediumBlue
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

// STO signal data (Series D)
#property indicator_color2 clrFireBrick
#property indicator_width2 1
#property indicator_style2 STYLE_SOLID

#property indicator_level1 0.0
 #property indicator_level2 -15.0
#property indicator_level3 15.0
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle 2

extern const int cci_mean_period = 10;                                  // K Period
extern const int cci_signal_period = 6;                                   // D Period
extern const ENUM_APPLIED_PRICE cci_price_mode = PRICE_CLOSE; // Applied Price

#include <../Libraries/libMTA/libSto.mq4>

StoData *sto_in;

int OnInit()
{
    sto_in = new StoData(cci_mean_period, cci_signal_period, cci_price_mode, _Symbol, _Period);
    const int idx = sto_in.initIndicator();
    if (idx == -1)
    {
        printf("Failed to initailize indicator");
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
    return sto_in.calculate(rates_total, prev_calculated);
}

void OnDeinit(const int dicode)
{
    FREEPTR(sto_in);
}
