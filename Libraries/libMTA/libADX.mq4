// Average Directional Movement Index

#ifndef _LIBADX_MQ4
#define _LIBADX_MQ4 1

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#include "libATR.mq4"
#include "trend.mq4" // crossover & binding for ADX

#property library
#property strict

#ifndef ADX_LOCAL_BUFFER_COUNT
#define ADX_LOCAL_BUFFER_COUNT 9
#endif

/// @brief An Implementation of Welles Wilder's Average Directional Movement Index
class ADXData : public ATRData
{

protected:
    void initBuffers()
    {
        int start = ATRData::classBufferCount();
        dx_buffer = data_buffers.get(start++);
        plus_dm_data = data_buffers.get(start++);
        minus_dm_data = data_buffers.get(start++);
        plus_dm_lr = data_buffers.get(start++);
        minus_dm_lr = data_buffers.get(start++);
        plus_di_buffer = data_buffers.get(start++);
        minus_di_buffer = data_buffers.get(start++);
        xbuff = data_buffers.get(start++);
        rebuff = data_buffers.get(start++);
    };

    PriceXOver *adxover;
    datetime earlier_xover;
    datetime previous_xover;
    bool previous_xover_bearish;

    // trend-line crossover analysis for +DI, -DI
    bool checkCrossover(const int idx)
    {
        const int faridx = idx + 1;

        const double plus_di_pre = plus_di_buffer.get(faridx);
        if (plus_di_pre == EMPTY_VALUE)
        {
            xbuff.setState(DBLEMPTY);
            FDEBUG(DEBUG_CALC, ("xover - No +DI at " + offset_time_str(faridx)));
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
            xbuff.setState(DBLEMPTY);
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
        FDEBUG(DEBUG_CALC, ("Xover located to " + TimeToStr(cur_time)));
        return true;
    }

    // trend-line reveral analysis for the gaining trend line
    int checkReversal(const int idx)
    {
        /// Implementation Notes:
        //
        // - In order to detect immediate inter-crossover reversals
        //   before the next +DI/-DI crossover emerges, this will
        //   backtrack to the previous +DI/-DI crossover, after
        //   any intermediate crossover or when idx == 0
        //
        // - In this method's present implementation, only reversals
        //   in the gaining +DI/-DI rate will be analyzed here.
        //
        //   This is a known limitation.
        //
        //   It may suffice at least for prototyping

        const int previous_shift = iBarShift(symbol, timeframe, previous_xover);

        const datetime farthest_dt = (idx == 0 && previous_shift != 0) ? previous_xover : earlier_xover;

        if (farthest_dt == EMPTY_VALUE)
        {
            return 0;
        }

        double rate_far = DBLZERO;  // rate of the gaining trend line, before reversal
        double rate_mid = DBLZERO;  // rate of the gaining trend line, at reversal
        double rate_near = DBLZERO; // rate of the gaining trend line, after reversal

        double opp_far = DBLZERO;
        double opp_mid = DBLZERO;
        double opp_near = DBLZERO;

        double sum_gain = DBLZERO; // sum of the adjusted rates at reversal for the gaining trend line
        int n_gain = 0;            // number of reversals in the gaining trend line

        const int xover_shift = iBarShift(symbol, timeframe, farthest_dt);
        const double xover_rate = xbuff.get(xover_shift);
        const bool bearish = minus_di_buffer.get(xover_shift) > plus_di_buffer.get(xover_shift);

        if (xover_rate == EMPTY_VALUE)
        {
            const string which = farthest_dt == previous_xover ? "Previous" : "Earlier";
            FDEBUG(DEBUG_CALC, ("No crossover rate available at [%d] %s (%s Crossover)",
                                xover_shift,
                                offset_time_str(xover_shift, symbol, timeframe),
                                which));
            return 0;
        }

        FDEBUG(DEBUG_CALC, ("Detecting " + (bearish ? "-DI" : "+DI") + " reversals [" + TimeToStr(farthest_dt) + ", " + offset_time_str(idx) + "]"));

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
                opp_far = plus_di_buffer.get(far_predx);
                opp_mid = plus_di_buffer.get(mid_predx);
                opp_near = predx == idx ? plus_di_buffer.getState() : plus_di_buffer.get(predx);
            }
            else
            {
                rate_far = plus_di_buffer.get(far_predx);
                rate_mid = plus_di_buffer.get(mid_predx);
                rate_near = predx == idx ? plus_di_buffer.getState() : plus_di_buffer.get(predx);
                opp_far = minus_di_buffer.get(far_predx);
                opp_mid = minus_di_buffer.get(mid_predx);
                opp_near = predx == idx ? minus_di_buffer.getState() : minus_di_buffer.get(predx);
            }
            if (rate_far == EMPTY_VALUE || rate_mid == EMPTY_VALUE || rate_near == EMPTY_VALUE ||
                opp_far == EMPTY_VALUE || opp_mid == EMPTY_VALUE || opp_near == EMPTY_VALUE)
            {
                FDEBUG(DEBUG_CALC, ("Reversal detection not available at %d, %d, %d (%f, %f, %f) to " +
                                        offset_time_str(predx, symbol, timeframe),
                                    predx, mid_predx, far_predx,
                                    rate_near, rate_mid, rate_far));
                continue;
            }
            const double gain_diff = rate_mid - xover_rate;
            const double opp_diff = xover_rate - opp_mid;
            const double _xmid = opp_mid + ((gain_diff + opp_diff) / 2);
            xbuff.storeState(mid_predx, _xmid);
        }

        return n_gain;
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
            const int _price_mode = PRICE_CLOSE,
            const string _symbol = NULL,
            const int _timeframe = EMPTY,
            const bool _managed = true,
            const string _name = "ADX++",
            const int _nr_buffers = EMPTY,
            const int _data_shift = EMPTY) : earlier_xover(EMPTY_VALUE),
                                             previous_xover(EMPTY_VALUE),
                                             previous_xover_bearish(false),
                                             ATRData(period,
                                                     _price_mode,
                                                     false,
                                                     _symbol,
                                                     _timeframe,
                                                     _managed,
                                                     _name,
                                                     _data_shift,
                                                     _nr_buffers == EMPTY ? classBufferCount() : _nr_buffers)
    {
        initBuffers();
        adxover = new PriceXOver();
    };

    ~ADXData()
    {
        /// linked buffers will be deleted within the BufferMgr protocol
        dx_buffer = NULL;
        plus_dm_data = NULL;
        minus_dm_data = NULL;
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
    ValueBuffer<double> *dx_buffer;
    ValueBuffer<double> *plus_dm_data;
    ValueBuffer<double> *minus_dm_data;
    ValueBuffer<double> *plus_dm_lr;
    ValueBuffer<double> *minus_dm_lr;

    ValueBuffer<double> *plus_di_buffer;
    ValueBuffer<double> *minus_di_buffer;
    // data buffers for crossover and reversal analysis
    ValueBuffer<double> *xbuff;
    ValueBuffer<double> *rebuff;

    virtual int classBufferCount()
    {
        // return the number of buffers used directly for this indicator.
        // should be incremented internally, in derived classes
        return ATRData::classBufferCount() + ADX_LOCAL_BUFFER_COUNT;
    };

    virtual string indicator_name()
    {
        return StringFormat("%s(%d)", name, ma_period);
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
        return plus_dm_data.getState();
    };

    double plusDmAt(const int idx)
    {
        return plus_dm_data.get(idx);
    };

    double minusDmState()
    {
        return minus_dm_data.getState();
    };

    double minusDmAt(const int idx)
    {
        return minus_dm_data.get(idx);
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
    double plusDm(const int idx, MqlRates &rates[])
    {
        return rates[idx].high - rates[idx + 1].high;
    };

    // Calculate the -DI directional movement at a given index, using the time-series
    // high and low quote data.
    //
    // idx must be less than the length of the time-series data minus one.
    double minusDm(const int idx, MqlRates &rates[])
    {
        return rates[idx + 1].low - rates[idx].low;
    };

    bool bindPlusDIMax(PriceReversal &_revinfo, const int begin = 0, const int end = EMPTY, const double limit = DBL_MAX)
    {
        return _revinfo.bindMax(plus_di_buffer, this, begin, end, limit);
    }

    bool bindPlusDIMin(PriceReversal &_revinfo, const int begin = 0, const int end = EMPTY, const double limit = DBL_MIN)
    {
        return _revinfo.bindMin(plus_di_buffer, this, begin, end, limit);
    }

    bool bindMinusDIMax(PriceReversal &_revinfo, const int begin = 0, const int end = EMPTY, const double limit = DBL_MAX)
    {
        return _revinfo.bindMax(minus_di_buffer, this, begin, end, limit);
    }

    bool bindMinusDIMin(PriceReversal &_revinfo, const int begin = 0, const int end = EMPTY, const double limit = DBL_MIN)
    {
        return _revinfo.bindMin(minus_di_buffer, this, begin, end, limit);
    }

    virtual void calcDM(const int idx, MqlRates &rates[])
    {
        double sm_plus_dm = __dblzero__;
        double sm_minus_dm = __dblzero__;

        const double ma_period_dbl = (double)ma_period;
        double weights = __dblzero__;

        // using volume as a weighting factor for +DM/-DM moving average
        for (int offset = idx + ma_period - 1, p_k = 1; offset >= idx; offset--, p_k++)
        {
            const double mov_plus = plusDm(offset, rates);
            const double mov_minus = minusDm(offset, rates);
            /// geometric weighting, scaled on volume
            const double wfactor = weightFor(p_k, ma_period) * (double)rates[idx].tick_volume;

            // DEBUG("+DM %d %f", offset, mov_plus);
            // DEBUG("-DM %d %f", offset, mov_minus);

            if (mov_plus > 0 && mov_plus > mov_minus)
            {
                sm_plus_dm += (mov_plus * wfactor);
            }
            else if (mov_minus > 0 && mov_minus > mov_plus)
            {
                sm_minus_dm += (mov_minus * wfactor);
            }
            weights += wfactor;
        }

        sm_plus_dm /= weights;
        sm_minus_dm /= weights;

        FDEBUG(DEBUG_CALC, ("Unfactored +DM %f -DM %f", sm_plus_dm, sm_minus_dm));

        const double plus_dm_pre = plus_dm_data.getState();
        const double minus_dm_pre = minus_dm_data.getState();

        const double plus_dm_early = plus_dm_data.get(idx + 2);
        const double minus_dm_early = minus_dm_data.get(idx + 2);

        if (plus_dm_pre != EMPTY_VALUE)
        {
            sm_plus_dm = smoothed(ma_period, sm_plus_dm, sm_plus_dm, plus_dm_pre, plus_dm_early);
            sm_minus_dm = smoothed(ma_period, sm_minus_dm, sm_minus_dm, minus_dm_pre, minus_dm_early);
        }

        plus_dm_data.setState(sm_plus_dm);
        minus_dm_data.setState(sm_minus_dm);
    }

    virtual void calcDI(const int idx, MqlRates &rates[])
    {
        FDEBUG(DEBUG_CALC, (indicator_name() +
                                " Previous ATR at calcDx [%d] %s : %f",
                            idx, offset_time_str(idx),
                            atr_buffer.getState()));
        /// update ATR to current, from previously initialized ATR
        ///
        /// adaptation: ATR is calculated, here, using [...]
        ///
        /// altogether, this adaptation is wholly unusable at some periods, e.g. 9, 12
        ///
        ATRData::calcMain(idx, rates);
        double atr_cur = atr_buffer.getState();

        FDEBUG(DEBUG_CALC, (indicator_name() +
                                " Current ATR at calcDx [%d] %s : %f",
                            idx, offset_time_str(idx),
                            atr_cur));

        if (dblZero(atr_cur))
        {
            printf(indicator_name() + " zero initial ATR [%d] %s", idx, offset_time_str(idx));
            // error if reached
            return;
        }
        else if (atr_cur < 0)
        {
            printf(indicator_name() + " negative ATR %f [%d] %s", atr_cur, idx, offset_time_str(idx));
            // error if reached
            return;
        }

        calcDM(idx, rates);

        const double sm_plus_dm = plus_dm_data.getState();
        const double sm_minus_dm = minus_dm_data.getState();

        const double plus_di_pre = plus_di_buffer.getState();
        const double minus_di_pre = minus_di_buffer.getState();

        const double plus_di_early = plus_di_buffer.get(idx + 2);
        const double minus_di_early = minus_di_buffer.get(idx + 2);

        ///
        /// conventional plus_di / minus_di formula
        ///
        // double plus_di = (sm_plus_dm / atr_cur) * 100.0;
        // double minus_di = (sm_minus_dm / atr_cur) * 100.0;
        ///
        /// another way to scale +DI/-DI to a percentage
        ///
        const double plus_di = 100.0 - (100.0 / (1.0 + (sm_plus_dm / atr_cur)));
        const double minus_di = 100.0 - (100.0 / (1.0 + (sm_minus_dm / atr_cur)));

        const double sm_plus_di = plus_di_pre == EMPTY_VALUE ? plus_di : smoothed(ma_period, plus_di, plus_di, plus_di_pre, plus_di_early);
        const double sm_minus_di = minus_di_pre == EMPTY_VALUE ? minus_di : smoothed(ma_period, minus_di, minus_di, minus_di_pre, minus_di_early);

        if (dblZero(plus_di) && dblZero(minus_di))
        {
            FDEBUG(DEBUG_CALC, (indicator_name() +
                                " zero plus_di, minus_di at " +
                                offset_time_str(idx)));
        }

        plus_di_buffer.setState(sm_plus_di);
        minus_di_buffer.setState(sm_minus_di);
    }

    virtual void calcDx(const int idx, MqlRates &rates[])
    {

        calcDI(idx, rates);

        const double plus_di = plus_di_buffer.getState();
        const double minus_di = minus_di_buffer.getState();

        const double di_sum = plus_di + minus_di;
        if (dblZero(di_sum))
        {
            FDEBUG(DEBUG_CALC, (indicator_name() +
                                    " zero di sum at " +
                                    offset_time_str(idx)));
            dx_buffer.setState(__dblzero__);
        }
        else
        {
            //// original method of calculation
            // const double dx = fabs((plus_di - minus_di) / di_sum) * 100.0;
            /// alternately, a down-scaled representation for DX
            /// as factored from a percentage-scaled DI
            const double dx = 100.0 - (100.0 / (1.0 + fabs((plus_di - minus_di) / di_sum)));
            FDEBUG(DEBUG_CALC, (indicator_name() +
                                    " DX [%d] %s : %f",
                                idx, offset_time_str(idx),
                                dx));
            dx_buffer.setState(dx);
            // dx_buffer.setState(EMPTY_VALUE);
        }
    };

    // calculate the first ADX
    //
    // returns the index of the first ADX value within this time series.
    //
    virtual int calcInitial(const int _extent, MqlRates &rates[])
    {
        FDEBUG(DEBUG_PROGRAM, (indicator_name() +
                                   " Initial calcuation for ADX to %d",
                               _extent));

        int calc_idx = ATRData::calcInitial(_extent, rates);
        double atr_cur = atr_buffer.getState();

        if (atr_cur <= 0 || atr_cur == EMPTY_VALUE)
        {
            Print(indicator_name() + " Initial ATR calculation failed => %f", atr_cur);
            return EMPTY;
        }

        atr_buffer.storeState(calc_idx);

        FDEBUG(DEBUG_CALC, (indicator_name() +
                                " Initial ATR at %s [%d] %f",
                            offset_time_str(calc_idx), calc_idx,
                            atr_cur));

        //// pad by one for the initial ATR
        calc_idx--;

        plus_dm_data.setState(DBLEMPTY);
        minus_dm_data.setState(DBLEMPTY);
        FDEBUG(DEBUG_CALC, (indicator_name() + " Initial calcDX at %d %d", calc_idx));
        calcDx(calc_idx, rates); // calculate initial component values
        /// an equal +DI and -DI ???
        FDEBUG(DEBUG_CALC, (indicator_name() +
                                " Initial values: DX %f, +DI %f, -DI %f",
                            dx_buffer.getState(),
                            plus_di_buffer.getState(),
                            minus_di_buffer.getState()));
        xbuff.setState(DBLEMPTY);
        rebuff.setState(DBLEMPTY);
        return calc_idx;
    }

    // ADX calculation, as a function onto DX
    virtual void calcMain(const int idx, MqlRates &rates[])
    {
        /// store previous DX
        const double adx_pre = dx_buffer.getState();
        /// calculte current DX, to be stored by side effect along with +DM/+DM, +DI/-DI
        calcDx(idx, rates);
        /// ADX
        const double dx_cur = dx_buffer.getState();
        // NOTE: Nothing here is providing any EMA/WMA for +DI/-DI
        // ... considering the averaging in +DM/-DM

        /// forward-shifted EMA
        // const double adx = ((adx_pre * (double)ema_factor) + (dx_cur * (double)ema_shift)) / (double)ma_period;
        /// conventional EMA (forward-shift unused here)
        // const double adx = ema(adx_pre, dx_cur, ma_period);
        const double adx = dx_cur;

        FDEBUG(DEBUG_CALC, (indicator_name() +
                                " DX (%f, %f) => %f at %s [%d]",
                            adx_pre, dx_cur, adx,
                            offset_time_str(idx), idx));
        dx_buffer.setState(adx);

        ///
        /// Crossover Detection & Reversal Recording
        ///

        const bool _xover = checkCrossover(idx);
        const bool detect_reversal = (_xover || idx == 0);
        if (detect_reversal)
        {
            checkReversal(idx);
        }
    };

    virtual int initIndicator(const int index = 0)
    {
        const bool undrawn = (index != 0);
        if (!undrawn && !PriceIndicator::initIndicator())
        {
            printf("Initialization failed, PriceIndicator::initIndicator");
            return -1;
        }

        // bind all indicator data buffers for management in the MQL program
        int idx = index;
        if (!initBuffer(idx++, plus_di_buffer.data, undrawn ? NULL : "+DI"))
        {
            return -1;
        }
        if (!initBuffer(idx++, minus_di_buffer.data, undrawn ? NULL : "-DI"))
        {
            return -1;
        }
        if (!initBuffer(idx++, dx_buffer.data, undrawn ? NULL : "DX"))
        {
            return -1;
        }
        if (!initBuffer(idx++, xbuff.data, undrawn ? NULL : "XOver", undrawn ? DRAW_NONE : DRAW_SECTION))
        {
            return -1;
        }
        const bool draw_atr = (debugLevel(DEBUG_PROGRAM) && !undrawn);
        if (!initBuffer(idx++, atr_buffer.data,
                        draw_atr ? "DX ATR" : NULL,
                        draw_atr ? DRAW_LINE : DRAW_NONE,
                        draw_atr ? INDICATOR_DATA : INDICATOR_CALCULATIONS))
        {
            return -1;
        }

        // non-drawn buffers

        if (!initBuffer(idx++, plus_dm_data.data, NULL))
        {
            return -1;
        }
        if (!initBuffer(idx++, minus_dm_data.data, NULL))
        {
            return -1;
        }
        if (!initBuffer(idx++, rebuff.data, NULL))
        {
            return -1;
        }
        if (!initBuffer(idx++, plus_dm_lr.data, NULL))
        {
            return -1;
        }
        if (!initBuffer(idx++, minus_dm_lr.data, NULL))
        {
            return -1;
        }
        /// previously:
        // if (!initBuffer(idx++, rebuff.data, "Rev", DRAW_HISTOGRAM)) {
        //     return -1;
        // }
        return idx;
    };

    /// @brief Locate the nearest crossover of +DI/-DI indicator values, from nearest start index to furthest end index.
    virtual bool bind(PriceXOver &_xover, const int start = 0, const int end = EMPTY)
    {
        const int last = (end == EMPTY ? getExtent() : end);
        double xplus_near = DBLEMPTY;
        double xminus_near = DBLEMPTY;
        double xplus_far = plusDiAt(start);
        double xminus_far = minusDiAt(start);
        int xshift = EMPTY;
        bool bearish = false;
        for (int n = start + 1; n <= last; n++)
        {
            xplus_near = xplus_far;
            xminus_near = xminus_far;
            xplus_far = plusDiAt(n);
            xminus_far = minusDiAt(n);
            if ((xplus_near > xminus_near) && (xplus_far < xminus_far))
            {
                xshift = n;
                break;
            }
            else if ((xplus_near < xminus_near) && (xplus_far > xminus_far))
            {
                xshift = n;
                bearish = true;
                break;
            }
        }
        if (xshift == EMPTY)
        {
            return false;
        }
        /// this simple datetime factoring would assume that the indicator data
        /// is synchronized with current market rates
        const datetime near_dt = offset_time(xshift - 1, symbol, timeframe);
        const datetime far_dt = offset_time(xshift, symbol, timeframe);
        _xover.bind(bearish, xplus_near, xplus_far, xminus_near, xminus_far, near_dt, far_dt);

        return true;
    }

    /// @brief utility method for PriceXOver located with bind()
    /// @param xover the bound crossover object
    /// @return +DI at the chronologically more recent endpoint of crossover
    double xoverNearPlusDI(PriceXOver &_xover)
    {
        return _xover.nearVal();
    }

    /// @brief utility method for PriceXOver located with bind()
    /// @param xover the bound crossover object
    /// @return -DI at the chronologically more recent endpoint of crossover
    double xoverNearMinusDI(PriceXOver &_xover)
    {
        return _xover.nearValB();
    }

    /// @brief utility method for PriceXOver located with bind()
    /// @param xover the bound crossover object
    /// @return +DI at the chronologically earlier endpoint of crossover
    double xoverFarPlusDI(PriceXOver &_xover)
    {
        return _xover.farVal();
    }

    /// @brief utility method for PriceXOver located with bind()
    /// @param xover the bound crossover object
    /// @return -DI at the chronologically earlier endpoint of crossover
    double xoverFarMinusDI(PriceXOver &_xover)
    {
        return _xover.farValB();
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

    string getDisplayName()
    {
        string p = IntegerToString(m_iter[0].ma_period);
        for (int n = 1; n < n_adx_members; n++)
        {
            p += ("," + IntegerToString(m_iter[n].ma_period));
        }
        return name + "(" + p + ")";
    }

public:
    const int n_adx_members;

    const double total_weights;
    const int far_period;
    string display_name;

    ADXAvg(const int n_members,
           const int &periods[],
           const double &weights[],
           const int _price_mode = PRICE_CLOSE,
           const string _symbol = NULL,
           const int _timeframe = EMPTY,
           const bool _managed = true,
           const string _name = "ADXvg") : n_adx_members(n_members),
                                           total_weights(sum(n_members, weights)),
                                           far_period(max(n_members, periods)),
                                           display_name(NULL),
                                           ADXData(max(n_members, periods), _price_mode, _symbol, _timeframe, _managed, _name)
    {
        ArrayResize(m_iter, n_members);
        ArrayResize(m_weights, n_members);
        int add_idx;
        int last_per = 0;
        for (int idx = 0; idx < n_members; idx++)
        {
            const int per = periods[idx];
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
            ADXData *it = new ADXData(per, price_mode, _symbol, _timeframe, _managed, StringFormat("ADX.%d", idx));
            /// cannot, from here ... should not need to link the sub-indicator buffers :
            // const int nbuf = it.data_buffers.size();
            // for(int n = 0; n < nbuf; n++) {
            //     data_buffers.add(it.data_buffers.get(n));
            // }
            m_iter[add_idx] = it;
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

    string indicatorName()
    {
        if (display_name == NULL)
        {
            display_name = getDisplayName();
        }
        return display_name;
    }

    virtual int usedBufferCount()
    {
        return classBufferCount() * (1 + n_adx_members);
    }

    virtual int initIndicator(const int idx = 0)
    {
        // ensure all local buffers and all member buffers will be
        // registered as indicator buffers
        const int start = ADXData::initIndicator();
        if (start == -1)
        {
            Print(__FUNCTION__ + " Initialization failed in ADXData::initIndicator");
            return -1;
        }
        const int count = classBufferCount();
        IndicatorBuffers(count * (1 + n_adx_members));
        int next_offset = start;
        for (int n = 0; n < n_adx_members; n++)
        {
            ADXData *it = m_iter[n];
            FDEBUG(DEBUG_PROGRAM,
                   ("Initializing %s, initial buffer offset %d",
                    it.indicatorName(),
                    next_offset));
            const int retv = it.initIndicator(next_offset);
            if (retv == -1)
            {
                Print(__FUNCTION__ + " Failed to initialize component indicator " + it.indicatorName());
                return -1;
            }
            else
            {
                next_offset = retv;
            }
        }
        return next_offset;
    }

    // copy elements of the indicator member object array to some provided buffer
    int copyMembers(ADXData *&buffer[])
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

    virtual bool setExtent(const int len)
    {
        if (!ADXData::setExtent(len))
        {
            printf("Failed to storeState extent %d", len);
            return false;
        }
        for (int n = 0; n < n_adx_members; n++)
        {
            ADXData *it = m_iter[n];
            if (!it.setExtent(len))
            {
                printf("Failed to storeState %d extent %d", n, len);
                return false;
            }
        }
        return true;
    }

    virtual void restoreFrom(const int idx)
    {
        FDEBUG(DEBUG_CALC, (__FUNCTION__ + " (%d)", idx));
        ADXData::restoreFrom(idx);
        for (int n = 0; n < n_adx_members; n++)
        {
            FDEBUG(DEBUG_CALC, (__FUNCTION__ + " (%d) [%d]", idx, n));
            ADXData *it = m_iter[n];
            it.restoreFrom(idx);
        }
    };

    virtual void storeState(const int idx)
    {
        FDEBUG(DEBUG_CALC, (__FUNCTION__ + " (%d)", idx));
        ADXData::storeState(idx);
        for (int n = 0; n < n_adx_members; n++)
        {
            FDEBUG(DEBUG_CALC, (__FUNCTION__ + " (%d) [%d]", idx, n));
            ADXData *it = m_iter[n];
            it.storeState(idx);
        }
    };

    void readAvgState()
    {
        const int nbuf = classBufferCount();
        for (int n = 0; n < nbuf; n++)
        {
            double avg = DBLZERO;
            for (int m = 0; m < n_adx_members; m++)
            {
                ADXData *it = m_iter[m];
                const double weight = m_weights[m];
                const double val = it.getState(n);
                if (val == EMPTY_VALUE)
                {
                    continue;
                }
                avg += (weight * val);
            }
            ValueBuffer<double> *lbuf = data_buffers.get(n);
            const double mn = avg / total_weights;
            const double _mn = dblZero(mn) ? DBLEMPTY : mn;
            lbuf.setState(_mn);
        }
    }

    void readAvgAt(const int idx)
    {
        const int nbuf = classBufferCount();
        for (int n = 0; n < nbuf; n++)
        {
            double avg = DBLZERO;
            for (int m = 0; m < n_adx_members; m++)
            {
                ADXData *it = m_iter[m];
                const double weight = m_weights[m];
                const double val = it.getValue(n, idx);
                if (val == EMPTY_VALUE)
                {
                    continue;
                }
                avg += (weight * val);
            }
            ValueBuffer<double> *lbuf = data_buffers.get(n);
            const double mn = avg / total_weights;
            const double _mn = dblZero(mn) ? DBLEMPTY : mn;
            lbuf.setState(_mn);
        }
    }

    virtual int calcInitial(const int _extent, MqlRates &rates[])
    {

        FDEBUG(DEBUG_PROGRAM, ("Calculating Initial Avg ADX wtihin %d", _extent));

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
                FDEBUG(DEBUG_PROGRAM, ("Calculating first ADX(%d) [%d]", it.ma_period, _extent));
                first_idx = it.calcInitial(_extent, rates);
                it.storeState(first_idx);
                FDEBUG(DEBUG_PROGRAM, ("First index %d", first_idx));
            }
            else
            {
                FDEBUG(DEBUG_PROGRAM, ("Calculating secondary ADX(%d) [%d]", it.ma_period, next_idx));
                next_idx = it.calcInitial(_extent, rates);
                for (int idx = next_idx - 1; idx >= first_idx; idx--)
                {
                    // fast-forward to the start for the ADX with furthest EMA period
                    FDEBUG(DEBUG_PROGRAM, ("Fast-forward for ADX(%d) [%d]", it.ma_period, idx));
                    it.calcMain(idx, rates);
                }
                it.storeState(first_idx);
            }
        }
        readAvgState();
        return first_idx;
    };

    virtual void calcMain(const int idx, MqlRates &rates[])
    {
        FDEBUG(DEBUG_CALC, ("Binding Avg ADX EMA %d", idx));
        for (int n = 0; n < n_adx_members; n++)
        {
            ADXData *it = m_iter[n];
            it.calcMain(idx, rates);
            it.storeState(idx);
        }
        readAvgState();
    };
};

#endif
