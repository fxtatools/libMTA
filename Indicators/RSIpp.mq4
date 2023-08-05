//+------------------------------------------------------------------+
//|                                                        RSIpp.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#property copyright "Copyright 2023, Sean Champ"
#property link "https://www.example.com/nop"
#property version "1.00"
#property strict
#property indicator_separate_window

#property indicator_buffers 1

#property indicator_color1 clrDarkSlateBlue
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

#property indicator_levelcolor clrDarkSlateGray
#property indicator_level1     58.0
#property indicator_level2     42.0
#property indicator_levelstyle 2

#include <../Libraries/libMTA/libRSI.mq4>

extern const int rsi_period = 10;                                 // RSI MA Period
extern const ENUM_PRICE_MODE rsi_price_mode = PRICE_MODE_TYPICAL; // Applied Price

RSIIndicator *rsi_in;

int OnInit()
{
    rsi_in = new RSIIndicator(rsi_period, rsi_price_mode, _Symbol, _Period);
    rsi_in.initIndicator();
    return (INIT_SUCCEEDED);
};

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
        DEBUG("Initialize for %d quotes", rates_total);
        rsi_in.initVars(rates_total, open, high, low, close, tick_volume, 0);
    }
    else
    {
        DEBUG("Updating for index %d", rates_total - prev_calculated);
        rsi_in.updateVars(open, high, low, close, tick_volume, EMPTY, 0);
    }
    return rates_total;
};

void OnDeinit(const int dicode)
{
    FREEPTR(rsi_in);
};
