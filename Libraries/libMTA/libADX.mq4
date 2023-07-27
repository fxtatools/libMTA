
#ifndef _LIBADX_MQ4
#define _LIBADX_MQ4 1

#include "libATR.mq4"
#include "rates.mq4"
#include "quotes.mq4"

class ADXIter : public ATRIter
{

protected:
    class ADXQuote
    {
    public:
        double atr_price; // generally used as an input value, current ATR
        double dx;        // output value for non-EMA DX, input and output value for EMA DX
        double plus_dm;   // internal state for +DM averaging (Wilder)
        double minus_dm;  // internal state for -DM averaging (Wilder)
        double plus_di;   // output value, indicator data
        double minus_di;  // output value, indicator data
        ADXQuote() : atr_price(-0.0), dx(-0.0), plus_dm(-0.0), minus_dm(-0.0), plus_di(-0.0), minus_di(-0.0){};
    };
    ADXQuote *adxq;

    class ADXBufferMgr : public ATRBufferMgr
    {
    public:
        // RateBuffer *atr_buffer; // similarly first_buffer, defined in base class
        RateBuffer *dx_buffer;
        RateBuffer *plus_dm_buffer;
        RateBuffer *minus_dm_buffer;
        RateBuffer *plus_di_buffer;
        RateBuffer *minus_di_buffer;

        ADXBufferMgr(const int extent = 0)  : ATRBufferMgr(extent)
        {
            
            // initialize local rate buffers,
            // storing a reference to each
            dx_buffer = new RateBuffer(extent, true, 4);
            // set pointers to locally created buffers
            plus_dm_buffer = dx_buffer.next();
            minus_dm_buffer = plus_dm_buffer.next();
            plus_di_buffer = minus_dm_buffer.next();
            minus_di_buffer = plus_di_buffer.next();
            RateBuffer *base_last = this.last_buffer();
            if (base_last == NULL) 
                printf("ADXBufferMgr failed to link to ATR buffers");
            else
                base_last.setNext(dx_buffer);            
        };

        ~ADXBufferMgr() 
        {   // base class destructor will delete all linked buffers
            //
            // clear references to local linked buffers            
            dx_buffer = NULL;
            plus_dm_buffer = NULL;
            minus_dm_buffer = NULL;
            plus_di_buffer = NULL;
            minus_di_buffer = NULL;
            dx_buffer = NULL;
        }

    };
    ADXBufferMgr *adx_buffer_mgr;

    ADXIter(string _symbol, int _timeframe) : ATRIter(_symbol, _timeframe)
    {
        adxq = new ADXQuote();
        adx_buffer_mgr = new ADXBufferMgr(0);
    }

public:
    // Implementation Notes:
    // - designed for application onto MT4 time-series data
    // - higher period shift => indicator will generally be more responsive
    //   to present market characteristics, even in event of a market rate spike
    // - period_shift should always be provided as < period
    ADXIter(int period, int period_shift = 1, const int _price_mode = PRICE_CLOSE, string _symbol = NULL, int _timeframe = EMPTY) : ATRIter(period, period_shift, _price_mode, _symbol, _timeframe)
    {
        adxq = new ADXQuote();
        adx_buffer_mgr = new ADXBufferMgr(0);
    };

    ~ADXIter()
    {
        FREEPTR(adxq);
        FREEPTR(adx_buffer_mgr);
    };

    bool setExtent(const int extent, const int padding = EMPTY) {
        return adx_buffer_mgr.setExtent(extent, padding);
    };

    bool reduceExtent(const int extent, const int padding = EMPTY) {
        return adx_buffer_mgr.reduceExtent(extent, padding);
    };

    double bound_atr_price()
    {
        // external adxq 'out' accessor for iterators
        return adxq.atr_price;
    }

    double bound_dx()
    {
        return adxq.dx;
    }

    double bound_plus_dm()
    {
        return adxq.plus_dm;
    }

    double bound_minus_dm()
    {
        return adxq.minus_dm;
    }

    double bound_plus_di()
    {
        return adxq.plus_di;
    }

    double bound_minus_di()
    {
        return adxq.minus_di;
    }

    RateBuffer *atr_buffer() { return adx_buffer_mgr.atr_buffer; };
    RateBuffer *dx_buffer() { return adx_buffer_mgr.dx_buffer; };
    RateBuffer *plus_dm_buffer() { return adx_buffer_mgr.plus_dm_buffer; };
    RateBuffer *minus_dm_buffer() { return adx_buffer_mgr.minus_dm_buffer; };
    RateBuffer *plus_di_buffer() { return adx_buffer_mgr.plus_di_buffer; };
    RateBuffer *minus_di_buffer() { return adx_buffer_mgr.minus_di_buffer; };

    // Initlaize the ADXQuote adxq for the previous ATR and previous DX at an arbitrary
    // data index
    void prepare_next_pass(const double atr_price, const double dx, const double plus_dm, const double minus_dm)
    {
        // set the current ATR and previous DX
        //
        // called generally before any first iterating call to bind_adx_ema()
        //
        // this is a convenience method. iterators should update adxq.atr_price
        // internally, after the initial previous-quote seed data.
        adxq.atr_price = atr_price;
        adxq.dx = dx;
        adxq.plus_dm = plus_dm;
        adxq.minus_dm = minus_dm;
    };

    // Calculate the +DI directional movement at a given index, using the time-series
    // high and low quote data.
    //
    // idx must be less than the length of the time-series data minus one.
    double plus_dm_movement(const int idx, const double &high[], const double &low[])
    {
        return high[idx] - high[idx + 1];
    };

    // Calculate the -DI directional movement at a given index, using the time-series
    // high and low quote data.
    //
    // idx must be less than the length of the time-series data minus one.
    double minus_dm_movement(const int idx, const double &high[], const double &low[])
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
    virtual void bind_adx_quote(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
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

        const double ema_period_dbl = (double) ema_period;
        double plus_dm_wt = __dblzero__;
        double minus_dm_wt = __dblzero__;

        DEBUG("(%d, %d) ATR at bind_adx_quote [%d] %s : %f", ema_period, ema_shift, idx, offset_time_str(idx), atr_cur);

        if (dblZero(atr_cur))
        {
            printf("zero initial ATR [%d] %s", idx, offset_time_str(idx));
        }
        else if (atr_cur < 0)
        {
            printf("negative ATR [%d] %s", idx, offset_time_str(idx));
        }

        for (int offset = idx + ema_period, p_k = 1; offset >= idx; offset--, p_k++)
        {
            const double mov_plus = plus_dm_movement(offset, high, low);
            const double mov_minus = minus_dm_movement(offset, high, low);
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

        const double plus_dm_prev = adxq.plus_dm;
        const double minus_dm_prev = adxq.minus_dm;

        //// Wilder, cf. p. 48
        //// Pruitt, G. (2016). Stochastics and Averages and RSI! Oh, My.
        ////   In The Ultimate Algorithmic Trading System Toolbox + Website (pp. 25–76).
        ////   John Wiley & Sons, Inc. https://doi.org/10.1002/9781119262992.ch2
        ////
        //// also https://www.investopedia.com/terms/a/adx.asp
        ////
        /* */
        /*
        
        if (plus_dm_prev != DBL_MIN)
            sm_plus_dm = plus_dm_prev - (plus_dm_prev / (double) ema_period) + sm_plus_dm;
        if (minus_dm_prev != DBL_MIN)
            sm_minus_dm = minus_dm_prev - (minus_dm_prev / (double) ema_period) + sm_minus_dm;
       adxq.plus_dm = sm_plus_dm;
       adxq.minus_dm = sm_minus_dm;
        */
        /* */

        /// alternately: DM for DI as forward-shifted EMA of the current weighted MA of +DM / -DM
        /* */
        const double ema_shifted_dbl = (double) ema_shifted_period;
        const double ema_shift_dbl = (double) ema_shift;
        if(plus_dm_prev != DBL_MIN)
            sm_plus_dm = ((plus_dm_prev * ema_shifted_dbl) + (sm_plus_dm * ema_shift_dbl)) / ema_period_dbl;
        if(minus_dm_prev != DBL_MIN) 
            sm_minus_dm = ((minus_dm_prev * ema_shifted_dbl) + (sm_minus_dm * ema_shift_dbl)) / ema_period_dbl;
        adxq.plus_dm = sm_plus_dm; 
        adxq.minus_dm = sm_minus_dm;

       /* */
       /// alternately: just use DM within period
       
       
        //// conventional plus_di / minus_di
        // const double plus_di = (sm_plus_dm / atr_cur) * 100.0;
        // const double minus_di = (sm_minus_dm / atr_cur)  * 100.0;
        //
        //// not used anywhere in reference for common ADX +DI/-DI calculation,
        //// this reliably converts it to a percentage however.
        const double plus_di = 100.0 - (100.0 / (1.0 + (sm_plus_dm / atr_cur)));
        const double minus_di = 100.0 - (100.0 / (1.0 + (sm_minus_dm / atr_cur)));

        if (dblZero(plus_di) && dblZero(minus_di))
        {
            DEBUG("zero plus_di, minus_di at " + offset_time_str(idx));
        }

        adxq.plus_di = plus_di;
        adxq.minus_di = minus_di;
        const double di_sum = plus_di + minus_di;
        if (dblZero(di_sum))
        {
            DEBUG("calculated zero di sum at " + offset_time_str(idx));
            adxq.dx = __dblzero__;
        }
        else
        {
            // adxq.dx = fabs((plus_di - minus_di) / di_sum) * 100.0;
            /// alternately, a down-scaled representation for DX factored from DI:
            adxq.dx =  100.0 - (100.0 / (1.0 + fabs((plus_di - minus_di) / di_sum)));
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
    virtual int bind_initial_adx(int extent, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        double next_atr = initial_atr_price(--extent, open, high, low, close);

        extent -= ema_period; // for initial ATR
        if (next_atr == 0)
        {
            Alert(StringFormat("%s %d (%d, %d): Initial ATR calculation failed => 0",
                               symbol, timeframe, ema_period, ema_shift));
            return EMPTY;
        }
        // atr_data[extent] = next_atr;
        DEBUG("(%d, %d) Initial ATR at %s [%d] %f", ema_period, ema_shift, offset_time_str(extent), extent, next_atr);

        extent--; // for ADX DM at start of ema_period
        next_atr = next_atr_price(extent, next_atr, open, high, low, close);

        DEBUG("(%d, %d) Second ATR at %s [%d] %f", ema_period, ema_shift, offset_time_str(extent), extent, next_atr);
        adxq.atr_price = next_atr;
        adxq.plus_dm = DBL_MIN;
        adxq.minus_dm = DBL_MIN;
        // atr_data[extent] = next_atr;
        bind_adx_quote(extent, open, high, low, close); // ?
        return extent;
    }

    // Bind current ATR, +DI, +DI, and DX EMA at index idx to fields of adxq
    //
    // This method assumes adxq was initialized for previous ATR and DX values
    //
    // See also:
    // - bind_initial_adx()
    virtual void bind_adx_ema(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        /// Implementation Note: EMA smothing for +DI/-DI at this point
        /// may produce a side effect of complicating any visual analysis
        /// of ADX chart lines, insofar as for locating a +DI/-DI crossover
        /// point.
        ///
        /// +DI/-DI values will already be smoothed accross each calculation
        /// period, before calculating DX within bind_adx_quote()
        ///
        /// This method provides EMA smoothing only for the DX value
        ///

        /// reusing previous DX from adxq, before the call to bind_adx_quote
        const double dx = adxq.dx;
        // const double plus_di = adxq.plus_di;
        // const double minus_di = adxq.minus_di;
        // set current ATR, using previous
        const double atr_prev = adxq.atr_price;
        adxq.atr_price = next_atr_price(idx, atr_prev, open, high, low, close);

        /// binding current to adxq
        bind_adx_quote(idx, open, high, low, close);

        /// binding DX EMA to adxq
        adxq.dx = ((dx * (double)ema_shifted_period) + (adxq.dx * (double)ema_shift)) / (double)ema_period;
    };

    // Set current ATR, +DM, -DM, +DI, -DI,  and DX at index idx, to local data buffers
    //
    // This method assumes adxq was initialized for previous data values
    //
    // See also:
    // - bind_initial_adx()
    virtual void update_adx_ema(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        // calculate ADX +DI, -DI, and EMA for DX
        bind_adx_ema(idx, open, high, low, close);
        DEBUG("[%d] DX %f DI +/- %f/%f", idx, adxq.dx, adxq.plus_di, adxq.minus_di);
        // bind adxq values to internal data buffers
        adx_buffer_mgr.dx_buffer.data[idx] = adxq.dx;
        adx_buffer_mgr.plus_dm_buffer.data[idx] = adxq.plus_dm;
        adx_buffer_mgr.minus_dm_buffer.data[idx] = adxq.minus_dm;
        adx_buffer_mgr.plus_di_buffer.data[idx] = adxq.plus_di;
        adx_buffer_mgr.minus_di_buffer.data[idx] = adxq.minus_di;
        adx_buffer_mgr.atr_buffer.data[idx] = adxq.atr_price;
    };

    // Initialize local ADX data arrays for ADX from extent to latest == 0
    //
    // This method assumes time-series data access for all data arrays.
    virtual datetime initialize_adx_data(int extent, const double &open[], const double &high[], const double &low[], const double &close[], const int extent_padding = EMPTY)
    {
        const int __latest__ = 0;
        int idx = bind_initial_adx(extent, open, high, low, close);
        adx_buffer_mgr.setExtent(extent, extent_padding);

        double next_atr = adxq.atr_price;
        adx_buffer_mgr.dx_buffer.data[idx] = adxq.dx;
        adx_buffer_mgr.plus_dm_buffer.data[idx] = adxq.plus_dm;
        adx_buffer_mgr.minus_dm_buffer.data[idx] = adxq.minus_dm;
        adx_buffer_mgr.plus_di_buffer.data[idx] = adxq.plus_di;
        adx_buffer_mgr.minus_di_buffer.data[idx] = adxq.minus_di;
        adx_buffer_mgr.atr_buffer.data[idx] = next_atr;

        DEBUG("Initial ADX at %s [%d] DX %f +DI %f -DI %f", offset_time_str(idx), idx, adxq.dx, adxq.plus_di, adxq.minus_di);

        idx--; // for the first ADX quote

        while (idx >= __latest__)
        {
            update_adx_ema(idx, open, high, low, close);
            idx--;
        }
        latest_quote_dt = iTime(symbol, timeframe, __latest__);
        return latest_quote_dt;
    };
    
    // Initialize the provided ADX data arrays for ADX from extent to latest == 0
    //
    // This method uses a Quote Manager for access to chart high, low, and close quotes.
    // This assumes that the Quote Manager was initialized for time-series data access
    // with high, low, and close rate buffers.
    virtual datetime initialize_adx_data(QuoteMgrOHLC &quote_mgr, const int extent = EMPTY)
    {
        // for data initialization within EAs
        const int nrquotes = extent == EMPTY ? iBars(symbol, timeframe) : extent;
        DEBUG("Initializing for quote manager with %d quotes", nrquotes);
        if (!quote_mgr.copyRates(nrquotes))
        {
            printf("Failed to copy %d initial rates to quote manager", nrquotes);
            return EMPTY;
        }
        return initialize_adx_data(nrquotes, quote_mgr.open_buffer.data, quote_mgr.high_buffer.data, quote_mgr.low_buffer.data, quote_mgr.close_buffer.data);
    }

    // Update the provided ADX data arrays from the most recently calculated extent
    // to latest == 0
    //
    // This method assumes time-series data access for all data arrays.
    virtual datetime update_adx_data(const double &open[], const double &high[], const double &low[], const double &close[], const int extent = EMPTY, const int padding = EMPTY)
    {
        if (extent != EMPTY)
        {
            adx_buffer_mgr.setExtent(extent, padding);
        }

        // plus one, plus two to ensure the previous ADX is recalculated from final market quote,
        // when the previous ADX was calculated at offset 0 => 1
        int idx = latest_quote_offset() + 1;
        const int prev_idx = idx + 1;
        const int __latest__ = 0;

        const double prev_atr = adx_buffer_mgr.atr_buffer.data[prev_idx];
        const double prev_dx = adx_buffer_mgr.dx_buffer.data[prev_idx];
        const double prev_plus_dm = adx_buffer_mgr.plus_dm_buffer.data[prev_idx];
        const double prev_minus_dm = adx_buffer_mgr.minus_dm_buffer.data[prev_idx];
        // prev_atr here should be the same across ticks
        // for the same initial chart offset 0, before
        // it advances 0 => 1 in effective offset
        DEBUG("updating from %s [%d] initial ATR %f DX %f", offset_time_str(prev_idx), prev_idx, prev_atr, prev_dx);
        prepare_next_pass(prev_atr, prev_dx, prev_plus_dm, prev_minus_dm);

        while (idx >= __latest__)
        {
            update_adx_ema(idx, open, high, low, close);
            idx--;
        }
        latest_quote_dt = iTime(symbol, timeframe, __latest__);
        return latest_quote_dt;
    };

    // Update the provided ADX data arrays from the most recently calculated extent
    // to latest == 0
    //
    // This method uses a Quote Manager for access to chart high, low, and close quotes.
    // This assumes that the Quote Manager was initialized for time-series data access
    // with high, low, and close rate buffers.
 
    virtual datetime update_adx_data(QuoteMgrOHLC &quote_mgr, const int _extent = EMPTY, const int _padding = EMPTY)
    {
        return update_adx_data(quote_mgr.open_buffer.data, quote_mgr.high_buffer.data, quote_mgr.low_buffer.data, quote_mgr.close_buffer.data, _extent, _padding);
    };
};

class ADXAvgBuffer : public ADXIter
{

protected:
    ADXIter *m_iter[];
    double m_weights[];

public:
    int n_adx_members;

    double total_weights;
    int longest_period;

    ADXAvgBuffer(const int n_members, const int &periods[], const int &period_shifts[], const double &weights[], const string _symbol = NULL, const int _timeframe = EMPTY) : n_adx_members(n_members), ADXIter(_symbol, _timeframe)
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
    int copy_iterators(ADXIter *&buffer[])
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
    int copy_weights(double &buffer[])
    {
        if (ArrayIsDynamic(buffer) && ArraySize(buffer) < n_adx_members)
            ArrayResize(buffer, n_adx_members);
        for (int n = 0; n < n_adx_members; n++)
        {
            buffer[n] = m_weights[n];
        }
        return n_adx_members;
    };

    virtual int bind_initial_adx(int extent, const double &open[], const double &high[], const double &low[], const double &close[])
    {

        DEBUG("Calculating Initial Avg ADX for %d", extent);

        int first_extent = -1;
        int next_extent;
        double avg_atr = __dblzero__;
        double avg_dx = __dblzero__;
        double avg_plus_di = __dblzero__;
        double avg_minus_di = __dblzero__;
        for (int n = 0; n < n_adx_members; n++)
        {
            ADXIter *it = m_iter[n];
            double weight = m_weights[n];
            if (first_extent == -1)
            {
                first_extent = it.bind_initial_adx(extent, open, high, low, close);
            }
            else
            {
                next_extent = it.bind_initial_adx(extent, open, high, low, close);
                for (int idx = next_extent; idx <= first_extent; idx++)
                {
                    // fast-forward to the start for the ADX with longest period
                    it.bind_adx_ema(idx, open, high, low, close);
                }
            }
            avg_atr += (it.bound_atr_price() * weight);
            avg_dx += (it.bound_dx() * weight);
            avg_plus_di += (it.bound_plus_di() * weight);
            avg_minus_di += (it.bound_minus_di() * weight);
        }
        avg_atr /= total_weights;
        avg_dx /= total_weights;
        avg_plus_di /= total_weights;
        avg_minus_di /= total_weights;
        adxq.atr_price = avg_atr;
        adxq.dx = avg_dx;
        adxq.plus_di = avg_plus_di;
        adxq.minus_di = avg_minus_di;
        return first_extent;
    }

    virtual void bind_adx_ema(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        DEBUG("Binding Avg ADX EMA %d", idx);
        double avg_atr = __dblzero__;
        double avg_dx = __dblzero__;
        double avg_plus_di = __dblzero__;
        double avg_minus_di = __dblzero__;
        for (int n = 0; n < n_adx_members; n++)
        {
            ADXIter *it = m_iter[n];
            double weight = m_weights[n];
            it.bind_adx_ema(idx, open, high, low, close);
            avg_atr += (it.bound_atr_price() * weight);
            avg_dx += (it.bound_dx() * weight);
            avg_plus_di += (it.bound_plus_di() * weight);
            avg_minus_di += (it.bound_minus_di() * weight);
        }
        avg_atr /= total_weights;
        avg_dx /= total_weights;
        avg_plus_di /= total_weights;
        avg_minus_di /= total_weights;
        adxq.atr_price = avg_atr;
        adxq.dx = avg_dx;
        adxq.plus_di = avg_plus_di;
        adxq.minus_di = avg_minus_di;
    }
};


#endif
