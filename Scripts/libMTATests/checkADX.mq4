/// ADX +DI/-DI min/max information

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#property strict
#property show_inputs
#property description "Logging Utility for ADX +DI, -DI Minimum/Maximum Analysis"

extern const int adx_period = 14;                               // ADX Period
extern const ENUM_APPLIED_PRICE adx_price_mode = PRICE_TYPICAL; // ADX Applied Price

#define NO_EA_TIME 1

#include <../Libraries/libMTA/libADX.mq4>
#include <../Libraries/libMTA/ratesbuffer.mq4>

#ifndef NRQUOTES
#define NRQUOTES 1440
#endif

ADXData *adx_data;
PriceReversal *adx_revinfo;
RatesBuffer *rbuff;

void printExtent(const string trend, const bool maxp, const double ext_val, const datetime ext_dt)
{
    const string kind = maxp ? "Max" : "Min";
    printf(adx_data.indicatorName() + " [%s, %d] Nearest %s %s %f at %s", _Symbol, _Period, trend, kind, ext_val, TimeToStr(ext_dt));
}

void cleanup()
{
    FREEPTR(adx_data);
    FREEPTR(adx_revinfo);
    FREEPTR(rbuff);
}

void OnStart()
{

    DEBUG("Init ADX binding");
    adx_data = new ADXData(adx_period, adx_price_mode, _Symbol, _Period, false);
    adx_revinfo = new PriceReversal();

    DEBUG("Set ADX extent");
    if (!adx_data.setExtent(NRQUOTES))
    {
        ERRMSG(("Unable to initialize ADX data for %d quotes", NRQUOTES));
        cleanup();
        return;
    }

    DEBUG("Init quotes");
    rbuff = new RatesBuffer(NRQUOTES, true, _Symbol, _Period);
    const int copied = rbuff.getRates();
    if (copied == -1)
    {
        ERRMSG(("Unable to copy %d quotes", NRQUOTES));
        cleanup();
        return;
    }
    DEBUG("Init ADX data");
    adx_data.initVars(NRQUOTES, rbuff.data);
    const int last = NRQUOTES - 1;
    const datetime dt_ext = rbuff.get(last).time;
    const string dts_ext = TimeToString(dt_ext);

    DEBUG("Search ADX +DI/-DI extents");

    const MqlRates rate_cur = rbuff.get(0);
    const datetime dt_cur = rate_cur.time;
    const string dts_cur = TimeToString(dt_cur);

    const double dx_cur = adx_data.dxAt(0);
    const double plus_cur = adx_data.plusDiAt(0);
    const double minus_cur = adx_data.minusDiAt(0);

    ///
    /// ADX +DI/-DI Crossover
    ///

    DEBUG("ADX last [%d] %s", last, dts_ext);
    // double xplus_cur = DBLEMPTY;
    // double xminus_cur = DBLEMPTY;
    // double xplus_pre = plus_cur;
    // double xminus_pre = minus_cur;
    // int xshift = EMPTY;
    // for (int n = 1; n < NRQUOTES; n++)
    // {
    //     xplus_cur = xplus_pre;
    //     xminus_cur = xminus_pre;
    //     xplus_pre = adx_data.plusDiAt(n);
    //     xminus_pre = adx_data.minusDiAt(n);
    //     if (((xplus_cur > xminus_cur) && (xplus_pre < xminus_pre)) ||
    //         ((xplus_cur < xminus_cur) && (xplus_pre > xminus_pre)))
    //     {
    //         xshift = n;
    //         break;
    //     }
    // }

    PriceXOver xover();
    const bool xover_p = adx_data.bind(xover);

    // if (xshift == EMPTY)
    if (!xover_p)
    {
        /// this might be reached on event of a bug, or network error, etc
        printf("No +DI/-DI crossover found from %s to %s", dts_ext, dts_cur);
        cleanup();
        return;
    }

    const datetime xshift_near_dt = xover.nearTime();
    const int xshift = iBarShift(_Symbol, _Period, xshift_near_dt);

    const datetime xshift_dt = rbuff.get(xshift).time;

    printf("Nearest +DI/-DI crossover (%s): %s", (xover.bearish() ? "Bearish" : "Not Bearish"), toString(xshift_dt));

    const double xplus_val = xover.nearVal();
    const double xminus_val = xover.nearValB();

    ///
    /// +DI Min/Max
    ///

    const bool plusmaxres = adx_data.bindPlusDIMax(adx_revinfo, 0, xshift);
    if (!plusmaxres)
    {
        Print("No +DI max reversal found, deferring to current data");
        /// FIXME use the greater of current +DI and +DI at crossover
        /// cleanup();
        // return;
    }

    const double plus_max_val = plusmaxres ? adx_revinfo.minmaxVal() : fmax(xplus_val, plus_cur);
    const datetime plus_max_dt = plusmaxres ? adx_revinfo.nearTime() : (xplus_val > plus_cur ? xshift_dt : dt_cur);
    const int plus_max_idx = iBarShift(_Symbol, _Period, plus_max_dt);
    printExtent("+DI", true, plus_max_val, plus_max_dt);

    const bool plusminres = adx_data.bindPlusDIMin(adx_revinfo, 0, xshift);
    if (!plusminres)
    {
        Print("No +DI min reversal found, deferring to current data");
        /// FIXME use the lesser of current +DI and +DI at crossover
        // cleanup();
        // return;
    }
    const double plus_min_val = plusminres ? adx_revinfo.minmaxVal() : fmin(xplus_val, plus_cur);
    const datetime plus_min_dt = plusminres ? adx_revinfo.nearTime() : (xplus_val < plus_cur ? xshift_dt : dt_cur);
    const int plus_min_idx = iBarShift(_Symbol, _Period, plus_min_dt);
    printExtent("+DI", false, plus_min_val, plus_min_dt);
    // printf(adx_data.indicatorName() + " (%s, %d) Nearest Min %f < %f at %s", _Symbol, _Period, plus_min_val, adx_low_limit, TimeToStr(plus_min_dt));

    ///
    /// -DI Min/Max
    ///

    const bool minusmaxres = adx_data.bindMinusDIMax(adx_revinfo, 0, xshift);
    if (!minusmaxres)
    {
        Print("No -DI max reversal found, deferring to current data");
        // FIXME use the greater of current -DI and -DI at crossover
        // cleanup();
        // return;
    }

    const double minus_max_val = minusmaxres ? adx_revinfo.minmaxVal() : fmax(xminus_val, minus_cur);
    const datetime minus_max_dt = minusmaxres ? adx_revinfo.nearTime() : (xminus_val > minus_cur ? xshift_dt : dt_cur);
    const int minus_max_idx = iBarShift(_Symbol, _Period, minus_max_dt);
    printExtent("-DI", true, minus_max_val, minus_max_dt);

    const bool minusminres = adx_data.bindMinusDIMin(adx_revinfo, 0, xshift);
    if (!minusminres)
    {
        Print("No -DI min reveral found, deferring to current data");
        /// FIXME use the lesser of current -DI and -DI at crossover
        // cleanup();
        // return;
    }
    const double minus_min_val = minusminres ? adx_revinfo.minmaxVal() : fmin(xminus_val, minus_cur);
    const datetime minus_min_dt = minusminres ? adx_revinfo.nearTime() : (xminus_val < minus_cur ? xshift_dt : dt_cur);
    const int minus_min_idx = iBarShift(_Symbol, _Period, minus_min_dt);
    printExtent("-DI", false, minus_min_val, minus_min_dt);

    // const int gain_idx = (minus_cur > plus_cur) ? minus_max_idx : plus_max_idx;
    // const int opp_idx = (minus_cur > plus_cur) ? plus_max_idx : minus_max_idx;

    // const double price_cur = priceFor(rate_cur, adx_price_mode);

    // const MqlRates rate_max = rbuff.get(plus_max_idx);
    // const MqlRates rate_min = rbuff.get(plus_min_idx);
    // const double price_max = priceFor(rate_max, adx_price_mode);
    // const double price_min = priceFor(rate_min, adx_price_mode);
    // const double chg_max = adx_data.pricePoints(adx_data.normalize(price_max - price_cur));
    // const double chg_min = adx_data.pricePoints(adx_data.normalize(price_min - price_cur));

    const bool minus_gain = (minus_cur > plus_cur);

    const datetime gain_max_dt = minus_gain ? minus_max_dt : plus_max_dt;
    const datetime gain_min_dt = minus_gain ? minus_min_dt : plus_min_dt;
    const double gain_cur = minus_gain ? minus_cur : plus_cur;
    const double gain_max = minus_gain ? minus_max_val : plus_max_val;
    const double gain_min = minus_gain ? minus_min_val : plus_min_val;

    const bool gain_max_foundp = minus_gain ? minusmaxres : plusmaxres;
    const bool gain_min_foundp = minus_gain ? minusminres : plusminres;


    const datetime opp_max_dt = minus_gain ? plus_max_dt : minus_max_dt;
    const datetime opp_min_dt = minus_gain ? plus_min_dt : minus_min_dt;
    const double opp_cur = minus_gain ? plus_cur : minus_cur;

    /// Implementation Note: This tries to hack some immediate gaining-trend reversal
    /// analysis into the three-value strength qualifier.
    ///
    /// With the ADX indicator, the gaining +DI or -DI trend line may undergo any number
    /// of minimum/maximum reversal series, as logically bound within an individual
    /// +DI/-DI crossover duration. 
    ///
    /// Here, the duration from "latest crossover" to  "next unrealized crossover" is analyzed
    ///
    const string strength = ((gain_max_foundp && gain_cur < gain_max) && (gain_max_dt < gain_min_dt)  ? "Decreasingly" :  gain_min_foundp && (gain_cur > gain_min) ?"Increasingly" :  "Currently");

    printf("ADX at current: +DI %f, -DI %f, DX %f (Signal trend: %s %s)", plus_cur, minus_cur, dx_cur, strength, (minus_gain ? "Bearish" : "Not Bearish"));


    /// Implementation Notes:
    ///
    /// Aditional qualifiers on the "Bearish" / "Not Bearish" rating:
    /// - If a CCI indicator at the same main period and a given signal period 
    ///   is past a crossover (or opposing reversal) nearer than the nearest 
    ///   ADX crossover, and the crossover (or reversal) opposes the
    ///   "Bearish"/"Not Bearish" rating from ADX,  the ADX indication
    ///   is substantively weakened - in effect, nulllified - for the
    ///   newer event. 
    ///
    ///   If CCI is past a nearer crossover and the crossover is not
    ///   opposed to the rating from the ADX indicator, no significant
    ///   effect per se.
    ///
    /// - At an M15 scale e.g ... If the CCI indicator has undergone any
    ///   number of crossovers since the nearest ADX crossover - for the
    ///   local CCI and ADX indicators, with both configured for an
    ///   equivalent main period - then it may indicate a period of
    ///   volaitliy, such that no trades should be opened in that duration.
    ///
    /// For ADX, the +DI/-DI trend lines may not typically be indicative
    /// of the extents of market rate changes, rather indicating the relative
    /// strength of the market's "Buy" and conversely, "Sell" positions
    ///
    /// Moreover, with the present ADX implementation, exact matching for price
    /// rates would be a little muddied. This would be due to the application of
    /// smoothing in the filtered rates stream as applied in this ADX implementation.

    /// Debugging
    // adx_data.writeCSV("CHECK_ADX.csv");

    cleanup();
}