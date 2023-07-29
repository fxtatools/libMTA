//+------------------------------------------------------------------+
//|                                                         iADX.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+
#property strict


#property indicator_buffers 3 // number of drawn buffers

#property indicator_separate_window

#property indicator_color1 clrYellow
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

#property indicator_color2 clrOrange
#property indicator_width2 1
#property indicator_style2 STYLE_SOLID

#property indicator_color3 clrDimGray
#property indicator_width3 1
#property indicator_style3 STYLE_SOLID

#property indicator_level1 25.0
#property indicator_levelcolor clrDarkSlateGray

/// declared in project file ...
// #property indicator_separate_window

extern const int iadx_period = 10;                               // EMA Period
extern const int iadx_period_shift = 3;                          // Forward Shift for EMA Period
extern const ENUM_APPLIED_PRICE iadx_price_mode = PRICE_TYPICAL; // ATR Applied Price

#include <../Libraries/libMTA/libADXw.mq4>

ADXwIter *adx_in;

int OnInit()
{
  string shortname = "ADXW";

  adx_in = new ADXwIter(iadx_period, iadx_period_shift, iadx_price_mode, _Symbol, _Period);

  IndicatorBuffers(4);

  IndicatorShortName(StringFormat("%s(%d, %d)", shortname, iadx_period, iadx_period_shift));
  IndicatorDigits(Digits);

  SetIndexBuffer(0, adx_in.plus_di_buffer().data);
  SetIndexLabel(0, "+DI");
  SetIndexStyle(0, DRAW_LINE);

  SetIndexBuffer(1, adx_in.minus_di_buffer().data);
  SetIndexLabel(1, "-DI");
  SetIndexStyle(1, DRAW_LINE);

  SetIndexBuffer(2, adx_in.dx_buffer().data);
  SetIndexLabel(2, "DX");
  SetIndexStyle(2, DRAW_LINE);

  SetIndexBuffer(3, adx_in.atr_buffer().data);
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
    adx_in.initialize_adx_data(rates_total, open, high, low, close, 0);
  }
  else
  {
    adx_in.update_adx_data(open, high, low, close, rates_total, 0);
  }
  return rates_total;
}

void OnDeinit(const int dicode)
{
  FREEPTR(adx_in);
}
