//+------------------------------------------------------------------+
//|                                                         iADX.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+
#property strict

#property indicator_buffers 3 // number of drawn buffers
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

extern const int iadx_period = 10; // EMA Period
extern const int iadx_period_shift = 3; // Forward Shift for EMA Period

#include <../Libraries/libMTA/libADX.mq4>

ADXBuffer* adx_buffer;

int OnInit()
{
  string shortname = "ADX++";

  adx_buffer = new ADXBuffer(iadx_period, iadx_period_shift, _Symbol, _Period);

  IndicatorBuffers(4);

  IndicatorShortName(StringFormat("%s(%d, %d)", shortname, iadx_period, iadx_period_shift));
  IndicatorDigits(Digits);

  SetIndexBuffer(0, adx_buffer.dx_buffer.data);
  SetIndexLabel(0, "DX");
  SetIndexStyle(0, DRAW_LINE);

  SetIndexBuffer(1, adx_buffer.plus_di_buffer.data);
  SetIndexLabel(1, "+DI");
  SetIndexStyle(1, DRAW_LINE);

  SetIndexBuffer(2, adx_buffer.minus_di_buffer.data);
  SetIndexLabel(2, "-DI");
  SetIndexStyle(2, DRAW_LINE);

  SetIndexBuffer(3, adx_buffer.atr_buffer.data);
  SetIndexLabel(3, NULL);
  SetIndexStyle(3, DRAW_NONE);

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
  if (prev_calculated == 0)
  {
    DEBUG("initializing for %d quotes", rates_total);
    adx_buffer.initialize_adx_data(rates_total, high, low, close);
    }
  else
  {
    adx_buffer.update_adx_data(high, low, close, rates_total);
  }
  return rates_total;
}

void OnDeinit(const int dicode) {
  delete adx_buffer;
}