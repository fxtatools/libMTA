
#ifndef _LIBADX_MQ4
#define _LIBADX_MQ4 1

#include "libATR.mq4"
#include "rates.mq4"
#include "quotes.mq4"

#property library

class ADXIter : public ATRIter
{

protected:

    ADXIter(const string _symbol, const int _timeframe, const string _name = "ADX++") : ATRIter(_symbol, _timeframe, _name, 6)
    {
        dx_buffer = atr_buffer.next();
        plus_dm_buffer = dx_buffer.next();
        minus_dm_buffer = plus_dm_buffer.next();
        plus_di_buffer = minus_dm_buffer.next();
        minus_di_buffer = plus_di_buffer.next();
    };

    // the following objects will be initialized from values created
    // & deinitialized under the BufferMgr protocol
    PriceBuffer *dx_buffer;
    PriceBuffer *plus_dm_buffer;
    PriceBuffer *minus_dm_buffer;
    PriceBuffer *plus_di_buffer;
    PriceBuffer *minus_di_buffer;

public:
    // Implementation Notes:
    // - designed for application onto MT4 time-series data
    // - higher period shift => indicator will generally be more responsive
    //   to present market characteristics, even in event of a market rate spike
    // - period_shift should always be provided as < period
    ADXIter(const int period,
            const int period_shift = 1,
            const int _price_mode = PRICE_CLOSE,
            string _symbol = NULL,
            int _timeframe = EMPTY,
            const string _name = "ADX++",
            const int _nr_buffers = 6) : ATRIter(period, period_shift,  _price_mode, false, _symbol, _timeframe, _name, _nr_buffers)
    {
        dx_buffer = atr_buffer.next();
        plus_dm_buffer = dx_buffer.next();
        minus_dm_buffer = plus_dm_buffer.next();
        plus_di_buffer = minus_dm_buffer.next();
        minus_di_buffer = plus_di_buffer.next();
    };

    ~ADXIter()
    {
        /// linked buffers will be deleted within the BufferMgr protocol
        dx_buffer = NULL;
        plus_dm_buffer = NULL;
        minus_dm_buffer = NULL;
        plus_di_buffer = NULL;
        minus_di_buffer = NULL;
    };

    virtual string indicator_name() const
    {
        return StringFormat("%s(%d, %d)", name, ema_period, ema_shift);
    };

    //
    // public buffer state accessors for ADXAvgIter
    //

    double atr_price_state() {
        return atr_buffer.getState();
    };

    double dx_state() {
        return dx_buffer.getState();
    };

    double plus_dm_state() {
        return plus_dm_buffer.getState();
    };

    double minus_dm_state() {
        return minus_dm_buffer.getState();
    };

    double plus_di_state() {
        return plus_di_buffer.getState();
    };

    double minus_di_state() {
        return minus_di_buffer.getState();
    };

    // Calculate the +DI directional movement at a given index, using the time-series
    // high and low quote data.
    //
    // idx must be less than the length of the time-series data minus one.
    double plusDm(const int idx, const double &high[], const double &low[])
    {
        return high[idx] - high[idx + 1];
    };

    // Calculate the -DI directional movement at a given index, using the time-series
    // high and low quote data.
    //
    // idx must be less than the length of the time-series data minus one.
    double minusDm(const int idx, const double &high[], const double &low[])
    {
        return low[idx + 1] - low[idx];
    };

    // calculate the non-EMA ADX DX, +DI and -DI at a provided index, using time-series
    // high, low, and close data
    //
    // This method assumes adxq.atr_price has been initialized to the ATR at idx,
    // externally
    //
    // Fields of adxq will be initialized for ATR, DX, +DI and -DI values, without DX EMA
    virtual void calcDx(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        // update ATR to current
        ATRIter::calcMain(idx, open, high, low, close);
        double atr_cur = atr_buffer.getState();

        double sm_plus_dm = __dblzero__;
        double sm_minus_dm = __dblzero__;

        const double ema_period_dbl = (double)ema_period;
        double plus_dm_wt = __dblzero__;
        double minus_dm_wt = __dblzero__;

        DEBUG(indicator_name() + " ATR at calcDx [%d] %s : %f", idx, offset_time_str(idx), atr_cur);

        if (dblZero(atr_cur))
        {
            printf(indicator_name() + " zero initial ATR [%d] %s", idx, offset_time_str(idx));
            return;
        }
        else if (atr_cur < 0)
        {
            printf(indicator_name() + " negative ATR [%d] %s", idx, offset_time_str(idx));
            return;
        }

        for (int offset = idx + ema_period, p_k = 1; offset >= idx; offset--, p_k++)
        {
            const double mov_plus = plusDm(offset, high, low);
            const double mov_minus = minusDm(offset, high, low);
            const double wfactor = (double)p_k / ema_period_dbl; // mWMA

            if (mov_plus > 0 && mov_plus > mov_minus)
            {
                // sm_plus_dm += mov_plus;
                // plus_dm_wt += 1.0;
                sm_plus_dm += (mov_plus * wfactor); // mWMA
                // plus_dm_wt += wfactor;
            }
            else if (mov_minus > 0 && mov_minus > mov_plus)
            {
                // sm_minus_dm += mov_minus;
                // minus_dm_wt += 1.0;
                sm_minus_dm += (mov_minus * wfactor); /// mWMA
                // minus_dm_wt += wfactor;
            }
            // plus_dm_wt += 1.0;
            // minus_dm_wt += 1.0;

            plus_dm_wt += wfactor;
            minus_dm_wt += wfactor;
        }

        /// mWMA - TBD
        if (!dblZero(plus_dm_wt))
            sm_plus_dm /= plus_dm_wt;
        if (!dblZero(minus_dm_wt))
            sm_minus_dm /= minus_dm_wt;

        // sm_plus_dm = plusDm(idx, high, low);
        // sm_minus_dm = minusDm(idx, high, low);

        const double plus_dm_prev = plus_dm_buffer.getState();
        const double minus_dm_prev = minus_dm_buffer.getState();

        //// Wilder, cf. p. 48
        //// Pruitt, G. (2016). Stochastics and Averages and RSI! Oh, My.
        ////   In The Ultimate Algorithmic Trading System Toolbox + Website (pp. 25–76).
        ////   John Wiley & Sons, Inc. https://doi.org/10.1002/9781119262992.ch2
        ////
        //// also https://www.investopedia.com/terms/a/adx.asp
        ////
        /*
        if (plus_dm_prev != DBL_MIN)
            sm_plus_dm = plus_dm_prev - (plus_dm_prev / (double) ema_period) + sm_plus_dm;
        if (minus_dm_prev != DBL_MIN)
            sm_minus_dm = minus_dm_prev - (minus_dm_prev / (double) ema_period) + sm_minus_dm;
       plus_dm_buffer.setState(sm_plus_dm);
       minus_dm_buffer.setState(sm_minus_dm);
        */

        /// alternately: DM for DI as forward-shifted EMA of the current weighted MA of +DM / -DM
        /*
        const double ema_shifted_dbl = (double)ema_shifted_period;
        const double ema_shift_dbl = (double)ema_shift;
        if (plus_dm_prev != DBL_MIN)
            sm_plus_dm = ((plus_dm_prev * ema_shifted_dbl) + (sm_plus_dm * ema_shift_dbl)) / ema_period_dbl;
        if (minus_dm_prev != DBL_MIN)
            sm_minus_dm = ((minus_dm_prev * ema_shifted_dbl) + (sm_minus_dm * ema_shift_dbl)) / ema_period_dbl;
        */
       /// or: standard ema (forward-shift unused here)
       if (plus_dm_prev != DBL_MIN)
            sm_plus_dm = ema(plus_dm_prev, sm_plus_dm, ema_period);
        if (minus_dm_prev != DBL_MIN)
            sm_minus_dm = ema(minus_dm_prev, sm_minus_dm, ema_period);
        plus_dm_buffer.setState(sm_plus_dm);
        minus_dm_buffer.setState(sm_minus_dm);


        /* */
        /// alternately: just use DM within period

        //// conventional plus_di / minus_di
        const double plus_di = (sm_plus_dm / atr_cur) * 100.0;
        const double minus_di = (sm_minus_dm / atr_cur)  * 100.0;
        //
        //// not used anywhere in reference for common ADX +DI/-DI calculation,
        //// this reliably converts it to a percentage however.
        // const double plus_di = 100.0 - (100.0 / (1.0 + (sm_plus_dm / atr_cur)));
        // const double minus_di = 100.0 - (100.0 / (1.0 + (sm_minus_dm / atr_cur)));

        if (dblZero(plus_di) && dblZero(minus_di))
        {
            DEBUG(indicator_name() + " zero plus_di, minus_di at " + offset_time_str(idx));
        }

        plus_di_buffer.setState(plus_di);
        minus_di_buffer.setState(minus_di);
        const double di_sum = plus_di + minus_di;
        if (dblZero(di_sum))
        {
            DEBUG(indicator_name() + " calculated zero di sum at " + offset_time_str(idx));
            dx_buffer.setState(__dblzero__);
        }
        else
        {
            // const double dx = fabs((plus_di - minus_di) / di_sum) * 100.0;
            /// alternately, a down-scaled representation for DX factored from DI:
            const double dx = 100.0 - (100.0 / (1.0 + fabs((plus_di - minus_di) / di_sum)));
            DEBUG(indicator_name() + "DX [%d] %s : %s", idx, offset_time_str(idx), dx);
            dx_buffer.setState(dx);
        }
    };

    // calculate the first ADX within an extent for time series high, low, and close data.
    //
    // returns the index of the first ADX value within this time series.
    //
    // This method will initialize the fields of adxq for ATR, DX, +DI and -DI values at
    // an index to the provided extent, adjusted for EMA period and directional movement
    // calculation.
    //
    // This method will not produce an EMA for the initial DX value
    virtual int calcInitial(const int extent, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        int calc_idx = ATRIter::calcInitial(extent, open, high, low, close);
        double next_atr = atr_buffer.getState();

        if (next_atr == 0)
        {
            Alert(indicator_name() + " Initial ATR calculation failed => 0");
            return EMPTY;
        }

        DEBUG(indicator_name() + " Initial ATR at %s [%d] %f", offset_time_str(calc_idx), calc_idx, next_atr);

        // pad by one for the initial ATR
        calc_idx--;

        // pad by one more and update ATR for the gap, to allow for +DM/-DM calculation
        // at start of first EMA_PERIOD (or not)
        //
        /*
        ATRIter::calcMain(calc_idx--, open, high, low, close);
        next_atr = debug ? atr_buffer.getState() : EMPTY; // now unused when not debug
        DEBUG(indicator_name() + " Second ATR at %s [%d] %f", offset_time_str(calc_idx), calc_idx, next_atr);
        */

        plus_dm_buffer.setState(DBL_MIN);
        minus_dm_buffer.setState(DBL_MIN);
        calcDx(calc_idx, open, high, low, close);
        return calc_idx;
    }

    // ADX calculation, as a function onto DX
    virtual void calcMain(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        /// store previous DX
        const double adx_pre = dx_buffer.getState();
        /// calculte current DX, to be stored by side effect along with +DM/+DM, +DI/-DI
        calcDx(idx, open, high, low, close);
        /// ADX
        const double dx_cur = dx_buffer.getState();
        /// forward-shifted EMA
        // const double adx = ((adx_pre * (double)ema_shifted_period) + (dx_cur * (double)ema_shift)) / (double)ema_period;
        /// conventional EMA (forward-shift unused here)
        const double adx = ema(adx_pre, dx_cur, ema_period);
        DEBUG(indicator_name() + " DX (%f, %f) => %f at %s [%d]", adx_pre, dx_cur, adx, offset_time_str(idx), idx);
        dx_buffer.setState(adx);
    };

    virtual void initIndicator()
    {
        // bind all drawn and undrawn buffers to the indicator
        SetIndexBuffer(0, plus_di_buffer.data);
        SetIndexLabel(0, "+DI");
        SetIndexStyle(0, DRAW_LINE);

        SetIndexBuffer(1, minus_di_buffer.data);
        SetIndexLabel(1, "-DI");
        SetIndexStyle(1, DRAW_LINE);

        SetIndexBuffer(2, dx_buffer.data);
        SetIndexLabel(2, "DX");
        SetIndexStyle(2, DRAW_LINE);

        // non-drawn buffers
        const bool draw_atr = debug;
        SetIndexBuffer(3, atr_buffer.data, draw_atr ? INDICATOR_DATA : INDICATOR_CALCULATIONS);
        SetIndexLabel(3, draw_atr ? "DX ATR" : NULL);
        SetIndexStyle(3, draw_atr ? DRAW_LINE : DRAW_NONE);

        SetIndexBuffer(4, plus_dm_buffer.data, INDICATOR_CALCULATIONS);
        SetIndexLabel(4, NULL);
        SetIndexStyle(4, DRAW_NONE);

        SetIndexBuffer(5, minus_dm_buffer.data, INDICATOR_CALCULATIONS);
        SetIndexLabel(5, NULL);
        SetIndexStyle(5, DRAW_NONE);
    };

};

double max(const double &values[]) {
    double m = __dblzero__;
    for(int n = 0; n < ArraySize(values); n++) {
        const double val = values[n];
        if (val > m) {
            m = val;
        }
    }
    return m;
}

class ADXAvgBuffer : public ADXIter
{
protected:
    ADXIter *m_iter[];
    double m_weights[];

public:
    int n_adx_members;

    double total_weights;
    int longest_period;

    ADXAvgBuffer(const int n_members, const int &periods[], const int &period_shifts[], const double &weights[], const string _symbol = NULL, const int _timeframe = EMPTY) : n_adx_members(n_members), ADXIter(_symbol, _timeframe, "ADXAvg")
    {

        ArrayResize(m_iter, n_adx_members);
        ArrayResize(m_weights, n_adx_members);
        int add_idx;
        int last_per = 0;
        int longest_per = 0;
        for (int idx = 0; idx < n_members; idx++)
        {
            const int per = periods[idx];
            const int shift = period_shifts[idx];
            const double weight = weights[idx];
            total_weights += weight;
            if (per > last_per)
            {
                for (int n = idx; n > 0; n--)
                {
                    // shift all iterators & weights forward by one
                    const int nminus = n - 1;
                    m_iter[n] = m_iter[nminus];
                    m_weights[n] = m_weights[nminus];
                }
                add_idx = 0;
                if (per > longest_per)
                {
                    longest_per = per;
                }
            }
            else
            {
                add_idx = idx;
            }
            m_iter[add_idx] = new ADXIter(per, shift, price_mode, _symbol, _timeframe);
            m_weights[add_idx] = weight;
            last_per = per;
        }
        longest_period = longest_per;
    }
    ~ADXAvgBuffer()
    {
        for (int n = 0; n < n_adx_members; n++)
        {
            ADXIter *it = m_iter[n];
            m_iter[n] = NULL;
            delete it;
        }
        ArrayFree(m_iter);
        ArrayFree(m_weights);
    }

    // copy elements of the m_iter array to some provided buffer
    int copyIter(ADXIter *&buffer[])
    {
        if (ArrayIsDynamic(buffer) && ArraySize(buffer) < n_adx_members)
            ArrayResize(buffer, n_adx_members);
        for (int n = 0; n < n_adx_members; n++)
        {
            buffer[n] = m_iter[n];
        }
        return n_adx_members;
    };

    // copy elements of the m_weights array to some provided buffer
    int copyWeights(double &buffer[])
    {
        if (ArrayIsDynamic(buffer) && ArraySize(buffer) < n_adx_members)
            ArrayResize(buffer, n_adx_members);
        for (int n = 0; n < n_adx_members; n++)
        {
            buffer[n] = m_weights[n];
        }
        return n_adx_members;
    };

    virtual bool setExtent(const int len, const int padding = EMPTY) {
        if (!PriceIndicator::setExtent(len, padding))
            return false;
        for (int n = 0; n < n_adx_members; n++)
        {
            ADXIter *it = m_iter[n];
            if (!it.setExtent(len, padding))
                return false;
        }
        return true;
    }

    virtual bool reduceExtent(const int len, const int padding = EMPTY) {
        if (!PriceIndicator::reduceExtent(len, padding))
            return false;
        for (int n = 0; n < n_adx_members; n++)
        {
            ADXIter *it = m_iter[n];
            if (!it.reduceExtent(len, padding))
                return false;
        }
        return true;
    }


    virtual void calcDx(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])  {
    // NOP
    };

    virtual int calcInitial(const int extent, const double &open[], const double &high[], const double &low[], const double &close[])
    {

        DEBUG("Calculating Initial Avg ADX wtihin %d", extent);

        int first_idx = -1;
        int next_idx;
        double avg_atr = __dblzero__;
        double avg_dx = __dblzero__;
        double avg_plus_dm = __dblzero__;
        double avg_minus_dm = __dblzero__;
        double avg_plus_di = __dblzero__;
        double avg_minus_di = __dblzero__;
        for (int n = 0; n < n_adx_members; n++)
        {
            ADXIter *it = m_iter[n];
            const double weight = m_weights[n];
            if (first_idx == -1)
            {
                // the ADX for the furthest EMA period will be calculated first
                DEBUG("Calculate first ADX(%d, %d) [%d]", it.ema_period, it.ema_shift, extent);
                first_idx = it.calcInitial(extent, open, high, low, close);
                DEBUG("First index %d", first_idx);
            }
            else
            {
                DEBUG("Calculate secondary ADX(%d, %d) [%d]", it.ema_period, it.ema_shift, next_idx);
                next_idx = it.calcInitial(extent, open, high, low, close);
                for (int idx = next_idx - 1; idx >= first_idx; idx--)
                {
                   // fast-forward to the start for the ADX with furthest EMA period
                   DEBUG("Fast-forward for ADX(%d, %d) [%d]", it.ema_period, it.ema_shift, idx);
                   it.calcMain(idx, open, high, low, close);
                }
               /// shortcut ...
               // it.calcInitial(first_idx, open, high, low, close);
            }
            avg_atr += (it.atr_price_state() * weight);
            avg_dx += (it.dx_state() * weight);
            avg_plus_dm += (it.plus_dm_state() * weight);
            avg_minus_dm += (it.minus_dm_state() * weight);
            avg_plus_di += (it.plus_di_state() * weight);
            avg_minus_di += (it.minus_di_state() * weight);
        }
        fillState(extent - 1, first_idx + 1);
        avg_atr /= total_weights;
        avg_dx /= total_weights;
        avg_plus_dm /= total_weights;
        avg_minus_dm /= total_weights;
        avg_plus_di /= total_weights;
        avg_minus_di /= total_weights;
        atr_buffer.setState(avg_atr);
        dx_buffer.setState(avg_dx);
        plus_dm_buffer.setState(avg_plus_dm);
        minus_dm_buffer.setState(avg_minus_dm);
        plus_di_buffer.setState(avg_plus_di);
        minus_di_buffer.setState(avg_minus_di);
        return first_idx;
    };

    virtual void calcMain(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        DEBUG("Binding Avg ADX EMA %d", idx);
        double avg_atr = __dblzero__;
        double avg_dx = __dblzero__;
        double avg_plus_dm = __dblzero__;
        double avg_minus_dm = __dblzero__;
        double avg_plus_di = __dblzero__;
        double avg_minus_di = __dblzero__;
        for (int n = 0; n < n_adx_members; n++)
        {
            ADXIter *it = m_iter[n];
            double weight = m_weights[n];
            it.calcMain(idx, open, high, low, close);
            avg_atr += (it.atr_price_state() * weight);
            avg_dx += (it.dx_state() * weight);
            avg_plus_dm += (it.plus_dm_state() * weight);
            avg_minus_dm += (it.minus_dm_state() * weight);
            avg_plus_di += (it.plus_di_state() * weight);
            avg_minus_di += (it.minus_di_state() * weight);
        }
        avg_atr /= total_weights;
        avg_dx /= total_weights;
        avg_plus_dm /= total_weights;
        avg_minus_dm /= total_weights;
        avg_plus_di /= total_weights;
        avg_minus_di /= total_weights;
        atr_buffer.setState(avg_atr);
        dx_buffer.setState(avg_dx);
        plus_dm_buffer.setState(avg_plus_dm);
        minus_dm_buffer.setState(avg_minus_dm);
        plus_di_buffer.setState(avg_plus_di);
        minus_di_buffer.setState(avg_minus_di);
    };
};

#endif

