//+------------------------------------------------------------------+
//|                                                       ZZWave.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#property description "ZZWave High/Low Trace"
#property strict

#include <../Libraries/libMTA/zzindicator.mq4>

#property indicator_chart_window

//// must be declared directly in this file
#property indicator_buffers 1

#property indicator_color1 clrYellow
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

// #property indicator_level1     30.0
// #property indicator_level2     70.0
// #property indicator_levelcolor clrDimGrey
// #property indicator_levelstyle STYLE_DOT

double ZZWaveLine[];  // price buffer (high/low)
double ZZWaveState[]; // extent state buffer

int OnInit()
{
  return zz_init("ZZWave", ZZWaveLine, ZZWaveState);
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
  zz_pre_update(ZZWaveLine, ZZWaveState, rates_total, prev_calculated);

  // ensure that the calculation will pass through a number of reversals
  // within the previously calculated data points, or across all data points
  // if none were previously calculated
  const int limit = zz_retrace_end(ZZWaveLine, prev_calculated, rates_total);

  // printf("graphing %d quotes", limit);

  fill_extents_hl(ZZWaveLine, ZZWaveState, limit, open, high, low, close);

  return rates_total;
}
