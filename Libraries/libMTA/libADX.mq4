
#ifndef _LIBADX_MQ4
#define _LIBADX_MQ4 1

#include "libATR.mq4"
#include "rates.mq4"

// Quote Manager constants
#define QUOTE_TIME 1
#define QUOTE_OPEN (1 << 1)
#define QUOTE_HIGH (1 << 2)
#define QUOTE_LOW (1 << 3)
#define QUOTE_CLOSE (1 << 4)
#define QUOTE_VOLUME (1 << 5) // cf. CopyTickVolume

class QuoteMgrOHLC : public Chartable
{

public:
    RateBuffer *open_buffer;
    RateBuffer *high_buffer;
    RateBuffer *low_buffer;
    RateBuffer *close_buffer;
    int extent;

    ~QuoteMgrOHLC()
    {
        if (open_buffer != NULL)
            delete open_buffer;
        if (high_buffer != NULL)
            delete high_buffer;
        if (low_buffer != NULL)
            delete low_buffer;
        if (close_buffer != NULL)
            delete close_buffer;
    };

    QuoteMgrOHLC(const int _extent, const int quote_kind, const bool as_series = true, const string _symbol = NULL, const int _timeframe = EMPTY) : extent(_extent), Chartable(_symbol, _timeframe)
    {
        if ((quote_kind & QUOTE_OPEN) != 0)
        {
            open_buffer = new RateBuffer(_extent);
            if (open_buffer.extent == -1 || !open_buffer.setAsSeries(as_series))
            {
                open_buffer = NULL; // FIXME error
            }
        }
        else
            open_buffer = NULL;

        if ((quote_kind & QUOTE_HIGH) != 0)
        {
            high_buffer = new RateBuffer(_extent);
            if (high_buffer.extent == -1 || !high_buffer.setAsSeries(as_series))
            {
                high_buffer = NULL; // FIXME error
            }
        }
        else
            high_buffer = NULL;

        if ((quote_kind & QUOTE_LOW) != 0)
        {
            low_buffer = new RateBuffer(_extent);
            if (low_buffer.extent == -1 || !low_buffer.setAsSeries(as_series))
            {
                low_buffer = NULL; // FIXME error
            }
        }
        else
            low_buffer = NULL;

        if ((quote_kind & QUOTE_CLOSE) != 0)
        {
            close_buffer = new RateBuffer(_extent);
            if (close_buffer.extent == -1 || !close_buffer.setAsSeries(as_series))
            {
                close_buffer = NULL; // FIXME error
            }
        }
        else
            close_buffer = NULL;
    };

    bool setExtent(int _extent)
    {
        if (open_buffer != NULL)
        {
            if (!open_buffer.setExtent(_extent))
                return false;
        }
        if (high_buffer != NULL)
        {
            if (!high_buffer.setExtent(_extent))
                return false;
        }
        if (low_buffer != NULL)
        {
            if (!low_buffer.setExtent(_extent))
                return false;
        }
        if (close_buffer != NULL)
        {
            if (!close_buffer.setExtent(_extent))
                return false;
        }
        extent = _extent;
        return true;
    };

    bool reduceExtent(int len)
    {
        if (open_buffer != NULL)
        {
            if (!open_buffer.reduceExtent(len))
                return false;
        }
        if (high_buffer != NULL)
        {
            if (!high_buffer.reduceExtent(len))
                return false;
        }
        if (low_buffer != NULL)
        {
            if (!low_buffer.reduceExtent(len))
                return false;
        }
        if (close_buffer != NULL)
        {
            if (!close_buffer.reduceExtent(len))
                return false;
        }
        extent = len;
        return true;
    }

    // copy rates to the provided extent for this Quote Manager, for any initialized
    // open, high, low, and close buffers
    bool copyRates(const int _extent)
    {
        if (!setExtent(_extent))
            return false;
        if (open_buffer != NULL)
        {
            int rslt = CopyOpen(symbol, timeframe, 0, _extent, open_buffer.data);
            if (rslt == -1)
                return false;
        }
        if (high_buffer != NULL)
        {
            int rslt = CopyHigh(symbol, timeframe, 0, _extent, high_buffer.data);
            if (rslt == -1)
                return false;
        }
        if (low_buffer != NULL)
        {
            int rslt = CopyLow(symbol, timeframe, 0, _extent, low_buffer.data);
            if (rslt == -1)
                return false;
        }
        if (close_buffer != NULL)
        {
            int rslt = CopyClose(symbol, timeframe, 0, _extent, close_buffer.data);
            if (rslt == -1)
                return false;
        }
        return true;
    };
};

class QuoteMgrHLC : public QuoteMgrOHLC
{
    // FIXME move to :Include/libEA/rates.mq4
public:
    QuoteMgrHLC(const int _extent, const string _symbol = NULL, const int _timeframe = EMPTY) : QuoteMgrOHLC(_extent, QUOTE_HIGH | QUOTE_LOW | QUOTE_CLOSE, true, _symbol, _timeframe){};
};

class ADXIter : public ATRIter
{

protected:
    class ADXQuote
    {
    public:
        double atr_price; // generally used as an input value, current ATR
        double dx;        // output value for non-EMA DX, input and output value for EMA DX
        double plus_di;   // output value
        double minus_di;  // output value
        ADXQuote() : atr_price(-0.0), dx(-0.0), plus_di(-0.0), minus_di(-0.0){};
    };
    ADXQuote *adxq;

    ADXIter(string _symbol, int _timeframe): ATRIter(_symbol, _timeframe) {
        adxq = new ADXQuote(); // TBD for ADXAvgBuffer
    }

public:
    // Implementation Notes:
    // - designed for application onto MT4 time-series data
    // - higher period shift => indicator will generally be more responsive
    //   to present market characteristics, even in event of a market rate spike
    // - period_shift should always be provided as < period
    ADXIter(int period, int period_shift = 1, string _symbol = NULL, int _timeframe = EMPTY) : ATRIter(period, period_shift, _symbol, _timeframe)
    {
        adxq = new ADXQuote();
    };

    ~ADXIter()
    {
        delete adxq;
    };

    double bound_atr_price() {
        // external adxq 'out' accessor for iterators
        return adxq.atr_price;
    }

    double bound_dx() {
        return adxq.dx;
    }
    
    double bound_plus_di() {
        return adxq.plus_di;
    }
    
    double bound_minus_di() {
        return adxq.minus_di;
    }
    
    // Initlaize the ADXQuote adxq for the previous ATR and previous DX at an arbitrary
    // data index
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
        for (int offset = idx + ema_period; offset >= idx; offset--)
        {
            const double mov_plus = plus_dm_movement(offset, high, low);
            const double mov_minus = minus_dm_movement(offset, high, low);

            if(mov_plus > 0 && mov_plus > mov_minus) {
                sm_plus_dm += mov_plus;
            } else if(mov_minus > 0 && mov_minus > mov_plus) {
                sm_minus_dm += mov_minus;
            }
        }

        //// ^ results in very large values for +DI/-DI
        /// or ...
        // sm_plus_dm = sm_plus_dm - (sm_plus_dm / ema_period) + plus_dm;
        // sm_minus_dm = sm_minus_dm - (sm_minus_dm / ema_period) + minus_dm;
        sm_plus_dm /= ema_period;
        sm_minus_dm /= ema_period;
        /// FIXME sometimes may result in +DI / -DI greater than 100

        // const double plus_di = (sm_plus_dm / atr_cur) * 100;
        // const double minus_di = (sm_minus_dm / atr_cur)  * 100;
        const double plus_di = 100 - (100 / (1 + (sm_plus_dm / atr_cur)));
        const double minus_di = 100 - (100 / (1 + (sm_minus_dm / atr_cur)));

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
            adxq.dx = fabs((plus_di - minus_di) / di_sum) * 100;
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
    virtual int bind_initial_adx(int extent, const double &high[], const double &low[], const double &close[])
    {
        double next_atr = initial_atr_price(--extent, high, low, close);

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
        next_atr = next_atr_price(extent, next_atr, high, low, close);

        DEBUG("(%d, %d) Second ATR at %s [%d] %f", ema_period, ema_shift, offset_time_str(extent), extent, next_atr);
        adxq.atr_price = next_atr;
        // atr_data[extent] = next_atr;
        bind_adx_quote(extent, high, low, close);
        return extent;
    }

    // Bind current ATR, +DI, +DI, and DX EMA at index idx to fields of adxq
    //
    // This method assumes adxq was initialized for previous ATR and DX values
    //
    // See also:
    // - bind_initial_adx()
    virtual void bind_adx_ema(const int idx, const double &high[], const double &low[], const double &close[])
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
        adxq.atr_price = next_atr_price(idx, atr_prev, high, low, close);

        /// binding current to adxq
        bind_adx_quote(idx, high, low, close);
        /// binding DX EMA to adxq
        adxq.dx = ((dx * ema_shifted_period) + (adxq.dx * ema_shift)) / ema_period;
    };

    // Set current +DI, -DI, and DX EMA at index idx, for that index within the provided
    // ADX data buffers.
    //
    // This method assumes adxq was initialized for previous ATR and DX values
    //
    // See also:
    // - bind_initial_adx()
    virtual void update_adx_ema(const int idx, double &atr_data[], double &dx[], double &plus_di[], double &minus_di[], const double &high[], const double &low[], const double &close[])
    {
        // calculate ADX +DI, -DI, and EMA for DX
        bind_adx_ema(idx, high, low, close);
        DEBUG("[%d] DX %f DI +/- %f/%f", idx, adxq.dx, adxq.plus_di, adxq.minus_di);
        // bind adxq values to data buffers
        dx[idx] = adxq.dx;
        plus_di[idx] = adxq.plus_di;
        minus_di[idx] = adxq.minus_di;
        atr_data[idx] = adxq.atr_price;
    };

    // Initialize the provided ADX data arrays for ADX from extent to latest == 0
    //
    // This method assumes time-series data access for all data arrays.
    virtual datetime initialize_adx_data(int extent, double &atr_data[], double &dx[], double &plus_di[], double &minus_di[], const double &high[], const double &low[], const double &close[])
    {
        const int __latest__ = 0;
        extent = bind_initial_adx(extent, high, low, close);

        double next_atr = adxq.atr_price;
        atr_data[extent] = next_atr;
        dx[extent] = adxq.dx;
        plus_di[extent] = adxq.plus_di;
        minus_di[extent] = adxq.minus_di;
        DEBUG("Initial ADX at %s [%d] DX %f +DI %f -DI %f", offset_time_str(extent), extent, adxq.dx, adxq.plus_di, adxq.minus_di);

        extent--; // for the first ADX quote

        while (extent >= __latest__)
        {
            update_adx_ema(extent, atr_data, dx, plus_di, minus_di, high, low, close);
            extent--;
        }
        latest_quote_dt = iTime(symbol, timeframe, __latest__);
        return latest_quote_dt;
    };

    // Initialize the provided ADX data arrays for ADX from extent to latest == 0
    //
    // This method uses a Quote Manager for access to chart high, low, and close quotes.
    // This assumes that the Quote Manager was initialized for time-series data access
    // with high, low, and close rate buffers.
    virtual datetime initialize_adx_data(QuoteMgrOHLC &quote_mgr, double &atr_data[], double &dx[], double &plus_di[], double &minus_di[], const int extent = EMPTY)
    {
        // for data initialization within EAs
        const int nrquotes = extent == EMPTY ? iBars(symbol, timeframe) : extent;
        DEBUG("Initializing for quote manager with %d quotes", nrquotes);
        if (!quote_mgr.copyRates(nrquotes))
        {
            printf("Failed to copy %d initial rates to quote manager", nrquotes);
            return EMPTY;
        }
        return initialize_adx_data(nrquotes, atr_data, dx, plus_di, minus_di, quote_mgr.high_buffer.data, quote_mgr.low_buffer.data, quote_mgr.close_buffer.data);
    }

    // Update the provided ADX data arrays from the most recently calculated extent
    // to latest == 0
    //
    // This method assumes time-series data access for all data arrays.
    virtual datetime update_adx_data(double &atr_data[], double &dx[], double &plus_di[], double &minus_di[], const double &high[], const double &low[], const double &close[])
    {
        // plus one, plus two to ensure the previous ADX is recalculated from final market quote,
        // when the previous ADX was calculated at offset 0 => 1
        int idx = latest_quote_offset() + 1;
        const int prev_idx = idx + 1;
        const int __latest__ = 0;

        const double prev_atr = atr_data[prev_idx];
        const double prev_dx = dx[prev_idx];
        // prev_atr here should be the same across ticks
        // for the same initial chart offset 0, before
        // it advances 0 => 1 in effective offset
        DEBUG("updating from %s [%d] initial ATR %f DX %f", offset_time_str(prev_idx), prev_idx, prev_atr, prev_dx);
        prepare_next_pass(prev_atr, prev_dx);

        while (idx >= __latest__)
        {
            update_adx_ema(idx, atr_data, dx, plus_di, minus_di, high, low, close);
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
    virtual datetime update_adx_data(QuoteMgrOHLC &quote_mgr, double &atr_data[], double &dx[], double &plus_di[], double &minus_di[])
    {
        // for data update within EAs
        const int extent = latest_quote_offset() + ema_period + 3;
        DEBUG("Updating for %d quotes", extent);
        if (!quote_mgr.copyRates(extent))
        {
            printf("Failed to copy %d rates to quote manager", extent);
            return EMPTY;
        }
        return update_adx_data(atr_data, dx, plus_di, minus_di, quote_mgr.high_buffer.data, quote_mgr.low_buffer.data, quote_mgr.close_buffer.data);
    };
};

// Iterator for ADX indicator data, providing internal data storage
class ADXBuffer : public ADXIter
{

protected:
    void init_buffers() {
        atr_buffer = new RateBuffer();
        dx_buffer = new RateBuffer();
        plus_di_buffer = new RateBuffer();
        minus_di_buffer = new RateBuffer();
    }

    ADXBuffer(string _symbol, int _timeframe): ADXIter(_symbol, _timeframe) {
        init_buffers();
    }

public:
    RateBuffer *atr_buffer;
    RateBuffer *dx_buffer;
    RateBuffer *plus_di_buffer;
    RateBuffer *minus_di_buffer;

    ADXBuffer(int period, int period_shift = 1, string _symbol = NULL, int _timeframe = EMPTY) : ADXIter(period, period_shift, _symbol, _timeframe)
    {
        init_buffers();
    };

    ~ADXBuffer()
    {
        delete atr_buffer;
        delete dx_buffer;
        delete plus_di_buffer;
        delete minus_di_buffer;
    };

    // increase the length of the indicator data buffers
    bool setExtent(int extent)
    {
        if (!atr_buffer.setExtent(extent))
            return false;
        if (!dx_buffer.setExtent(extent))
            return false;
        if (!plus_di_buffer.setExtent(extent))
            return false;
        if (!minus_di_buffer.setExtent(extent))
            return false;
        return true;
    };

    // reduce the length of the indicator data buffers
    bool reduceExtent(int extent)
    {
        if (!atr_buffer.reduceExtent(extent))
            return false;
        if (!dx_buffer.reduceExtent(extent))
            return false;
        if (!plus_di_buffer.reduceExtent(extent))
            return false;
        if (!minus_di_buffer.reduceExtent(extent))
            return false;
        return true;
    };

    // Initialize the indicator data buffers with high, low, close quotes via a time-series
    // Quote Manager
    virtual datetime initialize_adx_data(QuoteMgrOHLC &quote_mgr, const int extent = EMPTY)
    {
        setExtent(extent == EMPTY ? iBars(symbol, timeframe) : extent);
        return initialize_adx_data(quote_mgr, atr_buffer.data, dx_buffer.data, plus_di_buffer.data, minus_di_buffer.data, extent);
    };

    // Initialize the indicator data buffers from time-series high, low, and close quotes
    virtual datetime initialize_adx_data(const int extent, const double &high[], const double &low[], const double &close[])
    {
        setExtent(extent);
        return initialize_adx_data(extent, atr_buffer.data, dx_buffer.data, plus_di_buffer.data, minus_di_buffer.data, high, low, close);
    };

    // Update the indicator data buffers with a time-series Quote Manager
    virtual datetime update_adx_data(QuoteMgrOHLC &quote_mgr)
    {
        setExtent(quote_mgr.extent);
        return update_adx_data(quote_mgr, atr_buffer.data, dx_buffer.data, plus_di_buffer.data, minus_di_buffer.data);
    };

    // Update the indicator data buffers from time-series high, low, and close quotes
   virtual datetime update_adx_data(const double &high[], const double &low[], const double &close[], const int extent = EMPTY)
    {
        setExtent(extent == EMPTY ? ArraySize(high) : extent);
        return update_adx_data(atr_buffer.data, dx_buffer.data, plus_di_buffer.data, minus_di_buffer.data, high, low, close);
    };
};


class ADXAvgBuffer : public ADXBuffer
{

protected:
    ADXIter *m_iter[];
    double m_weights[];

public:
    int n_adx_members;

    double total_weights;
    int longest_period;


    ADXAvgBuffer(const int n_members, const int &periods[], const int &period_shifts[], const double &weights[], const string _symbol = NULL, const int _timeframe = EMPTY) : n_adx_members(n_members), ADXBuffer(_symbol, _timeframe)
    {

        ArrayResize(m_iter, n_adx_members);
        ArrayResize(m_weights, n_adx_members);
        int add_idx;
        int last_per = 0;
        int longest_per = 0;
        for (int idx = 0; idx < n_members; idx++) {
            const int per = periods[idx];
            const int shift = period_shifts[idx];
            const double weight = weights[idx];
            total_weights += weight;
            if (per > last_per) {
                for(int n = idx; n> 0; n--) {
                    // shift all iterators & weights forward by one
                    const int nminus = n - 1;
                    m_iter[n] = m_iter[nminus];
                    m_weights[n] = m_weights[nminus];
                }
                add_idx = 0;
                if(per > longest_per) {
                    longest_per = per;
                }
            } else {
                add_idx = idx;
            }
            m_iter[add_idx] = new ADXIter(per, shift, _symbol, _timeframe);
            m_weights[add_idx] = weight;
            last_per = per;
        }
        longest_period = longest_per;
    }
    ~ADXAvgBuffer()
    {
        for(int n = 0; n < n_adx_members; n++) {
            ADXIter *it = m_iter[n];
            m_iter[n] = NULL;
            delete it;
        }
        ArrayFree(m_iter);
        ArrayFree(m_weights);
    }

    // copy elements of the m_iter array to some provided buffer
    int copy_iterators(ADXIter *&buffer[]) {
        if(ArrayIsDynamic(buffer) && ArraySize(buffer) < n_adx_members) 
            ArrayResize(buffer, n_adx_members);
        for(int n = 0; n < n_adx_members; n++) {
            buffer[n] = m_iter[n];
        }
        return n_adx_members;
    };

    // copy elements of the m_weights array to some provided buffer
    int copy_weights(double &buffer[]) {
        if(ArrayIsDynamic(buffer) && ArraySize(buffer) < n_adx_members) 
            ArrayResize(buffer, n_adx_members);
        for(int n = 0; n < n_adx_members; n++) {
            buffer[n] = m_weights[n];
        }
        return n_adx_members;
    };

    virtual int bind_initial_adx(int extent, const double &high[], const double &low[], const double &close[]) {

        int first_extent = -1;
        int next_extent;
        double avg_atr = __dblzero__;
        double avg_dx = __dblzero__;
        double avg_plus_di = __dblzero__;
        double avg_minus_di = __dblzero__;
        for(int n = 0; n < n_adx_members; n++) {
            ADXIter *it = m_iter[n];
            double weight = m_weights[n];
            if(first_extent == -1) {
                first_extent = it.bind_initial_adx(extent, high, low, close);
            } else {
                next_extent = it.bind_initial_adx(extent, high, low, close);
                for(int idx = next_extent; idx <= first_extent; idx++) {
                    // fast-forward to the start for the ADX with longest period
                    it.bind_adx_ema(idx, high, low, close);
                }
            }
            avg_atr+=(it.bound_atr_price() * weight);
            avg_dx+=(it.bound_dx() * weight);
            avg_plus_di+=(it.bound_plus_di() * weight);
            avg_minus_di+=(it.bound_minus_di() * weight);
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

    virtual void bind_adx_ema(const int idx, const double &high[], const double &low[], const double &close[]) {
        DEBUG("Binding Avg ADX EMA %d", idx); 
        double avg_atr = __dblzero__;
        double avg_dx = __dblzero__;
        double avg_plus_di = __dblzero__;
        double avg_minus_di = __dblzero__;
        for(int n = 0; n < n_adx_members; n++) {
            ADXIter *it = m_iter[n];
            double weight = m_weights[n];
            it.bind_adx_ema(idx, high, low, close);
            avg_atr+=(it.bound_atr_price() * weight);
            avg_dx+=(it.bound_dx() * weight);
            avg_plus_di+=(it.bound_plus_di() * weight);
            avg_minus_di+=(it.bound_minus_di() * weight);
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
