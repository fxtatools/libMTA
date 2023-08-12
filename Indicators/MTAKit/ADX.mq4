//+------------------------------------------------------------------+
//|                                                         iADX.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+
#property strict

#property description "An adaptation of Welles Wilder's Average Directional Index"

#property indicator_separate_window

#property indicator_buffers 5 // number of drawn buffers

#property indicator_color1 clrYellow
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

#property indicator_color2 clrOrange
#property indicator_width2 1
#property indicator_style2 STYLE_SOLID

#property indicator_color3 clrDimGray
#property indicator_width3 1
#property indicator_style3 STYLE_SOLID

#property indicator_color4 clrDeepSkyBlue
#property indicator_width4 1
#property indicator_style4 STYLE_DOT

// #property indicator_color5 clrLimeGreen
// #property indicator_width5 1
// #property indicator_style5 STYLE_DOT


#property indicator_level1     20.0
#property indicator_levelcolor clrDarkSlateGray

extern const int iadx_period = 10;                               // EMA Period
extern const int iadx_period_shift = 3;                          // Forward Shift for EMA Period
extern const ENUM_APPLIED_PRICE iadx_price_mode = PRICE_TYPICAL; // ATR Applied Price

#include <../Libraries/libMTA/libADX.mq4>

ADXData *adx_data;

int OnInit()
{
  adx_data = new ADXData(iadx_period, iadx_period_shift, iadx_price_mode, _Symbol, _Period);
  if (adx_data.initIndicator() == -1) {
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
  return adx_data.calculate(rates_total, prev_calculated);
}

void OnDeinit(const int dicode)
{
  FREEPTR(adx_data);
}
