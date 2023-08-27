
#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#property strict
#property show_inputs

extern const int cci_mean_period = 8;                                     // Stochastic K Period
extern const int cci_signal_period = 6;                                     // Stochastic D Period
extern const ENUM_APPLIED_PRICE cci_price_mode = PRICE_TYPICAL; // Stochastic Applied Price
extern const double cci_high_limit = 15.0;                       // Min for Stochastic K Maximum
extern const double cci_low_limit = -15.0;                        // Max for Stochastic K Minimum

// extern const void *tbd = NULL; // no objects accepted here
// objects cannot be passed to indicator scripts


#include <../Libraries/libMTA/libSto.mq4>
#include <../Libraries/libMTA/ea.mq4>
#include <../Libraries/libMTA/ratesbuffer.mq4>

#ifndef NRQUOTES
#define NRQUOTES 1440
#endif

void OnStart()
{

    DEBUG("Init Stochastic binding");
    StoData *sto = new StoData(cci_mean_period, cci_signal_period, cci_price_mode, _Symbol, _Period, false);
    PriceReversal *revinfo = new PriceReversal();

    DEBUG("Set Sto extent");
    if (!sto.setExtent(NRQUOTES))
    {
        printf("Unable to initialize Stochastic data for %d quotes", NRQUOTES);
    }

    DEBUG("Init quotes");
    RatesBuffer *rbuff = new RatesBuffer(NRQUOTES, true, _Symbol, _Period);
    const int copied = rbuff.getRates();
    if (copied == -1)
    {
        Print("Unable to copy 1440 rates"); // skipping errno here
        return;
    }
    DEBUG("Init Stochastic data");  
    sto.initVars(NRQUOTES, rbuff.data);
    const int last = NRQUOTES - 1;
    const datetime dt_ext = rbuff.get(last).time;
    const string dts_ext = TimeToString(dt_ext);
    DEBUG("Search Stochastic max");

    const MqlRates rate_cur = rbuff.get(0);
    const datetime dt_cur = rate_cur.time;
    const string dts_cur = TimeToString(dt_cur);

    sto.bindMax(revinfo, 0, last, cci_high_limit);
    const double max_val = revinfo.minmaxVal();
    const datetime max_dt = revinfo.nearTime();
    const int max_idx = iBarShift(_Symbol,_Period, max_dt);
    printf(sto.indicatorName() + " (%s, %d) Max %f > %f at %s [%s ... %s]", _Symbol, _Period, max_val, cci_high_limit, TimeToStr(max_dt), dts_ext, dts_cur);

    sto.bindMin(revinfo, 0, last, cci_low_limit);
    const double min_val = revinfo.minmaxVal();
    const datetime min_dt = revinfo.nearTime();
    const int min_idx = iBarShift(_Symbol,_Period, min_dt);
    printf(sto.indicatorName() + " (%s, %d) Min %f < %f at %s [%s ... %s]", _Symbol, _Period, min_val, cci_low_limit, TimeToStr(min_dt), dts_ext, dts_cur);

    const double sto_cur = sto.valueK(0);
    // FIXME the case of min/max at 0 needs a more particular handling here.
    //
    // For purpose of EA prototyping, it would indicate that a new inflection
    // point has not yet been reached
    //// ----

    /// The bearish/not-bearish rating should not be based on price change.
    //  Insofar as for determining an avaialble price change, the nearest
    //  inflection point ...

    const bool bearish = (max_dt > min_dt) && (max_idx != 0);

    const double price_cur = priceFor(rate_cur, cci_price_mode);

    const MqlRates rate_max = rbuff.get(max_idx);
    const MqlRates rate_min = rbuff.get(min_idx);
    const double price_max = priceFor(rate_max, cci_price_mode);
    const double price_min = priceFor(rate_min, cci_price_mode);
    const double chg_max = sto.pricePoints(sto.normalize(price_max - price_cur));
    const double chg_min = sto.pricePoints(sto.normalize(price_min - price_cur));

    // const bool bearish = chg_max > chg_min;

    /// FIXME using true range across a wide section without MA, as an initial prototype

    printf("Sto at current: %f (Signal trend: %s)", sto_cur, (bearish ? "Bearish" : "Not Bearish"), (bearish ? "Max" : "Min"));


    // main datum of interest - pips range to the nearest major reversal
    const int gain_idx = bearish ? max_idx : min_idx;
    const MqlRates rate_gain = bearish ? rate_max : rate_min;
    const double gain_rng = sto.pricePoints(trueRange(rate_gain, rate_cur, cci_price_mode));
    const double gain_price = bearish ? price_max : price_min;
    // ! price change since the gaining crest/trough
    // - if negative, market rate is probably near or within another reversal
    const double gain_chg =  bearish ? chg_max : chg_min;
    printf("Range from %s%s (pips) %d, Change %d [%s] ", (bearish ? "Max" : "Min"), (gain_idx == 0 ? " (Newest Index)" : ""), (int) gain_rng, (int) gain_chg, TimeToStr(rbuff.data[gain_idx].time));

    // secondary data - pips range to the previous major reversal
    const int opp_idx = bearish ? min_idx : max_idx;
    const MqlRates rate_opp = bearish ? rate_min : rate_max;
    const double opp_rng= sto.pricePoints(trueRange(rate_opp, rate_cur, cci_price_mode));
    const double opp_price = bearish ? price_min : price_max;
    const double opp_chg = bearish ? chg_min : chg_max;
    printf("Range from %s%s (pips) %d, Change %d [%s] ", (bearish ? "Min" : "Max"), (opp_idx == 0 ? " (Newest Index)" : ""), (int) opp_rng, (int) opp_chg, TimeToStr(rbuff.data[opp_idx].time));

    // FIXME absolute max/min price change here may not be sufficient
    // as a market stagnation indicator.
    //
    // TBD: MA of the price change for every intermediate inflection from the
    // gaining inflection to current rate .. adjusting max low water, min high water
    // relative to the Sto rate at each inflection point and/or the position of that
    // rate-at-change, relative to Sto 0
    printf("%s price change (pips) %d",  (bearish ? "Min to Max" : "Max to Min"), (int) sto.pricePoints(sto.normalize(bearish ? gain_price - opp_price : opp_price - gain_price)));


    if(cci_high_limit > sto_cur && sto_cur > cci_low_limit) {
        const double high_diff = (cci_high_limit - sto_cur);
        const double low_diff = (sto_cur - cci_low_limit);
        const double gapratio = sto_cur > 0 ? low_diff / high_diff : high_diff / low_diff;
        const double tbd = sto.normalize(gapratio);
        printf("Caution: Rate is within intermediate high/low section, %.3f", tbd);
    } else if (bearish ? cci_low_limit > sto_cur : sto_cur > cci_high_limit) {
        // also a warning indicator: bearish and current rate is below the min high water
        // or !bearish and current high rate is above the max low water
        printf("Caution: %s Rate is within %s limit region", (bearish ? "Bearish" : "Non-Bearish"), (bearish ? "Min" : "Max"));
    }

    // ArrayFree(rates);
    FREEPTR(sto);
    FREEPTR(revinfo);
    FREEPTR(rbuff);
}