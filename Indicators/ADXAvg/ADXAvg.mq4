//+------------------------------------------------------------------+
//|                                                       ADXAvg.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#property strict

#property indicator_buffers 3 // number of drawn buffers

// FIXME add level descriptor
// - DX limit at xover = 25

#property indicator_color1 clrDimGray
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

#property indicator_color2 clrYellow
#property indicator_width2 1
#property indicator_style2 STYLE_SOLID

#property indicator_color3 clrOrange
#property indicator_width3 1
#property indicator_style3 STYLE_SOLID

#property indicator_level1     25.0
#property indicator_levelcolor clrDarkSlateGray

#include <../Libraries/libMTA/libADX.mq4>

ADXAvgBuffer* avg_buff;

int OnInit()
{
  // debug = true;

  string shortname = "ADXAvg";

  /// TEST
  const int periods[] = {20, 15, 5}; // ctrl
  // const int periods[3] = {10, 5, 20}; // test unordered inputs

  const int shifts[] = {5, 3, 3}; // ctrl
  // const int shifts[] = {3, 3, 5};

  const double weights[] = {0.15, 0.35, 0.50}; // ctrl
  // const double weights[] = {0.35, 0.4, 0.25};

  avg_buff = new ADXAvgBuffer(ArraySize(periods), periods, shifts, weights);
  printf("Initialized avg_buff with %d members, total weight %f, first period %d", avg_buff.n_adx_members, avg_buff.total_weights, avg_buff.longest_period);
  
  ADXIter *iterators[];
  avg_buff.copy_iterators(iterators);
  double out_weights[];
  avg_buff.copy_weights(out_weights);

  for(int n = 0; n < avg_buff.n_adx_members; n++) {
    // DEBUG
    const ADXIter *iter = iterators[n];
    const double weight = out_weights[n];
    printf("ADX Iterator [%d] (%d, %d) weight %f", n, iter.ema_period, iter.ema_shift, weight);
  }

  IndicatorBuffers(4);

  IndicatorShortName(StringFormat("%s(%d)", shortname, avg_buff.n_adx_members));
  IndicatorDigits(Digits);

  SetIndexBuffer(0, avg_buff.dx_buffer().data);
  SetIndexLabel(0, "DX");
  SetIndexStyle(0, DRAW_LINE);

  SetIndexBuffer(1, avg_buff.plus_di_buffer().data);
  SetIndexLabel(1, "+DI");
  SetIndexStyle(1, DRAW_LINE);

  SetIndexBuffer(2, avg_buff.minus_di_buffer().data);
  SetIndexLabel(2, "-DI");
  SetIndexStyle(2, DRAW_LINE);

  SetIndexBuffer(3, avg_buff.atr_buffer().data);
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
    printf("initializing for %d quotes", rates_total);
    avg_buff.initialize_adx_data(rates_total, open, high, low, close, 0);
    }
  else
  {
    DEBUG("Updating ... %d", rates_total - prev_calculated);
    avg_buff.update_adx_data(open, high, low, close, rates_total, 0);
  }
  return rates_total;
}

void OnDeinit(const int dicode)
{
  delete avg_buff;
}