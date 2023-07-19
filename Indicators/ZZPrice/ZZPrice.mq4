//+------------------------------------------------------------------+
//|                                                      ZZPrice.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#property description "ZZWave Price Trace"
#property strict

#include <pricemode.mq4>

extern const ENUM_PRICE_MODE zzwave_price_mode = PRICE_MODE_TYPICAL_OPEN; // Price mode for analysis

#include <zzindicator.mq4>

#property indicator_buffers 1
// ^ set only the number of drawn indicators
#property indicator_color1 clrMagenta
#property indicator_width1 2
#property indicator_style1 STYLE_SOLID

double ZZPriceLine[];  // price buffer (calculated)
double ZZPriceState[]; // extent state buffer

int OnInit()
{
  return zz_init("ZZPrice", ZZPriceLine, ZZPriceState);
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
  zz_pre_update(ZZPriceLine, ZZPriceState, rates_total, prev_calculated);

  // ensure that the calculation will pass through a number of reversals
  // within the previously calculated data points, or across all data points
  // if none were previously calculated
  const int limit = zz_retrace_end(ZZPriceLine, prev_calculated, rates_total);

  fill_extents_price(ZZPriceLine, ZZPriceState, limit, zzwave_price_mode, open, high, low, close);

  return rates_total;
}
