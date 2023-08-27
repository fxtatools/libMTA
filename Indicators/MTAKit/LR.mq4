//+------------------------------------------------------------------+
//|                                                          OCPc.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#property strict

#property description "Linear Regression for Price"

#property indicator_buffers 1
#property indicator_color1 clrSkyBlue
#property indicator_width1 2
#property indicator_style1 STYLE_SOLID

#property indicator_chart_window
// #property indicator_separate_window

extern int lr_period = 10;                               // Period for Least Squares
extern ENUM_APPLIED_PRICE lr_price_mode = PRICE_TYPICAL; // Price Mode

#include <../Libraries/libMTA/libLR.mq4>

LRData *lr_data;

int OnInit()
{
    lr_data = new LRData(lr_period, lr_price_mode, _Symbol, _Period);

    if (lr_data.initIndicator() == -1)
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

    return lr_data.calculate(rates_total, prev_calculated);
}

void OnDeinit(const int dicode)
{
    FREEPTR(lr_data);
}
