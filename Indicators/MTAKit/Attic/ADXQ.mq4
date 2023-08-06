//+------------------------------------------------------------------+
//|                                                         iADX.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+
#property strict

#property indicator_buffers 4 // number of drawn buffers

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

#property indicator_separate_window

extern const int iadx_period = 10;                               // EMA Period
extern const int iadx_period_shift = 3;                          // Forward Shift for EMA Period
extern const ENUM_APPLIED_PRICE iadx_price_mode = PRICE_TYPICAL; // ATR Applied Price

#include <../Libraries/libMTA/libADX.mq4>
#include <../Libraries/libMTA/quotes.mq4>

ADXData *adx_data;
QuoteMgr *quotes;

int OnInit()
{
  adx_data = new ADXData(iadx_period, iadx_period_shift, iadx_price_mode, _Symbol, _Period, "ADXq++");
  quotes = new QuoteMgr(0);
  adx_data.initIndicator();
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
    quotes.fetchQuotes(rates_total);
    DEBUG("initializing for %d quotes", rates_total);
    adx_data.initVars(rates_total, quotes, 0);
  }
  else
  {
    quotes.fetchQuotes(adx_data.latestQuoteShift() + adx_data.indicatorUpdateShift(rates_total - prev_calculated) + 1);    
    adx_data.updateVars(quotes, EMPTY, 0);
  }
  return rates_total;
}

void OnDeinit(const int dicode)
{
  FREEPTR(adx_data);
  FREEPTR(quotes);
}
