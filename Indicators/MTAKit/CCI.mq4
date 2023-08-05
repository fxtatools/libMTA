//+------------------------------------------------------------------+
//|                                                          CCI.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#property strict

#property description "Commodity Channel Index"

#property indicator_buffers 2

#property indicator_separate_window

// CCI primary data
#property indicator_color1 clrMediumBlue
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID
// CCI signal data
#property indicator_color2 clrFireBrick
#property indicator_width2 1
#property indicator_style2 STYLE_SOLID

/*
#property indicator_level1     0.0
#property indicator_level2     -45.0
#property indicator_level3     45.0
#property indicator_levelcolor clrDimGray
*/

extern const int cci_mean_period = 20;                          // Mean Period
extern const int cci_signal_period = 9;                         // Signal Period
extern const ENUM_APPLIED_PRICE cci_price_mode = PRICE_TYPICAL; // Price Mode
extern const double cci_factor = 0.15;                          // CCI Scale factor

#include <../Libraries/libMTA/libCCI.mq4>

CCIGraph *cci_in;

int OnInit()
{
    cci_in = new CCIGraph(cci_mean_period, cci_signal_period, cci_price_mode, cci_factor, _Symbol, _Period);

    //// FIXME update API : initIndicator => bool
    // if(cci_in.initIndicator()) ...
    cci_in.initIndicator();
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
        cci_in.initVars(rates_total, open, high, low, close, tick_volume, 0);
    }
    else
    {
        cci_in.updateVars(open, high, low, close, tick_volume, EMPTY, 0);
    }

    return (rates_total);
}

void OnDeinit(const int dicode)
{
    FREEPTR(cci_in);
}
