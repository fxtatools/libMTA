// libCCI.mq4: CCI Indicator

#ifndef _LIBCCI_MQ4
#define _LIBCCI_MQ4 1

#property library
#property strict

#include "indicator.mq4"
#include "trend.mq4"
#include "libSPrice.mq4"

#include "filter.mq4"

#ifndef CCI_FACTOR
#define CCI_FACTOR 0.015 // 3/20
#endif

/// @brief An adaptation of George C. Lane's Commodity Channel Index
///
// @par References
///
/// Pruitt, G. (2016). Stochastics and Averages and RSI! Oh, My.
///   In The Ultimate Algorithmic Trading System Toolbox + Website (pp. 25–76).
///   John Wiley & Sons, Inc. https://doi.org/10.1002/9781119262992.ch2
///
class CCIData : public PriceIndicator
{
protected:
    ValueBuffer<double> *cci_mean;
    ValueBuffer<double> *cci_sd;
    ValueBuffer<double> *cci_data;
    ValueBuffer<double> *cci_signal;
    ValueBuffer<double> *cci_cross;
    PriceReversal revinfo; // utility object  for reversal analsyis
    PriceXOver xover;      // utility object for crossover analysis
    double sdrates[];

    void fillRates(const int idx, double &_sdrates[], MqlRates &rates[])
    {
        for (int shift = idx + mean_period - 1, nth = 0; shift >= idx; shift--, nth++)
        {
            const double p = priceFor(rates[shift], price_mode);
            _sdrates[nth] = p;
        }
    }

public:
    const int mean_period;   // CCI mean period
    const int signal_period; // CCI signal period
    const int price_mode;    // CCI price mode
    const double cci_factor; // CCI scaling factor (market-dependent)

    CCIData(const int _mean_period = 20,
            const int _signal_period = 9,
            const int _price_mode = PRICE_TYPICAL,
            const string _symbol = NULL,
            const int _timeframe = EMPTY,
            const bool _managed = true,
            const string _name = "CCI",
            const int _nr_buffers = EMPTY,
            const int _data_shift = EMPTY) : mean_period(_mean_period),
                                             signal_period(_signal_period),
                                             price_mode(_price_mode),
                                             cci_factor(CCI_FACTOR),
                                             revinfo(), xover(),
                                             PriceIndicator(_managed,
                                                            _name,
                                                            _nr_buffers == EMPTY ? classBufferCount() : _nr_buffers,
                                                            _symbol,
                                                            _timeframe,
                                                            _data_shift == EMPTY ? _mean_period + _signal_period + 1 : _data_shift)
    {
        int idx = 0;
        cci_mean = data_buffers.get(idx++);
        cci_sd = data_buffers.get(idx++);
        cci_data = data_buffers.get(idx++);
        cci_signal = data_buffers.get(idx++);
        cci_cross = data_buffers.get(idx++);
        ArrayResize(sdrates, mean_period);
        ArraySetAsSeries(sdrates, true);
    };
    ~CCIData()
    {
        /// linked data buffers should be deleted within the buffer list protocol
        cci_mean = NULL;
        cci_sd = NULL;
        cci_data = NULL;
        cci_signal = NULL;
        ArrayFree(sdrates);
    };

    virtual int classBufferCount()
    {
        /// return the number of buffers used directly for this indicator.
        /// should be incremented internally, in derived classes
        return 5;
        // return SPriceData::classBufferCount() + 5;
    };

    string indicatorName()
    {
        return StringFormat("%s(%d, %d)", name, mean_period, signal_period);
    }

    virtual int dataShift()
    {
        // FIXME implement as a pure virtual function in the base class

        return mean_period + signal_period + 1;
    }

    virtual int indicatorUpdateShift(const int idx)
    {
        return idx + dataShift() + 1;
    };

    bool bindMax(PriceReversal &_revinfo, const int begin = 0, const int end = EMPTY, const double limit = DBL_MAX)
    {
        return _revinfo.bindMax(cci_data, this, begin, end, limit);
    }

    bool bindMin(PriceReversal &_revinfo, const int begin = 0, const int end = EMPTY, const double limit = DBL_MIN)
    {
        return _revinfo.bindMin(cci_data, this, begin, end, limit);
    }

    /// @brief Determine a factor of the partial area between the CCI main and signal
    ///  lines, within a duration of chart data
    ///
    /// @param furthest index for the traversal. If EMPTY, the extent of the
    ///  indicator's data set will be used.
    /// @oparam nearest nearst index for the traversal
    /// @return the partial area
    double rangeFactor(const int furthest = EMPTY, const int nearest = 0)
    {
        const double _icci_at = cci_data.get(nearest);
        const double _isignal_at = cci_signal.get(nearest);
        const bool cgaining = _icci_at > _isignal_at;
        double gain_cur = cgaining ? _icci_at : _isignal_at;
        double opp_cur = cgaining ? _isignal_at : _icci_at;
        double factor = DBLZERO;
        for (int n = nearest; n <= furthest; n++)
        {
            const double _cci_at = cci_data.get(nearest);
            const double _signal_at = cci_signal.get(nearest);

            double gain_pre = cgaining ? _cci_at : _signal_at;
            double opp_pre = cgaining ? _signal_at : _cci_at;

            const double a = fabs(gain_pre - gain_cur);
            const double b = fabs(opp_pre - opp_cur);

            factor += (a / 2.0) + (b / 2.0) + fmin(gain_cur, gain_pre) - fmax(opp_cur, opp_pre);

            gain_cur = gain_pre;
            opp_cur = opp_pre;
        }
        return factor;
    }

    double cciAt(const int idx)
    {
        return cci_data.get(idx);
    }

    double signalAt(const int idx)
    {
        return cci_signal.get(idx);
    }

    double crossAt(const int idx)
    {
        return cci_cross.get(idx);
    }
    void calcMean(const int idx, double &_sdrates[])
    {
        const double m = mean(mean_period, _sdrates);
        cci_mean.setState(m);
    }

    void calcSdev(const int idx, MqlRates &rates[])
    {

        fillRates(idx, sdrates, rates);

        calcMean(idx, sdrates);
        const double m = cci_mean.getState();

        const double sd = sdev(mean_period, sdrates, 0, m);
        DEBUG("current mean %f", m);
        DEBUG("current sd %f", sd);

        cci_sd.setState(sd);
    }

    void calcMdev(const int idx, MqlRates &rates[])
    {

        fillRates(idx, sdrates, rates);

        calcMean(idx, sdrates);
        const double m = cci_mean.getState();
        double md = DBLZERO;
        for (int n = 0; n < mean_period; n++)
        {
            const double sdr = sdrates[n];
            md += (sdr - m);
            printf("SDR %f, MDS %f", sdr, md);
        }
        md /= (double)mean_period;

        DEBUG("current mean %.10f", m);
        DEBUG("current md %.10f", md);

        cci_sd.setState(md);
    }

    // calculate the current CCI value, current CCI WMA, and CCI EMA
    void calcCCI(const int idx, MqlRates &rates[])
    {

        calcSdev(idx, rates);

        const double m = cci_mean.getState();
        const double sd = cci_sd.getState();

        const double p = priceFor(rates[idx], price_mode);

        /// Commodity Channel Index
        const double cci = (p - m) / ((dblZero(sd) ? DBL_EPSILON : sd) * cci_factor);

        const double pre = cci_data.getState();

        const double earlier = cci_data.get(idx + 2);
        const double cur = smoothed(mean_period, cci, cci, pre, earlier);
        cci_data.setState(cur);

    }

    // calculate the geometrically weighted mean of CCI main values
    // for the signal period, using  the EMA of this value as the CCI
    // signal value
    void calcSignal(const int idx, MqlRates &rates[])
    {
        double s_cur = DBLZERO;
        double weights = DBLZERO;

        const double s_pre = cci_signal.getState();
        if (s_pre == EMPTY_VALUE)
        {
            const double cci_val = cci_data.get(idx);
            if (cci_val == EMPTY_VALUE)
            {
                DEBUG(__FUNCSIG__ + " CCI value undefined at %d", idx);
                cci_signal.setState(DBLEMPTY);
            }
            else
            {
                cci_signal.setState(cci_val);
            }
            return;
        }

        for (int n = idx + signal_period - 1, p_k = 1; n >= idx; n--, p_k++)
        {
            const double wfactor = weightFor(p_k, signal_period);
            const double cur = cci_data.get(n);
            if (cur == EMPTY_VALUE)
            {
                DEBUG(__FUNCSIG__ + " CCI not defined at %d", n);
            }
            {
                DEBUG("CCI input EMA [%d] %f", n, cur);
                s_cur += (cur * wfactor);
                weights += wfactor;
            }
        }
        s_cur /= weights;
        const double s_ema = ema(s_pre, s_cur, signal_period);
        DEBUG("CCI current signal EMA [%d] %f", idx, s_ema);
        cci_signal.setState(s_ema);
    }

    void calcMain(const int idx, MqlRates &rates[])
    {
        calcCCI(idx, rates);
        cci_data.storeState(idx);
        calcSignal(idx, rates);


        /// illsutration a ratio of strength at crossover
        ///
        /// ostensibly simpler than defining a new indicator class and callback
        /// for this puprose
        const int pre_idx = idx + 1;
        cci_cross.setState(DBLEMPTY);
        DEBUG("check crossover to [%d] %s", pre_idx, toString(rates[pre_idx].time));
        const double cci_pre = cci_data.get(pre_idx);
        if (cci_pre == EMPTY_VALUE)
        {
            return;
        }
        const double signal_pre = cci_signal.get(pre_idx);
        if (signal_pre == EMPTY_VALUE)
        {
            return;
        }
        const double cci_cur = cci_data.getState();
        const double signal_cur = cci_signal.getState();
        bool bearish = false;
        if ((cci_pre >= signal_pre) && (signal_cur > cci_cur))
        {
            bearish = true;
        }
        else if (!((cci_pre <= signal_pre) && (signal_cur < cci_cur)))
        {
            DEBUG("No crossover");
            return;
        }

        DEBUG("Detected Crossover at %s", toString(rates[idx].time));

        int next_xshift = EMPTY;
        double next_xval = EMPTY_VALUE;
        const int _len = cci_cross.getExtent();
        DEBUG("Check previous crossovers since [%d] %s", _len, toString(rates[_len - 1].time));
        for (int n = pre_idx; n < _len; n++)
        {
            const double xval = cci_cross.get(n);
            if (xval != EMPTY_VALUE)
            {
                next_xshift = n;
                next_xval = xval;
                break;
            }
        }
        if (next_xshift == EMPTY)
        {
            /// first crossover in series
            cci_cross.setState(DBLZERO);
            DEBUG("No previous crossovers found since %d", _len);
            return;
        }
        DEBUG("Previous crossover [%d] %s", next_xshift, toString(rates[next_xshift].time));

        /// an albeit crude illustration of the strength of the previous reversal:
        /// partial CCI rate area between the gaining CCI trend line and opposing
        /// CCI trend line, up to the next previous crossover.
        ///
        /// this factor may not represent an "open" signal, per se, but rather
        /// a risk limiting signal. A difference below a certain value may
        /// indicate a dynamically weak intermediate reversal.

        const double factor = rangeFactor(next_xshift, pre_idx + 1);
        DEBUG("xfactor %f", factor);
        cci_cross.setState(factor);
    }

    int calcInitial(const int _extent, MqlRates &rates[])
    {
        const int calc_idx = _extent - data_shift - 3;
        cci_mean.setState(DBLEMPTY);
        cci_sd.setState(DBLEMPTY);
        cci_data.setState(DBLEMPTY);
        cci_signal.setState(DBLEMPTY);
        for (int n = calc_idx + signal_period + 1; n >= calc_idx; n--)
        {
            DEBUG("Set initial CCI value at %d", n);
            calcCCI(n, rates);
            if (debugLevel(DEBUG_CALC))
            {
                const double rslt = cci_data.getState();
                DEBUG("Initial CCI value at %d: %f", n, rslt);
            }
            cci_data.storeState(n);
        }
        DEBUG("Set initial CCI signal value at %d", calc_idx);
        const double _cci_state = cci_data.getState();
        cci_signal.setState(_cci_state);
        calcSignal(calc_idx, rates);
        double rslt = cci_signal.getState();
        DEBUG("Initial CCI signal value at %d: %f", calc_idx, rslt);
        cci_signal.storeState(calc_idx + 1, rslt);
        cci_cross.setState(DBLEMPTY);
        return calc_idx;
    }

    virtual int initIndicator(const int start = 0)
    {
        if (start == 0 && !PriceIndicator::initIndicator())
        {
            return -1;
        }
        int idx = start;
        if (!initBuffer(idx++, cci_data.data, "CCI"))
        {
            return -1;
        }
        if (!initBuffer(idx++, cci_signal.data, "CCI S"))
        {
            return -1;
        }
        if (!initBuffer(idx++, cci_cross.data, "CCI X", DRAW_NONE))
        {
            return -1;
        }
        if (!initBuffer(idx++, cci_mean.data, NULL))
        {
            return -1;
        }
        if (!initBuffer(idx++, cci_sd.data, NULL))
        {
            return -1;
        }
        return idx;
    }

    virtual void writeCSVHeader(CsvFile &file)
    {
        /// leading timestamp label and delim, additional data labels,
        /// and trailing newline will be written elsewhere in the API
        file.writeString("Mean MA");
        file.writeDelimiter();
        file.writeString("SD MA");
        file.writeDelimiter();
        file.writeString("CCI");
        file.writeDelimiter();
        file.writeString("CCI Signal");
        file.writeDelimiter();
        file.writeString("CCI Crossover");
    }
};

#endif
