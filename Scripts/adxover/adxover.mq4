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

input int input_period = 15;
input ENUM_APPLIED_PRICE input_price_kind = PRICE_TYPICAL;

static int nr_bars;
static int nr_xover = 0;
static string cur_symbol;
static ENUM_TIMEFRAMES cur_timeframe;

double adx_plusdi[];
double adx_minusdi[];
datetime xover_start[], xover_end[];

void OnStart()
{

    cur_symbol = ChartSymbol();
    cur_timeframe = ChartPeriod();

    nr_bars = iBars(NULL, 0);
    ArrayResize(adx_plusdi, nr_bars);
    ArrayResize(adx_minusdi, nr_bars);
    //// nr_xover will contain the actual crossover count
    ArrayResize(xover_start, nr_bars);
    ArrayResize(xover_end, nr_bars);

    // SetIndexBuffer(0, adx_plusdi);
    // SetIndexBuffer(1, adx_minusdi);
    //// ArraySetAsSeries(ADX_PlusDI_Buffer, true);
    //// ArraySetAsSeries(ADX_MinusDI_Buffer, true);

    if (nr_bars == 0)
    {
        Alert("No bars on current chart");
        return;
    }
    else
    {
        Alert(StringFormat("Bars on current chart: %d", nr_bars));
    }

    // fill_buff(adx_plusdi, adx_minusdi, 0);
    fill_buff(0);
    int pre = 0;
    for (int n = 1; n < nr_bars; n++)
    {
        // fill_buff(adx_plusdi, adx_minusdi, n);
        fill_buff(n);
        double plus_cur = adx_plusdi[n];
        double minus_cur = adx_minusdi[n];
        double plus_pre = adx_plusdi[pre];
        double minus_pre = adx_minusdi[pre];
        //// alerts will appear over the main MT4 window during testing
        // Alert(StringFormat("DI spread %d: (%f, %f)", n, plus_cur, minus_cur));
        if (((plus_cur < minus_cur) && (plus_pre > minus_pre)) ||
            ((plus_cur > minus_cur) && (plus_pre < minus_pre)))
        {
            datetime time_cur = time_for(n);
            datetime time_pre = time_for(pre);
            Alert(StringFormat("Found crossover: %s <> %s", TimeToStr(time_cur), TimeToStr(time_pre)));
            xover_start[nr_xover] = time_pre;
            xover_end[nr_xover] = time_cur;
            nr_xover++;
        }
        pre = n;
    }

    Alert("Number of crossovers: ", nr_xover);

    if (nr_xover > 0)
    {
        Alert(StringFormat("Nearest crossover: %s", TimeToStr(xover_start[0])));
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
