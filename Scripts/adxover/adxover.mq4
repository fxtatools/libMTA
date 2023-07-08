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

#include <adxcommon.mq4>

/**
 * MetaTrader Script activation
 */
void OnStart()
{

    cur_symbol = ChartSymbol();
    cur_timeframe = ChartPeriod();

    int nr_bars = iBars(cur_symbol, cur_timeframe);

    XOver xov = XOver();

    bool found = find_open_xover(xov, 0, nr_bars, cur_timeframe);

    if (found)
    {
        string trend = xov.sell_trend ? "Sell" : "Buy";
        Alert(StringFormat("Nearest active crossover in %s %d (%s): %s <> %s", cur_symbol, cur_timeframe, trend, TimeToStr(xov.start), TimeToStr(xov.end)));
    }
    else
    {
        Alert(StringFormat("No active crossover in %s %d ", cur_symbol, cur_timeframe));
    }
}
