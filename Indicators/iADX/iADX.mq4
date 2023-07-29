//+------------------------------------------------------------------+
//|                                                         iADX.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+
#property strict

#property indicator_buffers 4 // number of drawn buffers

#property indicator_color1 clrYellow
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

#property indicator_color2 clrOrange
#property indicator_width2 1
#property indicator_style2 STYLE_SOLID

#property indicator_color3 clrDimGray
#property indicator_width3 1
#property indicator_style3 STYLE_SOLID

/// declared in project file ...
// #property indicator_separate_window

extern const int iadx_period = 10;                               // EMA Period
extern const int iadx_period_shift = 3;                          // Forward Shift for EMA Period
extern const ENUM_APPLIED_PRICE iadx_price_mode = PRICE_TYPICAL; // ATR Applied Price

// libATR supports using e.g by Typical Price when calculating ATR,
// rather than the conventional close price

#include <../Libraries/libMTA/libADX.mq4>

ADXIter *adx_in;

int OnInit()
{

  adx_in = new ADXIter(iadx_period, iadx_period_shift, iadx_price_mode, _Symbol, _Period);

  IndicatorBuffers(adx_in.nDataBuffers()); // number of buffers applied for indicator
  IndicatorShortName(adx_in.indicator_name());
  IndicatorDigits(Digits);

  adx_in.initIndicator();

  return (INIT_SUCCEEDED);
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
    DEBUG("initializing for %d quotes", rates_total);
    adx_in.initVars(rates_total, open, high, low, close, 0);
  }
  else
  {
    adx_in.updateVars(open, high, low, close, EMPTY, 0);
  }
  return rates_total;
}

void OnDeinit(const int dicode)
{
  delete adx_in;
}
