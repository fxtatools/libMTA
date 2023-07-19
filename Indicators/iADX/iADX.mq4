//+------------------------------------------------------------------+
//|                                                         iADX.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+
#property strict

#property indicator_buffers 3
#property indicator_color1 clrGainsboro
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

#property indicator_color2 clrYellow
#property indicator_width2 1
#property indicator_style2 STYLE_SOLID

#property indicator_color3 clrOrange
#property indicator_width3 1
#property indicator_style3 STYLE_SOLID

/// declared in project file ...
// #property indicator_separate_window

extern const int iadx_period = 20; // iADX EMA Period
extern const int iadx_period_shift = 1; // EMA Period shift

#include <../Libraries/libMTA/libADX.mq4>

double ADX_dx[];
double ADX_plus_di[];
double ADX_minus_di[];
double ATR_data[]; // FIXME no longer used

ADXIter ADX_iter(iadx_period, iadx_period_shift);

static int __initial_rates_total__ = EMPTY;

#define BUFFER_PADDING 256

void iadx_pre_update(const int rates_total, const int prev_calculated) {
    if (__initial_rates_total__ == EMPTY) {
    __initial_rates_total__ = rates_total;
  } else if (rates_total > __initial_rates_total__ && (rates_total - __initial_rates_total__ >= BUFFER_PADDING)) {
    __initial_rates_total__ = rates_total;
    ArrayResize(ADX_dx, rates_total, BUFFER_PADDING);
    ArrayResize(ADX_plus_di, rates_total, BUFFER_PADDING);  
    ArrayResize(ADX_minus_di, rates_total, BUFFER_PADDING);  
    ArrayResize(ATR_data, rates_total, BUFFER_PADDING);  // FIXME no longer used
  }
}

int OnInit()
{
  string shortname = "iADX";

  IndicatorBuffers(4);

  IndicatorShortName(StringFormat("%s(%d, %d)", shortname, iadx_period, iadx_period_shift));
  IndicatorDigits(Digits);

  SetIndexBuffer(0, ADX_dx);
  SetIndexLabel(0, "DX");
  SetIndexStyle(0, DRAW_LINE);

  SetIndexBuffer(1, ADX_plus_di, INDICATOR_DATA);
  SetIndexLabel(1, "+DI");
  SetIndexStyle(1, DRAW_LINE);

  SetIndexBuffer(2, ADX_minus_di, INDICATOR_DATA);
  SetIndexLabel(2, "-DI");
  SetIndexStyle(2, DRAW_LINE);

  SetIndexBuffer(3, ATR_data, INDICATOR_DATA); // FIXME no longer used
  SetIndexLabel(3, NULL);
  SetIndexStyle(3, DRAW_NONE);

  ArraySetAsSeries(ADX_dx, true);
  ArraySetAsSeries(ADX_plus_di, true);
  ArraySetAsSeries(ADX_minus_di, true);
  ArraySetAsSeries(ATR_data, true); // FIXME no longer used

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
  iadx_pre_update(rates_total, prev_calculated);

  // FIXME the chart may need to be reinitialized when scrolling back in chart history

  /*
  if (prev_calculated != rates_total) {
    // debug
    printf("rates_total %d, prev_calculated %d", rates_total, prev_calculated);
  }
  */

  if (prev_calculated == 0)
  {
  
    // DEBUG("init %d", rates_total);
    printf("initializing for %d rate quotes", rates_total);
    ADX_iter.initialize_adx(rates_total, ATR_data, ADX_dx, ADX_plus_di, ADX_minus_di, high, low, close);
  }
  else
  {
    int extent = rates_total - prev_calculated;
    const int prev_ext = extent + 1;
    
    double next_atr = ATR_data[prev_ext];
    const double initial_dx=ADX_dx[prev_ext];
    // printf("updating %d/%d initial (%s)  atr %f dx  %f", prev_calculated, rates_total, offset_time_str(prev_ext), next_atr, initial_dx);
    // ^ next_atr here should stay the same across ticks ...
    const double initial_plus_di = ADX_plus_di[prev_ext];
    const double initial_minus_di = ADX_minus_di[prev_ext];

    ADX_iter.prepare_next_iter(next_atr, initial_dx, initial_plus_di, initial_minus_di);

    while(extent >= 0) {      
      next_atr = ADX_iter.next_atr_price(extent, next_atr, high, low, close);
      // printf("updating @ %d next atr (%s) %f", extent, offset_time_str(extent), next_atr);

      // ATR_data[extent] = next_atr;
      ADX_iter.update_adx(extent, ATR_data, ADX_dx, ADX_plus_di, ADX_minus_di, high, low, close);
      extent--;
    }
  }

  return (rates_total);
}