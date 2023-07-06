//+------------------------------------------------------------------+
//|                                                      adxover.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#include <libMql4.mq4>

#define NO_MATCH -1
#define CANCEL_MATCH -2

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

string cur_symbol;
ENUM_TIMEFRAMES cur_timeframe;

int sto_price = sto_mode_lowhigh ? 0 : 1;

void OnStart()
{

    cur_symbol = ChartSymbol();
    cur_timeframe = ChartPeriod();

    int next = 0;
    bool xover = false;
    bool sell_trend = false;
    double plus_cur, minus_cur, plus_next, minus_next, ratio_next;
    datetime time_cur = 0;
    datetime time_next = 0;

    plus_next = adx_plus(0);
    minus_next = adx_minus(0);

    int nr_bars = iBars(cur_symbol, cur_timeframe);

    for (int n = 1; n < nr_bars; n++)
    {
        plus_cur = adx_plus(n);
        minus_cur = adx_minus(n);

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
            if (next_sto_x == CANCEL_MATCH) {
                if (debug)
                    Alert("Converging sto, cancelling crossover activation");
                xover = false;                
            }
            else if (next_sto_x == NO_MATCH)
            {
                // detecting convergence in the ADX +DI, -DI values across N=1, N=0
                ratio_next = MathAbs((adx_plus(1) - adx_minus(1)) / (adx_plus(0) - adx_minus(0)));
                if (debug)
                    Alert("Ratio next ", ratio_next);
                if (ratio_next < 1) // < 1 ??
                {
                    // no crossover cancellation found
                    time_cur = offset_time(n);
                    time_next = offset_time(next);
                    if (debug)
                        Alert(StringFormat("Found open crossover: %s <> %s", TimeToStr(time_cur), TimeToStr(time_next)));
                }
                else {
                    if (debug)
                        Alert("Converging adx, cancelling crossover activation");
                    xover = false;
                }
            } else {
                if (debug)
                    Alert("Found Sto crossover at ", TimeToStr(offset_time(next_sto_x)), ". Cancelling crossover activation");
                xover = false;
            }
            break;
        }

        next = n;
        plus_next = plus_cur;
        minus_next = minus_cur;
    }
    if (xover)
    {
        string trend = sell_trend ? "Sell" : "Buy";
        Alert(StringFormat("Nearest active crossover in %s %d (%s): %s", cur_symbol, cur_timeframe, trend, TimeToStr(time_next)));
    }
    else
    {
        Alert(StringFormat("No active crossover in %s %d ", cur_symbol, cur_timeframe));
    }
}

double adx_value(int shift, int mode)
{
    return iADX(cur_symbol, cur_timeframe, adx_period, adx_price_kind, mode, shift);
}

double adx_plus(int shift)
{
    return adx_value(shift, MODE_PLUSDI);
}
double adx_minus(int shift)
{
    return adx_value(shift, MODE_MINUSDI);
}

datetime offset_time(int shift)
{
    ENUM_TIMEFRAMES timeframe = cur_timeframe;
    string symbol = cur_symbol;

    datetime dtbuff[1];
    CopyTime(symbol, timeframe, shift, 1, dtbuff);
    return dtbuff[0];
}

int next_sto_xover(int shift)
{
    if (shift == 0)
    {
        return NO_MATCH;
    }
    int next = shift - 1;
    bool xover = false;

    double sto_sto_cur = iStochastic(cur_symbol, cur_timeframe, sto_k, sto_d, sto_slowing, sto_ma, sto_price, MODE_MAIN, shift);
    double sto_snl_cur = iStochastic(cur_symbol, cur_timeframe, sto_k, sto_d, sto_slowing, sto_ma, sto_price, MODE_SIGNAL, shift);
    double sto_sto_next = sto_sto_cur;
    double sto_snl_next = sto_snl_cur;
    double sto_ratio = 100.0;
    for (int n = shift - 1; n > 0; n--)
    {
        sto_sto_next = iStochastic(cur_symbol, cur_timeframe, sto_k, sto_d, sto_slowing, sto_ma, sto_price, MODE_MAIN, next);
        sto_snl_next = iStochastic(cur_symbol, cur_timeframe, sto_k, sto_d, sto_slowing, sto_ma, sto_price, MODE_SIGNAL, next);

        sto_ratio = MathAbs((sto_sto_cur - sto_snl_cur) / (sto_sto_next - sto_snl_next ));
        // ^ detect a convergence of the main and signal lines past n == 1

        if (((sto_sto_cur < sto_snl_cur) && (sto_sto_next > sto_snl_next)) ||
            ((sto_sto_cur > sto_snl_cur) && (sto_sto_next < sto_snl_next)))
        {
            
            xover = true;
            break;
        }
        else
        {
            sto_sto_cur = sto_sto_next;
            sto_snl_cur = sto_snl_next;
        }
        next = n;
    }

    if (xover && (sto_ratio < 1))
    {
        return next;
    }
    else if (xover) {
        if (debug)
            Alert("Detected convergence, sto ratio ", sto_ratio);
        return CANCEL_MATCH;
    }
    {
        return NO_MATCH;
    }
}
