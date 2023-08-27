// True Strength Indicator, adaptation

#ifndef _LIBTSI_MQ4
#define _LIBTSI_MQ4 1

#include "indicator.mq4"
#include "trend.mq4"

#property library
#property strict

/// @brief Adaptation of William Blau's True Strength Index
///
/// @par References
///
/// Kaufman, P. J. (2013). Momentum and Oscillators. In Trading Systems
///    and Methods (5th ed.). Wiley. 404-405
///
class TSIData : public PriceIndicator
{
protected:
    ValueBuffer<double> *tsi_data;

public:
    const int r_period;
    const int s_period;
    const int price_mode;

    TSIData(const int r = 10,
            const int s = 6,
            const int _price_mode = PRICE_TYPICAL,
            const string _symbol = NULL,
            const int _timeframe = NULL,
            const bool _managed = true,
            const string _name = "TSI",
            const int _nr_buffers = EMPTY,
            const int _data_shift = EMPTY) : r_period(r),
                                             s_period(s),
                                             price_mode(_price_mode),
                                             PriceIndicator(_managed, _name,
                                                            _nr_buffers == EMPTY ? classBufferCount() : _nr_buffers,
                                                            _symbol, _timeframe,
                                                            _data_shift == EMPTY ? (r + s + 1) : data_shift)
    {
        tsi_data = data_buffers.get(0);
        // tsi_rev = data_buffers.get(1);
    };
    ~TSIData()
    {
        FREEPTR(tsi_data);
        // FREEPTR(tsi_rev);
    }

    int classBufferCount()
    {
        return 1;
    }

    virtual string indicatorName()
    {
        return StringFormat("%s(%d, %d)", name, r_period, s_period);
    }

    double tsiAt(const int idx)
    {
        return tsi_data.get(idx);
    }

    void bindMax(PriceReversal &_revinfo, const int begin = 0, const int end = EMPTY, const double limit = DBL_MAX)
    {
        //_revinfo.bindMax(tsi_data, this, begin, end, limit == DBL_MAX ? DBLZERO : limit);
        _revinfo.bindMax(tsi_data, this, begin, end, limit);
    }

    void bindMin(PriceReversal &_revinfo, const int begin = 0, const int end = EMPTY, const double limit = DBL_MIN)
    {
        // _revinfo.bindMin(tsi_data, this, begin, end, limit == DBL_MIN ? DBLZERO : limit);
        _revinfo.bindMin(tsi_data, this, begin, end, limit);
    }

    void calcMain(const int idx, MqlRates &rates[])
    {
        // the method of averaging applied in the Ultimate Oscillator
        // may be more generally more effective

        DEBUG("Updating [%d]", idx);

        double s_ma = DBLZERO;
        double s_abs_ma = DBLZERO;
        double s_weights = DBLZERO;
        for (int n_s = idx + s_period - 1, f_s = 1; n_s >= idx; n_s--, f_s++)
        {
            DEBUG("MA for TSI S [%d]", n_s);
            /// geometric weighting with volume, in series S
            const double wfactor_s = weightFor(f_s, s_period) * (double)rates[n_s].tick_volume;

            double r_sum = DBLZERO;
            double r_abs_sum = DBLZERO;
            double r_weights = DBLZERO;
            for (int n_r = n_s + r_period - 1, f_r = 1; n_r >= n_s; n_r--, f_r++)
            {
                DEBUG("MA for TSI R [%d:%d]", n_s, n_r);
                const MqlRates cur = rates[n_r];
                // const MqlRates pre = rates[n_r + shift];
                const MqlRates pre = rates[n_r + 1];
                /// geometric weighting with volume, in series R
                const double wfactor = weightFor(f_r, r_period) * (double)cur.tick_volume;
                /// TBD weighting on the MA on true range
                // const double trng = trueRange(n_r, price_mode, rates);
                // const double wfactor = weightFor(f_r, r_period) * (dblZero(trng) ? DBL_EPSILON : trng);
                const double rchg = priceFor(cur, price_mode) - priceFor(pre, price_mode);
                r_sum += rchg;
                r_abs_sum += fabs(rchg);
                r_weights += wfactor;
            }
            s_ma += wfactor_s * (r_sum / r_weights);
            s_abs_ma += wfactor_s * (r_abs_sum / r_weights);
            s_weights += wfactor_s;
        }
        s_ma /= s_weights;
        s_abs_ma /= s_weights;

        const double tsi = dblZero(s_abs_ma) ? DBLZERO : (100.0 * s_ma) / s_abs_ma;

        DEBUG("TSI [%d] %f", idx, tsi);

        const double pre = tsi_data.getState();

        /// volume-weighted MA at the greater of the r and s periods
        const int period_ma = fmax(r_period, s_period);
        /// ... or s period ...
        // const int period_ma = s_period;
        /// or shortest ...
        // const int period_ma = fmin(r_period, s_period);
        const double cur_weight = weightFor(period_ma, period_ma) * (double)rates[idx].tick_volume;
        const double pre_weight = weightFor(period_ma - 1, period_ma) * (double)rates[idx + 1].tick_volume;
        double ma = (tsi * cur_weight) + (pre * pre_weight);
        double weights = cur_weight + pre_weight;
        const int stop = idx + 1; // stop before previous
        for (int n = idx + period_ma - 1, p_k = 1; n > stop; n--, p_k++)
        {
            const double early = tsi_data.get(n);
            if (early != EMPTY_VALUE)
            {
                const double wfactor = weightFor(p_k, period_ma) * (double)rates[n].tick_volume;
                ma += (early * wfactor);
                weights += wfactor;
            }
        }
        ma /= weights;

        if (pre == EMPTY_VALUE)
        {
            tsi_data.setState(ma);
        }
        else
        {
            // Using an EMA at two short of the third MA period, 
            // due to the inclusion of current and previous
            // values in the MA
            const double ma_period = fmax(period_ma - 2, 1);
            const double _e = ema(pre, ma, ma_period);
            tsi_data.setState(_e);
        }
    }

    int calcInitial(const int _extent, MqlRates &rates[])
    {
        DEBUG("TSI Initalizing for %d", _extent);
        const int calc_idx = _extent - data_shift - 1;
        // tsi_rev.setState(EMPTY_VALUE);
        // calcMain(calc_idx, rates); // called higher in the API
        return calc_idx;
    }

    virtual int initIndicator(const int start = 0)
    {
        if (!PriceIndicator::initIndicator())
        {
            return -1;
        }
        if (!initBuffer(start, tsi_data.data, "TSI"))
        {
            return -1;
        }
        return start + 1;
    }
};

#endif