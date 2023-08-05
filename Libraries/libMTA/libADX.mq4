
#ifndef _LIBADX_MQ4
#define _LIBADX_MQ4 1

#include "libATR.mq4"
#include "trend.mq4" // crossover & binding for ADX

#property library
#property strict

class ADXIndicator : public ATRIndicator
{

protected:
    // a generalized constructor for application under ADXAvg,
    // which uses no single EMA period
    ADXIndicator(const int _price_mode,
                 const string _symbol = NULL,
                 const int _timeframe = EMPTY,
                 const string _name = "ADX++") : ATRIndicator(_price_mode, _symbol, _timeframe, _name, 6)
    {
        initBuffers(atr_buffer);
    };

    void initBuffers(PriceBuffer &start_buff)
    {
        dx_buffer = start_buff.next();
        plus_dm_buffer = dx_buffer.next();
        minus_dm_buffer = plus_dm_buffer.next();
        plus_di_buffer = minus_dm_buffer.next();
        minus_di_buffer = plus_di_buffer.next();
    };

public:
    // Implementation Notes:
    // - designed for application onto MT4 time-series data
    // - higher period shift => indicator will generally be more responsive
    //   to present market characteristics, even in event of a market rate spike,
    //   though likewise more erratic over durations
    // - period_shift should always be provided as < period
    // - for a conventional EMA behavior, provide period_shift = 1
    ADXIndicator(const int period,
                 const int period_shift = 1,
                 const int _price_mode = PRICE_CLOSE,
                 const string _symbol = NULL,
                 const int _timeframe = EMPTY,
                 const string _name = "ADX++",
                 const int _nr_buffers = 6,
                 const int _data_shift = EMPTY) : ATRIndicator(period, period_shift, _price_mode, false, _symbol, _timeframe, _name, _data_shift, _nr_buffers)
    {
        initBuffers(atr_buffer);
    };

    ~ADXIndicator()
    {
        /// linked buffers will be deleted within the BufferMgr protocol
        dx_buffer = NULL;
        plus_dm_buffer = NULL;
        minus_dm_buffer = NULL;
        plus_di_buffer = NULL;
        minus_di_buffer = NULL;
    };

    // the following objects will be initialized from values created
    // & deinitialized under the BufferMgr protocol
    //
    // declared as public for purpose of simple direct access under ADXAvg
    //  FIXME -> bindDxBuffer(const int offset, label = NULL) ...
    PriceBuffer *dx_buffer;
    PriceBuffer *plus_dm_buffer;
    PriceBuffer *minus_dm_buffer;
    PriceBuffer *plus_di_buffer;
    PriceBuffer *minus_di_buffer;

    virtual int dataBufferCount() const
    {
        // return the number of buffers used directly for this indicator.
        // should be incremented internally, in derived classes
        return ATRIndicator::dataBufferCount() + 5;
    };

    virtual string indicator_name() const
    {
        return StringFormat("%s(%d, %d)", name, ema_period, ema_shift);
    };

    //
    // public buffer state accessors for ADXAvgIter
    //

    double atrState()
    {
        return atr_buffer.getState();
    };

    double atrAt(const int idx)
    {
        return atr_buffer.get(idx);
    }

    double dxState()
    {
        return dx_buffer.getState();
    };

    double dxAt(const int idx)
    {
        return dx_buffer.get(idx);
    };

    double plusDmState()
    {
        return plus_dm_buffer.getState();
    };

    double plusDmAt(const int idx)
    {
        return plus_dm_buffer.get(idx);
    };

    double minusDmState()
    {
        return minus_dm_buffer.getState();
    };

    double minusDmAt(const int idx)
    {
        return minus_dm_buffer.get(idx);
    };

    double plusDiState()
    {
        return plus_di_buffer.getState();
    };

    double plusDiAt(const int idx)
    {
        return plus_di_buffer.get(idx);
    };

    double minusDiState()
    {
        return minus_di_buffer.getState();
    };

    double minusDiAt(const int idx)
    {
        return minus_di_buffer.get(idx);
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
    
    double chg(const int idx, const double &open[], const double &high[], const double &low[], const double &close[]) {
        const double p_near = price_for(idx, price_mode, open, high, low, close);
        const double p_far = price_for(idx, price_mode, open, high, low, close);
        return p_near - p_far;
    }

    // calculate the non-EMA ADX DX, +DI and -DI at a provided index, using time-series
    // high, low, and close data
    //
    // This method assumes adxq.atr_price has been initialized to the ATR at idx,
    // externally
    //
    // Fields of adxq will be initialized for ATR, DX, +DI and -DI values, without DX EMA
    virtual void calcDx(const int idx, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
    {
        // update ATR to current, from previously initialized ATR
        DEBUG(indicator_name() + " Previous ATR at calcDx [%d] %s : %f", idx, offset_time_str(idx), atr_buffer.getState());
        ATRIndicator::calcMain(idx, open, high, low, close, volume);
        double atr_cur = atr_buffer.getState();
        // ^ FIXME something about the ATR calculation at [0] is breaking now in ADXAvg

        double sm_plus_dm = __dblzero__;
        double sm_minus_dm = __dblzero__;

        const double ema_period_dbl = (double)ema_period;
        double weights = __dblzero__;

        DEBUG(indicator_name() + " ATR at calcDx [%d] %s : %f", idx, offset_time_str(idx), atr_cur);

        if (dblZero(atr_cur))
        {
            printf(indicator_name() + " zero initial ATR [%d] %s", idx, offset_time_str(idx));
            // FIXME error
            return;
        }
        else if (atr_cur < 0)
        {
            printf(indicator_name() + " negative ATR [%d] %s", idx, offset_time_str(idx));
            // FIXME error
            return;
        }

        // Partial/Modified Hull MA for DM
        // https://alanhull.com/hull-moving-average
        // simplified
        // https://school.stockcharts.com/doku.php?id=technical_indicators:hull_moving_average
        // - modified as in using the period shift in lieu of both the 2 * short factor
        //   and (TO DO) as the period for the prevailing MA
        // - this uses one iteration for calculating both the short and primary MA
        // - as yet, no additional MA over the sum of short and primary
        //
        /// period for the prevailing MA
        // const int p_sqrt = ema_shift; // (int)sqrt(ema_period);
        ///
        const int p_short = ema_shift; // (int)(ema_period/2);
        double weights_short = DBLZERO;
        double sm_plus_short = DBLZERO;
        double sm_minus_short = DBLZERO;

        // - using volume as a weighting factor for +DM/-DM mWMA [!]
        for (int offset = idx + ema_period - 1, p_k = 1; offset >= idx; offset--, p_k++)
        {
            const double mov_plus = plusDm(offset, high, low);
            const double mov_minus = minusDm(offset, high, low);
            // const double wfactor = ((double)p_k * volume[idx]) / ema_period_dbl; // mWMA feat. volume
            // const double wfactor = ((double)p_k / volume[idx]) / ema_period_dbl ; // mWMA feat. volume++
            // ? 
            const double wfactor = ((double)p_k ) / (ema_period_dbl * volume[idx]) ; // mWMA feat. volume+++


            // const double wfactor = (double)p_k / ema_period_dbl; // mWMA

            // const double wfactor = 1.0; // AVG

            DEBUG("+DM %d %f", offset, mov_plus);
            DEBUG("-DM %d %f", offset, mov_minus);

            if (mov_plus > 0 && mov_plus > mov_minus)
            {
                // sm_plus_dm += mov_plus;
                // plus_dm_wt += 1.0;
                const double plus = (mov_plus * wfactor); // mWMA
                sm_plus_dm += plus;
                /*
                if (p_k >= p_short)
                    sm_plus_short += plus; // Partial Hull MA
                */
            }
            else if (mov_minus > 0 && mov_minus > mov_plus)
            {
                // sm_minus_dm += mov_minus;
                // minus_dm_wt += 1.0;
                const double minus = (mov_minus * wfactor); /// mWMA
                sm_minus_dm += minus;
                /*
                if (p_k >= p_short)
                    sm_minus_short += minus; // Partial Hull MA
                */
            }
            weights += wfactor;
            if (p_k > p_short)
                weights_short += wfactor;
        }

        /// Parital Hull MA
        // sm_plus_short /= weights_short;
        // sm_minus_short /= weights_short;

        /// mWMA - TBD
        sm_plus_dm /= weights;
        sm_minus_dm /= weights;

        //// Partial HMA TBD
        //// NB: This alone may result in negative values
        // --
        // sm_plus_dm = (2 * sm_plus_short) - sm_plus_dm;
        /// ++ but ...
        // sm_plus_dm = (ema_shift * sm_plus_short) - sm_plus_dm;
        // --
        // sm_minus_dm = (2 * sm_minus_short) - sm_minus_dm;
        /// ++ but ...
        // sm_minus_dm = (ema_shift * sm_minus_short) - sm_minus_dm;

        /// non-MA ..
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
        /* - smoothed but not necc. useful as an indicator
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
        
        // or RVI-like WMA
        /*
        if (plus_dm_prev != DBL_MIN)
            sm_plus_dm = (2.0 * plus_dm_prev + (sm_plus_dm)) / 3.0;
        if (minus_dm_prev != DBL_MIN)
            sm_minus_dm = (2.0 * minus_dm_prev + (sm_minus_dm)) / 3.0;
        */
        // ... similarly, RVI-like WMA using input parameters (??)
        
        /*
        if (plus_dm_prev != DBL_MIN)
            sm_plus_dm = ((ema_shift * plus_dm_prev) + (sm_plus_dm * ema_shifted_period)) / ema_period_dbl;
        if (minus_dm_prev != DBL_MIN)
            sm_minus_dm = ((ema_shift * minus_dm_prev) + (sm_minus_dm * ema_shifted_period)) / ema_period_dbl;
        */

        plus_dm_buffer.setState(sm_plus_dm);
        minus_dm_buffer.setState(sm_minus_dm);

        /* */
        /// alternately: just use DM within period

        //// conventional plus_di / minus_di
        const double plus_di = (sm_plus_dm / atr_cur) * 100.0;
        const double minus_di = (sm_minus_dm / atr_cur) * 100.0;
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
            DEBUG(indicator_name() + " DX [%d] %s : %f", idx, offset_time_str(idx), dx);
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
    virtual int calcInitial(const int _extent, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
    {
        int calc_idx = ATRIndicator::calcInitial(_extent, open, high, low, close, volume);
        double atr_cur = atr_buffer.getState();

        if (atr_cur == 0)
        {
            Alert(indicator_name() + " Initial ATR calculation failed => 0");
            return EMPTY;
        }

        DEBUG(indicator_name() + " Initial ATR at %s [%d] %f", offset_time_str(calc_idx), calc_idx, atr_cur);

        // pad by one for the initial ATR
        calc_idx--;

        plus_dm_buffer.setState(DBL_MIN);
        minus_dm_buffer.setState(DBL_MIN);
        calcDx(calc_idx, open, high, low, close, volume);
        return calc_idx;
    }

    // ADX calculation, as a function onto DX
    virtual void calcMain(const int idx, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
    {
        /// store previous DX
        const double adx_pre = dx_buffer.getState();
        /// calculte current DX, to be stored by side effect along with +DM/+DM, +DI/-DI
        calcDx(idx, open, high, low, close, volume);
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
        PriceIndicator::initIndicator();

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
        // const bool draw_atr = true;
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

    virtual bool bind(PriceXOver &xover, const int start = 0, const int end = EMPTY)
    {
        const bool found = xover.bind(plus_di_buffer.data, minus_di_buffer.data, this, start, end);
        if (found)
        {
            // further +DI > further -DI
            xover.setBearish(xover.farVal() > xover.farValB());
            return true;
        }
        else
        {
            return false;
        }
    }

    double xoverNearPlusDI(PriceXOver &xover)
    {
        return xover.nearVal();
    }
    double xoverNearMinusDI(PriceXOver &xover)
    {
        return xover.nearValB();
    }

    double xoverFarPlusDI(PriceXOver &xover)
    {
        return xover.farVal();
    }

    double xoverFarMinusDI(PriceXOver &xover)
    {
        return xover.farValB();
    }
};

class ADXAvg : public ADXIndicator
{
protected:
    ADXIndicator *m_iter[];
    double m_weights[];

    // FIXME absent of convnetion for passing a flag indicating "Draw no buffers",
    // this has not been initializing all member data buffers as indicator
    // buffers under initIndicator()
    //
    // This initalizes only the buffers used for capturing average data from
    // member indicators.
    //
    // The rest of the buffers should be succesfully managed under
    // BufferMgr. This is being tested locally.

    int max(const int n_val, const int &values[])
    {
        int m = 0;
        for (int n = 0; n < n_val; n++)
        {
            const int v = values[n];
            if (v > m)
                m = v;
        }
        return m;
    }

    double sum(const int n_val, const double &values[])
    {
        double m = DBLZERO;
        for (int n = 0; n < n_val; n++)
        {
            m += values[n];
        }
        return m;
    }

public:
    const int n_adx_members;

    const double total_weights;
    const int longest_period;

    ADXAvg(const int n_members,
           const int &periods[],
           const int &period_shifts[],
           const double &weights[],
           const int _price_mode = PRICE_CLOSE,
           const string _symbol = NULL,
           const int _timeframe = EMPTY,
           const string _name = "ADXvg") : n_adx_members(n_members), total_weights(sum(n_members, weights)), longest_period(max(n_members, periods)), ADXIndicator(_price_mode, _symbol, _timeframe, _name)

    {
        ArrayResize(m_iter, n_members);
        ArrayResize(m_weights, n_members);
        int add_idx;
        int last_per = 0;
        for (int idx = 0; idx < n_members; idx++)
        {
            const int per = periods[idx];
            const int shift = period_shifts[idx];
            const double weight = weights[idx];
            if (last_per != 0 && per > last_per)
            {
                for (int n = idx; n > 0; n--)
                {
                    // shift all iterators & weights forward by one
                    const int nminus = n - 1;
                    m_iter[n] = m_iter[nminus];
                    m_weights[n] = m_weights[nminus];
                }
                add_idx = 0;
            }
            else
            {
                add_idx = idx;
            }
            m_iter[add_idx] = new ADXIndicator(per, shift, price_mode, _symbol, _timeframe);
            m_weights[add_idx] = weight;
            last_per = per;
        }
    }
    ~ADXAvg()
    {
        for (int n = 0; n < n_adx_members; n++)
        {
            ADXIndicator *it = m_iter[n];
            m_iter[n] = NULL;
            delete it;
        }
        ArrayFree(m_iter);
        ArrayFree(m_weights);
    }

    virtual void initIndicator()
    {
        // ensure all local buffers and all member buffers will be
        // registered as indicator buffers
        //
        // if not called for all member buffers, there would be side
        // effects towards calculations during indicator update,
        // presumably as an effect of a behavior of pointer shift
        // performed within the MT4 implementation, for indicator
        // data.
        //
        ADXIndicator::initIndicator();
        const int count = dataBufferCount();
        IndicatorBuffers(count * (1 + n_adx_members));
        int next_offset = count;
        for (int n = 0; n < n_adx_members; n++)
        {
            ADXIndicator *it = m_iter[n];
            // bind ADX member buffers as undrawn
            SetIndexBuffer(next_offset, it.plus_di_buffer.data, INDICATOR_CALCULATIONS);
            SetIndexLabel(next_offset, NULL);
            SetIndexStyle(next_offset++, DRAW_NONE);

            SetIndexBuffer(next_offset, it.minus_di_buffer.data, INDICATOR_CALCULATIONS);
            SetIndexLabel(next_offset, NULL);
            SetIndexStyle(next_offset++, DRAW_NONE);

            SetIndexBuffer(next_offset, it.dx_buffer.data, INDICATOR_CALCULATIONS);
            SetIndexLabel(next_offset, NULL);
            SetIndexStyle(next_offset++, DRAW_NONE);

            SetIndexBuffer(next_offset, it.atr_buffer.data, INDICATOR_CALCULATIONS);
            SetIndexLabel(next_offset, NULL);
            SetIndexStyle(next_offset++, DRAW_NONE);

            SetIndexBuffer(next_offset, it.plus_dm_buffer.data, INDICATOR_CALCULATIONS);
            SetIndexLabel(next_offset, NULL);
            SetIndexStyle(next_offset++, DRAW_NONE);

            SetIndexBuffer(next_offset, it.minus_dm_buffer.data, INDICATOR_CALCULATIONS);
            SetIndexLabel(next_offset, NULL);
            SetIndexStyle(next_offset++, DRAW_NONE);
        }
    }

    // copy elements of the m_iter array to some provided buffer
    int copyIter(ADXIndicator *&buffer[])
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

    virtual bool setExtent(const int len, const int padding = EMPTY)
    {
        if (!PriceIndicator::setExtent(len, padding))
            return false;
        for (int n = 0; n < n_adx_members; n++)
        {
            ADXIndicator *it = m_iter[n];
            if (!it.setExtent(len, padding))
                return false;
        }
        return true;
    }

    virtual bool reduceExtent(const int len, const int padding = EMPTY)
    {
        if (!PriceIndicator::reduceExtent(len, padding))
            return false;
        for (int n = 0; n < n_adx_members; n++)
        {
            ADXIndicator *it = m_iter[n];
            if (!it.reduceExtent(len, padding))
                return false;
        }
        return true;
    }

    virtual void calcDx(const int idx, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[]){
        // N/A. The DX here is calculated from a weighted average of member ADX series
    };

    virtual void restoreState(const int idx)
    {
        for (int n = 0; n < n_adx_members; n++)
        {
            ADXIndicator *it = m_iter[n];
            it.restoreState(idx);
        }
    };

    virtual datetime updateVars(const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[], const int initial_index = EMPTY, const int padding = EMPTY)
    {
        for (int n = 0; n < n_adx_members; n++)
        {
            ADXIndicator *it = m_iter[n];
            // dispatch to restoreState(), calcMain(), and storeState() for each
            it.updateVars(open, high, low, close, volume, initial_index, padding);
        }
        return ADXIndicator::updateVars(open, high, low, close, volume, initial_index, padding);
    }

    virtual int calcInitial(const int _extent, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
    {

        DEBUG("Calculating Initial Avg ADX wtihin %d", _extent);

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
            ADXIndicator *it = m_iter[n];
            const double weight = m_weights[n];
            if (first_idx == -1)
            {
                // the ADX for the furthest EMA period will be calculated first
                DEBUG("Calculating first ADX(%d, %d) [%d]", it.ema_period, it.ema_shift, _extent);
                first_idx = it.calcInitial(_extent, open, high, low, close, volume);
                it.storeState(first_idx);
                DEBUG("First index %d", first_idx);
            }
            else
            {
                DEBUG("Calculating secondary ADX(%d, %d) [%d]", it.ema_period, it.ema_shift, next_idx);
                next_idx = it.calcInitial(_extent, open, high, low, close, volume);
                for (int idx = next_idx - 1; idx >= first_idx; idx--)
                {
                    // fast-forward to the start for the ADX with furthest EMA period
                    DEBUG("Fast-forward for ADX(%d, %d) [%d]", it.ema_period, it.ema_shift, idx);
                    it.calcMain(idx, open, high, low, close, volume);
                }
                it.storeState(first_idx);
            }
            avg_atr += (it.atrState() * weight);
            avg_dx += (it.dxState() * weight);
            avg_plus_dm += (it.plusDmState() * weight);
            avg_minus_dm += (it.minusDmState() * weight);
            avg_plus_di += (it.plusDiState() * weight);
            avg_minus_di += (it.minusDiState() * weight);
        }
        fillState(_extent - 1, first_idx + 1);
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

    virtual void calcMain(const int idx, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
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
            ADXIndicator *it = m_iter[n];
            double weight = m_weights[n];
            /// not re-running calculations here.
            // Retrieving values calculated from it.updateVars()
            avg_atr += (it.atrAt(idx) * weight);
            avg_dx += (it.dxAt(idx) * weight);
            avg_plus_dm += (it.plusDmAt(idx) * weight);
            avg_minus_dm += (it.minusDmAt(idx) * weight);
            avg_plus_di += (it.plusDiAt(idx) * weight);
            avg_minus_di += (it.minusDiAt(idx) * weight);
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
