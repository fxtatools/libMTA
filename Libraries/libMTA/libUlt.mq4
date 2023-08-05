#ifndef _LIBULT_MQ4
#define _LIBULT_MQ4

#property library
#property strict

#include "indicator.mq4"

// refs:
// - Kaufman, P. J. (2013). Momentum and Oscillators. In Trading Systems and Methods (5. Aufl., 5, Vol. 591). Wiley. 402-403
class UltOsc : public PriceIndicator
{
protected:
    PriceBuffer *ult_buffer;

public:
    const int period_a;
    const int scale_a;
    const int period_b;
    const int scale_b;
    const int period_c;
    const int scale_c;
    const int price_mode;
    const int longest_period;

    UltOsc(const int a = 7,
           const int b = 14,
           const int c = 28,
           const int a_scale = 4,
           const int b_scale = 2,
           const int c_scale = 1,
           const int _price_mode = PRICE_CLOSE,
           const string _symbol = NULL,
           const int _timeframe = EMPTY,
           const string _name = "Ult",
           const int _nr_buffers = 1,
           const int _data_shift = EMPTY) : period_a(a),
                                        period_b(b),
                                        period_c(c),
                                        scale_a(a_scale),
                                        scale_b(b_scale),
                                        scale_c(c_scale),
                                        price_mode(_price_mode),
                                        longest_period(fmax(c, fmax(a, b))),
                                        PriceIndicator(_name, 
                                        _nr_buffers, 
                                        _symbol, 
                                        _timeframe,
                                        _data_shift == EMPTY ? fmax(c, fmax(a, b)) : _data_shift)
    {
        ult_buffer = price_mgr.primary_buffer;
    }
    ~UltOsc()
    {
        // buffer deletion is managed under the buffer manager protocol
        ult_buffer = NULL;
    }

    string indicatorName() const
    {
        return StringFormat("%s(%d:%d, %d:%d, %d:%d)", name, scale_a, period_a, scale_b, period_b, scale_c, period_c);
    }

    // UO True Low for price
    double tlow(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        return fmin(low[idx], price_for(idx + 1, price_mode, open, high, low, close));
    }

    // UO Buying Power for price
    double bpow(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        return price_for(idx, price_mode, open, high, low, close) - tlow(idx, open, high, low, close);
    }

    // UO True Range for price
    double trange(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        const double h = high[idx];
        const double l = low[idx];
        const double pm = price_for(idx + 1, price_mode, open, high, low, close);
        return fmax(h - l, fmax(h - pm, pm - l));
    }

    // Calculate the UO factor for a provided period and scale
    double calc_for(const int period, const int scale, const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        double sbpow = DBLZERO;
        double strng = DBLZERO;
        for (int n = idx + period - 1; n >= idx; n--)
        {
            sbpow += bpow(n, open, high, low, close);
            strng += trange(n, open, high, low, close);
        }
        return scale * sbpow / strng;
    }

    void calcMain(const int idx, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
    {
        const double fact_a = calc_for(period_a, scale_a, idx, open, high, low, close);
        const double fact_b = calc_for(period_b, scale_b, idx, open, high, low, close);
        const double fact_c = calc_for(period_c, scale_c, idx, open, high, low, close);
        //// original implementation
        // ult_buffer.setState(fact_a + fact_b + fact_c);
        //// adapted for percentage
        const double fact_p = 100.0 - (100.0 / (1.0 + fact_a + fact_b + fact_c));
        ult_buffer.setState(fact_p);
    }

    int calcInitial(const int _extent, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
    {
        const int calc_idx = _extent - 1 - longest_period;
        calcMain(calc_idx, open, high, low, close, volume);
        return calc_idx;
    }

    void initIndicator() {
        // FIXME update API : initIndicator => bool

        const string sname = StringFormat("%s(%d:%d %d:%d %d:%d)", name, scale_a, period_a, scale_b, period_b, scale_c, period_c);
        IndicatorShortName(sname);

        const int nrbuf = dataBufferCount();
        IndicatorBuffers(nrbuf);
        
        const int curbuf = nrbuf - 1;
        SetIndexBuffer(curbuf, ult_buffer.data);
        SetIndexLabel(curbuf, "Ult");
        SetIndexStyle(curbuf, DRAW_LINE);
    }
};

#endif