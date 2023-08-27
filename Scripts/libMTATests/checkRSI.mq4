// tests for RSIData min/max selection

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#property strict
#property show_inputs

extern const int rsi_period = 12;                               // RSI Period
extern const ENUM_APPLIED_PRICE rsi_price_mode = PRICE_TYPICAL; // RSI Applied Price
extern const double rsi_high_limit = 50.0;                      // Min for RSI Maximum
extern const double rsi_low_limit = 50.0;                       // Max for RSI Minimum

#include <../Libraries/libMTA/libRSI.mq4>
#include <../Libraries/libMTA/ratesbuffer.mq4>
#include <../Libraries/libMTA/ea.mq4>

#ifndef NRQUOTES
#define NRQUOTES 1440
#endif

void OnStart()
{

    DEBUG("Init RSI binding");
    RSIData *rsi = new RSIData(rsi_period, rsi_price_mode, _Symbol, _Period, false);
    PriceReversal *revinfo = new PriceReversal();
    RatesBuffer *rbuff = new RatesBuffer(NRQUOTES, true, _Symbol, _Period);

    DEBUG("Set RSI extent");
    if (!rsi.setExtent(NRQUOTES))
    {
        printf("Unable to initialize RSI data for %d quotes", NRQUOTES);
    }

    DEBUG("Init quotes");
    const int copied = rbuff.getRates();
    if (copied == -1)
    {
        Print("Unable to copy 1440 rates"); // skipping errno here
        return;
    }
    DEBUG("Init RSI data");
    rsi.initVars(NRQUOTES, rbuff.data);
    const int last = NRQUOTES - 1;
    DEBUG("Search RSI max");

    // PARAM max limit 50.0
    rsi.bindMax(revinfo, 0, last, rsi_high_limit);
    const double max_val = revinfo.minmaxVal();
    const datetime max_dt = revinfo.nearTime();
    printf(rsi.indicatorName() + " (%s, %d) Max %f > %f at %s since %s", _Symbol, _Period, max_val, rsi_high_limit, TimeToStr(max_dt), offset_time_str(last));

    // PARAM min limit 50.0
    rsi.bindMin(revinfo, 0, last, rsi_low_limit);
    const double min_val = revinfo.minmaxVal();
    const datetime min_dt = revinfo.nearTime();
    printf(rsi.indicatorName() + " (%s, %d) Min %f < %f at %s since %s", _Symbol, _Period, min_val, rsi_low_limit, TimeToStr(min_dt), offset_time_str(last));

    // FIXME if min_dt > max_dt but max_val > rsi_cur it may be bearish after all ...

    const double rsi_cur = rsi.rsiAt(0);
    const bool bearish = (max_dt > min_dt);
    printf("RSI at current: %f (%s)", rsi_cur, (bearish ? "Bearish" : "Not Bearish"));

    // ArrayFree(rates);
    FREEPTR(rbuff);
    FREEPTR(rsi);
    FREEPTR(revinfo);
}