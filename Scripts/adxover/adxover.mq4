//+------------------------------------------------------------------+
//|                                                      adxover.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#define NO_MATCH -1
#define CANCEL_MATCH -2

#property copyright "Copyright 2023, Sean Champ."
#property link "https://www.example.com/nop"
#property version "1.00"
// ...
#property show_inputs
#property strict

/**
 * Script runtime configuration
 **/
extern int adx_period = 30;
extern ENUM_APPLIED_PRICE adx_price_kind = PRICE_TYPICAL;
extern int sto_k = 30;
extern int sto_d = 10;
extern int sto_slowing = 5;
extern ENUM_MA_METHOD sto_ma = MODE_LWMA;
// sto_mode_lowhigh: an input flag for iStochastic price mode
extern bool sto_mode_lowhigh = true;

// define the debug option and offset_time()
#include <libMql4.mq4>

string cur_symbol;
ENUM_TIMEFRAMES cur_timeframe;

int sto_price = sto_mode_lowhigh ? 0 : 1;


/**
 * utility class for crossover detection, given a known symbol, timeframe, 
 * and indicator kind
 */
class XOver
{

public:
    datetime start;
    datetime end;
    bool sell_trend;

    XOver() : start(0), end(0), sell_trend(false) {};
};


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

/**
 * Utility functions for ADX crossover detection, given the active chart symbol, 
 * global (input) timeframe period and price kind, and the provided args
 **/

#define adx_value(shift, mode, timeframe) iADX(cur_symbol, timeframe, adx_period, adx_price_kind, mode, shift);

double adx_plus(const int shift, const int timeframe)
{
    return adx_value(shift, MODE_PLUSDI, timeframe);
}

double adx_minus(const int shift, const int timeframe)
{
    return adx_value(shift, MODE_MINUSDI, timeframe);
}


/**
 * Locate the latest "Open" crossover in ADX +DI/-DI lines, mitigated with 
 * any of the following as exclusional criteria:
 * 
 * - Stochastic signal/main crossover ahead of the latest +DI/-DI crossover
 * 
 * - Convergence trend in Stoschastic signal/main lines, to the 'end' tick offset
 * 
 * - Convergence trend for ADX +DI/-DI lines, to the 'end' tick offset
 * 
 * If an ADX +DI/-DI crossover is found without any of those criteria, sets the 
 * datetime start and end values in the provided `xover` object to the bounds
 * of the +DI/-DI crossover, as well as denoting the direction of the crossover 
 * trend in the xover object (sell-oriented or not sell-oriented), then returns 
 * true, else returns false.
 * 
 **/
bool find_open_xover(XOver &xover, const int start, const int end, const int timeframe) {
    int next = start;
    int splus1 = start + 1;
    bool foundx = false;
    bool sell_trend = false;
    double plus_cur, minus_cur, plus_next, minus_next, ratio_next;
    datetime time_cur = 0;
    datetime time_next = 0;

    plus_next = adx_plus(start, timeframe);
    minus_next = adx_minus(start, timeframe);

    // int nr_bars = iBars(cur_symbol, cur_timeframe);

    for (int n = start + 1; n < end; n++)
    {
        plus_cur = adx_plus(n, timeframe);
        minus_cur = adx_minus(n, timeframe);

        if ((plus_next > minus_next) && (plus_cur < minus_cur))
        {
            foundx = true;
            sell_trend = false;
        }
        else if ((plus_next < minus_next) && (plus_cur > minus_cur))
        {
            foundx = true;
            sell_trend = true;
        }
        else
        {
            foundx = false;
        }

        if (foundx)
        {
            int next_sto_x = next_sto_xover(n, timeframe);
            if (next_sto_x == CANCEL_MATCH) {
                if (debug)
                    Alert("Converging sto, no crossover activation");
                return false;
            }
            else if (next_sto_x == NO_MATCH)
            {
                // detecting convergence in the ADX +DI, -DI values across N=1, N=0 (?? here tho ??)
                ratio_next = MathAbs((adx_plus(splus1, timeframe) - adx_minus(splus1, timeframe)) / (adx_plus(start, timeframe) - adx_minus(start, timeframe)));
                if (debug)
                    Alert("Ratio next ", ratio_next);
                if (ratio_next < 1) // < 1 ??
                {
                    // no crossover cancellation found
                    time_cur = offset_time(n);
                    time_next = offset_time(next);
                    if (debug)
                        Alert(StringFormat("Found open crossover: %s <> %s", TimeToStr(time_cur), TimeToStr(time_next)));
                    xover.start = time_cur;
                    xover.end = time_next;
                    xover.sell_trend = sell_trend;
                    return true;
                }
                else {
                    if (debug)
                        Alert("Converging adx, no crossover activation");
                    return false;
                }
            } else {
                if (debug)
                    Alert("Found Sto crossover at ", TimeToStr(offset_time(next_sto_x)), ". No crossover activation");
                return false;
            }
            break;
        }

        next = n;
        plus_next = plus_cur;
        minus_next = minus_cur;
    }
    return false;
}

/**
 * Utility functions for forward analysis of Stochastic signal/main crossover
 **/

#define sto_value(timeframe, mode, shift) iStochastic(cur_symbol, timeframe, sto_k, sto_d, sto_slowing, sto_ma, sto_price, mode, shift);

double sto_main(const int timeframe, const int shift) {
    return sto_value(timeframe, MODE_MAIN, shift);
}

double sto_signal(const int timeframe, const int shift) {
    return sto_value(timeframe, MODE_SIGNAL, shift);
}


/**
 * search forward from a 'shift' tick point, to locate any crossover
 * of signal and main indicator lines under the iStochastic indicator,
 * as forward of that 'shift' tick
 * 
 * this will also detect any iStochastic convergence to the newest tick
 * 
 * returns a negative value, one of NO_MATCH or CANCEL_MATCH respectively
 * if no crossover is found, or if convergence is detect to the newest tick.
 * 
 * else returns the offset of any start for the iStochastic crossover
 *
 * Generally NO_MATCH would be the only return value that may be 
 * in any ways potentially favoring towards any order activation
 * 
 * (No Warranty)
 * 
 **/

int next_sto_xover(const int shift, const int timeframe)
{

    if (shift == 0)
    {
        return NO_MATCH;
    }
    bool foundx = false;
    int idx = -1;
    double sto_sto_cur = sto_main(timeframe, shift);
    double sto_snl_cur = sto_signal(timeframe, shift); 
    double sto_sto_next = sto_sto_cur;
    double sto_snl_next = sto_snl_cur;
    for (int n = shift - 1; n > 0; n--)
    {
        
        sto_sto_next = sto_main(timeframe, n);
        sto_snl_next = sto_signal(timeframe, n); 

        if (((sto_sto_cur < sto_snl_cur) && (sto_sto_next > sto_snl_next)) ||
            ((sto_sto_cur > sto_snl_cur) && (sto_sto_next < sto_snl_next)))
        {
            foundx = true;
            idx = n;
            break;
        }
        else
        {
            sto_sto_cur = sto_sto_next;
            sto_snl_cur = sto_snl_next;
        }
    }

    // detect a convergence of the Stochastic indicator's main and signal across {1, 0}
    sto_sto_cur = sto_main(timeframe, 1);
    sto_snl_cur = sto_signal(timeframe, 1);
    sto_sto_next = sto_main(timeframe, 0);
    sto_snl_next = sto_signal(timeframe, 0);

    double sto_ratio = MathAbs((sto_sto_cur - sto_snl_cur) / (sto_sto_next - sto_snl_next ));
    
    if (sto_ratio > 1) {
        if (debug) {
            Alert("Detected convergence, sto ratio ", sto_ratio);
        }
        return CANCEL_MATCH;
    }   
    else if (foundx)
    {
        return idx;
    } else {
        return NO_MATCH;
    }
}
