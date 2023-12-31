//+------------------------------------------------------------------+
//|                                                          OCPc.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#property strict

#property description "Adaptation of William Blau's True Strength Index"

#property indicator_separate_window

#property indicator_buffers 1
#property indicator_color1 clrDodgerBlue
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

#property indicator_level1 0.0
#property indicator_level2 - 15.0
#property indicator_level3 15.0
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle 2


extern int tsi_r = 10;                                    // First Smoothing Period
extern int tsi_s = 6;                                     // Second Smoothing Period
extern ENUM_APPLIED_PRICE tsi_price_mode = PRICE_TYPICAL; // Applied Price

#include <../Libraries/libMTA/libTSI.mq4>


TSIData *tsi_data;

int OnInit()
{
    tsi_data = new TSIData(tsi_r, tsi_s, tsi_price_mode, _Symbol, _Period);
    if (tsi_data.initIndicator() == -1)
    {
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

    return tsi_data.calculate(rates_total, prev_calculated);
}

void OnDeinit(const int dicode)
{
    FREEPTR(tsi_data);
}
