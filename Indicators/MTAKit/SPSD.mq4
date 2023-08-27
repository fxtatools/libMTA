//+------------------------------------------------------------------+
//|                                                          OCSprice.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#property strict

#property description "SD for Smoothed Price, an application of John F. Ehlers' Super Smoother"

#property indicator_buffers 2
#property indicator_color1 clrLime
#property indicator_width1 1
#property indicator_style1 STYLE_SOLID

#property indicator_color2 clrLime
#property indicator_width2 1
#property indicator_style2 STYLE_SOLID

#property indicator_chart_window

extern int sprice_period = 14;                         // Period for Smoothing
extern ENUM_APPLIED_PRICE sprice_mode = PRICE_TYPICAL; // Applied Price

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#include <../Libraries/libMTA/libSPrice.mq4>

/// @brief Standard Deviation bands for the SPrice Smoothed Price indicator
///
/// @par Implementation Notes
///
/// This indicator class was implemented originally as a prototype 
/// for an ad hoc method of visual correlation in analysis of market 
/// rate trends.
///
/// This indicator uses the initial SPrice indicator as a price source,
/// pursuant to the analysis under standard deviation for a moving average
/// of price.
///
/// If compared to a Bollinger Band series of equivalent period and number 
/// of standard deviations, the present indicator will generally produce 
/// a wider band space under market fluctions.
///
/// This indicator may be reimplemented, pursuant of integrating the
/// Smoothed Price filter as implemented for the newer filters API.
class SPSData : public SPriceData
{

protected:
    ValueBuffer<double> *sd_data;
    ValueBuffer<double> *sdplus_band;
    ValueBuffer<double> *sdminus_band;
    double sdcache[];

public:
    SPSData(const int _period = 14,
            const int _price_mode = PRICE_TYPICAL,
            const string _symbol = NULL,
            const int _timeframe = NULL,
            const bool _managed = true,
            const string _name = "SPSD",
            const int _nr_buffers = EMPTY,
            const int _data_shift = EMPTY) : SPriceData(_period, _price_mode, _symbol, _timeframe, _managed, _name, _nr_buffers, _data_shift)
    {

        sd_data = new ValueBuffer<double>(0, true, _managed);
        data_buffers.push( sd_data);
        sdplus_band = new ValueBuffer<double>(0, true, _managed);
        data_buffers.push(sdplus_band);
        sdminus_band = new ValueBuffer<double>(0, true, _managed);
        data_buffers.push(sdminus_band);
        ArrayResize(sdcache, period);
    };
    ~SPSData()
    {
        FREEPTR(sd_data);
        ArrayFree(sdcache);
    }

    void calcMain(const int idx, MqlRates &rates[])
    {
        SPriceData::calcMain(idx, rates);
        const double sp = sprice_data.getState();
        if(sp == EMPTY_VALUE) {
            // not reached
            DEBUG("SPrice not calculated at %d", idx);
            return;
        }
        sdcache[0]=sp;
        int in_period = 1;
        double m = sp;
        for(int n = idx+1, nth = 1; nth < period; n++, nth++) {
            const double msp = sprice_data.get(n);
            if(msp == EMPTY_VALUE) {
                DEBUG("SPrice undefined at %d", n);
                break;
            } else {
                sdcache[nth] = msp;
                DEBUG("+M [%d/%d] %f", in_period, period, msp);
                m += msp;
                in_period++;
            } 
        }
        if(in_period < 2) {
            DEBUG("No additional sprice data available [%d]", idx);
            return;
        }
        m /= in_period;
        DEBUG("calc sd from %d", idx);
        const double sd = sdev(in_period, sdcache, 0, m);
        if (dblZero(sd)) {
            sd_data.setState(DBLEMPTY);
            sdplus_band.setState(DBLEMPTY);
            sdminus_band.setState(DBLEMPTY);
            return; 
        }
        DEBUG("M %f SD %f", m, sd);
        sd_data.setState(sd); // otherwise unused here (FIXME)
        const double plus = sp + (2.0 * sd);
        sdplus_band.setState(plus);
        const double minus =sp - (2.0 * sd);
        sdminus_band.setState(minus);
    }

    int calcInitial(const int _extent, MqlRates &rates[]) {
        const int spidx = SPriceData::calcInitial(_extent, rates);
        int calc_idx = spidx;
        DEBUG("Initial sprice %f", sprice_data.getState());
        sprice_data.storeState(calc_idx);
        /// fill additional sprice data for first mean
        ///
        /// without such a lengthy initial fill period, calcMain would retrieve
        /// some initial sprice values literally impossible for the symbol.
        ///
        /// considering that an sprice indicator at the same period does not show 
        /// any such values, it's unclear as to what may be the programmatic origins 
        /// of the spurious sprice values received here. 
        ///
        /// The workaround is to fast-forward by a certain extent of the main period,
        /// before calcMain would be called in this class
        ///
        const int ext = period * 3;
        for(int n = 0; n < ext; n++, calc_idx--) {
            SPriceData::calcMain(calc_idx, rates);
            
            DEBUG("Filling sprice [%d] %f", calc_idx, sprice_data.getState());
            sprice_data.storeState(calc_idx);
        }
        sd_data.setState(DBLEMPTY);
        sdplus_band.setState(DBLEMPTY);
        sdminus_band.setState(DBLEMPTY);
        return calc_idx;
    }

    int classBufferCount()
    {
        return SPriceData::classBufferCount() + 3;
    }

    int initIndicator(const int start)
    {
        const bool drawn = start == 0;
        if (drawn && !PriceIndicator::initIndicator())
        {
            return -1;
        }
        int idx = start;
        if (!initBuffer(idx++, sdplus_band.data, drawn ? "S+" : NULL))
        {
            return false;
        }
        if (!initBuffer(idx++, sdminus_band.data, drawn ? "S-" : NULL))
        {
            return false;
        }
        if (!initBuffer(idx++, sd_data.data, NULL))
        {
            return false;
        }
        return SPriceData::initIndicator(idx);
    }
};

SPSData *spsdata;

/// FIXME extend this indicator, as an alternative to a moving
/// average of price. Using the sprice as a substitute for the
/// mean of price, calculate the nth standard deviation from
/// that substitute mean.
///
/// For the visual indicator, display bands for the sprice
/// plus and minus the substitute standard deviation,
///
/// i.e Bollinger Bands, for values of an alternate price source
///
/// If viable, implement additional member functions for purpose
/// of trend detection within an EA.
/// - autocorrelation ??

int OnInit()
{
    spsdata = new SPSData(sprice_period, sprice_mode, _Symbol, _Period);

    if (spsdata.initIndicator() == -1)
    {
        return INIT_FAILED;
    }
    return INIT_SUCCEEDED;
}

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

    return spsdata.calculate(rates_total, prev_calculated);
}

void OnDeinit(const int dicode)
{
    FREEPTR(spsdata);
}
