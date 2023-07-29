
#ifndef _LIBADXW_MQ4
#define _LIBADXW_MQ4 1


#property library

#include "libADX.mq4"

class ADXwIter : public ADXIter
{
protected:
    ADXwIter(string _symbol, int _timeframe) : ADXIter(_symbol, _timeframe){};

public:
    ADXwIter(int period, int period_shift = 1, const int _price_mode = PRICE_CLOSE, string _symbol = NULL, int _timeframe = EMPTY) : ADXIter(period, period_shift, _price_mode, _symbol, _timeframe){};

    // calculate the non-EMA ADX DX, +DI and -DI at a provided index, using time-series
    // high, low, and close data
    //
    // This method assumes adxq.atr_price has been initialized to the ATR at idx,
    // externally
    //
    // Fields of adxq will be initialized for ATR, DX, +DI and -DI values, without DX EMA
    virtual void bind_adx_quote(const int idx, const double &high[], const double &low[], const double &close[])
    {

        // Implementation Notes:
        //
        // - current ATR must be initialized externally onto adxq
        //   cf. prepare_next_pass(), used in methods defined below
        //   e.g before calling bind_adx_ema()

        double sm_plus_dm = __dblzero__;
        double sm_minus_dm = __dblzero__;
        double plus_dm = __dblzero__;
        double minus_dm = __dblzero__;

        double atr_cur = adxq.atr_price;

        double plus_dm_wt = __dblzero__;
        double minus_dm_wt = __dblzero__;
        const double ema_p_dbl = (double)ema_period;

        DEBUG("(%d, %d) ATR at bind_adx_quote [%d] %s : %f", ema_period, ema_shift, idx, offset_time_str(idx), atr_cur);

        if (atr_cur == 0)
        {
            printf("zero initial ATR [%d] %s", idx, offset_time_str(idx));
        }
        else if (atr_cur < 0)
        {
            printf("negative ATR [%d] %s", idx, offset_time_str(idx));
        }

        // https://en.wikipedia.org/wiki/Average_directional_movement_index
        //
        // this implementation does not provide additional smoothing of the EMA
        for (int offset = idx + ema_period, p_k = 1; offset >= idx; offset--, p_k++)
        {
            // TBD using forward-weighted moving WMA for +DM/-DM as here
            const double mov_plus = getPlusDm(offset, high, low);
            const double mov_minus = movementMinusDm(offset, high, low);
            const double wfactor = (double)p_k / ema_p_dbl;

            if (mov_plus > 0 && mov_plus > mov_minus)
            {
                sm_plus_dm += (mov_plus * wfactor);
                plus_dm_wt += wfactor;
            }
            else if (mov_minus > 0 && mov_minus > mov_plus)
            {
                sm_minus_dm += (mov_minus * wfactor);
                minus_dm_wt += wfactor;
            }
        }

        /// WMA - TBD
        if (plus_dm_wt == 0)
            // probalby when sm_plus_dm == 0
            sm_plus_dm /= ema_period;
        else
            sm_plus_dm /= plus_dm_wt;
        if (minus_dm_wt == 0)
            // probalby when sm_minus_dm == 0
            sm_minus_dm /= ema_period;
        else
            sm_minus_dm /= minus_dm_wt;

        //// conventional plus_di / minus_di
        // const double plus_di = (sm_plus_dm / atr_cur) * 100;
        // const double minus_di = (sm_minus_dm / atr_cur)  * 100;
        //
        //// not used anywhere in reference for common ADX +DI/-DI calculation,
        //// this reliably converts it to a percentage however.
        const double plus_di = 100.0 - (100.0 / (1.0 + (sm_plus_dm / atr_cur)));
        const double minus_di = 100.0 - (100.0 / (1.0 + (sm_minus_dm / atr_cur)));

        if (plus_di == 0 && minus_di == 0)
        {
            // reached e.g in both XAGUSD and AUDCAD M1
            // not so much elsewhere - zero directional
            // EMA movement across consecutive chart quotes
            // within some chart period
            DEBUG("zero plus_di, minus_di at " + offset_time_str(idx));
        }

        adxq.plus_di = plus_di;
        adxq.minus_di = minus_di;
        const double di_sum = plus_di + minus_di;
        if (di_sum == 0)
        {
            // likewise reached in XAGUSD
            DEBUG("calculated zero di sum at " + offset_time_str(idx));
            adxq.dx = __dblzero__;
        }
        else
        {
            adxq.dx = fabs((plus_di - minus_di) / di_sum) * (double)100;
        }
    };
};

#endif
