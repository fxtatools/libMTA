//+------------------------------------------------------------------+
//|                                                        libTR.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#property library
#property strict

#include <libMQL4.mq4>

class ATRIter
{
    // references
    // [ATR] https://www.investopedia.com/terms/a/atr.asp
    // [Wik] https://en.wikipedia.org/wiki/Average_true_range
    //
    // for/see also
    // [ADX] https://www.investopedia.com/terms/a/adx.asp

    int last_idx;
    const int period_minus;

public:
    int period;

    // FIXME if period < 2, fail w/ a custom errno
    ATRIter(int _period) : last_idx(0), period(_period), period_minus(_period - 1){};

    void set_idx(int idx)
    {
        last_idx = idx;
    }

    void init_buffers(const double &high[], const double &low[], const double &close[])
    {
        /// application notes:
        // - This needs to be called for every call to OnCalculate()
        // - Also set the &atr data buffer to not-as-series, before initialize() & subsq.
        // - if the open buffer is being used in OnCalculate, also set that buffer
        //   to not-as-series, externally
        //
        /// implementation notes:
        // - Unlike the MT4 ATR indicator, this does not smooth later ATR values
        //   across the initial period, subsequent of the initial values within that period
        // - Per references cited above, this is an adequate method for calculating ATR
        //   as an exponential moving average
        // - Market open quotes are unused in ATR and ADX.
        // - This will not set any unused open buffer for reference as non-time-series data
        // - MQL programs may commonly use ArraySetAsSeries on arrays declared as const

        // ArraySetAsSeries(open, false);
        ArraySetAsSeries(high, false);
        ArraySetAsSeries(low, false);
        ArraySetAsSeries(close, false);
    }

    double next_tr(const double &high[], const double &low[], const double &close[])
    {
        // not applicable for the first True Range value
        const double prev_close = close[last_idx++];
        const double cur_high = high[last_idx];
        const double cur_low = low[last_idx];
        //// simplified calculation [Wik]
        return MathMax(cur_high, prev_close) - MathMin(cur_low, prev_close);
    }
    double next_atr(const double prev, const double &high[], const double &low[], const double &close[])
    {
        // not applicable if last_idx < period

        // by side effect, the next_tr() call will update last_idx to current

        // see implementation notes, above
        return (prev * period_minus + next_tr(high, low, close)) / period;
    }

    void initialize(const int count, double &atr[], const double &high[], const double &low[], const double &close[], const int start = 0)
    {
        /// NOTE
        /// this uses units of price internally, but stores units of points
        /// within the atr buffer. For subsequent calculations, the translation
        /// to points will need to be reversed, i.e after retrieving the value
        /// of the last initialized ATR (in points), before providing the value
        /// (in units of price) to next_atr()
        last_idx = start;
        double last_atr = high[last_idx] - low[last_idx++];
        // atr[0] = __dblzero__; // initializes the value, but messes up the indicator display
        for (int n = 1; n < period; n++)
        {
            last_atr += next_tr(high, low, close);
            // atr[n] = __dblzero__;
        }
        last_atr = last_atr / period;
        for (int n = period; n < count; n++)
        {
            last_atr = next_atr(last_atr, high, low, close);
            /// FIXME note this point shift for the data buffer.
            /// needs to be reversed under later calculations for initial next_atr in OnCalculate
            atr[n] = last_atr / _Point;           
        }
    };
};
