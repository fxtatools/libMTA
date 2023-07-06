//+------------------------------------------------------------------+
//|                                                      adxover.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#include <libMql4.mq4>

#property copyright "Copyright 2023, Sean Champ."
#property link "https://www.example.com/nop"
#property version "1.00"
// ...
#property show_inputs
#property strict

input int adx_period = 30;
input ENUM_APPLIED_PRICE adx_price_kind = PRICE_TYPICAL;
input int sto_k = 30;
input int sto_d = 10;
input int sto_slowing = 5;
input ENUM_MA_METHOD sto_ma = MODE_LWMA;
// sto_mode_lowhigh: input flag for iStochastic price mode
input bool sto_mode_lowhigh = true;
input bool debug = false;

static int nr_bars;
static string cur_symbol;
static ENUM_TIMEFRAMES cur_timeframe;

static int sto_price = sto_mode_lowhigh ? 0 : 1;

double adx_plusdi[];
double adx_minusdi[];

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

    XoverBuf adx_xover = XoverBuf(nr_bars, cur_symbol, cur_timeframe); 

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
    int next = 0;
    bool xover = false;
    bool sell_trend = false;
    double plus_cur, minus_cur, plus_next, minus_next, ratio_next;

    for (int n = 1; n < nr_bars; n++)
    {
        fill_buff(n);
        plus_cur = adx_plusdi[n];
        minus_cur = adx_minusdi[n];
        plus_next = adx_plusdi[next];
        minus_next = adx_minusdi[next];

        if ((plus_next > minus_next) && (plus_cur < minus_cur))
        {
            xover = true;
            sell_trend = false;
        }
        else if ((plus_next < minus_next) && (plus_cur > minus_cur))
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
            int next_sto_x = next_sto_xover(n);
            if (next_sto_x == -1 ) {
                // detect convergence in the ADX +DI, -DI values across N=1, N=0
                ratio_next = MathAbs((adx_plus(1) - adx_minus(1)) / (adx_plus(0) - adx_minus(0)));
                if(debug) Alert("Ratio next ", ratio_next);
                if (ratio_next < 1)  {
                    // no crossover cancellation found
                    datetime time_cur = time_for(n);
                    datetime time_next = time_for(next);
                    adx_xover.plot_xover(time_cur, time_next, sell_trend);
                    if (debug) Alert(StringFormat("Found crossover: %s <> %s", TimeToStr(time_cur), TimeToStr(time_next)));
                }
            }
            break;
        }

        next = n;
    }

    // Alert("Number of crossovers: ", adx_xover.nr_xover);

    if (adx_xover.nr_xover > 0)
    {
        string trend = adx_xover.xover_sell[0] ? "Sell": "Buy";
        Alert(StringFormat("Nearest active crossover in %s %d (%s): %s", cur_symbol, cur_timeframe, trend, TimeToStr(adx_xover.xover_start[0])));
    } else {
        Alert(StringFormat("No active crossover in %s %d ", cur_symbol, cur_timeframe));
    }
}

double adx_value(int shift, int mode) {
    return iADX(cur_symbol, cur_timeframe, adx_period, adx_price_kind, mode, shift);
}

double adx_plus(int shift) {
    return adx_value(shift, MODE_PLUSDI);
}
double adx_minus(int shift) {
    return adx_value(shift, MODE_MINUSDI);
}



void fill_buff(int shift)
{
    adx_plusdi[shift] = adx_plus(shift);
    adx_minusdi[shift] = adx_minus(shift);
}

datetime time_for(int shift)
{
    ENUM_TIMEFRAMES timeframe = cur_timeframe;
    string symbol = cur_symbol;

    datetime dtbuff[1];
    CopyTime(symbol, timeframe, shift, 1, dtbuff);
    return dtbuff[0];
}

int next_sto_xover(int shift) {
        static int no_match = -1;
        if ( shift == 0 ) {
            return no_match;
        }
        int next = 0;
        double sto_sto_cur, sto_sto_next, sto_snl_cur, sto_snl_next;
        // initialize values for the compiler
        sto_sto_cur = 0.0;
        sto_snl_cur = 0.0;
        sto_sto_next = 0.0;
        sto_snl_next = 0.0;
        for (int n = shift; n > 0; n--) {
            next = n - 1;
            sto_sto_cur = iStochastic(cur_symbol, cur_timeframe, sto_k, sto_d, sto_slowing, sto_ma, sto_price, MODE_MAIN, n);
            sto_snl_cur = iStochastic(cur_symbol, cur_timeframe, sto_k, sto_d, sto_slowing, sto_ma, sto_price, MODE_SIGNAL, n);
            sto_sto_next = iStochastic(cur_symbol, cur_timeframe, sto_k, sto_d, sto_slowing, sto_ma, sto_price, MODE_MAIN, next);
            sto_snl_next= iStochastic(cur_symbol, cur_timeframe, sto_k, sto_d, sto_slowing, sto_ma, sto_price, MODE_SIGNAL, next);
            if (((sto_sto_cur < sto_snl_cur) && (sto_sto_next > sto_snl_next)) ||
                ((sto_sto_cur > sto_snl_cur) && (sto_sto_next < sto_snl_next)))
            { 
                return next;
            }
        }

        // detect a convergence of the main and signal lines past n == 1
        double sto_ratio = MathAbs((sto_sto_cur - sto_snl_cur) / (sto_sto_next - sto_snl_next));
        if (sto_ratio < 1) {
            return next;
        } else {
            return no_match;
        }
}

