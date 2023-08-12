//+------------------------------------------------------------------+
//|                                                         iATR.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#property strict

#property indicator_buffers 1
#property indicator_color1 clrLimeGreen
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

#property indicator_separate_window

extern const int iatr_period = 14;                             // ATR EMA Period
extern const int iatr_period_shift = 1;                        // EMA Period shift
extern const ENUM_APPLIED_PRICE iadx_price_mode = PRICE_CLOSE; // Applied Price
extern const bool iatr_use_points = true;                      // Points if True, else Price

#include <../Libraries/libMTA/libATR.mq4>

ATRData *atr_data;

int OnInit()
{
  atr_data = new ATRData(iatr_period, iatr_period_shift, iadx_price_mode, iatr_use_points, _Symbol, _Period);

  if (atr_data.initIndicator() == -1) {
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
  return atr_data.calculate(rates_total, prev_calculated);
  if (prev_calculated == 0)
  {
    DEBUG("init %d", rates_total);
    atr_data.initVars(rates_total, open, high, low, close, tick_volume, 0);
  }
  else
  {
    DEBUG("updating %d/%d %s => %s", prev_calculated, rates_total, TimeToStr(atr_data.latest_quote_dt), offset_time_str(0));
    atr_data.updateVars(open, high, low, close, tick_volume, EMPTY, 0);
  }
  
  return (rates_total);
  */
}

void OnDeinit(const int dicode)
{
  FREEPTR(atr_data);
}
