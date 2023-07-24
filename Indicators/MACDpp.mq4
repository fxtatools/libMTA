//+------------------------------------------------------------------+
//|                                                       MACDpp.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#property copyright "Copyright 2023, Sean Champ"
#property link "https://www.example.com/nop"
#property version "1.00"
#property strict
#property indicator_separate_window

#property indicator_buffers 4

#property indicator_color1 clrForestGreen // MACD plus bars
#property indicator_width1 2
#property indicator_style1 STYLE_SOLID

#property indicator_color2 clrDarkOrange // MACD minus bars
#property indicator_width2 2
#property indicator_style2 STYLE_SOLID

#property indicator_color3 clrSteelBlue // MACD line
#property indicator_width3 1
#property indicator_style3 STYLE_SOLID

#property indicator_color4 clrFireBrick // MACD signal line
#property indicator_width4 1
#property indicator_style4 STYLE_SOLID

#include <../Libraries/libMTA/chartable.mq4>
#include <../Libraries/libMTA/rates.mq4>
#include <pricemode.mq4>

extern const int macd_fast_ema = 12;
extern const int macd_slow_ema = 26;
extern const int macd_signal_ema = 9;
extern const ENUM_PRICE_MODE macd_price_mode = PRICE_MODE_TYPICAL;

class MACDBuffer : public Chartable
{
protected:
  class MACDQuote
  {
  public:
    double fast_ema;
    double slow_ema;
    double macd;
    double signal;

    MACDQuote() : fast_ema(__dblzero__), slow_ema(__dblzero__), macd(__dblzero__), signal(__dblzero__){};

    void bind_next(const double fast, const double slow, const double _macd, const double _signal)
    {
      fast_ema = fast;
      slow_ema = slow;
      macd = _macd;
      signal = _signal;
      DEBUG("Bound %f %f %f %f", fast_ema, slow_ema, macd, signal);
    };
  };
  MACDQuote *macd_quote;

public:
  // indicator configuration
  const int fast_ema_p;
  const int slow_ema_p;
  const bool fast_ema_larger; // just in case ...
  const int signal_ema_p;
  const int price_mode;
  const double point_ratio;
  // state
  datetime latest_quote_dt;
  // indicator data buffers
  int extent;
  RateBuffer *macd_fast_ema_buffer;
  RateBuffer *macd_slow_ema_buffer;
  RateBuffer *macd_macd_buffer;
  RateBuffer *macd_signal_buffer;
  // indicator drawing buffers
  RateBuffer *macd_splus_buffer;
  RateBuffer *macd_sminus_buffer;

  // refs
  // https://www.investopedia.com/terms/m/macd.asp
  // Pruitt, G. (2016). Chapter 2: Stochastics and Averages and RSI! Oh, My. In The Ultimate Algorithmic Trading System Toolbox + Website (pp. 25–76). John Wiley & Sons, Inc. https://doi.org/10.1002/9781119262992.ch2

  MACDBuffer(const int fast_ema, const int slow_ema, const int signal_ema, const int _price_mode, const string _symbol = NULL, const int _timeframe = EMPTY) : fast_ema_p(fast_ema), slow_ema_p(slow_ema), fast_ema_larger(fast_ema > slow_ema), signal_ema_p(signal_ema), price_mode(_price_mode), latest_quote_dt(0), extent(0), point_ratio(_symbol == NULL ? _Point : SymbolInfoDouble(_symbol, SYMBOL_POINT)), Chartable(symbol, timeframe)
  {
    macd_quote = new MACDQuote();
    macd_fast_ema_buffer = new RateBuffer();
    macd_slow_ema_buffer = new RateBuffer();
    macd_macd_buffer = new RateBuffer();
    macd_signal_buffer = new RateBuffer();
    macd_splus_buffer = new RateBuffer();
    macd_sminus_buffer = new RateBuffer();
  };
  ~MACDBuffer()
  {
    delete macd_quote;
    delete macd_fast_ema_buffer;
    delete macd_slow_ema_buffer;
    delete macd_macd_buffer;
    delete macd_signal_buffer;
    delete macd_splus_buffer;
    delete macd_sminus_buffer;
  };

  double points_to_price(const double points)
  {
    if (point_ratio == NULL)
    {
      return points;
    }
    else
    {
      return points * point_ratio;
    }
  };

  double price_to_points(const double price)
  {
    if (point_ratio == NULL)
    {
      return price;
    }
    else
    {
      return price / point_ratio;
    }
  };

  bool setExtent(const int _extent, const bool no_pad = false)
  {
    if (_extent == extent)
      return true;
    if (!macd_fast_ema_buffer.setExtent(_extent, 0))
      return false;
    if (!macd_slow_ema_buffer.setExtent(_extent, 0))
      return false;
    if (!macd_macd_buffer.setExtent(_extent, 0))
      return false;
    if (!macd_signal_buffer.setExtent(_extent, 0))
      return false;
    if (!macd_splus_buffer.setExtent(_extent, 0))
      return false;
    if (!macd_sminus_buffer.setExtent(_extent, 0))
      return false;
    extent = _extent;
    return true;
  };

  bool reduceExtent(const int _extent)
  {
    if (_extent == extent)
      return true;
    if (!macd_fast_ema_buffer.reduceExtent(_extent))
      return false;
    if (!macd_slow_ema_buffer.reduceExtent(_extent))
      return false;
    if (!macd_macd_buffer.reduceExtent(_extent))
      return false;
    if (!macd_signal_buffer.reduceExtent(_extent))
      return false;
    if (!macd_splus_buffer.reduceExtent(_extent))
      return false;
    if (!macd_sminus_buffer.reduceExtent(_extent))
      return false;
    extent = _extent;
    return true;
  };

  double avg(const int period, const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
  {
    // plain average, for EMA at (start - longest_period)
    //
    // assumes time-series data
    int p = period;
    int n = (idx + p--);
    // initializing avg to a non-double zero value ...
    double avg = price_for(n, price_mode, open, high, low, close);
    for (; p > 0; p--, n--)
    {
      avg += price_for(idx, price_mode, open, high, low, close);
    }
    return (avg / period);
  }

  double ema(const double prev, const double cur, const int p_k)
  {
    // partial EMA calculation, given a previous, current, and moving period-based 'k factor'
    //
    // References:
    // https://en.wikipedia.org/wiki/Exponential_smoothing
    // https://www.investopedia.com/ask/answers/122314/what-exponential-moving-average-ema-formula-and-how-ema-calculated.asp
    // Pruitt, G. (2016). Chapter 2: Stochastics and Averages and RSI! Oh, My. In The Ultimate Algorithmic Trading System Toolbox + Website (pp. 25–76). John Wiley & Sons, Inc. https://doi.org/10.1002/9781119262992.ch2

    const double k = ((double)2 / (double)(p_k + 1)); // .... casts necessary for MT4 here
    const double rslt = (cur * k) + (prev * ((double)1 - k));
    DEBUG("EMA [%d] K %f => %f", p_k, k, rslt);
    return rslt;
  };

  // calculate Weighted MA for price, forward to a provided index, given period
  double wma(const double prev, const int period, const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
  {
    double cur_wema = __dblzero__;
    double wfactor_sum = __dblzero__;
    const double double_p = double(period);
    for (int p_k = 1, n = idx + period; p_k <= period; p_k++, n--)
    {
      // using a forward-weighted MA, starting the oldest 'k' factor at 1
      const double cur_price = price_for(n, price_mode, open, high, low, close);
      const double wfactor = (double)p_k / double_p;
      wfactor_sum += wfactor;
      cur_wema += (cur_price * wfactor);
      // DEBUG("EMA [%d/%d] == %f from %f, %f, %d/%d", n, idx, ema_cur, cur_price, prev, p_k, period);
    }
    const double _wma = cur_wema / wfactor_sum;
    // const double rslt = ema(prev, _wma, period);
    DEBUG("WMA %d [%d] %f/%d => %f", period, idx, cur_wema, wfactor_sum, _wma);
    // return rslt; // was return _wma ...  which worked out better for an indicator
    return _wma;
  };

  virtual double bind_fast_wma(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
  {
    const double prev = macd_quote.fast_ema;
    DEBUG("Begin Fast WMA [%d] %f", idx, prev);
    const double rslt = wma(prev, fast_ema_p, idx, open, high, low, close);
    DEBUG("Bind Fast WMA [%d] %f => %f", idx, prev, rslt);
    macd_quote.fast_ema = rslt;
    return rslt;
  };

  virtual double bind_slow_wma(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
  {
    const double prev = macd_quote.slow_ema;
    DEBUG("Begin Slow WMA [%d] %f", idx, prev);
    const double rslt = wma(prev, slow_ema_p, idx, open, high, low, close);
    DEBUG("Bind Slow WMA [%d] %f => %f", idx, prev, rslt);
    macd_quote.slow_ema = rslt;
    return rslt;
  };

  virtual double bind_macd(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
  {
    DEBUG("Begin MACD [%d]", idx);
    const double fast = bind_fast_wma(idx, open, high, low, close);
    const double slow = bind_slow_wma(idx, open, high, low, close);
    const double diff = fast - slow;
    DEBUG("Bind MACD [%d] %f - %f = %f", idx, fast, slow, diff);
    macd_quote.macd = diff;
    return diff;
  };

  virtual double bind_signal_ema(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
  {
    DEBUG("Begin Signal EMA [%d]", idx);
    // EMA of macd_quote.macd
    const double prev = macd_quote.signal;
    // sets slow, fast EMA and macd into macd_quote by side effect
    const double cur = bind_macd(idx, open, high, low, close);
    const double rslt = ema(prev, cur, signal_ema_p);
    DEBUG("Bind Signal EMA [%d] %f", idx, rslt);
    macd_quote.signal = rslt;
    return rslt;
  };

  virtual int bind_initial_signal(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
  {
    // bind initial indicator component values using average
    const int longest_p = fast_ema_larger ? fast_ema_p : slow_ema_p;
    const int start_idx = idx - (longest_p + signal_ema_p);
    const double avg = avg(longest_p, start_idx, open, high, low, close);
    DEBUG("Binding initial average [%d => %d] => %f", idx, start_idx, avg);
    macd_quote.bind_next(avg, avg, avg, __dblzero__);
    return start_idx;
  };

  virtual datetime update_data(const double &open[], const double &high[], const double &low[], const double &close[], const int index = EMPTY)
  {
    const int __latest__ = 0;
    const int idx_initial = (index == EMPTY ? iBarShift(symbol, timeframe, latest_quote_dt) : index);
    const int idx_prev = (index == EMPTY ? idx_initial + 1 : idx_initial);
    if (index == EMPTY)
    {
      // this assumes that an empty index values indicates that the calculation
      // is being resumed from some earlier, initialized data set, for data from
      // the last time of calculation to current.
      setExtent(idx_initial);
      const int idx_plus = idx_initial + 1;
      const double fast_initial = macd_fast_ema_buffer.data[idx_plus];
      const double slow_initial = macd_slow_ema_buffer.data[idx_plus];
      // FIXME use the point value only for chart drawing, original price value for calculation
      const double macd_initial = points_to_price(macd_macd_buffer.data[idx_plus]);
      const double signal_initial = points_to_price(macd_signal_buffer.data[idx_plus]);
      /// restore state for the internal data process
      macd_quote.bind_next(fast_initial, slow_initial, macd_initial, signal_initial);
    }
    /// starting at no earlier than tick 1, to ensure the previous indicator
    /// values are recalculated from final market quotes after the calculation
    /// index has advanced 0 => 1
    for (int idx = idx_initial; idx >= __latest__; idx--)
    {
      DEBUG("Bind %d cur macd %f", idx, macd_quote.macd);
      bind_signal_ema(idx, open, high, low, close);
      macd_fast_ema_buffer.data[idx] = macd_quote.fast_ema;
      macd_slow_ema_buffer.data[idx] = macd_quote.slow_ema;
      const double macd = price_to_points(macd_quote.macd);
      const double signal = price_to_points(macd_quote.signal);
      macd_macd_buffer.data[idx] = macd;
      macd_signal_buffer.data[idx] = signal;

      // FIXME use the following only for a visual indicator
      // - TBD piping the callback into this iterative section
      const double sdiff = macd - signal;
      if (sdiff >= 0)
      {
        macd_splus_buffer.data[idx] = sdiff; // price_to_points(sdiff);
        macd_sminus_buffer.data[idx] = __dblzero__;
      }
      else
      {
        macd_sminus_buffer.data[idx] = sdiff; // price_to_points(sdiff);
        macd_splus_buffer.data[idx] = __dblzero__;
      }
    }
    latest_quote_dt = iTime(symbol, timeframe, __latest__);
    return latest_quote_dt;
  };

  virtual datetime initialize_data(const int _extent, const double &open[], const double &high[], const double &low[], const double &close[])
  {
    if (!setExtent(_extent, true))
    {
      printf("Unable to set initial extent %d", _extent);
      return EMPTY;
    }
    DEBUG("Bind intial average in %d", extent);
    const int calc_idx = bind_initial_signal(_extent - 1, open, high, low, close);
    DEBUG("Initializing data [%d/%d]", calc_idx, _extent - 1);
    return update_data(open, high, low, close, calc_idx);
  };
};

MACDBuffer *macd_buffer;

int OnInit()
{
  macd_buffer = new MACDBuffer(macd_fast_ema, macd_slow_ema, macd_signal_ema, macd_price_mode, _Symbol, _Period);

  IndicatorBuffers(4);
  const string shortname = "MACD++";
  IndicatorShortName(StringFormat("%s(%d, %d, %d)", shortname, macd_fast_ema, macd_slow_ema, macd_signal_ema));

  SetIndexBuffer(0, macd_buffer.macd_splus_buffer.data);
  SetIndexLabel(0, "MACD+");
  SetIndexStyle(0, DRAW_HISTOGRAM);

  SetIndexBuffer(1, macd_buffer.macd_sminus_buffer.data);
  SetIndexLabel(1, "MACD-");
  SetIndexStyle(1, DRAW_HISTOGRAM);

  SetIndexBuffer(2, macd_buffer.macd_macd_buffer.data);
  SetIndexLabel(2, "MACD");
  SetIndexStyle(2, DRAW_LINE);

  SetIndexBuffer(3, macd_buffer.macd_signal_buffer.data);
  SetIndexLabel(3, "M Signal");
  SetIndexStyle(3, DRAW_LINE);

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
    DEBUG("Initialize for %d quotes", rates_total);
    macd_buffer.initialize_data(rates_total, open, high, low, close);
  }
  else
  {
    DEBUG("Updating for index %d", rates_total - prev_calculated);
    macd_buffer.update_data(open, high, low, close);
  }
  return rates_total;
}

void OnDeinit(const int dicode)
{
  delete macd_buffer;
}
