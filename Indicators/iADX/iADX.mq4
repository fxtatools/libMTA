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

extern const bool iadx_test_quote_mgr = false; // Test for Quote Manager
static bool quotes_reduced = false;

#include <../Libraries/libMTA/libADX.mq4>

double ADX_dx[];
double ADX_plus_di[];
double ADX_minus_di[];
double ATR_data[]; // FIXME no longer used

ADXIter ADX_iter(iadx_period, iadx_period_shift);

QuoteMgrHLC* hlc_quote_mgr;

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
  ArraySetAsSeries(ATR_data, true);

  if(iadx_test_quote_mgr) {
    hlc_quote_mgr = new QuoteMgrHLC(iBars(_Symbol, _Period), _Symbol, _Period);
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
  iadx_pre_update(rates_total, prev_calculated);
  if (prev_calculated == 0)
  {
    printf("initializing for %d quotes", rates_total);
    if(iadx_test_quote_mgr) {
      hlc_quote_mgr.setExtent(rates_total);
      ADX_iter.initialize_adx_data(*hlc_quote_mgr, ATR_data, ADX_dx, ADX_plus_di, ADX_minus_di, rates_total);
      quotes_reduced = false;
    } else {
      ADX_iter.initialize_adx_data(rates_total, ATR_data, ADX_dx, ADX_plus_di, ADX_minus_di, high, low, close);
    }
  }
  else
  {
    if(iadx_test_quote_mgr) {
      if (!quotes_reduced) {
        // TBD, Nearly arbitrary extent after [re]initialization of indicator data
        hlc_quote_mgr.reduceExtent(WindowBarsPerChart());
        quotes_reduced = true;
      }
      ADX_iter.update_adx_data(*hlc_quote_mgr, ATR_data, ADX_dx, ADX_plus_di, ADX_minus_di);
    } else {
      ADX_iter.update_adx_data(ATR_data, ADX_dx, ADX_plus_di, ADX_minus_di, high, low, close);
    }
  }

  return (rates_total);
}

void OnDeinit(const int dicode) {
  delete &ADX_iter;
  ArrayFree(ATR_data);
  ArrayFree(ADX_dx);
  ArrayFree(ADX_plus_di);
  ArrayFree(ADX_minus_di);
  if(iadx_test_quote_mgr)
    delete hlc_quote_mgr;
}