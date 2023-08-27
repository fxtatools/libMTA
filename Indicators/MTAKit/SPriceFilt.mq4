//+------------------------------------------------------------------+
//|                                                          OCSprice.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#property strict

#property description "Smoothed Price, a filter-based application of John F. Ehlers' Super Smoother"

#property indicator_buffers 1
#property indicator_color1 clrLime
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

#property indicator_chart_window

extern int sprice_period = 14;                         // Period for Smoothing
extern ENUM_APPLIED_PRICE sprice_mode = PRICE_TYPICAL; // Applied Price

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#include <../Libraries/libMTA/libSPriceFilt.mq4>

SPFData *sprice_data;
 

int OnInit()
{
    sprice_data = new SPFData(sprice_period, sprice_mode, _Symbol, _Period);

    if (sprice_data.initIndicator() == -1)
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

    return sprice_data.calculate(rates_total, prev_calculated);
}

void OnDeinit(const int dicode)
{
    FREEPTR(sprice_data);
}
