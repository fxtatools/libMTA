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

extern const int iatr_period = 8;                              // ATR Smoothing Period
extern const ENUM_APPLIED_PRICE iadx_price_mode = PRICE_CLOSE; // Applied Price
extern const bool iatr_use_points = true;                      // Points if True, else Price

extern const bool test_unmanaged = false; // Run Tests for Indicator API

#include <../Libraries/libMTA/libATR.mq4>
#include <../Libraries/libMTA/data.mq4>

ATRData *atr_data;
ATRData *atr_unmanaged; // TEST
DataManager *mgr;

int OnInit()
{
  atr_data = new ATRData(iatr_period, iadx_price_mode, iatr_use_points, _Symbol, _Period);

  if (atr_data.initIndicator() == -1)
  {
    return INIT_FAILED;
  }

  if (test_unmanaged) // TEST
  {
    atr_unmanaged = new ATRData(iatr_period, iadx_price_mode, iatr_use_points, _Symbol, _Period, false);
    mgr = new DataManager();
    mgr.bind(atr_unmanaged);
  }
  else
  {
    mgr = NULL;
    atr_unmanaged = NULL;
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
  const int rslt = atr_data.calculate(rates_total, prev_calculated);

  if (test_unmanaged)
  {
    /// test for indicator-oriented update
    // mgr.update(rates_total, prev_calculated);
    /// test for EA-oriented update
    mgr.update();
    /// verifying consistency of data in the unmanaged indicator,
    /// for each update from an earlier or uninitialized index 0
    if (debugLevel(DEBUG_CALC) && (rates_total != prev_calculated))
    {
      const double mngatr = atr_data.atrAt(0);
      const double otheratr = atr_unmanaged.atrAt(0);
      const string label = (mngatr != otheratr) ? "difference" : "parity";
      if (mngatr != otheratr)
      {
        printf("Uamanaged ATR %s %f to managed %f at 0",
               label, otheratr, mngatr);
      }
    }
  }
  
  return rslt;
}

void OnDeinit(const int dicode)
{
  FREEPTR(atr_data);
  FREEPTR(atr_unmanaged);
  FREEPTR(mgr);
}
