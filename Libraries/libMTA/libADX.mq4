
#ifndef _LIBADX_MQ4
#define _LIBADX_MQ4 1

#include "libATR.mq4"

#include <dlib/Lang/pointer.mqh>

class ADXIter : public ATRIter
{

protected:
    class ADXQuote
    {
    public:
        double atr_period_start; // in ...
        double atr_price;
        double dx;
        double plus_di;
        double minus_di;
        ADXQuote() : atr_price(-0.0), dx(-0.0), plus_di(-0.0), minus_di(-0.0){};
    };
    ADXQuote adxq;

public:
    ADXIter(int period, int period_shift = 1) : ATRIter(period, period_shift)
    {
        adxq = ADXQuote();
    };
    ~ADXIter() {
        delete &adxq;
    }

    void prepare_next_iter(const double atr_price, const double dx, const double plus_di, const double minus_di) {
        adxq.atr_price = atr_price;
        adxq.dx = dx;
        adxq.plus_di = plus_di;
        adxq.minus_di = minus_di;
    }

    // designed for application onto MT4 time-series data

    double plus_dm_movement(const int idx, const double &high[], const double &low[])
    {
        return high[idx] - high[idx + 1];
    };

    double minus_dm_movement(const int idx, const double &high[], const double &low[])
    {
        return low[idx + 1] - low[idx];
    };

    void bind_adx_quote(const int idx, /* const double prev_atr_price ,*/ const double &high[], const double &low[], const double &close[])
    {
        double sm_plus_dm = __dblzero__;
        double sm_minus_dm = __dblzero__;

        double plus_dm = __dblzero__;
        double minus_dm = __dblzero__;

        double sm_atr = __dblzero__;

        // double next_atr = prev_atr_price;
        //// ATR smoothing not required
        // double next_atr = adxq.atr_period_start;
        double next_atr = adxq.atr_price;

        DEBUG("ATR at bind ADX quote [%d] %s : %f", idx, offset_time_str(idx), next_atr);
        DEBUG("Start bind_adx_quote MA at %d",  idx + ema_period);

        if (next_atr == 0)
        {
            printf("zero initial next_atr [%d] %s", idx, offset_time_str(idx));
        }
        else
        {
            //// DEBUG
            // printf("initial next_atr [%d] %s", idx, offset_time_str(idx));
        }
        // https://en.wikipedia.org/wiki/Average_directional_movement_index
        for (int offset = idx + ema_period; offset >= idx; offset--)
        {
            //// ATR smoothing not reuqired
            // next_atr = next_atr_price(offset, next_atr, high, low, close);
            // ^ FIXME not actually usable here, unless the prev_atr_price
            //  was from offset idx + ema_period
            ////
            // printf("next_atr [%d] %s", offset, offset_time_str(offset)); // DEBUG
            // sm_atr += next_atr;

            // printf("thunk %d", offset);

            const double mov_plus = plus_dm_movement(offset, high, low);
            const double mov_minus = minus_dm_movement(offset, high, low);
            plus_dm = mov_plus > 0 && mov_plus > mov_minus ? mov_plus : __dblzero__;
            minus_dm = mov_minus > 0 && mov_minus > mov_plus ? mov_minus : __dblzero__;
            sm_plus_dm += plus_dm;
            sm_minus_dm += minus_dm;
        }

        // https://www.investopedia.com/terms/a/adx.asp ...  (??)
        sm_plus_dm = sm_plus_dm - (sm_plus_dm / ema_period) + plus_dm;
        sm_minus_dm = sm_minus_dm - (sm_minus_dm / ema_period) + minus_dm;
        //// ^ results in very large values for +DI/-DI
        /// or ...
        sm_plus_dm /= ema_period;
        sm_minus_dm /= ema_period;
        /// ^ also too-large values, if the MA is applied * 100
        /// though less so by an order of manitude ...
        ///// or both ... 
        //// FIXME still sometimes results in +DI / -DI greater than 100

        //// ATR smoothing not required
        // sm_atr /= ema_period;
        sm_atr = next_atr;
        if (sm_atr == 0)
        {
            printf("zero sm_atr [%d] %s", idx, offset_time_str(idx));
        }
        else if (sm_atr < 0)
        {
            printf("negative sm_atr [%d] %s", idx, offset_time_str(idx));
        }

        const double plus_di = (sm_plus_dm / sm_atr) * 100;
        const double minus_di = (sm_minus_dm / sm_atr) * 100;

        if (plus_di == 0 && minus_di == 0)
        {
            // reached fairly often, in XAGUSD M1
            // not so much elsewhere
            Print("zero plus_di, minus_di at " + offset_time_str(idx));
        }

        adxq.plus_di = plus_di;
        adxq.minus_di = minus_di;
        const double di_sum = plus_di + minus_di;
        if (di_sum == 0) {
            // likewise reached in XAGUSD
            printf("calculated zero di sum at %s", offset_time_str(idx));
            adxq.dx = __dblzero__;
        } else {
            adxq.dx = fabs((plus_di - minus_di) / di_sum) * 100;
        }
        adxq.atr_price = next_atr;
    };

    void bind_adx_ema(const int idx, const double &high[], const double &low[], const double &close[])
    {
        // reusing previous adxq values (!)
        double dx = adxq.dx;
        double plus_di = adxq.plus_di;
        double minus_di = adxq.minus_di;
        // binding current to adxq
        bind_adx_quote(idx, high, low, close);
        adxq.dx = ((dx * ema_shifted_period) + (adxq.dx * ema_shift)) / ema_period;
    }

    void update_adx(const int idx, double &atr_data[], double &dx[], double &plus_di[], double &minus_di[], const double &high[], const double &low[], const double &close[])
    {
        // FIXME this still uses the previous ATR smoothing approach

        // this assumes adxq was initialized for the first adx

        /*
        const double atr = adxq.atr_period_start;
        if (atr == 0)
        {
            printf("Invalid atr_period_start in libADX @ %d", idx);
            return;
        }
        */

        // bind_adx_quote(idx, /* atr, */ high, low, close); // FIXME remove atr arg
        bind_adx_ema(idx, high, low, close);
        // printf("! ADX [%d] %f %f/%f", idx, adxq.dx, adxq.plus_di, adxq.minus_di); // [X]
        dx[idx] = adxq.dx;
        plus_di[idx] = adxq.plus_di;
        minus_di[idx] = adxq.minus_di;
        atr_data[idx] = adxq.atr_price;
    };

    void initialize_adx(int extent, double &atr_data[], double &dx[], double &plus_di[], double &minus_di[], const double &high[], const double &low[], const double &close[])
    {
        // printf("ema_shifted_period %d", ema_shifted_period);
        double next_atr = initial_atr_price(--extent, high, low, close);
        extent -= ema_period; /// for initial ATR
        if (next_atr == 0)
        {
            Alert("Initial ATR calculation failed");
            return;
        }
        atr_data[extent] = next_atr; // FIXME no longer used

        // Alert("Initial ATR %f", next_atr);

        printf("Initial ATR at %s [%d] %f", offset_time_str(extent), extent, next_atr);
        // FIXME this does not need to store a sequence of atr values.
        // only the most recent ATR at some chart tick ...
        
        extent--; // for ADX DM
        next_atr = next_atr_price(extent, next_atr, high, low, close);
        printf("Second ATR at %s [%d] %f", offset_time_str(extent), extent, next_atr);

        adxq.atr_price = next_atr;
        bind_adx_quote(extent, high, low, close); // first ADX, no EMA
        dx[extent] = adxq.dx;
        plus_di[extent] = adxq.plus_di;
        minus_di[extent] = adxq.minus_di;
        printf("Initial ADX at %s [%d] DX %f +DI %f -DI %f", offset_time_str(extent), extent, adxq.dx, adxq.plus_di, adxq.minus_di);

        extent--; // because first ADX quote
        // next_atr = next_atr_price(extent, high, low, close); // because first adx quote
        // adxq.atr_price = next_atr; // because first adx quote

        // adxq.atr_period_start = next_atr; // for ATR smoothing
        // extent -= ema_period;             // for ATR smoothing
        while (extent >=     0)               // ?
        {
            next_atr = next_atr_price(extent, next_atr, high, low, close);
            adxq.atr_price = next_atr;
            atr_data[extent] = next_atr; // FIXME no longer used

            update_adx(extent, atr_data, dx, plus_di, minus_di, high, low, close);
            // printf("ADX [%d] %f %f/%f", extent, dx[extent], plus_di[extent], minus_di[extent]);
            /* for ATR smoothing in ADX
            if (extent != 0)
            {
                next_atr = next_atr_price(extent, next_atr, high, low, close); // ...
                adxq.atr_period_start = next_atr;
            }
            */
            extent--;
        }
    };
};

#endif