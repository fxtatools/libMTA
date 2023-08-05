#ifndef _LIBRVI_MQ4
#define _LIBRVI_MQ4

#property library
#property strict

#property description "An adaptation of John Ehlers' Relative Vigor Index (John F. Ehlers, 2002)"

#include "indicator.mq4"
#include "trend.mq4"

// Relative Vigor Index (adapted)
// - including price range as a weighting factor in calculation of RVI numerator and denominator values
// - scaling "R Factor" by 100 for presentation as a percentage
// - Applying True Range from Wilder's Average True Range, throughout the RVI factoring of price
//
// refs:
// - Kaufman, P. J. (2013). Momentum and Oscillators. In Trading Systems and Methods (5. Aufl., 5, Vol. 591). Wiley. 403
class RVIIn : public PriceIndicator
{
protected:
    PriceBuffer *rvi_buf;        // RVI buffer
    PriceBuffer *rvi_signal_buf; // RVI signal buffer
    PriceBuffer *xma_buf;        // TBD. Buffer for SMA of rate at crossover
    PriceXOver *xover;

public:
    // const int period; // actually unused here
    const double scale_a;
    const double scale_b;
    const double scale_c;
    const double scale_d;
    const double scale_weights;
    const int xma_period;

    RVIIn(const double a = 1.0,
          const double b = 2.0,
          const double c = 2.0,
          const double d = 1.0,
          const int xma = 4, // TBD
          const string _symbol = NULL,
          const int _timeframe = EMPTY,
          const string _name = "RVI",
          const int _data_shift = 9,
          const int _nr_buffers = 3) : scale_a(a), scale_b(b), scale_c(c), scale_d(d),
                                       xma_period(xma),
                                       scale_weights(a + b + c + d),
                                       PriceIndicator(_name, _nr_buffers, _symbol, _timeframe, _data_shift)
    {
        rvi_buf = price_mgr.primary_buffer;
        rvi_signal_buf = rvi_buf.next();
        xma_buf = rvi_signal_buf.next();
        xover = new PriceXOver();
    }
    ~RVIIn()
    {
        // buffer deletion is managed under the buffer manager protocol
        rvi_buf = NULL;
        rvi_signal_buf = NULL;
        xma_buf = NULL;
        FREEPTR(xover);
    }

    virtual string indicatorName() const
    {
        //// FIXME use a constant display_name field throughout
        return StringFormat("%s(%d)", name, xma_period);
    }

    virtual int dataBufferCount()
    {
        return 3;
    }

    virtual int indicatorUpdateShift(const int idx) {
        const int ext = price_mgr.extent;
        double pre = DBLZERO;
        for (int n = idx + 1; n < ext; n++)
        {
            pre = xma_buf.get(n);
            if (pre != EMPTY_VALUE)
            {
                // recalculate to one quote before n+1st crossover
                return n + 1;
            }
        }
        // default, when no previous XMA value
        return idx + dataShift() + 1;
    }

    double factor(const double a, const double b, const double c, const double d, const double csum)
    {
        return ((scale_a * a) + (scale_b * b) + (scale_c * c) + (scale_d * d)) / ((dblZero(csum) ? 2 * DBL_EPSILON : csum) * scale_weights);
    }

    double numAt(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        const double trng = trueRange(idx, PRICE_TYPICAL, open, high, low, close);  // TBD
        const double endsrng = close[idx] - open[idx];
        if (dblZero(trng)) return endsrng / (2.0 * DBL_EPSILON);
        return endsrng / trng;
    }

    double denomAt(const int idx, const double &open[], const double &high[], const double &low[], const double &close[])
    {
        const double trng = trueRange(idx, PRICE_TYPICAL, open, high, low, close);  // TBD
        const double extrng = high[idx] - low[idx];
        if (dblZero(trng)) return extrng / (2.0 * DBL_EPSILON);
        return extrng / trng;
    }

    double chgAt(const int idx, const double &open[], const double &high[], const double &low[], const double &close[], const int period = 1) {
        const double p_far = price_for(idx+period, PRICE_TYPICAL, open, high, low, close);
        const double p_near = price_for(idx, PRICE_TYPICAL, open, high, low, close);
        return p_far - p_near;
    }

    double numFor(const int idx, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
    {
        const double d = numAt(idx, open, high, low, close);
        const double d_1 = numAt(idx + 1, open, high, low, close);
        const double d_2 = numAt(idx + 2, open, high, low, close);
        const double d_3 = numAt(idx + 3, open, high, low, close);
        return factor(d, d_1, d_2, d_3, 1.0);
    }

    double denomFor(const int idx, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
    {
        const double d = denomAt(idx, open, high, low, close);
        const double d_1 = denomAt(idx + 1, open, high, low, close);
        const double d_2 = denomAt(idx + 2, open, high, low, close);
        const double d_3 = denomAt(idx + 3, open, high, low, close);
        return factor(d, d_1, d_2, d_3, 1.0);
    }

    double calcRvi(const int idx, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
    {
        // Implementation note:
        // - This indicator will not use any additional smoothing.
        const double vol = (double)volume[idx];
        const double nsum = numFor(idx, open, high, low, close, volume);
        const double dsum = denomFor(idx, open, high, low, close, volume);

        const double chg = chgAt(idx, open, high, low, close, 4);
        const double p = price_for(idx, PRICE_TYPICAL, open, high, low, close);
        // const double rchg = (chg / p);
        const double rchg = dblZero(chg) ? DBLZERO : (p / chg);
        const double pchg = rchg == DBLZERO ? 0 : 100.0 - (100.0 / (1.0 + rchg));
        if (dblZero(dsum))
            return nsum / (2 * DBL_EPSILON);
        const double rslt = (nsum / dsum) * pchg; 
        return rslt
    }

    double calcRviSignal(const int idx)
    {
        const double r = rvi_buf.get(idx);
        if (r == EMPTY_VALUE)
        {
            printf("RVI 0 at %d (%s) is undefined", idx, offset_time_str(idx, symbol, timeframe));
            return EMPTY_VALUE;
        }
        const double r1 = rvi_buf.get(idx + 1);
        if (r1 == EMPTY_VALUE)
        {
            printf("RVI 1 at %d (%s) is undefined", idx + 1, offset_time_str(idx + 1, symbol, timeframe));
            return EMPTY_VALUE;
        }
        const double r2 = rvi_buf.get(idx + 2);
        if (r2 == EMPTY_VALUE)
        {
            printf("RVI 2 at %d (%s) is undefined", idx + 2, offset_time_str(idx + 2, symbol, timeframe));
            return EMPTY_VALUE;
        }
        const double r3 = rvi_buf.get(idx + 3);
        if (r3 == EMPTY_VALUE)
        {
            printf("RVI 3 at %d (%s) is undefined", idx + 3, offset_time_str(idx + 3, symbol, timeframe));
            return EMPTY_VALUE;
        }
        return factor(r, r1, r2, r3, 1.0);
    }

    void calcMain(const int idx, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
    {
        // FIXME override storeState() and restoreState() here
        const double rvi = calcRvi(idx, open, high, low, close, volume);
        rvi_buf.setState(rvi);
        rvi_buf.set(idx, rvi);
        const double s = calcRviSignal(idx);
        rvi_signal_buf.setState(s);

        // check for the event of signal line at (i.e immediately past) crossover.
        //
        // If at crossover,
        // - calculate the estimated rate at crossover, and set the value into a new data array
        // - push the crossover rate into a simple moving average of rates at crossover
        // - for indicator display, add the buffer of average rates at crossover
        // - this may help with interpreting whether to avoid buy/sell signals
        //   for a market in bearish/bullish performance
        //
        // crossover:
        // rvi(idx + 1) > rvi(idx) && rvi_signal(idx + 1) < rvi_signal(idx)
        // - bearish crossover
        // rvi(idx + 1) < rvi(idx) && rvi_signal(idx + 1) > rvi_signal(idx)
        // - bullish crossover
        //
        // crossover SMA
        // - calculate the esimated rate at point of intermediate cross
        // - use some form of an SMA period, no further smoothing required
        // - when nr crossovers < SMA period, use nr crossovers
        const double rvi_pre = rvi_buf.get(idx + 1);
        const double s_pre = rvi_signal_buf.get(idx + 1);
        double xop = false;
        double bearish = EMPTY_VALUE;

        if (s_pre > rvi_pre && s < rvi)
        {
            bearish = true;
        }
        else if (s_pre < rvi_pre && s > rvi)
        {
            bearish = false;
        }
        else
        {
            // ... for section plot:
            xma_buf.setState(EMPTY_VALUE);
            // ... for histogram plot:
            // xma_buf.setState(xma_buf.get(idx + 1));
            return;
        }
        // TBD
        const datetime t = offset_time(idx, symbol, timeframe);
        const datetime t_pre = offset_time(idx + 1, symbol, timeframe);
        xover.bind(rvi, rvi_pre, s, s_pre, t, t_pre);

        // shortcut ...
        /*
        xma_buf.setState(xover.rate());
        return;
        */

        // TBD
        /*
        double ma = xover.rate();
        const int ext = price_mgr.extent;
        double count = 1;
        for (int n = idx; n < ext && count < xma_period; n++)
        {
            const double val = xma_buf.get(n);
            if (val != EMPTY_VALUE)
            {
                ma += val;
                count++;
            }
        }
        if (count > 0)
        {
            ma /= count;
        }
        ma /= count;
        */
        // xma_buf.setState(ma * 10);

        // FIXME store the actual value at crossover in one buffer.
        // For display, store an MA of the average of:
        // - value at crossover
        // - value at previous RVI extent 

        /* alt (not as smoothed) */
        double pre = EMPTY_VALUE;
        const int ext = price_mgr.extent;
        for (int n = idx + 1; n < ext; n++)
        {
            pre = xma_buf.get(n);
            if (pre != EMPTY_VALUE)
            {
                break;
            }
        }
        if (pre == EMPTY_VALUE) {
            xma_buf.setState(xover.rate());
        } else {
            const double cur = xover.rate();
            // xma_buf.setState(ema(pre, cur, xma_period));
            // ++ :
            xma_buf.setState(emaShifted(pre, cur, xma_period, xma_period / 2));
            //// Wilder ADX EMA, a (far, far too) dynamic EMA method:
            // xma_buf.setState(emaWilder(pre, cur, xma_period));
        }
    }

    int calcInitial(const int _extent, const double &open[], const double &high[], const double &low[], const double &close[], const long &volume[])
    {
        // 1 for index
        const int calc_idx = _extent - 1 - RVIIn::dataShift();
        DEBUG("Calculating Initial RVI [%d] at %d/%d", RVIIn::dataShift(), calc_idx, _extent);
        for (int n = _extent - 5; n >= calc_idx; n--)
        {
            const double rvi = calcRvi(n, open, high, low, close, volume);
            rvi_buf.setState(rvi);
            rvi_buf.set(n, rvi);
        }
        DEBUG("Calculating RVI Signal");
        const double s = calcRviSignal(calc_idx);
        if (s != DBL_MIN)
        {
            rvi_signal_buf.setState(s);
            rvi_signal_buf.set(calc_idx, s);
        }
        return calc_idx;
    }

    void initIndicator()
    {
        // FIXME update API : initIndicator => bool

        IndicatorShortName(indicatorName());

        const int nrbuf = dataBufferCount();
        IndicatorBuffers(nrbuf); // if ! return false

        int curbuf = 0;
        SetIndexBuffer(curbuf, rvi_buf.data);
        SetIndexLabel(curbuf, "RVI");
        SetIndexStyle(curbuf++, DRAW_LINE);

        SetIndexBuffer(curbuf, rvi_signal_buf.data);
        SetIndexLabel(curbuf, "RVI S");
        SetIndexStyle(curbuf++, DRAW_LINE);

        SetIndexBuffer(curbuf, xma_buf.data);
        SetIndexLabel(curbuf, "XMA");
        SetIndexStyle(curbuf++, DRAW_SECTION);
        // SetIndexStyle(curbuf++, DRAW_HISTOGRAM);
    }
};

#endif