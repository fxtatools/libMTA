//+------------------------------------------------------------------+
//|                                                         iATR.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+
#property strict

#property indicator_buffers 1
#property indicator_color1 clrDodgerBlue
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

/// declared in project file ...
// #property indicator_separate_window

extern const int iatr_period = 14;                             // ATR EMA Period
extern const int iatr_period_shift = 1;                        // EMA Period shift
extern const ENUM_APPLIED_PRICE iadx_price_mode = PRICE_CLOSE; // Applied Price
extern const bool iatr_use_points = true;                      // Points if True, else Price

#include <../Libraries/libMTA/libATR.mq4>

ATRIter *atr_iter;

int OnInit()
{
  string shortname = "iATR";
  atr_iter = new ATRIter(iatr_period, iatr_period_shift, iadx_price_mode, iatr_use_points, _Symbol, _Period);

  IndicatorShortName(atr_iter.indicator_name());
  IndicatorDigits(Digits);
  atr_iter.initIndicator();

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
    DEBUG("init %d", rates_total);
    atr_iter.initVars(rates_total, open, high, low, close, 0);
  }
  else
  {
    DEBUG("updating %d/%d %s => %s", prev_calculated, rates_total, TimeToStr(atr_iter.latest_quote_dt), offset_time_str(0));
    atr_iter.updateVars(open, high, low, close, EMPTY, 0);
  }

  return (rates_total);
}

void OnDeinit(const int dicode)
{
  delete atr_iter;
}
