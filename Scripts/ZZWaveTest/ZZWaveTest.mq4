//+------------------------------------------------------------------+
//|                                                   ZZWaveTest.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#property description "ZZWave Test Script"
#property strict
// #property script_show_inputs // has been set in *.mqproj

#include <../Libraries/libZZWave/libZZWave.mq4>

#include <libMql4.mq4>

/// @brief return a default limit value for short-term analysis,
///         in units of chart-bars, given the provided timeframe
/// @param timeframe timeframe for limit, or -1 to use current timeframe
/// @return the number of chart bars
/// @details Known limitation: Does not support any start-time for limit
int timeframe_short_bars(const int timeframe = EMPTY) {
  switch(timeframe == EMPTY ? _Period : timeframe) {
    case PERIOD_M1:
      // hour
      return 60;
    case PERIOD_M5:
      // 5 hours
      return 60;
    case PERIOD_M15:
      // 16 hours
      return 64;
    case PERIOD_M30:
      // 24 hours
      return 48;
    case PERIOD_H1:
      // hours for 1 market week (five days)
      return 120;
    case PERIOD_H4:
      // 1/6-day periods for 1 month of market weeks, approx
      return 120;
    case PERIOD_D1:
      // days for 1 month of market weeks, approx
      return 22;
    case PERIOD_W1:
      // one quarter year ...
      return 16;
    case PERIOD_MN1:
      // one year ...
      return 12;
    default:
      // FIXME other timeframes are not yet well supported here
      return 60;
  }
}

extern const int default_bars = EMPTY; // Chart ticks to analyze. -1 for default

double ZZPriceLine[];
double ZZState[];

double _open[];
double _high[];
double _low[];
double _close[];

void OnStart()
{
  
  const int nr_bars = (default_bars == EMPTY ? timeframe_short_bars() : default_bars);

  if(debug) {
    Alert(StringFormat("Market Point ratio %f", _Point));
  }

  ArraySetAsSeries(ZZPriceLine, true);
  ArraySetAsSeries(ZZState, true);
  ArraySetAsSeries(_open, true);
  ArraySetAsSeries(_high, true);
  ArraySetAsSeries(_low, true);
  ArraySetAsSeries(_close, true);
  ArrayResize(ZZPriceLine, nr_bars);
  ArrayResize(ZZState, nr_bars);
  ArrayResize(_open, nr_bars);
  ArrayResize(_high, nr_bars);
  ArrayResize(_low, nr_bars);
  ArrayResize(_close, nr_bars);

  CopyOpen(_Symbol, _Period, 0, nr_bars, _open);
  CopyHigh(_Symbol, _Period, 0, nr_bars, _high);
  CopyLow(_Symbol, _Period, 0, nr_bars, _low);
  CopyClose(_Symbol, _Period, 0, nr_bars, _close);

  fill_extents_hl(ZZPriceLine, ZZState, nr_bars, _open, _high, _low, _close, true);
  
  double first_price = __dblzero__;
  int first_shift = EMPTY;
  double first_trend = __none__;
  int nr_extents = 1;
  double cur_state = ZZState[0];
  double cur_price = ZZPriceLine[0];
  double ext_price = cur_state == __crest__ ? cur_price : -cur_price;

  if (cur_state == __dblzero__) {
    Alert("Debug: Initial extent state unset");
  }

  for(int n = 1; n < nr_bars; n++) {
    cur_state = ZZState[n];
    if(cur_state != __none__) {
      nr_extents++;
      cur_price = ZZPriceLine[n];
      ext_price += (cur_state == __crest__ ? cur_price : -cur_price);
      if (first_shift == EMPTY) {
        first_price = cur_price;
        first_trend = cur_state;
        first_shift = n;
      }
    }
  }

  // FIXME these alert messages do not indicate current chart and timeframe

  const string label = _Symbol + " " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period), 7) + " ";

  if(first_shift == EMPTY) {
    Alert(label + "Found no points of inflection");
  }
  else {
    const string first_dir = first_trend == __crest__ ? "Crest" : "Trough";
    const string first_dts = TimeToStr(offset_time(first_shift, _Period));
    Alert(StringFormat(label + "First non-zero extent: %f at %s (%s)", first_price, first_dts, first_dir));

    const string ext_dir = ext_price > 0 ? "Bullish" : "Bearish";
    const string start_dts = TimeToStr(offset_time(nr_bars, _Period));
    const string cur_dts = TimeToStr(offset_time(0, _Period));
    Alert(StringFormat(label + "Price Delta at extents [%d/%d] = %f (%s) from %s to %s", nr_extents, nr_bars, ext_price, ext_dir, start_dts, cur_dts));
  }
}
