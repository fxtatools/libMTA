// libRSI.mq4: RSI Indicator

#ifndef _LIBRSI_MQ4
#define _LIBRSI_MQ4 1

#property library
#property strict

#include "indicator.mq4"

/// @brief RSI Indicator
class RSIIndicator : public PriceIndicator
{
protected:
    PriceBuffer *rsi_data;

public:
    const int ma_period;
    const int price_mode;

    RSIIndicator(const int _ma_period,
                 const int _price_mode,
                 const string _symbol = NULL,
                 const int _timeframe = EMPTY,
                 const string _name = "RSI++",
                 const int _nr_buffers = 1,
                 const int _data_shift = EMPTY) : ma_period(_ma_period),
                                                  price_mode(_price_mode),
                                                  PriceIndicator(_name,
                                                                 _nr_buffers,
                                                                 _symbol,
                                                                 _timeframe,
                                                                 _data_shift == EMPTY ? _ma_period : _data_shift)
    {
        rsi_data = price_mgr.primary_buffer;
    };
    ~RSIIndicator()
    {
        // the data buffer should be deleted within the buffer manager protocol
        // as activated under the PriceIndicator dtor
        rsi_data = NULL;
    };

    string indicatorName() const
    {
        return StringFormat("%s(%d)", name, ma_period);
    }

    void calcMain(const int idx, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
    {
        // FIXME use EMA of MWMA, to try to smooth out "zero gaps" from p_diff
        // EMA initial : Just use MWMA

        // addition: Using volume as a weighting factor
        double rs_plus = __dblzero__;
        double rs_minus = __dblzero__;
        double wsum = __dblzero__;
        double weights = __dblzero__;
        for (int n = idx + ma_period, p_k = 1; p_k <= ma_period; p_k++, n--)
        {
            const double p_prev = price_for(n + 1, price_mode, open, high, low, close);
            const double p_cur = price_for(n, price_mode, open, high, low, close);
            const double p_diff = p_cur - p_prev; // sometimes zero
            // const double wfactor = ((double)p_k * volume[n]) / (double)ma_period;
            //// volume needs to be weighted for direction of price change.
            //// it would create a ghost sell strength in this indicator.
            //// see ADX +DM/-DM
            const double wfactor = (double)p_k / (double)ma_period; // FIXME factor-in true range here (denominator)

            if (dblZero(p_diff))
            {
                // continue; // nop
            }
            else if (p_diff > 0)
            {
                rs_plus += (p_diff * wfactor);
            }
            else if (p_diff < 0)
            {
                rs_minus += (-p_diff * wfactor);
            }
            weights += wfactor;
        }
        rs_plus /= weights;
        rs_minus /= weights;

        const double rs = (dblZero(rs_minus) ? __dblzero__ : (rs_plus / rs_minus));
        const double rsi_cur = (rs == __dblzero__ ? rs : 100.0 - (100.0 / (1.0 + rs)));
        const double rsi_pre = rsi_data.getState();
        // using EMA of weighted average should ensure this will produce
        // no zero values in the RSI line
        //
        // the resulting RSI line may resemble a MACD line projected entirely
        // into a positive range
        // const double store_rsi = (rsi_pre == EMPTY_VALUE ? rsi_cur : ema(rsi_pre, rsi_cur, ma_period));
        //// alternately, using Wilder's EMA function, generally to an effect of more
        ///  sequential smoothing in the RSI indicator line
        const double store_rsi = (rsi_pre == EMPTY_VALUE ? rsi_cur : emaShifted(rsi_pre, rsi_cur, ma_period));
        rsi_data.setState(store_rsi);
    }

    int calcInitial(const int _extent, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
    {
        // clear any present value and calculate an initial RSI for subsequent EMA
        rsi_data.setState(EMPTY_VALUE);
        const int calc_idx = _extent - 2 - ma_period;
        calcMain(calc_idx, open, high, low, close, volume);
        return calc_idx;
    }

    virtual int dataBufferCount() const
    {
        // return the number of buffers used directly for this indicator.
        // should be incremented internally, in derived classes
        return 1;
    };

    void initIndicator()
    {
        // FIXME update API : initIndicator => bool

        PriceIndicator::initIndicator();

        // does not provide values for the indicator window, e.g indicator shortname
        // - cf indicatorName()
        const int first_buffer = dataBufferCount() - 1;
        SetIndexBuffer(first_buffer, rsi_data.data);
        SetIndexLabel(first_buffer, "RSI");
        SetIndexStyle(first_buffer, DRAW_LINE);
    }
};

#endif
