
#ifndef _LIBADX_MQ4
#define _LIBADX_MQ4 1

#include "libATR.mq4"
#include "trend.mq4" // crossover & binding for ADX

#property library
#property strict

/// @brief Average Directional Movement Index
class ADXData : public ATRData
{

protected:
    // a generalized constructor for application under ADXAvg,
    // which uses no single EMA period
    ADXData(const int _price_mode,
            const string _symbol = NULL,
            const int _timeframe = EMPTY,
            const string _name = "ADX++") : earlier_xover(EMPTY_VALUE),
                                            previous_xover(EMPTY_VALUE),
                                            previous_xover_bearish(false),
                                            ATRData(_price_mode,
                                                    _symbol,
                                                    _timeframe,
                                                    _name,
                                                    7)
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
        xbuff = minus_di_buffer.next();
        rebuff = xbuff.next();
    };

    PriceXOver *adxover;
    datetime earlier_xover;
    datetime previous_xover;
    bool previous_xover_bearish;

    bool recordCrossover(const int idx)
    {

        ///
        /// Crossover Detection
        ///

        const int faridx = idx + 1;

        const double plus_di_pre = plus_di_buffer.get(faridx);
        if (plus_di_pre == EMPTY_VALUE)
        {
            xbuff.setState(EMPTY_VALUE);
            DEBUG("xover - No +DI at " + offset_time_str(faridx));
            return false;
        }
        const double plus_di_cur = plus_di_buffer.getState();
        const double minus_di_pre = minus_di_buffer.get(faridx);
        const double minus_di_cur = minus_di_buffer.getState();
        bool bearish = false;

        if ((plus_di_pre > minus_di_pre) && (plus_di_cur < minus_di_cur))
        {
            bearish = true;
        }
        else if (!((minus_di_pre > plus_di_pre) && (minus_di_cur < plus_di_cur)))
        {
            xbuff.setState(EMPTY_VALUE);
            return false;
        }
        const datetime pre_time = offset_time(faridx, symbol, timeframe);
        const datetime cur_time = offset_time(idx, symbol, timeframe);
        earlier_xover = previous_xover;
        previous_xover = cur_time;
        previous_xover_bearish = bearish;
        adxover.bind(bearish, plus_di_cur, plus_di_pre, minus_di_cur, minus_di_pre, cur_time, pre_time);
        const double xr = adxover.rate();
        xbuff.setState(xr);
        DEBUG("Xover located to " + TimeToStr(cur_time));
        return true;
    }

public:
    // Implementation Notes:
    // - designed for application onto MT4 time-series data
    // - higher period shift => indicator will generally be more responsive
    //   to present market characteristics, even in event of a market rate spike,
    //   though likewise more erratic over durations
    // - period_shift should always be provided as < period
    // - for a conventional EMA behavior, provide period_shift = 1
    ADXData(const int period,
            const int period_shift = 1,
            const int _price_mode = PRICE_CLOSE,
            const string _symbol = NULL,
            const int _timeframe = EMPTY,
            const string _name = "ADX++",
            const int _nr_buffers = 8,
            const int _data_shift = EMPTY) : earlier_xover(EMPTY_VALUE),
                                             previous_xover(EMPTY_VALUE),
                                             previous_xover_bearish(false),
                                             ATRData(period,
                                                     period_shift,
                                                     _price_mode,
                                                     false,
                                                     _symbol,
                                                     _timeframe,
                                                     _name,
                                                     _data_shift,
                                                     _nr_buffers)
    {
        initBuffers(atr_buffer);
        adxover = new PriceXOver();
    };

    ~ADXData()
    {
        /// linked buffers will be deleted within the BufferMgr protocol
        dx_buffer = NULL;
        plus_dm_buffer = NULL;
        minus_dm_buffer = NULL;
        plus_di_buffer = NULL;
        minus_di_buffer = NULL;
        xbuff = NULL;
        rebuff = NULL;
        FREEPTR(adxover);
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
    // data buffers for crossover and reversal analysis
    PriceBuffer *xbuff;
    PriceBuffer *rebuff;

    virtual int dataBufferCount() const
    {
        // return the number of buffers used directly for this indicator.
        // should be incremented internally, in derived classes
        return ATRData::dataBufferCount() + 7;
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

    double chg(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
    {
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
        ATRData::calcMain(idx, open, high, low, close, volume);
        double atr_cur = atr_buffer.getState();

        double sm_plus_dm = __dblzero__;
        double sm_minus_dm = __dblzero__;

        const double ema_period_dbl = (double)ema_period;
        double weights = __dblzero__;

        DEBUG(indicator_name() + " Current ATR at calcDx [%d] %s : %f", idx, offset_time_str(idx), atr_cur);

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

        // TBD: Partial/Modified Hull MA for DM (not presently applied)
        //
        // Hull Moving Average: https://alanhull.com/hull-moving-average
        // simplified
        // https://school.stockcharts.com/doku.php?id=technical_indicators:hull_moving_average
        //
        // - may be modified as in using the local period shift in lieu of both the
        //   2 * short factor and (TO DO) as the period for the prevailing MA
        // - this would use one iteration for calculating both the short and primary MA
        // - as yet, no additional MA over the sum of short and primary
        //
        /// period for the prevailing MA
        // const int p_sqrt = ema_shift; // (int)sqrt(ema_period);
        ///
        const int p_short = ema_shift; // (int)(ema_period/2);
        double weights_short = DBLZERO;
        double sm_plus_short = DBLZERO;
        double sm_minus_short = DBLZERO;

        // - using volume as a weighting factor for +DM/-DM Linear WMA
        for (int offset = idx + ema_period - 1, p_k = 1; offset >= idx; offset--, p_k++)
        {
            const double mov_plus = plusDm(offset, high, low);
            const double mov_minus = minusDm(offset, high, low);
            const double wfactor = ((double)p_k / ema_period_dbl) * (double)volume[idx];

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

        /// Linear WMA
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

        /// alternately: DM for DI as forward-shifted EMA
        //               of the current weighted MA of +DM / -DM
        /// - smoothed moving average
        /// - +DI/-DI reversals may be the most significant here
        const double ema_shifted_dbl = (double)ema_shifted_period;
        const double ema_shift_dbl = (double)ema_shift;
        if (plus_dm_prev != DBL_MIN)
            sm_plus_dm = ((plus_dm_prev * ema_shifted_dbl) + (sm_plus_dm * ema_shift_dbl)) / ema_period_dbl;
        if (minus_dm_prev != DBL_MIN)
            sm_minus_dm = ((minus_dm_prev * ema_shifted_dbl) + (sm_minus_dm * ema_shift_dbl)) / ema_period_dbl;


        /// standard ema (forward-shift unused here)
        /*
        if (plus_dm_prev != DBL_MIN)
            sm_plus_dm = ema(plus_dm_prev, sm_plus_dm, ema_period);
        if (minus_dm_prev != DBL_MIN)
            sm_minus_dm = ema(minus_dm_prev, sm_minus_dm, ema_period);
        */

        /*
        */

        //// or simpler weighted MA, cf. RVI
        // if (plus_dm_prev != DBL_MIN)
        //     sm_plus_dm = (plus_dm_prev + (2.0 * sm_plus_dm)) / 3.0;
        // if (minus_dm_prev != DBL_MIN)
        //     sm_minus_dm = (minus_dm_prev + (2.0 * sm_minus_dm)) / 3.0;

        plus_dm_buffer.setState(sm_plus_dm);
        minus_dm_buffer.setState(sm_minus_dm);

        /* */
        /// alternately: just use DM within period

        //// conventional plus_di / minus_di
        // double plus_di = (sm_plus_dm / atr_cur) * 100.0;
        // double minus_di = (sm_minus_dm / atr_cur) * 100.0;
        //
        //// another way to scale +DI/-DI to a percentage
        const double plus_di = 100.0 - (100.0 / (1.0 + (sm_plus_dm / atr_cur)));
        const double minus_di = 100.0 - (100.0 / (1.0 + (sm_minus_dm / atr_cur)));

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
            /// original method of calculation
            // const double dx = fabs((plus_di - minus_di) / di_sum) * 100.0;
            /// skpping DX for now
            const double dx = EMPTY_VALUE;
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
        DEBUG(indicator_name() + " Initial calcuation for ADX to %d", _extent);

        int calc_idx = ATRData::calcInitial(_extent, open, high, low, close, volume);
        double atr_cur = atr_buffer.getState();

        if (atr_cur == 0 || atr_cur == EMPTY_VALUE)
        {
            Print(indicator_name() + " Initial ATR calculation failed => %f", atr_cur);
            return EMPTY;
        }

        DEBUG(indicator_name() + " Initial ATR at %s [%d] %f", offset_time_str(calc_idx), calc_idx, atr_cur);

        //// pad by one for the initial ATR
        calc_idx--;

        plus_dm_buffer.setState(DBL_MIN);
        minus_dm_buffer.setState(DBL_MIN);
        DEBUG(indicator_name() + " Initial calcDX at %d %d", calc_idx);
        calcDx(calc_idx, open, high, low, close, volume); // initial component values
        xbuff.setState(EMPTY_VALUE);
        rebuff.setState(EMPTY_VALUE);
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

        ///
        /// Crossover Detection & Reversal Recording
        ///

        const bool xover = recordCrossover(idx);
        const bool detect_reversal = (xover || idx == 0);
        if (!detect_reversal)
        {
            return;
        }

        /// Implementation Notes:
        //
        // - In order to detect immediate inter-crossover reversals
        //   before the next +DI/-DI crossover emerges, this will
        //   backtrack to the previous +DI/-DI crossover, after
        //   any intermediate crossover or when idx == 0
        //
        // - In this method's present implementation, only reversals
        //   in the prevailing +DI/-DI rate will be analyzed here.
        //   This is a known limitation.
        //   It may suffice at least for prototyping

        const int previous_shift = iBarShift(symbol, timeframe, previous_xover);

        const datetime farthest_dt = (idx == 0 && previous_shift != 0) ? previous_xover : earlier_xover;

        if (farthest_dt == EMPTY_VALUE)
        {
            return;
        }

        double rate_far = DBLZERO;  // rate of the gaining trend line, before reversal
        double rate_mid = DBLZERO;  // rate of the gaining trend line, at reversal
        double rate_near = DBLZERO; // rate of the gaining trend line, after reversal
        double rate_opp = DBLZERO;  // rate of the opposing trend line, at reversal

        double sum_gain = DBLZERO; // sum of the adjusted rates at reversal for the gaining trend line
        int n_gain = 0;            // number of reversals in the gaining trend line

        const int xover_shift = iBarShift(symbol, timeframe, farthest_dt);
        const double xover_rate = xbuff.get(xover_shift);
        const bool bearish = minus_di_buffer.get(xover_shift) > plus_di_buffer.get(xover_shift);

        DEBUG("Detecting " + (bearish ? "-DI" : "+DI") + " reversals [" + TimeToStr(farthest_dt) + ", " + offset_time_str(idx) + "]"); // DEBUG

        for (int far_predx = xover_shift; far_predx > idx; far_predx--)
        {
            const int mid_predx = far_predx - 1;
            if (mid_predx == idx)
            {
                break;
            }
            const int predx = mid_predx - 1;

            // DEBUG("rev detect far %d, mid %d, near %d", far_predx, mid_predx, predx);
            if (bearish)
            {
                rate_far = minus_di_buffer.get(far_predx);
                rate_mid = minus_di_buffer.get(mid_predx);
                rate_near = predx == idx ? minus_di_buffer.getState() : minus_di_buffer.get(predx);
                rate_opp = plus_di_buffer.get(mid_predx);
            }
            else
            {
                rate_far = plus_di_buffer.get(far_predx);
                rate_mid = plus_di_buffer.get(mid_predx);
                rate_near = predx == idx ? plus_di_buffer.getState() : plus_di_buffer.get(predx);
                rate_opp = minus_di_buffer.get(mid_predx);
            }
            if (rate_far == EMPTY_VALUE || rate_mid == EMPTY_VALUE || rate_near == EMPTY_VALUE)
            {
                DEBUG("Reversal detection not available at %d, %d, %d (%f, %f, %f) to " + offset_time_str(predx, symbol, timeframe), predx, mid_predx, far_predx, rate_near, rate_mid, rate_far); // DEBUG
                continue;
            }
            DEBUG("%f, %f, %f to " + offset_time_str(predx, symbol, timeframe), rate_far, rate_mid, rate_near);
            if (rate_far <= rate_mid && rate_mid >= rate_near)
            // ^ because operator overloading (??) this expression did not evaluate
            // as expected in MT4, with simply the following:
            //  rate_far <= rate_mid >= rate_near
            {
                // weighting for most recent, in the stored value for the rate reversal
                const double gain_rate = (rate_far + (2.0 * rate_mid) + (3.0 * rate_near)) / 6;
                // rebuff.set(mid_predx, gain_rate);
                const double gain_diff = gain_rate - xover_rate;
                const double opp_diff = 2.0 * (xover_rate - rate_opp); // weighted?
                //// geometric sum of the gain-xover difference and weighted xover-opposing difference
                const double adj_rate = sqrt(pow(gain_diff, 2) + pow(opp_diff, 2));
                const double signum = bearish ? -1.0 : 1.0;
                const double p = signum * adj_rate;

                rebuff.set(predx, EMPTY_VALUE);
                //// temporarily deactivated, while evaluating MA methods for ADX
                // rebuff.set(mid_predx, p); 
                rebuff.set(far_predx, EMPTY_VALUE);
                DEBUG((bearish ? "-DI" : "+DI") + " Reversal detected at " + offset_time_str(mid_predx));
                n_gain++;      // FIXME apply
                sum_gain += p; // FIXME apply
            }
        }
    };

    virtual void initIndicator()
    {
        // if !
        PriceIndicator::initIndicator();
        // return

        // bind all drawn and undrawn buffers to the indicator
        int idx = 0;
        SetIndexBuffer(idx, plus_di_buffer.data);
        SetIndexLabel(idx, "+DI");
        SetIndexStyle(idx++, DRAW_LINE);

        SetIndexBuffer(idx, minus_di_buffer.data);
        SetIndexLabel(idx, "-DI");
        SetIndexStyle(idx++, DRAW_LINE);

        SetIndexBuffer(idx, dx_buffer.data);
        SetIndexLabel(idx, "DX");
        SetIndexStyle(idx++, DRAW_LINE);

        const bool draw_atr = debug;
        // const bool draw_atr = true;
        SetIndexBuffer(idx, atr_buffer.data, draw_atr ? INDICATOR_DATA : INDICATOR_CALCULATIONS);
        SetIndexLabel(idx, draw_atr ? "DX ATR" : NULL);
        SetIndexStyle(idx++, draw_atr ? DRAW_LINE : DRAW_NONE);

        SetIndexBuffer(idx, xbuff.data);
        SetIndexLabel(idx, "XR"); // rate at crossover
        SetIndexStyle(idx++, DRAW_SECTION);

        SetIndexBuffer(idx, rebuff.data);
        SetIndexLabel(idx, "Rev"); // adjusted rate at reversal
        SetIndexStyle(idx++, DRAW_SECTION);

        // non-drawn buffers

        SetIndexBuffer(idx, plus_dm_buffer.data, INDICATOR_CALCULATIONS);
        SetIndexLabel(idx, NULL);
        SetIndexStyle(idx++, DRAW_NONE);

        SetIndexBuffer(idx, minus_dm_buffer.data, INDICATOR_CALCULATIONS);
        SetIndexLabel(idx, NULL);
        SetIndexStyle(idx++, DRAW_NONE);
    };

    /// @brief Locate the nearest crossover of +DI/-DI indicator values, from nearest start index to furthest end index.
    ///
    /// @par Usage
    /// If a crossover of +DI/-DI indicator values is found within the specified index range, the xover object
    /// will be initialized with PriceXOver 'A' values representing the +DI indicator line and 'B' values representing
    /// the -DI indicator line. As a convenience, xoverFarPlusDI() and similar methods may be used for
    /// accessing these values from the initialized crossover.
    ///
    /// @par
    /// After analsysis, the xover.clear() method may be used to reset all configured values.
    ///
    /// @par Notes - Analysis
    /// It should be noted that a +DI/-DI crossover may not represent the most significant event within
    /// a trend indicated with +DI/-DI. Typically, a single <u>+DI/-DI reversal</u> chronologically previous
    /// to a point of crossover may indicate the earlier beginning of an immediate market trend.
    ///
    /// @par
    /// Within a duration between two chronologically subsequent +DI/-DI crossovers, when more than one
    /// +DI/-DI reversal occurs within the duration, the +DI/-DI reversal at the point of greatest relative
    /// +DI/-DI value may represent the begining of the general trend for that +DI or -DI line within that
    /// time period - respectively, of a bearish or bullish trend at immediate scale.
    ///
    /// @param xover [inout] PriceXOver object for storing the crossover data
    /// @param start [in] chronologically most recent index for time-series analysis, 0 for current.
    /// @param end [in] chronologically earliest index for time-series analysis.
    ///        EMPTY to use the total number of indicator rates at time of call.
    /// @return true if a crossover was found within the index range. Otherwise,  false.
    virtual bool bind(PriceXOver &xover, const int start = 0, const int end = EMPTY)
    {
        const bool found = xover.bind(plus_di_buffer.data, minus_di_buffer.data, this, start, end);
        if (found)
        {
            // bearish crossover when further +DI > further -DI
            xover.setBearish(xover.farVal() > xover.farValB());
            return true;
        }
        else
        {
            return false;
        }
    }

    /// @brief utility method for PriceXOver located with bind()
    /// @param xover the bound crossover object
    /// @return +DI at the chronologically more recent endpoint of crossover
    double xoverNearPlusDI(PriceXOver &xover)
    {
        return xover.nearVal();
    }

    /// @brief utility method for PriceXOver located with bind()
    /// @param xover the bound crossover object
    /// @return -DI at the chronologically more recent endpoint of crossover
    double xoverNearMinusDI(PriceXOver &xover)
    {
        return xover.nearValB();
    }

    /// @brief utility method for PriceXOver located with bind()
    /// @param xover the bound crossover object
    /// @return +DI at the chronologically earlier endpoint of crossover
    double xoverFarPlusDI(PriceXOver &xover)
    {
        return xover.farVal();
    }

    /// @brief utility method for PriceXOver located with bind()
    /// @param xover the bound crossover object
    /// @return -DI at the chronologically earlier endpoint of crossover
    double xoverFarMinusDI(PriceXOver &xover)
    {
        return xover.farValB();
    }
};

class ADXAvg : public ADXData
{
protected:
    ADXData *m_iter[];
    double m_weights[];

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
           const string _name = "ADXvg") : n_adx_members(n_members), total_weights(sum(n_members, weights)), longest_period(max(n_members, periods)), ADXData(_price_mode, _symbol, _timeframe, _name)

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
            m_iter[add_idx] = new ADXData(per, shift, price_mode, _symbol, _timeframe);
            m_weights[add_idx] = weight;
            last_per = per;
        }
    }
    ~ADXAvg()
    {
        for (int n = 0; n < n_adx_members; n++)
        {
            ADXData *it = m_iter[n];
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
        // effects towards calculations during indicator update.
        // This may represent a side effect of pointer shift or other
        // update method performed within the MT4 implementation, for
        // indicator buffers.
        //
        ADXData::initIndicator();
        const int count = dataBufferCount();
        IndicatorBuffers(count * (1 + n_adx_members));
        int next_offset = count;
        for (int n = 0; n < n_adx_members; n++)
        {
            ADXData *it = m_iter[n];
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

    // copy elements of the indicator member object array to some provided buffer
    int copyMember(ADXData *&buffer[])
    {
        if (ArrayIsDynamic(buffer) && ArraySize(buffer) < n_adx_members)
            ArrayResize(buffer, n_adx_members);
        for (int n = 0; n < n_adx_members; n++)
        {
            buffer[n] = m_iter[n];
        }
        return n_adx_members;
    };

    // copy elements of the indicator weights array to some provided buffer
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
            ADXData *it = m_iter[n];
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
            ADXData *it = m_iter[n];
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
            ADXData *it = m_iter[n];
            it.restoreState(idx);
        }
    };

    virtual datetime updateVars(const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[], const int initial_index = EMPTY, const int padding = EMPTY)
    {
        for (int n = 0; n < n_adx_members; n++)
        {
            ADXData *it = m_iter[n];
            // dispatch to restoreState(), calcMain(), and storeState() for each
            it.updateVars(open, high, low, close, volume, initial_index, padding);
        }
        return ADXData::updateVars(open, high, low, close, volume, initial_index, padding);
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
            ADXData *it = m_iter[n];
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
            ADXData *it = m_iter[n];
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
