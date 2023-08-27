
#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#property show_inputs

extern int s_period = 14;                            // Period for Smoothed Price
extern ENUM_APPLIED_PRICE s_price_mode = PRICE_OPEN; // Applied Price for Rates

#include <../Libraries/libMTA/filter.mq4>
#include <../Libraries/libMTA/ratesbuffer.mq4>

#ifndef NRQUOTES
// #define NRQUOTES 1440
#define NRQUOTES iBars(_Symbol, _Period)
#endif

RatesBuffer *rbuff;
PriceFilter *pf;
SmoothedPrice *sp;

void cleanup()
{
    FREEPTR(rbuff);
    FREEPTR(pf);
    FREEPTR(sp);
}

void OnStart()
{

    // TBD use a chart info manager, to create one Chartable for each {symbol, timeframe} in use

    DEBUG("Init quotes");
    rbuff = new RatesBuffer(NRQUOTES, true, _Symbol, _Period);
    const int copied = rbuff.getRates();
    if (copied == -1)
    {
        ERRMSG(("Unable to copy %d quotes", NRQUOTES));
        cleanup();
        return;
    }

    pf = new PriceFilter(s_price_mode, rbuff.getChartInfo(), "PF", true, false);

    pf.initialize(0, rbuff.data);

    // const string tbd = rbuff.getChartLabel();

    // const double pf_newest = pf.calcOutput(0, rbuff.data);
    // const double pf_newest = pf.valueAt(0, rbuff.data);
    const double pf_newest = pf.valueAt(rbuff.data[0].time, rbuff.data);
    printf("Price at %s [%s]: %f", toString(rbuff.data[0].time), EnumToString(s_price_mode), pf_newest);

    sp = new SmoothedPrice(s_period, "SP", pf);
    /// FIXME it's showing the same value as the price filter,
    /// and not any value matching that in the SPrice indicator
    // const double sp_newest = sp.valueAt(0, rbuff.data); // FIXME this is not actually the newest output value of the filter

    /// slightly different values than the SPrice indicator, given the "spin-up period"
    /// used in the indicator ...
    const double sp_newest = sp.valueAt(0, rbuff.data);
    printf("Smoothed Price at %s [%s]: %f (%f)", toString(rbuff.data[0].time), EnumToString(s_price_mode), rbuff.getChartInfo().normalize(sp_newest), sp.getOutputState());

    cleanup();
}
