//+------------------------------------------------------------------+
//|                                                       ADXAvg.mq4 |
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

#property indicator_level1     25.0
#property indicator_levelcolor clrDarkSlateGray

extern const ENUM_APPLIED_PRICE adxavg_price_mode = PRICE_TYPICAL; // ATR Applied Price

#include <../Libraries/libMTA/libADX.mq4>

ADXAvg* avg_buff;

int OnInit()
{
  // debug = true;

  string shortname = "ADXAvg";

  /// TEST
  // const int periods[] = {20, 15, 5}; // ctrl
  const int periods[] = {20, 10, 5}; // new ctrl
  // const int periods[3] = {10, 5, 20}; // test unordered inputs

  const int shifts[] = {5, 3, 3}; // ctrl
  // const int shifts[] = {3, 3, 5};

  const double weights[] = {0.35, 0.50, 0.15}; // ctrl
  // const double weights[] = {0.35, 0.4, 0.25};

  avg_buff = new ADXAvg(ArraySize(periods), periods, shifts, weights, adxavg_price_mode);
  
  printf("Initialized avg_buff with %d members, total weight %f, first period %d", avg_buff.n_adx_members, avg_buff.total_weights, avg_buff.longest_period);
  
  ADXData *iterators[];
  avg_buff.copyMember(iterators);
  double out_weights[];
  avg_buff.copyWeights(out_weights);

  for(int n = 0; n < avg_buff.n_adx_members; n++) {
    // DEBUG
    const ADXData *iter = iterators[n];
    const double weight = out_weights[n];
    printf("ADX Iterator [%d] (%d, %d) weight %f", n, iter.ema_period, iter.ema_shift, weight);
  }

  printf("Total weights %f", avg_buff.total_weights);

  // IndicatorBuffers(avg_buff.dataBufferCount());
  if (avg_buff.initIndicator() == -1) {
    return INIT_FAILED;

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

  return avg_buff.calculate(rates_total, prev_calculated);
}

void OnDeinit(const int dicode)
{
  delete avg_buff;
}
