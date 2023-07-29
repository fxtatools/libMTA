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
#property indicator_levelcolor clrDarkSlateGray

#include <../Libraries/libMTA/indicator.mq4>

extern const int rsi_period = 10;                                 // RSI MA Period
extern const ENUM_PRICE_MODE rsi_price_mode = PRICE_MODE_TYPICAL; // Applied Price

class RSIIndicator : public PriceIndicator
{
protected:
    PriceBuffer *rsi_data;

public:
    const int ma_period;
    const int price_mode;

    RSIIndicator(const int _ma_period, const int _price_mode, const string _symbol = NULL, const int _timeframe = EMPTY, const string _name = "RSI++", const int _nr_buffers = 1) :  ma_period(_ma_period), price_mode(_price_mode), PriceIndicator((_symbol == NULL ? _Symbol : _symbol), (_timeframe == EMPTY ? _Period : _timeframe), _name, _nr_buffers) {
        rsi_data = price_mgr.primary_buffer;
    };
    ~RSIIndicator() {
        // the data buffer should be deleted within the buffer manager protocol
        // as activated under the PriceIndicator dtor
        rsi_data = NULL;
    };
    

    string indicator_name() const {
        return StringFormat("%s(%d)", name, ma_period);
    }


    void calcMain(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        // FIXME use EMA of MWMA, to try to smooth out "zero gaps" from p_diff
        // EMA initial : Just use MWMA

        double rs_plus = __dblzero__;
        double rs_minus = __dblzero__;
        double wsum = __dblzero__;
        double weights = __dblzero__;
        for (int n = idx + ma_period, p_k = 1; p_k <= ma_period; p_k++, n--)
        {
            const double p_prev = price_for(n + 1, price_mode, open, high, low, close);
            const double p_cur = price_for(n, price_mode, open, high, low, close);
            const double p_diff = p_cur - p_prev; // sometimes zero
            const double wfactor = (double)p_k / (double)ma_period;
            if(dblZero(p_diff)) {
                // continue; // nop
            } else if (p_diff > 0)
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
        const double store_rsi = (rsi_pre == EMPTY_VALUE ? rsi_cur : emaWilder(rsi_pre, rsi_cur, ma_period));
        rsi_data.setState(store_rsi);
    } 

    int calcInitial(const int _extent, const double &open[], const double &high[], const double &low[], const double &close[]) {
        // clear any present value and calculate an initial RSI for subsequent EMA
        rsi_data.setState(EMPTY_VALUE);
        const int calc_idx = _extent - 2 - ma_period;
        calcMain(calc_idx, open, high, low, close);
        return calc_idx;
    }

    void initIndicator() {
        // does not provide values for the indicator window, e.g indicator shortname
        // - cf indicator_name()
        const int first_buffer = 0;
        SetIndexBuffer(first_buffer, rsi_data.data);
        SetIndexLabel(first_buffer, "RSI");
        SetIndexStyle(first_buffer, DRAW_LINE);
    }   
};

RSIIndicator *rsi_in;

int OnInit()
{
    rsi_in = new RSIIndicator(rsi_period, rsi_price_mode, _Symbol, _Period);
    printf("Initialized RSI indicator (%d)", rsi_in.nDataBuffers());

    IndicatorShortName(rsi_in.indicator_name());
    IndicatorBuffers(rsi_in.nDataBuffers());
    rsi_in.initIndicator();

    return (INIT_SUCCEEDED);
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
        rsi_in.initVars(rates_total, open, high, low, close, 0);
    }
    else
    {
        DEBUG("Updating for index %d", rates_total - prev_calculated);
        rsi_in.updateVars(open, high, low, close, 0);
    }
    return rates_total;
};

void OnDeinit(const int dicode)
{
    FREEPTR(rsi_in);
};
