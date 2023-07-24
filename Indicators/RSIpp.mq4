//+------------------------------------------------------------------+
//|                                                        RSIpp.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#property copyright "Copyright 2023, Sean Champ"
#property link "https://www.example.com/nop"
#property version "1.00"
#property strict
#property indicator_separate_window

#property indicator_buffers 1

#property indicator_color1 clrDeepSkyBlue
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

#property indicator_level1     70.0
#property indicator_level2     30.0
#property indicator_levelcolor clrDimGray

#include <../Libraries/libMTA/chartable.mq4>
#include <../Libraries/libMTA/rates.mq4>
#include <pricemode.mq4>

extern const int rsi_period = 14;                                 // RSI WMA Period
extern const ENUM_PRICE_MODE rsi_price_mode = PRICE_MODE_TYPICAL; // Price Mode

class RSIBuffer : public Chartable
{

protected:
public:
    const int ma_period;
    const double ma_period_dbl;
    const int price_mode;
    datetime latest_quote_dt;

    RateBuffer *rsi_data;

    RSIBuffer(const int _ma_period, const int _price_mode, const string _symbol, const int _timeframe) : ma_period(_ma_period), ma_period_dbl((double)ma_period), price_mode(_price_mode), latest_quote_dt(0), Chartable(_symbol, _timeframe)
    {

        rsi_data = new RateBuffer();
    };
    ~RSIBuffer()
    {
        delete rsi_data;
    };

    bool setExtent(const int len, const int padding = EMPTY)
    {
        return rsi_data.setExtent(len, padding);
    };

    bool reduceExtent(const int len, const int padding = EMPTY)
    {
        return rsi_data.reduceExtent(len, padding);
    };

    double calc_rsi(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        double rs_plus = __dblzero__;
        double rs_minus = __dblzero__;
        double wsum = __dblzero__;
        double weights = __dblzero__;
        for (int n = idx + rsi_period, p_k = 1; p_k <= rsi_period; p_k++, n--)
        {
            const double p_prev = price_for(n + 1, price_mode, open, high, low, close);
            const double p_cur = price_for(n, price_mode, open, high, low, close);
            const double p_diff = p_cur - p_prev;
            const double wfactor = (double)p_k / ma_period_dbl;
            if (p_diff > 0)
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
        const double rs = (rs_minus == 0 ? 0 : rs_plus / rs_minus);
        const double rsi = 100.0 - (100.0 / (1.0 + rs));
        return rsi;
    }

    virtual datetime update_data(const double &open[], const double &high[], const double &low[], const double &close[], const int _extent = EMPTY, const int index = EMPTY)
    {
        const int __latest__ = 0;

        if (latest_quote_dt != 0)
        {
            setExtent(_extent == EMPTY ? iBars(symbol, timeframe) : _extent);
        }
        const int idx_initial = index == EMPTY ? iBarShift(symbol, timeframe, latest_quote_dt) : index;

        for (int idx = idx_initial; idx >= __latest__; idx--)
        {
            const double rsi = calc_rsi(idx, open, high, low, close);
            rsi_data.data[idx] = rsi;
        }

        latest_quote_dt = iTime(symbol, timeframe, __latest__);
        return latest_quote_dt;
    };

    virtual datetime initialize_data(const int _extent, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        if (!setExtent(_extent, 0))
        {
            printf("Unable to set initial extent %d", _extent);
            return EMPTY;
        }
        DEBUG("Bind intial RSI in %d", _extent);
        latest_quote_dt = 0;
        const int calc_idx = _extent - rsi_period - 2; // +1 for previous-price analysis
        DEBUG("Initializing data [%d/%d]", calc_idx, _extent);
        latest_quote_dt = 0;
        return update_data(open, high, low, close, _extent, calc_idx);
    };
};

RSIBuffer *rsi_buffer;

int OnInit()
{
    rsi_buffer = new RSIBuffer(rsi_period, rsi_price_mode, _Symbol, _Period);

    IndicatorBuffers(1);
    const string shortname = "RSI++";
    IndicatorShortName(StringFormat("%s(%d)", shortname, rsi_period));

    SetIndexBuffer(0, rsi_buffer.rsi_data.data);
    SetIndexLabel(0, "RSI");
    SetIndexStyle(0, DRAW_LINE);

    return INIT_SUCCEEDED;
};

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    if (prev_calculated == 0)
    {
        DEBUG("Initialize for %d quotes", rates_total);
        rsi_buffer.initialize_data(rates_total, open, high, low, close);
    }
    else
    {
        DEBUG("Updating for index %d", rates_total - prev_calculated);
        rsi_buffer.update_data(open, high, low, close);
    }
    return rates_total;
};

void OnDeinit(const int dicode)
{
    delete rsi_buffer;
};