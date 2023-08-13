#ifndef _LIBRVI_MQ4
#define _LIBRVI_MQ4

#property library
#property strict

#property description "An adaptation of John Ehlers' Relative Vigor Index (John F. Ehlers, 2002)"

#include "indicator.mq4"
#include "trend.mq4"
#include "libMql4.mq4"

// Relative Vigor Index (adapted)
//
// Adaptations:
// - for the calculation of the ratio of moving averages for A, the difference
//   of close and open prices, over B, the difference of the high and low prices,
//   when the high-low moving average B is zero, this adaptation will apply the
//   unscaled difference of close and open prices within that period
//
// - supporting a calculation period other than 4, though using a weighting method
//   generally similar to the four-period RVI
//
// - scaling the RVI value by a factor of 500, generally to an effect of a result
//   resembling a percentage
//
// - adjusting the RVI value for a volume-weighted linear moving average of relative
//   change in price
//
// - calculating a moving average of the intermediate value at main/signal crossover
//   (not displayed)
//
// refs:
// - Kaufman, P. J. (2013). Momentum and Oscillators. In Trading Systems and Methods (5. Aufl., 5, Vol. 591). Wiley. 403
class RVIData : public PriceIndicator
{

protected:
    PriceBuffer *rvi_buf;        // RVI buffer
    PriceBuffer *rvi_signal_buf; // RVI signal buffer
    PriceBuffer *xma_buf;        // TBD. Buffer for SMA of rate at crossover
    PriceXOver *xover;

    /// @brief utility function or weighting in a manner generally similar to the
    ///  original RVI series 1, 2, 2, 1, with a sum weight of 6
    /// @param offset zero-indexed offset for the current weighting factor,
    ///  within the period of moving average
    /// @param period period of moving average
    /// @param pre weighting factor for idx - 1, or 0 for the first weighting factor
    /// @return the new weighting factor for this offset
    virtual double rweightFor(const int offset, const int period, const double pre)
    {
        const int m = (period - (period % 2)) / 2;
        const bool evenp = (period % 2 != 0);
        if (offset < m)
            return offset + 1;
        else if ((offset == m) && !evenp)
            return pre;
        else if (offset == m)
            return offset + 1;
        else
            return pre - 1;
    }

public:
    const int fill_period;
    const int price_mode;
    const int signal_period;

    RVIData(const int fill = 10,
            const int signal = 6,
            const int _price_mode = PRICE_TYPICAL,
            const string _symbol = NULL,
            const int _timeframe = EMPTY,
            const string _name = "RVI",
            const int _data_shift = EMPTY,
            const int _nr_buffers = 3) : fill_period(fill),
                                         signal_period(signal),
                                         price_mode(_price_mode),
                                         PriceIndicator(_name, _nr_buffers, _symbol, _timeframe, _data_shift == EMPTY ? fill + signal + 1 : _data_shift)
    {
        rvi_buf = price_mgr.primary_buffer;
        rvi_signal_buf = dynamic_cast<PriceBuffer *>(rvi_buf.next_buffer);
        xma_buf = dynamic_cast<PriceBuffer *>(rvi_signal_buf.next_buffer);
        xover = new PriceXOver();
    }
    ~RVIData()
    {
        /// buffer deletion is managed under the buffer manager protocol
        rvi_buf = NULL;
        rvi_signal_buf = NULL;
        xma_buf = NULL;
        FREEPTR(xover);
    }

    virtual string indicatorName()
    {
        return StringFormat("%s(%d, %d)", name, fill_period, signal_period);
    }

    virtual int dataBufferCount()
    {
        return 3;
    }

    virtual int indicatorUpdateShift(const int idx)
    {
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

    double numAt(const int idx, MqlRates &rates[])
    {
        MqlRates rate = rates[idx];
        return rate.close - rate.open;
    }

    double denomAt(const int idx, MqlRates &rates[])
    {
        MqlRates rate = rates[idx];
        return rate.high - rate.low;
    }

    double numFor(const int idx, MqlRates &rates[])
    {
        const double p = (double)fill_period;
        double ma = DBLZERO;
        double weights = DBLZERO;
        double wfactor = DBLZERO;
        for (int n = idx + fill_period - 1, p_k = 0; n >= idx; n--, p_k++)
        {
            wfactor = rweightFor(p_k, fill_period, wfactor);
            ma += (wfactor * numAt(n, rates));
            weights += wfactor;
        }
        return ma / weights;
    }

    double denomFor(const int idx, MqlRates &rates[])
    {
        const double p = (double)fill_period;
        double ma = DBLZERO;
        double weights = DBLZERO;
        double wfactor = DBLZERO;
        for (int n = idx + fill_period - 1, p_k = 0; n >= idx; n--, p_k++)
        {
            wfactor = rweightFor(p_k, fill_period, wfactor);
            ma += (wfactor * denomAt(n, rates));
            weights += wfactor;
        }
        return ma / weights;
    }

    double calcRvi(const int idx, MqlRates &rates[])
    {
        const double nsum = numFor(idx, rates);
        const double dsum = denomFor(idx, rates);
        if (dblZero(dsum))
        {
            return DBLZERO;
        }
        return nsum / dsum;
    }

    double calcRviSignal(const int idx, MqlRates &rates[])
    {
        double ma = DBLZERO;
        double wfactor = DBLZERO;
        double weights = DBLZERO;
        for (int n = idx + signal_period - 1, p_k = 0; n >= idx; n--, p_k++)
        {
            wfactor = rweightFor(p_k, signal_period, wfactor);
            const double r = rvi_buf.get(n);
            if (r != EMPTY_VALUE)
            {
                ma += (wfactor * r);
                weights += wfactor;
            }
        }
        if (weights == DBLZERO)
        {
            return rvi_buf.get(idx);
        }
        const double cur = ma / weights;
        return cur;
    }

    void calcMain(const int idx, MqlRates &rates[])
    {
        const double rvi = calcRvi(idx, rates) * 500.0;

        // adaptation: factoring price change for RVI
        const double cur_adj = priceAdjusted(rvi, idx, price_mode, rates, fill_period);

        rvi_buf.setState(cur_adj);
        rvi_buf.set(idx);

        const double s_state = rvi_signal_buf.getState();
        if (s_state == EMPTY_VALUE)
        {
            rvi_signal_buf.setState(rvi);
        }
        else
        {
            const double s = calcRviSignal(idx, rates);
            rvi_signal_buf.setState(s);
        }

        // ** Crossover Analysis **

        // check for the event of the signal/main lines at (i.e immediately past)
        // signal/main crossover
        //
        // If at crossover,
        // - calculate the estimated rate at crossover, and set the value into
        //   a crossover data array
        // - push the crossover rate into a simple moving average of rates at crossover
        //
        // bearish crossover:
        // rvi(idx + 1) > rvi(idx) && rvi_signal(idx + 1) < rvi_signal(idx)
        //
        // bullish crossover:
        // rvi(idx + 1) < rvi(idx) && rvi_signal(idx + 1) > rvi_signal(idx)
        //
        // crossover SMA: Moving average of the esimated rate at point of
        // intermediate crossover
        ////
        const double s = rvi_signal_buf.getState();
        const double rvi_pre = rvi_buf.get(idx + 1);
        const double s_pre = rvi_signal_buf.get(idx + 1);
        bool bearish = false;

        if (s_pre > rvi_pre && s < cur_adj)
        {
            bearish = true;
        }
        else if (!(s_pre < rvi_pre && s > cur_adj))
        {
            /// for section plot:
            xma_buf.setState(EMPTY_VALUE);
            /// for histogram plot:
            // xma_buf.setState(xma_buf.get(idx + 1));
            return;
        }

        const datetime t = offset_time(idx, symbol, timeframe);
        const datetime t_pre = offset_time(idx + 1, symbol, timeframe);
        xover.bind(cur_adj, rvi_pre, s, s_pre, t, t_pre);

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
        if (pre == EMPTY_VALUE)
        {
            xma_buf.setState(xover.rate());
        }
        else
        {
            const double cur = xover.rate();
            xma_buf.setState(emaShifted(pre, cur, signal_period, (double)signal_period / 2.0));
        }
    }

    int calcInitial(const int _extent, MqlRates &rates[])
    {
        // 1 for index
        const int calc_idx = _extent - 1 - RVIData::dataShift();
        DEBUG("Calculating Initial RVI [%d] at %d/%d", RVIData::dataShift(), calc_idx, _extent);
        for (int n = _extent - 1 - fill_period - signal_period; n >= calc_idx; n--)
        {
            const double rvi = calcRvi(n, rates);
            rvi_buf.setState(rvi);
            rvi_buf.set(n);
        }
        DEBUG("Calculating RVI Signal");
        const double s = calcRviSignal(calc_idx, rates);
        rvi_signal_buf.setState(s);
        return calc_idx;
    }

    virtual int initIndicator(const int start = 0)
    {
        if (!PriceIndicator::initIndicator())
        {
            return -1;
        }
        int idx = start;
        if (!initBuffer(idx++, rvi_buf.data, "RVI"))
        {
            return -1;
        }
        if (!initBuffer(idx++, rvi_signal_buf.data, "RVI S"))
        {
            return -1;
        }
        const bool draw_xover = true;
        if (!initBuffer(idx++, xma_buf.data, draw_xover ? "XMA" : NULL, draw_xover ? DRAW_SECTION : DRAW_NONE))
        {
            return -1;
        }
        return idx;
    }
};

#endif
