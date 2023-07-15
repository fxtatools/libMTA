//+------------------------------------------------------------------+
//|                                                         iATR.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+
#property strict

#include <../Libraries/libMTA/libATR.mq4>

#property indicator_buffers 1
#property indicator_color1 clrDodgerBlue
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

/// declared in project file ...
// #property indicator_separate_window

extern const int iatr_period = 14; // ATR Period

double ATR_data[];
ATRIter ATR_iter(iatr_period, _Point);

int OnInit()
{
  string shortname = "iATR";

  IndicatorShortName(StringFormat("%s(%d)", shortname, iatr_period));
  IndicatorDigits(Digits);

  SetIndexBuffer(0, ATR_data, INDICATOR_DATA);
  SetIndexLabel(0, shortname);
  SetIndexStyle(0, DRAW_LINE);

  ArraySetAsSeries(ATR_data, true);
  // ArrayResize(ATR_data, iBars(_Symbol, _Period));

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
    ATR_iter.initialize_atr_points(rates_total, ATR_data, high, low, close);
  }
  else
  {
    // printf("updating %d/%d", prev_calculated, rates_total);
    int count = rates_total == prev_calculated ? rates_total - 1 : prev_calculated - rates_total;
    double next_points = ATR_data[count];
    while(count != 0) 
    {
      next_points = ATR_iter.next_atr_points(--count, next_points, high, low, close);
      ATR_data[count] = next_points;
    }
  }

  return (rates_total);
}