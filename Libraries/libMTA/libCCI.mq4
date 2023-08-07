// libCCI.mq4: CCI Indicator

#ifndef _LIBCCI_MQ4
#define _LIBCCI_MQ4 1

#property library
#property strict

#include "indicator.mq4"

// TBD: generalize CCIData to CCIBase,
// - moving the signal line configuration (initIndicator) to CCIData.
// - implement class CCIBands : public CCIData
//   - derive the bands from the CCI signal line in CCIBase

/// @brief CCI Graph Indicator
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
        cci_data = price_mgr.primary_buffer;
        cci_signal = cci_data.next();
    };
    ~CCIData()
    {
        // linked data buffers should be deleted within the buffer manager protocol
        cci_data = NULL;
        cci_signal = NULL;
    };

    string indicatorName() const
    {
        return StringFormat("%s[%.2f](%d, %d)", name, cci_factor, cci_mean_period, signal_period);
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

    void calcCCI(const int idx, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
    {
        const double m_dbl = (double)mean_period;
        double weights = __dblzero__;
        double m = __dblzero__;
        for (int n = idx + mean_period - 1, p_k = 1; n >= idx; n--, p_k++)
        {
            const double wfactor = (double)p_k / m_dbl;
            m += (price_for(n, price_mode, open, high, low, close) * wfactor);
            weights += wfactor;
        }
        m /= weights;
        // const double m = mean(mean_period, price_mode, open, high, low, close, idx);
        DEBUG("CCI Mean at %d: %f", idx, m);
        const double sd = sdev(mean_period, price_mode, open, high, low, close, idx, m);
        DEBUG("CCI SDev at %d: %f", idx, sd);
        const double p = price_for(idx, price_mode, open, high, low, close);
        if (dblZero(sd)) {
            cci_data.setState(DBLZERO);
            return;
        }
        const double cci = (p - m) / (sd * (cci_factor / marketDigits()));
        cci_data.setState(cci);
    }

    void calcSignal(const int idx, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
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
            const double wfactor = (double)p_k / s_d;
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

    void calcMain(const int idx, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
    {
        calcCCI(idx, open, high, low, close, volume);
        cci_data.set(idx, cci_data.getState());
        calcSignal(idx, open, high, low, close, volume);
    }

    int calcInitial(const int _extent, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
    {
        const int calc_idx = _extent - 1 - CCIData::dataShift();
        DEBUG("Set initial CCI values for %d/%d", calc_idx, _extent);
        cci_data.setState(DBL_MIN);
        for (int n = calc_idx + signal_period + 1; n >= calc_idx; n--)
        {
            DEBUG("Set initial CCI value at %d", n);
            calcCCI(n, open, high, low, close, volume);
            const double rslt = cci_data.getState();
            DEBUG("Initial CCI value at %d: %f", n, rslt);
            cci_data.set(n, rslt);
        }
        DEBUG("Set initial CCI signal value at %d", calc_idx);
        // cci_signal.setState(DBL_MIN);
        cci_signal.setState(cci_data.getState());
        calcSignal(calc_idx + 1, open, high, low, close, volume);

        double rslt = cci_signal.getState();
        DEBUG("Initial CCI signal value at %d: %f", calc_idx, rslt);
        cci_signal.set(calc_idx + 1, rslt);

        calcSignal(calc_idx, open, high, low, close, volume);
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

    void initIndicator()
    {
        // FIXME update API : initIndicator => bool

        PriceIndicator::initIndicator();

        int idx = dataBufferCount() - 2;
        SetIndexBuffer(idx, cci_data.data);
        SetIndexLabel(idx, "CCI");
        SetIndexStyle(idx++, DRAW_LINE);

        SetIndexBuffer(idx, cci_signal.data);
        SetIndexLabel(idx, "CCI S");
        SetIndexStyle(idx, DRAW_LINE);
    }
};

#endif
