//+------------------------------------------------------------------+
//|                                             XTBeta.mq4 Prototype |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#property copyright "Copyright 2023, Sean Champ."
#property link "https://www.example.com/nop"
#property version "1.00"

#property show_inputs
#property strict

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

const string xt_symbol = _Symbol;

extern const ENUM_TIMEFRAMES xt_timeframe = PERIOD_M1;         // Analysis Timeframe
extern const ENUM_APPLIED_PRICE xt_price_mode = PRICE_TYPICAL; // Price Mode for Analysis

// TBD main_period 12
extern const int main_period = 8;   // Analysis Main Period
extern const int signal_period = 4; // Analysis Signal Period

extern const double cci_trend_high = 12.0; // CCI trend high limit
extern const double cci_trend_low = -12.0; // CCI trend low limit

extern double lot_size = 0.2; // Lot size for order open

extern const long ts_points = 20; // Trailing Stop Points
extern const long tp_points = 60; // Take Profit Points
extern const long sl_points = 40; // Initial Stop Loss Points

/// TBD update the order mgr API for the following
extern const bool open_buy = false;  // Open Buy Orders
extern const bool open_sell = false; // Open Sell orders
// extern const bool manage_other = true; // Manage Other Orders

// #include <adxcommon.mq4>

#include <../Libraries/libMTA/ea.mq4>
EA_MAGIC_DEFINE

#include <../Libraries/libMTA/libCCI.mq4>
#include <../Libraries/libMTA/libADX.mq4>

// ** Utilities for Analysis

/// TBD - this may be applied as something like a built-in length for MqlQuotes data[]
// const int _ea_max_bars_ = iBars(_Symbol, _Period);

OrderManager *order_mgr;
DataManager *data_mgr;
CCIData *cci_data;
ADXData *adx_data;
// MqlRates s_rates[];
PriceReversal *revinfo;
PriceXOver *xover;

int OnInit()
{
  // FIXME delay analysis during market close periods (weekends)
  // and avoid opening orders within the hour at the end of the market week,
  // or generally, within one, two, or more hours at the end of the market day.

  if (__testing__)
  {
    Print("Initializing for testing");
  }

  order_mgr = new OrderManager(sl_points, tp_points, ts_points, true, 1, EA_MAGIC, xt_symbol, xt_timeframe);

  // FIXME these may not belong as paramters of the order mgr, but rather of an EA mgr ..
  order_mgr.setLateMinutes(late_minutes);
  // order_mgr.setEarlyMinutes(early_minutes);

  cci_data = new CCIData(main_period, signal_period, xt_price_mode, xt_symbol, xt_timeframe, false);

  adx_data = new ADXData(main_period, xt_price_mode, xt_symbol, xt_timeframe, false);

  data_mgr = new DataManager(false, xt_symbol, xt_timeframe);
  data_mgr.bind(cci_data);
  data_mgr.bind(adx_data);

  data_mgr.initWrite("xTBeta");

  // iCustom(xt_symbol, xt_timeframe, "MTAKit/Attic/Proxy", 0, 0);

  revinfo = new PriceReversal();
  xover = new PriceXOver();

  /// initialize bound indicators

  const int quotes_initial = iBars(xt_symbol, xt_timeframe);

  DEBUG("Initial update for data manager, %d quotes", quotes_initial);

  //// this fails.
  ////
  //// within the strategy tester at e.g M1, the thing might produce only so many rates
  //// as e.g into the day before the testing period ??
  // const int quotes_initial = TerminalInfoInteger(TERMINAL_MAXBARS);
  
  if (data_mgr.update(quotes_initial) == EMPTY)
  {
    handleError("Unable to initialize indicators");
    return INIT_FAILED;
  }

  return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
  bool temporary = true;
  switch (reason)
  {
  case REASON_PROGRAM:
    temporary = false;
  case REASON_REMOVE:
    temporary = false;
  case REASON_CHARTCLOSE:
    temporary = false;
  case REASON_INITFAILED:
    temporary = false;
  case REASON_CLOSE:
    temporary = false;
  }

  if(TESTING && !temporary) {
    const string pfx = StringFormat("%s_%d_CCI_%d_%d", cci_data.getSymbol(), cci_data.getTimeframe(), main_period, signal_period);
    const int dt_int = (int) TimeCurrent();
    cci_data.writeCSV(pfx + "_" + toString(dt_int) + ".csv");
  }

  FREEPTR(cci_data);
  FREEPTR(adx_data);
  FREEPTR(data_mgr);
  FREEPTR(order_mgr);
  FREEPTR(revinfo);
  FREEPTR(xover);

  // ArrayFree(rates);
}

void OnTick()
{

  // NOTE: Network issues may prevent regular tick receipt
  DEBUG("Tick Received");

  bool orders = false;

  if (order_mgr.activeOrders())
  { orders = true;
    DEBUG("Managing orders");
    order_mgr.manageTrailingStop();
    // return; /// still need to update the indicator ...
    if (late_minutes != 0)
    {
      // close EA-managed orders
    }
  }
  // update bound indicators
  if (data_mgr.update() == EMPTY)
  {
    handleError("Unable to update indicators");
    ExpertRemove();
  }
  
  if (early_minutes != 0 && inEarlySeconds())
  {
    DEBUG("Current time is within the early minutes range %d", early_minutes);
    return;
  }

  if (orders) {
    return;
  }

  // const int traceback = tracebackExtent(xt_timeframe);

  /// alternate API: checkcci_data.mq4 script

  /// TBD : Implement something like the following,
  /// within an EA mgr checkStrategy() method?
  ///
  /// EA mgr member objects
  /// - data mgr
  /// - order mgr
  /// - any indicators bound to the data mgr
  /// - ostensibly the quote mgr being used
  ///   within the data mgr

  const double cci_cur = cci_data.cciAt(0);
  const double cci_signal_cur = cci_data.signalAt(0);
  /// should generally match the indicator values at the time of logging
  /// TBD as to why it does not.

  DEBUG("Previous CCI %f", cci_data.cciAt(1));
  DEBUG("Previous CCI Signal %f", cci_data.signalAt(1));
  DEBUG("Current CCI %f", cci_cur);
  DEBUG("Current CCI Signal %f", cci_signal_cur);

  const int extent_current = data_mgr.getExtent();

  // const bool maxbound = cci_data.bindMax(revinfo, 0, extent_current, cci_trend_high);
  // // const bool maxbound = cci_data.bindMax(revinfo);
  // if (!maxbound && debug)
  // {
  //   DEBUG("No max found to %s", toString(data_mgr.timeAt(0)));
  //   return;
  // }
  // const double max_val = revinfo.minmaxVal();
  // const datetime max_dt = revinfo.nearTime();
  // const int max_shift = iBarShift(xt_symbol, xt_timeframe, max_dt);
  // DEBUG("CCI Max at %s", toString(max_dt));

  // const bool minbound = cci_data.bindMin(revinfo, 0, extent_current, cci_trend_low);
  // // const bool minbound = cci_data.bindMin(revinfo);
  // if (!minbound && debug)
  // {
  //   DEBUG("No min found to %s", toString(data_mgr.timeAt(0)));
  //   return;
  // }
  // const double min_val = revinfo.minmaxVal();
  // const datetime min_dt = revinfo.nearTime();
  // const int min_shift = iBarShift(xt_symbol, xt_timeframe, min_dt);
  // DEBUG("CCI Min at %s", toString(min_dt));

  // if (max_shift == 0 || min_shift == 0)
  // {
  //   // bug - this may represent a bug in the reversal detection,
  //   // should generally not be reached
  //   DEBUG("max_idx = %d, min_shift = %d", max_shift, min_shift);
  //   return;
  // }
  // else if (max_shift == min_shift)
  // {
  //   // similar to the previous condition
  //   DEBUG("max_shift == min_shift %d", min_shift);
  //   return;
  // }

  // /// gain values: representative of a possible current rate trend
  // const int gain_shift = fmin(min_shift, max_shift);
  // /// opposing values: representative of the previous rate trend
  // const int opp_shift = fmax(min_shift, max_shift);
  // // const bool bearish = (gain_shift == max_shift); // not determinable as yet

  /// find nearest CCI signal/main crossover
  int xshift_near = EMPTY;
  double xval_near = DBL_MIN;
  for (int n = 0; n < extent_current; n++)
  {
    const double cross = cci_data.crossAt(n);
    if (cross != EMPTY_VALUE)
    {
      xshift_near = n;
      xval_near = cross;
      break;
    }
  }
  if (xshift_near == EMPTY)
  {
    DEBUG("No crossover from %s to current", toString(data_mgr.timeAt(xshift_near)));
    return;
  }
  const double cci_xnear = cci_data.cciAt(xshift_near);
  DEBUG("Nearest crossover at %s, CCI %f, X factor %f", toString(data_mgr.timeAt(xshift_near)), cci_xnear, xval_near);

  /// find nearest crossover before previous
  int xshift_far = EMPTY;
  double xval_far = DBL_MIN;
  for (int n = xshift_near + 1; n < extent_current; n++)
  {
    const double cross = cci_data.crossAt(n);
    if (cross != EMPTY_VALUE)
    {
      // cross == 0.0 is an error, but reached often
      xshift_far = n;
      xval_far = cross;
      break;
    }
  }
  if (xshift_far == EMPTY)
  {
    DEBUG("No crossover to %s", toString(data_mgr.timeAt(xshift_near)));
    return;
  }  else if (xshift_near == xshift_far) {
     DEBUG("Found same xshift for near/far, %s", toString(data_mgr.timeAt(xshift_near)));
     return;
  } else if (dblZero(xshift_near)) {
    DEBUG("Zero xfactor for crossover to %s",  toString(data_mgr.timeAt(xshift_near)));
  }
  
  const double cci_xfar = cci_data.cciAt(xshift_far);
  // factor of zero is an error
  DEBUG("Previous crossover at %s, CCI %f, X factor %f", toString(data_mgr.timeAt(xshift_far)), cci_xfar, xval_far);

  // const bool bearish = cci_xnear > cci_xfar; // TBD. No real trend analysis here
  const bool bearish = cci_signal_cur > cci_cur; // just as simple ...

  const double _cci_cross_min_ = 10.0;
  const bool xval_p = (xval_near > _cci_cross_min_); // && xval_near > xval_far;

 const bool maxbound = cci_data.bindMax(revinfo, 0, EMPTY, cci_trend_high);
  if (!maxbound && debug)
  {
    DEBUG("No max found to %s for lower limit %f", toString(data_mgr.timeAt(0)), cci_trend_high);
    return;
  }
  const double max_val = revinfo.minmaxVal();
  const datetime max_dt = revinfo.nearTime();
  const int max_shift = iBarShift(xt_symbol, xt_timeframe, max_dt);
  DEBUG("CCI Max at %s, %f", toString(max_dt), cci_data.cciAt(max_shift));

  const bool minbound = cci_data.bindMin(revinfo, 0, EMPTY, cci_trend_low);
  if (!minbound && debug)
  {
    DEBUG("No min found to %s for uppper limit %f", toString(data_mgr.timeAt(0)), cci_trend_low);
    return;
  }
  const double min_val = revinfo.minmaxVal();
  const datetime min_dt = revinfo.nearTime();
  const int min_shift = iBarShift(xt_symbol, xt_timeframe, min_dt);
  DEBUG("CCI Min at %s, %f", toString(min_dt), cci_data.cciAt(min_shift));

  if (max_shift == 0 || min_shift == 0)
  {
    // bug - this may represent a bug in the reversal detection,
    // should generally not be reached
    DEBUG("max_idx = %d, min_shift = %d", max_shift, min_shift);
    return;
  }
  else if (max_shift == min_shift)
  {
    // similar to the previous condition
    DEBUG("max_shift == min_shift %d", min_shift);
    return;
  }

  DEBUG("M-Max %s M-Min %s", toString(data_mgr.timeAt(max_shift)), toString(data_mgr.timeAt(min_shift)));

  const bool cci_mbearish = max_shift > min_shift;
  
  const bool trending_p = xval_p; // && (cci_mbearish == bearish);
  if (!trending_p)
  {
    DEBUG("Failed trending check");
    return;
  }


  // const double xcci_near = cci_data.cciAt(xshift_near);
  // const double xcci_far = cci_data.cciAt(xshift_far);

  const bool limit_chk = (bearish ? cci_cur > cci_trend_high : cci_cur < cci_trend_low);


  if (!limit_chk)
  {
    DEBUG("Failed limit check");
    return;
  }

  /// TBD: Detecting an intermediate reversal as an event within some broader reversal,
  /// and avoiding any open order contrary to the broader reversal
  /// - juxtaposed to detecting a major reversal
  ///   e.g outside of the [-12, 12] range

  /// initial ADX +DI/-DI crossover detection
  const bool adxover_p = adx_data.bind(xover);
  if (!adxover_p) {
    Print("No +DI/-DI reversal detected in " + adx_data.indicatorName());
    return;
  }

  const int adxshift = iBarShift(xt_symbol, xt_timeframe, xover.nearTime());
  const double adxover_rate = xover.rate();

  // ... additional analysis per adx adxshift ...

  const bool dplus_maxp = adx_data.bindPlusDIMax(revinfo, 0, adxshift);
  const double dplus_max = dplus_maxp ? revinfo.minmaxVal() : DBL_MIN; // TBD ...
  const bool dplus_minp = adx_data.bindPlusDIMin(revinfo, 0, adxshift);
  const double dplus_min = dplus_minp ? revinfo.minmaxVal() : DBL_MAX;

  const bool dminus_maxp = adx_data.bindMinusDIMax(revinfo, 0, adxshift);
  const double dminus_max = dminus_maxp ? revinfo.minmaxVal() : DBL_MIN;
  const bool dminus_minp = adx_data.bindMinusDIMin(revinfo, 0, adxshift);
  const double dminus_min = dminus_minp ? revinfo.minmaxVal() : DBL_MAX;

  const double plus_di = adx_data.plusDiAt(0);
  const double minus_di = adx_data.minusDiAt(0);
  
  const bool adx_minus_up = xover.bearish(); // plus_di < minus_di;

  const bool plus_di_dec = dplus_maxp ? (plus_di < dplus_max) : (plus_di < adxover_rate); // plus_di < plus_di_pre;
  const bool minus_di_dec = dminus_maxp ? (minus_di < dminus_max) : (minus_di < adxover_rate); // minus_di < minus_di_pre;

  const bool plus_di_inc = plus_di_dec ? false : (dplus_maxp ? (plus_di > dplus_max) : (plus_di > adxover_rate)); // plus_di > plus_di_pre;
  const bool minus_di_inc = minus_di_dec ? false : (dminus_maxp ? (minus_di > dminus_max) : (minus_di > adxover_rate)) ; // minus_di > minus_di_pre;

  // const double gain_di = adx_minus_up ? minus_di : plus_di;
  // const double gain_di_pre = adx_minus_up ? minus_di_pre : plus_di_pre;

  // const double opp_di = adx_minus_up ? plus_di : minus_di;
  // const double opp_di_pre = adx_minus_up ? plus_di_pre : minus_di_pre;
  // const double dx = adx_data.dxAt(0);

  const bool adx_gain_chk = bearish ? adx_minus_up : !adx_minus_up;

  const bool adxgain_inc = adx_minus_up ? minus_di_inc : plus_di_inc;
  const bool adxgain_dec = adx_minus_up ? minus_di_dec : plus_di_dec;
  // const bool adxopp_inc = 
  // const bool adxopp_dec = 

  // const bool adx_trend_chk = adx_gain_chk ? (gain_di > gain_di_pre && opp_di < opp_di_pre) : (opp_di > opp_di_pre && gain_di < gain_di_pre); // ...
  // const bool adx_trend_chk = adx_gain_chk ? (gain_di > gain_di_pre && opp_di < opp_di_pre) : false; // ...

  const bool adx_chk = adx_gain_chk ? (adxgain_inc && !adxgain_dec) : false;


  if (!adx_chk)
  {
    DEBUG("Failed adx check");
    return;
  }

  const bool order_p = trending_p && limit_chk && adx_chk;

  if (order_p)
  {
    order_mgr.openOrder(lot_size, bearish);
  }
}
