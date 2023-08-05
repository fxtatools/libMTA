//+------------------------------------------------------------------+
//|                                                          RVI.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#property strict

#property description "An adaptation of John Ehlers' Relative Vigor Index (John F. Ehlers, 2002)"

#property indicator_buffers 3

#property indicator_separate_window

#property indicator_minimum    -100
#property indicator_maximum    100

// RVI primary data
#property indicator_color1 clrMediumBlue
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

#property indicator_level1 0.0
#property indicator_level2 - 50.0
#property indicator_level3 50.0
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle 2

extern const int rvi_xma_period = 10; // MA for Crossover
extern const double rvi_scale_a = 1;  // Scale A
extern const double rvi_scale_b = 2;  // Scale B
extern const double rvi_scale_c = 2;  // Scale C
extern const double rvi_scale_d = 1;  // Scale D

#include <../Libraries/libMTA/libRVI.mq4>

RVIIn *rvi_in;

int OnInit()
{
    rvi_in = new RVIIn(rvi_scale_a, rvi_scale_b, rvi_scale_c, rvi_scale_d, rvi_xma_period, _Symbol, _Period);

    //// FIXME update API : initIndicator => bool
    // if(rvi_in.initIndicator()) ...
    rvi_in.initIndicator();
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
        rvi_in.initVars(rates_total, open, high, low, close, tick_volume, 0);
    }
    else
    {
        rvi_in.updateVars(open, high, low, close, tick_volume, EMPTY, 0);
    }

    return (rates_total);
}

void OnDeinit(const int dicode)
{
    FREEPTR(rvi_in);
}
