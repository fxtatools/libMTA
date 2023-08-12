//+------------------------------------------------------------------+
//|                                                       MACDpp.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#property description "An adaptation of Gerald Appel's Moving Average Convergence Divergence (MACD)"
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

MACDData *macd_in;

int OnInit()
{
  macd_in = new MACDData(macd_fast_ema, macd_slow_ema, macd_signal_ema, macd_price_mode, _Symbol, _Period);
  if (!macd_in.initIndicator() == -1) {
    return INIT_FAILED;
  }
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
 return macd_in.calculate(rates_total, prev_calculated);
}

void OnDeinit(const int dicode)
{
  FREEPTR(macd_in);
}
