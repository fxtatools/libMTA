// libCCI.mq4: CCI Indicator

#ifndef _LIBCCI_MQ4
#define _LIBCCI_MQ4 1

#property library
#property strict

#include "indicator.mq4"

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
    PriceBuffer *cci_data;
    PriceBuffer *cci_signal;

public:
    const int mean_period;   // CCI mean period
    const int signal_period; // CCI signal period
    const int price_mode;    // CCI price mode
    const double cci_factor; // CCI scaling factor (market-dependent)

    CCIData(const int _mean_period = 20,
            const int _signal_period = 9,
            const int _price_mode = PRICE_TYPICAL,
            const double _cci_factor = EMPTY,
            const string _symbol = NULL,
            const int _timeframe = EMPTY,
            const string _name = "CCI",
            const int _data_shift = EMPTY,
            const int _nr_buffers = 2) : mean_period(_mean_period),
                                         signal_period(_signal_period),
                                         price_mode(_price_mode),
                                         cci_factor(_cci_factor == EMPTY ? 0.015 : _cci_factor),
                                         PriceIndicator(_name,
                                                        _nr_buffers,
                                                        _symbol,
                                                        _timeframe,
                                                        _data_shift == EMPTY ? _mean_period + _signal_period : _data_shift)
    {
        cci_data = dynamic_cast<PriceBuffer *>(price_mgr.primary_buffer);
        cci_signal = dynamic_cast<PriceBuffer *>(cci_data.next_buffer);
    };
    ~CCIData()
    {
        // linked data buffers should be deleted within the buffer manager protocol
        cci_data = NULL;
        cci_signal = NULL;
    };

    string indicatorName() const
    {
        return StringFormat("%s(%d, %d)", name, mean_period, signal_period);
    }

    virtual int dataShift()
    {
        // FIXME implement as a pure virtual function in the base class
        return mean_period + signal_period;
    }

    virtual int indicatorUpdateShift(const int idx)
    {
        return idx + dataShift() + 1;
    };

    void calcCCI(const int idx, MqlRates &rates[])
    {
        const double m_dbl = (double)mean_period;
        double weights = __dblzero__;
        double m = __dblzero__;
        for (int n = idx + mean_period - 1, p_k = 1; n >= idx; n--, p_k++)
        {
            // const double wfactor = (double)p_k / m_dbl;
            const double wfactor = weightFor(p_k, mean_period);
            m += (priceFor(n, price_mode, rates) * wfactor);
            weights += wfactor;
        }
        m /= weights;
        // const double m = mean(mean_period, price_mode, open, high, low, close, idx);
        DEBUG("CCI Mean at %d: %f", idx, m);
        const double sd = sdev(mean_period, price_mode, rates, idx, m);
        DEBUG("CCI SDev at %d: %f", idx, sd);
        const double p = priceFor(idx, price_mode, rates);
        if (dblZero(sd))
        {
            cci_data.setState(DBLZERO);
            return;
        }
        const double cci = (p - m) / (sd * (cci_factor / marketDigits()));
        cci_data.setState(cci);
    }

    void calcSignal(const int idx, MqlRates &rates[])
    {
        const double s_d = (double)signal_period;
        double s_cur = DBLZERO;
        double weights = DBLZERO;

        const double s_pre = cci_signal.getState();
        // const double s_pre = cci_signal.get(idx + 1);
        if (s_pre == EMPTY_VALUE)
        {
            printf("CCI Signal undefined at %d", idx);
            cci_signal.setState(EMPTY_VALUE);
            return;
        }

        // not a particularly useful signal calculation:
        for (int n = idx + signal_period - 1, p_k = 1; p_k <= signal_period; n--, p_k++)
        {
            // const double wfactor = (double)p_k / s_d;
            const double wfactor = weightFor(p_k, signal_period);
            const double cur = cci_data.get(n);
            if (cur == EMPTY_VALUE)
            {
                printf("CCI undefined at %d", n);
                cci_signal.setState(EMPTY_VALUE);
                return;
            }
            s_cur += (cur * wfactor);
            weights += wfactor;
        }
        s_cur /= weights;
        if (s_pre == DBL_MIN)
        {
            cci_signal.setState(s_cur);
            return;
        }
        // const double s_ema = ema(s_pre, s_cur, signal_period);
        const double s_ema = (s_pre * 2.0 + s_cur) / 3;
        cci_signal.setState(s_ema);
    }

    void calcMain(const int idx, MqlRates &rates[])
    {
        calcCCI(idx, rates);
        cci_data.set(idx, cci_data.getState());
        calcSignal(idx, rates);
    }

    int calcInitial(const int _extent, MqlRates &rates[])
    {
        const int calc_idx = _extent - 1 - CCIData::dataShift();
        DEBUG("Set initial CCI values for %d/%d", calc_idx, _extent);
        cci_data.setState(DBL_MIN);
        for (int n = calc_idx + signal_period + 1; n >= calc_idx; n--)
        {
            DEBUG("Set initial CCI value at %d", n);
            calcCCI(n, rates);
            const double rslt = cci_data.getState();
            DEBUG("Initial CCI value at %d: %f", n, rslt);
            cci_data.set(n, rslt);
        }
        DEBUG("Set initial CCI signal value at %d", calc_idx);
        // cci_signal.setState(DBL_MIN);
        cci_signal.setState(cci_data.getState());
        calcSignal(calc_idx + 1, rates);

        double rslt = cci_signal.getState();
        DEBUG("Initial CCI signal value at %d: %f", calc_idx, rslt);
        cci_signal.set(calc_idx + 1, rslt);

        calcSignal(calc_idx, rates);
        rslt = cci_signal.getState();
        DEBUG("Second CCI signal value at %d: %f", calc_idx, rslt);
        cci_signal.set(calc_idx, rslt);
        return calc_idx;
    }

    virtual int dataBufferCount() const
    {
        // return the number of buffers used directly for this indicator.
        // should be incremented internally, in derived classes
        return 2;
    };

    virtual int initIndicator(const int start = 0)
    {
        if (!PriceIndicator::initIndicator())
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
        return idx;
    }
};

#endif
