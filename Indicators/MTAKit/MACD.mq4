//+------------------------------------------------------------------+
//|                                                       MACDpp.mq4 |
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

#property indicator_buffers 4

#property indicator_color1 clrForestGreen // MACD plus bars
#property indicator_width1 2
#property indicator_style1 STYLE_SOLID

#property indicator_color2 clrDarkOrange // MACD minus bars
#property indicator_width2 2
#property indicator_style2 STYLE_SOLID

#property indicator_color3 clrSteelBlue // MACD line
#property indicator_width3 1
#property indicator_style3 STYLE_SOLID

#property indicator_color4 clrFireBrick // MACD signal line
#property indicator_width4 1
#property indicator_style4 STYLE_SOLID

#include <../Libraries/libMTA/libMACD.mq4>

extern const int macd_fast_ema = 12;                               // Fast EMA
extern const int macd_slow_ema = 26;                               // Slow EMA
extern const int macd_signal_ema = 9;                              // Signal EMA
extern const ENUM_PRICE_MODE macd_price_mode = PRICE_MODE_TYPICAL; // Price Mode

MACDIndicator *macd_in;

int OnInit()
{
  macd_in = new MACDIndicator(macd_fast_ema, macd_slow_ema, macd_signal_ema, macd_price_mode, _Symbol, _Period);
  macd_in.initIndicator();
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
    DEBUG("Initialize for %d quotes", rates_total);
    macd_in.initVars(rates_total, open, high, low, close, tick_volume, 0);
  }
  else
  {
    DEBUG("Updating for index %d", rates_total - prev_calculated);
    macd_in.updateVars(open, high, low, close, tick_volume, 0);
  }
  return rates_total;
}

void OnDeinit(const int dicode)
{
  FREEPTR(macd_in);
}
