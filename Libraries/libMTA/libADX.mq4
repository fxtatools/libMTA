
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
    // Implementation Notes:
    // - designed for application onto MT4 time-series data
    // - higher period shift => indicator will generally be more responsive
    //   to present market characteristics, even in event of a market rate spike
    // - period_shift should always be provided as < period
    ADXIter(int period, int period_shift = 1, string _symbol = NULL, int _timeframe = EMPTY) : ATRIter(period, period_shift, _symbol, _timeframe)
    {
        adxq = ADXQuote();
    };

    ~ADXIter()
    {
        delete &adxq;
    };

    void prepare_next_pass(const double atr_price, const double dx)
    {
        // set the current ATR and previous DX
        //
        // called generally before any first iterating call to bind_adx_ema()
        //
        // this is a convenience method. iterators should update adxq.atr_price
        // internally, after the initial previous-quote seed data.
        adxq.atr_price = atr_price;
        adxq.dx = dx;
    };

    double plus_dm_movement(const int idx, const double &high[], const double &low[])
    {
        return high[idx] - high[idx + 1];
    };

    double minus_dm_movement(const int idx, const double &high[], const double &low[])
    {
        return low[idx + 1] - low[idx];
    };

    void bind_adx_quote(const int idx, const double &high[], const double &low[], const double &close[])
    {
        // Implementation Notes:
        //
        // - current ATR must be initialized externally onto adxq
        //   cf. prepare_next_pass(), used in methods defined below
        //   before calling bind_adx_ema()

        double sm_plus_dm = __dblzero__;
        double sm_minus_dm = __dblzero__;
        double plus_dm = __dblzero__;
        double minus_dm = __dblzero__;

        double atr_cur = adxq.atr_price;

        DEBUG("ATR at bind_adx_quote [%d] %s : %f", idx, offset_time_str(idx), atr_cur);

        if (atr_cur == 0)
        {
            printf("zero initial ATR [%d] %s", idx, offset_time_str(idx));
        }
        else if (atr_cur < 0)
        {
            printf("negative ATR [%d] %s", idx, offset_time_str(idx));
        }
        else
        {
            DEBUG("initial ATR [%d] %s", idx, offset_time_str(idx));
        }

        // https://en.wikipedia.org/wiki/Average_directional_movement_index
        //
        // this implementation does not provide additional smoothing of the EMA
        for (int offset = idx + ema_period; offset >= idx; offset--)
        {
            const double mov_plus = plus_dm_movement(offset, high, low);
            const double mov_minus = minus_dm_movement(offset, high, low);
            plus_dm = mov_plus > 0 && mov_plus > mov_minus ? mov_plus : __dblzero__;
            minus_dm = mov_minus > 0 && mov_minus > mov_plus ? mov_minus : __dblzero__;
            sm_plus_dm += plus_dm;
            sm_minus_dm += minus_dm;
        }

        // https://www.investopedia.com/terms/a/adx.asp ...
        sm_plus_dm = sm_plus_dm - (sm_plus_dm / ema_period) + plus_dm;
        sm_minus_dm = sm_minus_dm - (sm_minus_dm / ema_period) + minus_dm;
        //// ^ results in very large values for +DI/-DI
        /// or ...
        sm_plus_dm /= ema_period;
        sm_minus_dm /= ema_period;
        /// ^ also too-large values, once the EMA is applied * 100
        /// though less so by an order of magnitude ...
        /// so both ...
        //
        /// FIXME sometimes may result in +DI / -DI greater than 100
        
        const double plus_di = (sm_plus_dm / atr_cur) * 100;
        const double minus_di = (sm_minus_dm / atr_cur) * 100;

        if (plus_di == 0 && minus_di == 0)
        {
            // reached fairly often, in XAGUSD M1
            // not so much elsewhere
            Print("zero plus_di, minus_di at " + offset_time_str(idx));
        }

        adxq.plus_di = plus_di;
        adxq.minus_di = minus_di;
        const double di_sum = plus_di + minus_di;
        if (di_sum == 0)
        {
            // likewise reached in XAGUSD
            Print("calculated zero di sum at " + offset_time_str(idx));
            adxq.dx = __dblzero__;
        }
        else
        {
            adxq.dx = fabs((plus_di - minus_di) / di_sum) * 100;
        }
    };

    void bind_adx_ema(const int idx, const double &high[], const double &low[], const double &close[])
    {
        /// reusing previous adxq values, before the call to bind_adx_quote
        double dx = adxq.dx;
        /// TBD also bind EMA for +DI/-DI
        /// Side effect: EMA for +DI/-DI makes it difficult to spot indication of 
        /// crossover within the indicator graph
        // double plus_di = adxq.plus_di;
        // double minus_di = adxq.minus_di;

        /// binding current to adxq
        bind_adx_quote(idx, high, low, close);
        /// binding EMA to adxq
        adxq.dx = ((dx * ema_shifted_period) + (adxq.dx * ema_shift)) / ema_period;
        // adxq.plus_di = ((plus_di * ema_shifted_period) + (adxq.plus_di * ema_shift)) / ema_period;
        // adxq.minus_di = ((plus_di * ema_shifted_period) + (adxq.minus_di * ema_shift)) / ema_period;
    };

    void update_adx_ema(const int idx, double &atr_data[], double &dx[], double &plus_di[], double &minus_di[], const double &high[], const double &low[], const double &close[])
    {
        // this assumes adxq was initialized for the first adx
        // - for initial values, see initial_atr_price()
        // - for updates, see prepare_next_pass()
        //
        bind_adx_ema(idx, high, low, close);
        DEBUG("[%d] DX %f DI +/- %f/%f", idx, adxq.dx, adxq.plus_di, adxq.minus_di);
        dx[idx] = adxq.dx;
        plus_di[idx] = adxq.plus_di;
        minus_di[idx] = adxq.minus_di;
        atr_data[idx] = adxq.atr_price;
    };

    void initialize_adx_data(int extent, double &atr_data[], double &dx[], double &plus_di[], double &minus_di[], const double &high[], const double &low[], const double &close[])
    {
        DEBUG("Initalizing ADX from quote %s [%d]", offset_time_str(extent), extent);
        const int __latest__ = 0;

        double next_atr = initial_atr_price(--extent, high, low, close);

        extent -= ema_period; // for initial ATR
        if (next_atr == 0)
        {
            Alert("Initial ATR calculation failed");
            return;
        }
        atr_data[extent] = next_atr;

        DEBUG("Initial ATR at %s [%d] %f", offset_time_str(extent), extent, next_atr);

        extent--; // for ADX DM
        next_atr = next_atr_price(extent, next_atr, high, low, close);

        DEBUG("Second ATR at %s [%d] %f", offset_time_str(extent), extent, next_atr);
        adxq.atr_price = next_atr;
        atr_data[extent] = next_atr;
        bind_adx_quote(extent, high, low, close); // first ADX, no EMA
        dx[extent] = adxq.dx;
        plus_di[extent] = adxq.plus_di;
        minus_di[extent] = adxq.minus_di;
        DEBUG("Initial ADX at %s [%d] DX %f +DI %f -DI %f", offset_time_str(extent), extent, adxq.dx, adxq.plus_di, adxq.minus_di);

        extent--; // for the first ADX quote

        while (extent >= __latest__)
        {
            next_atr = next_atr_price(extent, next_atr, high, low, close);
            adxq.atr_price = next_atr;
            update_adx_ema(extent, atr_data, dx, plus_di, minus_di, high, low, close);
            extent--;
        }
        latest_quote_dt = iTime(symbol, timeframe, __latest__);
    };

    void update_adx_data(double &atr_data[], double &dx[], double &plus_di[], double &minus_di[], const double &high[], const double &low[], const double &close[])
    {
        // plus one, plus two to ensure the previous ADX is recalculated from final market quote,
        // mainly when the previous ADX was calculated at offset 0
        int idx = latest_quote_offset() + 1;
        const int prev_idx = idx + 1;
        const int __latest__ = 0;

        double next_atr = atr_data[prev_idx];
        const double prev_dx = dx[prev_idx];
        // next_atr here should stay the same across ticks
        DEBUG("updating from %s [%d] initial ATR %f DX %f", offset_time_str(prev_idx), prev_idx, next_atr, prev_dx);
        prepare_next_pass(next_atr, prev_dx);

        while (idx >= __latest__)
        {
            next_atr = next_atr_price(idx, next_atr, high, low, close);
            DEBUG("updating at %s [%d] using ATR %f", idx, offset_time_str(idx), next_atr);
            // set the current ATR
            adxq.atr_price = next_atr;
            update_adx_ema(idx, atr_data, dx, plus_di, minus_di, high, low, close);
            idx--;
        }
        latest_quote_dt = iTime(symbol, timeframe, __latest__);
    };
};

#endif
