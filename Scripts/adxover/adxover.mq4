//+------------------------------------------------------------------+
//|                                                      adxover.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#property copyright "Copyright 2023, Sean Champ."
#property link "https://www.example.com/nop"
#property version "1.00"
// ...
#property show_inputs
#property strict

input int input_period = 30;
input ENUM_APPLIED_PRICE input_price_kind = PRICE_TYPICAL;
input bool debug = false;

static int nr_bars;
static string cur_symbol;
static ENUM_TIMEFRAMES cur_timeframe;

double adx_plusdi[];
double adx_minusdi[];

union Timeframe
{
    ENUM_TIMEFRAMES timeframe;
    int period;

public:
    Timeframe() : period(_Period){};
    Timeframe(int duration) : period(duration){};
    Timeframe(ENUM_TIMEFRAMES tframe) : timeframe(tframe){};
};

class Chartable
{
protected:
    string symbol;
    Timeframe timeframe;

public:
    Chartable() : symbol(_Symbol), timeframe(_Period)
    {
        if (debug) Alert(StringFormat("Initialized charatble: %s %d", symbol, timeframe.period));
    };
    Chartable(ENUM_TIMEFRAMES tframe) : symbol(_Symbol), timeframe(tframe){};
    Chartable(string s) : symbol(s), timeframe(_Period){};
    Chartable(string s, ENUM_TIMEFRAMES tframe) : symbol(s), timeframe(tframe){};
};

class XoverBuf : public Chartable
{
protected:

    int bufflen;

    void init_buffers()
    {
        int len = bufflen;
        ArrayResize(xover_start, len);
        ArrayResize(xover_end, len);
        ArrayResize(xover_sell, len);
        if (debug) Alert("Initialized buffers: ", len);
    };

public:
    // FIXME move these to protected access, provide an API for access ...
    datetime xover_start[];
    datetime xover_end[];
    bool xover_sell[];

    int nr_xover;

    XoverBuf() : Chartable(), bufflen(0), nr_xover(0)
    {
        // this may be reached first, from another constructor ...
        if (bufflen == 0)
        {
            bufflen = iBars(symbol, timeframe.timeframe);
            if (debug) Alert("Using defauilt bufflen ", bufflen);
        }
        if (debug) Alert("Bufflen [0] ", bufflen);
        init_buffers();
    };

    XoverBuf(int len) : Chartable(), bufflen(len), nr_xover(0)
    {
        if (debug) Alert("Bufflen [1] ", bufflen);
    };

    XoverBuf(ENUM_TIMEFRAMES tframe) : Chartable(tframe), bufflen(iBars(symbol, timeframe.timeframe)), nr_xover(0)
    {
        if (debug) Alert("Bufflen [2] ", bufflen);
    };

    XoverBuf(string s, ENUM_TIMEFRAMES tframe) : Chartable(s, tframe), bufflen(iBars(symbol, timeframe.timeframe)), nr_xover(0)
    {
        if (debug) Alert("Bufflen [3]", bufflen);
    };

    XoverBuf(int len, string s, ENUM_TIMEFRAMES tframe) : Chartable(s, tframe), bufflen(len), nr_xover(0)
    {
        if (debug) Alert("Bufflen [4]", bufflen);
    };

    void plot_xover(datetime start, datetime end, bool sell_trend)
    {
        int n = nr_xover++;
        if (debug) Alert(StringFormat("Plotting xover %d [%d] : %s <> %s ", n, bufflen, TimeToStr(start), TimeToStr(end)));
        xover_start[n] = start;
        xover_end[n] = end;
        xover_sell[n] = sell_trend;
    }
};

void OnStart()
{

    cur_symbol = ChartSymbol();
    cur_timeframe = ChartPeriod();

    nr_bars = iBars(NULL, 0);
    ArrayResize(adx_plusdi, nr_bars);
    ArrayResize(adx_minusdi, nr_bars);

    XoverBuf xovers = XoverBuf(nr_bars, cur_symbol, cur_timeframe); 

    if (nr_bars == 0)
    {
        Alert("No bars on current chart");
        return;
    }
    else
    {
        if (debug) Alert(StringFormat("Bars on current chart: %d", nr_bars));
    }

    fill_buff(0);
    int pre = 0;
    bool xover = false;
    bool sell_trend = false;
    double plus_cur, minus_cur, plus_pre, minus_pre;
    for (int n = 1; n < nr_bars; n++)
    {
        fill_buff(n);
        plus_cur = adx_plusdi[n];
        minus_cur = adx_minusdi[n];
        plus_pre = adx_plusdi[pre];
        minus_pre = adx_minusdi[pre];

        if ((plus_pre > minus_pre) && (plus_cur < minus_cur))
        {
            xover = true;
            sell_trend = false;
        }
        else if ((plus_pre < minus_pre) && (plus_cur > minus_cur))
        {
            xover = true;
            sell_trend = true;
        }
        else
        {
            xover = false;
        }

        if (xover)
        {
            datetime time_cur = time_for(n);
            datetime time_pre = time_for(pre);
            xovers.plot_xover(time_pre, time_cur, sell_trend);
            if (debug) Alert(StringFormat("Found crossover: %s <> %s", TimeToStr(time_cur), TimeToStr(time_pre)));
        }

        pre = n;
    }

    Alert("Number of crossovers: ", xovers.nr_xover);

    if (xovers.nr_xover > 0)
    {
        string trend = xovers.xover_sell[0] ? "Sell": "Buy";
        Alert(StringFormat("Nearest crossover (%s): %s", trend, TimeToStr(xovers.xover_start[0])));
    }
}

void fill_buff(int shift)
{
    ENUM_TIMEFRAMES timeframe = cur_timeframe;
    string symbol = cur_symbol;
    adx_plusdi[shift] = iADX(symbol, timeframe, input_period, input_price_kind, MODE_PLUSDI, shift);
    adx_minusdi[shift] = iADX(symbol, timeframe, input_period, input_price_kind, MODE_MINUSDI, shift);
}

datetime time_for(int shift)
{
    ENUM_TIMEFRAMES timeframe = cur_timeframe;
    string symbol = cur_symbol;

    datetime dtbuff[1];
    CopyTime(symbol, timeframe, shift, 1, dtbuff);
    return dtbuff[0];
}

/*
datetime find_nearest_xover()
{

}
*/
