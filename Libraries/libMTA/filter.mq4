// filter.mq4

#ifndef _FILTER_MQ4
#define _FILTER_MQ4 1

#property library
#property strict

#include "rates.mq4"
#include "chartable.mq4"

/// @brief Abstract Filter base class
class Filter : public ValueBuffer<double>
{
    //// Implementation Notes
    ///
    /// In this application, the Valuebuffer<T>::state_cur field will
    /// be applied to hold the 'current output state' of each filter

protected:
    const string label; /// Informative label. Used in debugging, TBD for indicator support & CSV writeout

    Chartable *chart_info; // chart info for the containing filter

    /// presently, calc_idx has been implemented as a sort of series-wise pointer
    /// decreasing to zero.
    int calc_idx;
    /// calc_total has been implement as roughly analogous to an indicator's rates_total param
    int calc_total;
    // ^ FIXME both of those should be removed, in lieu of using initial_dt and latest_dt
    //   values, both as similarly non-const

    datetime initial_dt;
    datetime latest_dt;

    double input_state; // FIXME => T input_state
    double input_state_pre;
    double output_state_pre;

    /// @brief return any initialization delay for the implementing class
    /// @return the initialization delay. The default implementation returns zero
    /// @see calcDelayed()
    virtual int getInitDelay()
    {
        return 0; // should usually be overidden in the filter implementation
    }

    virtual double calcInput(const int idx, MqlRates &rates[]) = 0; // FIXME double => T

    virtual double getInputState()
    {                       // FIXME double => T
        return input_state; // first part of two-step state mgt for the input function
    }

    virtual double getInputStatePre()
    {                           // FIXME double => T
        return input_state_pre; // second part of two-step state mgt for the input function
    }

    virtual bool shift(const int count = 1)
    {
        DEBUG(__FUNCTION__ + " %s [%d, %d]", getLabel(), calc_idx, calc_total);
        calc_total++;
        if (calc_total == getExtent())
        {
            DEBUG(__FUNCTION__ + " %s shift extent", getLabel());
            const bool shifted = shiftExtent(count);
            if (!shifted)
            {
                ERRMSG((__FUNCTION__ + "%s: failed to shift extent at %d", getLabel(), extent));
                return false; // FIXME do not discard the return value elsewhere
            }
        }
        // Implementation note: updating the input and output states externally
        if (calc_idx > 0)
        {
            // decrease the time-series history pointer, if not already at newest
            calc_idx--;
            DEBUG(__FUNCTION__ + " %s dec calc_idx => %d", getLabel(), calc_idx);
        }
        return true;
    }

    virtual void restoreState(const int whence = EMPTY)
    {
        /// TBD usage - the following may be redundant
        const int idx = whence == EMPTY ? calc_idx : whence;
        if (idx == extent)
        {
            state_cur = EMPTY_VALUE;
        }
        else
        {
            restoreFrom(idx + 1);
        }
    }

    virtual bool update(MqlRates &rates[])
    {
        DEBUG(__FUNCTION__ + " %s [%d, %d]", getLabel(), calc_idx, getExtent());

        input_state_pre = input_state;
        input_state = EMPTY_VALUE;
        DEBUG(__FUNCTION__ + " %s calcInput(%d, &rates[%d])", label, calc_idx, ArraySize(rates));
        input_state = calcInput(calc_idx, rates);

        const double tmp_pre = getState(); // two-stage temporary output storage
        DEBUG(__FUNCTION__ + " %s calcOutput(%d, &rates[%d])", label, calc_idx, ArraySize(rates));
        if (calcOutput(calc_idx, rates))
        {
            // the calcOutput() call should have updated state_cur as with setState(out)
            storeState(calc_idx);
            output_state_pre = tmp_pre;
        }

        latest_dt = rates[calc_idx].time;
        return true;
    }

public:
    // FIXME remove extent from all ctors (buffer API)
    Filter(Chartable *_chart_info,
           const string _label = NULL,
           const bool as_series = true,
           const bool managed = false) : chart_info(_chart_info), label(_label),
                                         ValueBuffer<double>(0, as_series, managed)
    {
        /// how and why is the chart info part failing and only in libHPS?
        // DEBUG("Chart Info %s, %d", chart_info.getSymbol(), chart_info.getTimeframe()); // failing
        resetState();
    }

    virtual Chartable *getChartInfo()
    {
        return chart_info;
    }
    virtual string getLabel()
    {
        return label;
    }

    virtual string getDebugLabel()
    {
        return getLabel();
        /// TBD - partly redundant as text in the EA log:
        // return StringConcatenate(getLabel(), " ", chart_info.getChartName());
    }

    virtual double getOutputState()
    {                     // FIXME double => T
        return state_cur; // reusing the existing buffer state mgt
    }

    virtual double getOutputStatePre()
    {
        return output_state_pre; // supplementing the existing buffer state mgt
    }

    virtual datetime getInitialDt()
    {
        return initial_dt;
    }

    virtual datetime getLatestDt()
    {
        return latest_dt;
    }

    virtual void resetState()
    {
        calc_idx = EMPTY;
        input_state_pre = EMPTY_VALUE;
        input_state = EMPTY_VALUE;
        output_state_pre = EMPTY_VALUE;
        state_cur = EMPTY_VALUE;
        initial_dt = INT_MAX;
        latest_dt = INT_MIN;
        const int sz = ArraySize(data);
        if (sz != 0)
        {
            ArrayFill(data, 0, sz - 1, EMPTY_VALUE);
        }
    }

    virtual void initialize(const int stopidx, MqlRates &rates[], const int earliest = EMPTY)
    {
        // FIXME cheaply done, this. ambiguous to the main update() method
        const int len = ArraySize(rates);
        setExtent(len);
        calc_idx = len - 1; // NB calc_idx is applied as relative to the "earliest dt"
        const datetime earliest_dt = earliest == EMPTY ? rates[calc_idx].time : rates[earliest].time;
        FDEBUG(DEBUG_PROGRAM, (" %s Initializing [%d, %d] to %s", getLabel(),
                               stopidx, calc_idx,
                               toString(earliest_dt, true)));
        if (!update(rates[stopidx].time, rates, earliest_dt))
        {
            printf("%s: Error when updating to %s",
                   toString(rates[stopidx].time, true));
        }
        FDEBUG(DEBUG_PROGRAM, ("%s initialized", getLabel()));
    }

    /// @brief utility function for update(...)
    /// @param dt
    /// @param rates
    /// @param earliest
    /// @return
    virtual bool reinitialize(const datetime dt, MqlRates &rates[], const datetime earliest)
    {
        FDEBUG(DEBUG_PROGRAM, (__FUNCTION__ + " %s reinitialize(%s, rates[%d], %s)",
                               label, toString(dt, true), ArraySize(rates),
                               toString(earliest, true)));
        const int ratesend = ArraySize(rates) - 1;
        const MqlRates r_earliest = rates[ratesend];
        const datetime dt_earliest = r_earliest.time;
        if (dt_earliest < earliest)
        {
            FDEBUG(DEBUG_PROGRAM, (label + ": Earliest rates data is at %s, while %s was provided as initial time. Using earliest rates data",
                                   toString(dt_earliest, true),
                                   toString(earliest, true)));
        }
        /// que reinitialization for the filter data
        resetState();
        const int calc_newest = timeShift(dt, rates); // ? for debug ...
        // calc_idx = ratesend; // FIXME should use the earliest dt ...

        initial_dt = r_earliest.time;
        latest_dt = initial_dt;

        const int eidx = timeShift(earliest, rates);
        if (eidx == EMPTY)
        {
            /// FIXME this illustrates a bug, esp when earliest dt is in effect "zero"
            printf(__FUNCTION__ + " " + label +
                       " earliest datetime not found in rates: %s",
                   toString(earliest, true));
            return false;
        }
        calc_idx = eidx;

        FDEBUG(DEBUG_PROGRAM, (__FUNCTION__ + " " + label +
                                   " Reinitializing [%d..%d] @ %s, %s",
                               calc_idx, calc_newest,
                               toString(earliest, true),
                               toString(initial_dt, true)));

        const int dtidx = timeShift(dt, rates);
        if (dtidx == EMPTY)
        {
            printf(__FUNCTION__ + " " + label +
                       " limit datetime not found in rates: %s",
                   toString(dt, true));
            return false;
        }

        const int delay = getInitDelay();
        for (int nth = 0; nth < delay && calc_idx >= dtidx; nth++)
        {
            /// running through initial calculations without storing state
            /// beyond the caching variables
            ///
            /// this section is generally called within any "reinitializing" event
            ///
            FDEBUG(DEBUG_PROGRAM, (__FUNCTION__ + " " + label +
                                       " Initialization delay [%d, %d, %d]",
                                   nth, delay, calc_idx));
            input_state_pre = input_state;
            input_state = EMPTY_VALUE;
            input_state = calcInput(calc_idx, rates);
            const double tmp_pre = getState(); /// two-stage temporary output storage
            latest_dt = rates[calc_idx].time;
            calcDelayed(calc_idx, rates);
            output_state_pre = tmp_pre;
            FDEBUG(DEBUG_PROGRAM, (__FUNCTION__ + " " + label +
                                       " in delay [%d, %d] => %f",
                                   nth, delay, getState()));
            calc_idx--; /// lastly
        }
        return true;
    }

    virtual bool update(const datetime dt, MqlRates &rates[], const datetime earliest)
    {

        FDEBUG(DEBUG_PROGRAM, (__FUNCTION__ + " %s update(%s, rates[%d], %s) [%s ... %s]",
                               label, toString(dt, true), ArraySize(rates),
                               toString(earliest, true),
                               toString(initial_dt, true),
                               toString(latest_dt, true)));

        if (earliest < initial_dt)
        {
            reinitialize(dt, rates, earliest);
        }

        if (dt > latest_dt)
        {

            /// update to the nearest rates tick at the provided dt
            const datetime ratesnewest = rates[0].time;
            if (dt > ratesnewest)
            {
                FDEBUG(DEBUG_PROGRAM, (label + ": Newest rates data is at %s, while %s was provided as reference time. Updating to newest available rates data",
                                       toString(ratesnewest, true),
                                       toString(dt, true)));
            }
            const int requested_idx = timeShift(dt, rates);
            const int prev_idx = timeShift(latest_dt, rates);
            if (prev_idx < requested_idx && latest_dt != INT_MIN)
            {
                const int count = requested_idx - prev_idx;
                FDEBUG(DEBUG_PROGRAM, (__FUNCTION__ + label +
                                           " Shift %d for update %s ... %s",
                                       count,
                                       toString(latest_dt, true),
                                       toString(dt, true)));
                shift(count);
            }

            while (latest_dt < dt)
            {

                FDEBUG(DEBUG_PROGRAM, (__FUNCTION__ + label +
                                           " Update [%d] from %s to %s",
                                       calc_idx,
                                       toString(latest_dt, true),
                                       toString(dt, true)));

                const bool updated = update(rates);
                if (!updated)
                {
                    printf("Update failed at %d [%s]",
                           calc_idx,
                           toString(rates[calc_idx].time, true));
                    return false;
                }
                if (calc_idx == 0)
                {
                    break; // FIXME this is a separate condition for end of iteration
                }
                calc_idx--;
            }
        }
        return true;
    }

    /// @brief
    /// @param idx
    /// @param rates
    /// @return true if an output value was calculated, else false
    virtual bool calcOutput(const int idx, MqlRates &rates[]) = 0; // FIXME double => T

    /// @brief process any values within the initial delay period of the filter.
    ///  The default implementation calls calcOutput(). Implementing classes
    ///  may override this method
    /// @param idx
    /// @param rates
    /// @return
    /// @see getInitDelay()
    virtual bool calcDelayed(const int idx, MqlRates &rates[])
    {
        return calcOutput(idx, rates);
    }

    /// @brief return the filter output value for the nearest index to a provided datetime,
    ///  updating if no value has been produced for that index
    /// @param dt
    /// @param rates
    /// @return
    virtual double valueAt(const datetime dt, MqlRates &rates[])
    {
        const bool updated = update(dt, rates, rates[0].time);
        if (!updated)
        {
            return EMPTY_VALUE;
        }
        // return getNthOutput(0);
        const int dtshift = timeShift(dt, rates);
        if (dtshift == EMPTY)
        {
            Print(__FUNCTION__ + " " + getDebugLabel() +
                  ": No matchig datetime found " +
                  toString(dt, true));
            return EMPTY_VALUE;
        }
        return get(dtshift);
    }

    virtual double valueAt(const int shift, MqlRates &rates[])
    {
        const datetime dt = rates[shift].time;
        return valueAt(dt, rates);
    }

    /// FIXME differentiate between inputState and outputState.
    /// Here, return a value in output state
    /// In this implementation, input state will not be stored beyond the previous input state
    virtual double getNthOutput(const int nth_pre, const int start = EMPTY) // FIXME double => T
    {
        /// NOTE this does not update the filter to the resulting index.

        // FIXME remove. use valueAt()

        const int latest = (start == EMPTY ? calc_idx : start);
        const int idx = latest + nth_pre;
        FDEBUG(DEBUG_CALC, (__FUNCTION__ + " %s (%d, %d) [%d, %d]", label, nth_pre, start, latest, idx));
        const double rslt = get(idx);
        // const double rslt = valueAt(idx, the_rates_array...);
        FDEBUG(DEBUG_CALC, (__FUNCTION__ + " %s => %f", label, rslt));
        return rslt;
    }

    virtual void recalcNewer(const datetime dt, MqlRates &rates[])
    {
        /// preliminary support for recalculating index 0 from latest
        /// quote data, in indicators and other programs
        ///
        /// - initial prototype in application: libSPriceFilt.mq4
        ///   in which the dt is provided to this function as the
        ///   quote time at index 1, when calculating index 0.
        ///
        ///   This function would be called before begining the
        ///   main calculation, if and only if the calculation
        ///   is to be produced at index 0.
        ///
        /// Not yet tested against network lag in quotes retrieval
        const int idx = timeShift(dt, rates);
        const datetime initial_latest = latest_dt;
        for (int n = idx; n > calc_idx; n--)
        {
            latest_dt = rates[n + 1].time;
            input_state_pre = calcInput(n + 1, rates);
            input_state = calcInput(n, rates);
            output_state_pre = valueAt(n + 1, rates);
            state_cur = valueAt(n, rates);
        }
        latest_dt = initial_latest;
    }
};

/// @brief a filter data source producing a single series of price values as output
class PriceFilter : public Filter
{
    const int price_mode; // price mode

protected:
    double calcInput(const int idx, MqlRates &rates[])
    {
        // NOP
        return EMPTY_VALUE;
    };

public:
    PriceFilter(const int _price_mode,
                Chartable *_chart_info,
                const string _label = NULL,
                const bool as_series = true,
                const bool managed = false) : price_mode(_price_mode),
                                              Filter(_chart_info,
                                                     _label,
                                                     as_series,
                                                     managed){};

    /// Implementation Note: This class will not free the chart_info pointer,
    /// considering that the pointer may represent an object implementing
    /// an indicator or other program object

    bool calcOutput(const int idx, MqlRates &rates[])
    {
        // FIXME add some way to apply debug tests for filters that e.g should not
        // produce a zero value, etc.
        FDEBUG(DEBUG_CALC, (__FUNCTION__ + " %s [%d %s]", getLabel(),
                            idx,
                            toString(rates[idx].time, true)))
        const double p = priceFor(rates[idx], price_mode);
        FDEBUG(DEBUG_CALC, (__FUNCTION__ + " %s [%d %s] => %f", getLabel(),
                            idx,
                            toString(rates[idx].time, true),
                            p));
        setState(p);
        return true;
    }

    virtual double getNthOutput(const int nth_pre, const int start = EMPTY)
    {
        // DEBUG
        const double rslt = Filter::getNthOutput(nth_pre, start);
        if (dblZero(rslt))
        {
            // FIXME => 0 for args (1, 0) and (0, 1)
            printf(__FUNCTION__ + " %s (%d, %d) => zero ", label, nth_pre, start);
        }
        return rslt;
    }
};

template <typename T>
class LinkedFilter : public Filter
{
protected:
    /// FIXME previous_filter should be stored here as const ....
    T previous_filter; // T should be a subtype of Filter

    // bool reinitialize(const datetime dt, MqlRates &rates[], const datetime earliest)
    // {
    //     /// TBD this may be leading to some redundant reinitialize() processes
    //     FDEBUG(DEBUG_PROGRAM, (__FUNCTION__ + " %s reinitialize(%s, rates[%d], %s)", label,
    //                            toString(dt, true),
    //                            ArraySize(rates),
    //                            toString(earliest, true)));
    //     if (!previous_filter.reinitialize(dt, rates, earliest))
    //     {
    //         printf(__FUNCTION__ + " %s Failed to reinitialize %s", label,
    //                previous_filter.getLabel());
    //         return false;
    //     }
    //     Filter::reinitialize(dt, rates, earliest);
    //     return true;
    // }

public:
    LinkedFilter(const string _label,
                 T previous) : previous_filter(previous),
                               Filter(previous.getChartInfo(),
                                      _label,
                                      previous.getAsSeries(),
                                      previous.getManagedP())
    {
        setExtent(previous.getExtent());
    };
    ~LinkedFilter()
    {
        FREEPTR(previous_filter);
    }

    double calcInput(const int idx, MqlRates &rates[])
    {
        /// should ensure calcOutput is called in the linked filter at most once,
        /// for the requested index ...
        return previous_filter.valueAt(idx, rates);
    }

    /// calling calcOutput on the linked filter, every time ...
    // double calcInput(const int idx, MqlRates &rates[])
    // {
    //     /// FIXME ensure that the previous linked filter will call its
    //     /// internal calcOutput function once, only if its current output
    //     /// state is not EMPTY_VALUE
    //     ///
    //     /// FIXME ensure date-time sync with the linked (previous) filter
    //     FDEBUG(DEBUG_PROGRAM, (__FUNCTION__ + " %s calcInput(%d, rates)", label, idx));
    //     if (previous_filter.calcOutput(idx, rates))
    //     {
    //         return previous_filter.getOutputState();
    //     }
    //     else
    //     {
    //         printf(__FUNCTION__ + " %s failure in %s ::calcOutput(%d, rates[%d]), using empty value", label,
    //                previous_filter.getLabel(),
    //                idx, ArraySize(rates));
    //         return EMPTY_VALUE;
    //     }
    // }

    void recalcNewer(const datetime dt, MqlRates &rates[])
    {
        previous_filter.recalcNewer(dt, rates);
        Filter::recalcNewer(dt, rates);
    }

    bool update(const datetime dt, MqlRates &rates[], const datetime earliest)
    {
        FDEBUG(DEBUG_PROGRAM, (__FUNCTION__ + " " + getDebugLabel() +
                                   " (%d, rates[%d], %d)",
                               toString(dt, true),
                               ArraySize(rates),
                               toString(earliest, true)));

        FDEBUG(DEBUG_PROGRAM, (__FUNCTION__ + " " + getDebugLabel() +
                                   " dispatch to update %s",
                               previous_filter.getLabel()));

        if (!previous_filter.update(dt, rates, earliest))
        {
            printf(__FUNCTION__ + " " + getDebugLabel() +
                       " (%d, rates[%d], %d) Initialization Failed for %s",
                   toString(dt, true),
                   ArraySize(rates),
                   toString(earliest, true),
                   previous_filter.getLabel());

            return false;
        }
        FDEBUG(DEBUG_PROGRAM, (__FUNCTION__ + " " + getDebugLabel() + " main update"));

        return Filter::update(dt, rates, earliest);
    }
};

template <typename T>
class SuperSmoother : public LinkedFilter<T>
{
    // abstract class
    // each implementating class derived from this class must provide a calcInput method
    // - example: mapping calcOutput() from PriceFilter to calcInput for this class,
    //   mainly after setting the linked filter as a PriceFilter

protected:
    const int period;

public:
    SuperSmoother(const int _period,
                  const string _label,
                  T previous) : period(_period),
                                LinkedFilter<T>(_label, previous){};

    /// four-tick initialization delay, while the linked filter
    /// produces a suitable number of input values for here,
    /// with this filter producing a suitable number of output
    /// values for the filter's calculation process.
    int getInitDelay() { return 4; }

    // FIXME should be a protected method
    bool calcOutput(const int idx, MqlRates &rates[])
    {
        if (input_state_pre == EMPTY_VALUE)
        {
            FDEBUG(DEBUG_CALC, (__FUNCTION__ + " %s [%d %s] previous input is empty (no output)",
                                label, idx,
                                toString(rates[idx].time, true)));
            return false;
        }
        else if (input_state == EMPTY_VALUE)
        {
            FDEBUG(DEBUG_CALC, (__FUNCTION__ + " %s [%d %s] current input is empty (no output)",
                                label, idx,
                                toString(rates[idx].time, true)));
            return false;
        }

        FDEBUG(DEBUG_CALC, (__FUNCTION__ + " %s [%d %s] in: %f in pre: %f ", label,
                            idx, toString(rates[idx].time, true), input_state,
                            input_state_pre));

        const double out_earlier = previous_filter.getOutputStatePre();
        const double out_pre = previous_filter.getOutputState();
        const double s = smoothed(period, input_state, input_state_pre, out_pre, out_earlier);

        FDEBUG(DEBUG_CALC, (__FUNCTION__ + " %s [%d %s] => %f", label,
                            idx, toString(rates[idx].time, true),
                            s));
        setState(s);
        return true;
    }
};

class SmoothedPrice : public SuperSmoother<PriceFilter *>
{

protected:
public:
    SmoothedPrice(const int _period,
                  const string _label,
                  PriceFilter *filt) : SuperSmoother<PriceFilter *>(_period, _label, filt){};
};

/// An application of John F. Ehlers' High Pass filter
///
/// @par Remarks
///
/// This filter class is implemented generally to be used as an input
/// to a Super Smoother filter. The combined filter pair may support
/// periods as short as 4.
///
/// @par References
///
/// Ehlers, J. F. (2013). The Hilbert Transformer. In Cycle Analytics
///   for Traders: Advanced Technical Trading Concepts (pp. 175–194).
///   John Wiley & Sons, Incorporated.
///
class HPPrice : public Filter
{
protected:
    const int price_mode;

public:
    HPPrice(const int _price_mode,
            Chartable *_chart_info,
            const string _label,
            const bool as_series = true,
            const bool managed = false) : price_mode(_price_mode),
                                          Filter(_chart_info, _label, as_series, managed)
    {
    }

    int getInitDelay() { return 5; }

    bool calcDelayed(const int idx, MqlRates &rates[])
    {
        /// NOP until the calc idx has advanced far enough for complete
        /// price information to be available to the output function
        const int start_idx = timeShift(initial_dt, rates);
        const int count = start_idx - idx;
        // printf("THUNK %d", count); // => -2, -1, 0, 1, 2 ...
        // ^ not always so ...
        if (count >= 2)
        {
            Filter::calcDelayed(idx, rates);
        }
        return true;
    }

    double calcInput(const int idx, MqlRates &rates[])
    {
        /// NOP. This filter provides a values source deriving directly
        /// from price information.
        ///
        /// The price information is applied within a three-period interval,
        /// internal to calcOutput()
        ///
        /// A futher adadptation may reimpelement this class as using a linked filter
        /// for inputs to the high-pass function. This would require additional caching
        /// in this class, for initializing and updating the third output value from
        /// the linked filter.
        ///
        /// The filters API, at present, provides a history of two ticks, for the
        /// inputs to each filter. ...
        return EMPTY_VALUE;
    }

    bool calcOutput(const int idx, MqlRates &rates[])
    {

        DEBUG(getLabel() + " " __FUNCTION__ + " (%d, rates[%d])", idx, ArraySize(rates));
        const double p0 = priceFor(idx, price_mode, rates);
        const double p1 = priceFor(idx + 1, price_mode, rates);
        const double p2 = priceFor(idx + 2, price_mode, rates);

        const double pre_0 = getState();
        const double pre_1 = output_state_pre;

        /// Constants for an application of John F. Ehlers' High Pass Filter
        ///
        /// Implementation note: If these constant factors were implemented and applied
        /// with preprocessor constants in MQL4, then the calculation would fail, in effect,
        /// though producing no obvious error message.
        ///
        /// The compiler would produce substantially different values for the factors
        /// of the calculation and hence for the application of the mathematical formula of
        /// the high-pass filter, if these factors were implemented as preprocessor constants.
        ///
        /// If applying those preprocessor constants instead, then the output series of the
        /// high-pass filter function would proceed promptly toward inifinity.
        ///
        static const double _hfact1_ = (sqrt(0.5) * 2.0 * M_PI) / 48.0;
        static const double _alph1_ = (cos(_hfact1_) + sin(_hfact1_)) / cos(_hfact1_);
        static const double _hpfact_ = pow(1.0 - (_alph1_ / 2.0), 2.0);
        static const double _malph1_ = 1.0 - _alph1_;
        static const double _msqalph1_ = pow(_malph1_, 2.0);

        const double f1 = (state_cur == EMPTY_VALUE ? DBLZERO : (2.0 * _malph1_ * pre_0));
        const double f2 = (output_state_pre == EMPTY_VALUE ? DBLZERO : (_msqalph1_ * pre_1));

        /// Application note: This filter will naturally produce negative values in its output
        /// series. The full series of values will consistently oscillate around 0, broadly in
        /// response to market rate changes.

        FDEBUG(DEBUG_CALC, (getLabel() + " " __FUNCTION__ +
                                " pre_0: %f pre_1: %f f1: %f f2: %f",
                            pre_0, pre_1,
                            f1, f2));

        const double hppart = (_hpfact_ * (p0 - (2.0 * p1) + p2));

        const double fact = hppart + f1 - f2;
        FDEBUG(DEBUG_CALC, (getLabel() + " " + __FUNCTION__ + " => %f (%f)", fact, hppart));

        setState(fact);
        return true;
    };
};

class SHPPrice : public SuperSmoother<HPPrice *>
{

public:
    SHPPrice(const int _period,
             const string _label,
             HPPrice *hpp) : SuperSmoother<HPPrice *>(_period, _label, hpp){};

    int getInitDelay() { return previous_filter.getInitDelay(); }
};

/// prototype for a trivial Mean filter
///
/// @par Known Limtiations
///
/// This filter would not provide any support for a moving average
template <typename T>
class MeanFilter : public LinkedFilter<T>
{
    /// abstract

protected:
    double meanfill[];
    const int period; /// TBD move the period var & getter to Filter

public:
    MeanFilter(const int _period,
               const string _label,
               T previous) : period(_period),
                             LinkedFilter<T>(_label, previous){};

    bool calcOutput(const int idx, MqlRates &rates[])
    {
        /// Implementation Note: output value here is comprised as a mean
        /// of the input filter's output values, and not as a moving average
        double sum = DBLZERO;
        for (int nth = 0; nth < period; nth++)
        {
            /// why every filter must implement value storage, an illustration:
            const double pre = previous_filter.getNthOutput(nth);
            meanFill[nth] = pre;
            sum += pre
        }
        setState(sum / (double)period);
        return true;
    }
};

template <typename T>
class WMAFilter : public LinkedFilter<T>
{

protected:
    const int period;

public:
    WMAFilter(const int _period,
              const string _label,
              T previous) : period(_period),
                            LinkedFilter<T>(_label, previous){};

    int getInitDelay()
    {
        return period;
    }

    virtual double getWeight(const int n, const int _period)
    {
        return weightFor(n, _period);
    }

    bool calcDelayed(const int idx, MqlRates &rates[])
    {
        /// NOP, Allowing the linked filter to accumulate values
        /// within the period of the moving average
        return true;
    }

    bool calcOutput(const int idx, MqlRates &rates[])
    {
        /// Implementation Note: output value here is comprised as a mean
        /// of the input filter's output values, and not as a moving average
        double ma = DBLZERO;
        double weights = DBLZERO;
        for (int shift = idx + period - 1, nth = 1; shift >= idx; shift--, nth++)
        {
            const double pre = previous_filter.valueAt(shift, rates);
            if (pre != EMPTY_VALUE)
            {
                const double wfactor = getWeight(nth, period);
                ma += (pre * wfactor);
                weights += wfactor;
            }
        }
        if (dblZero(weights))
        {
            setState(DBLEMPTY);
            // setState(DBLZERO);
        }
        ma /= weights;
        setState(ma);
        return true;
    }
};

/// @brief Standard Deviation filter
///
/// @par Applciations
/// - CCI
/// - Bollinger Bands
///
/// @par Implementation Notes
/// - [Ehlers]
template <typename T>
class MeanStandardDevFilter : public MeanFilter
{

protected:
    const double sd_period; // = period - 1

public:
    bool calcOutput(const int idx, MqlRates &rates[])
    {
        const double m = MeanFilter::calcOutput(idx, rates);
        double variance = DBLZERO;
        for (int nth = 0; nth < period; nth++)
        {
            DEBUG("sdev var [%d] %f", nth, variance);
            variance += pow(meanFill[nth] - m, 2);
        }
        setState(sqrt(variance / sd_period));
        return true;
    }
};

/// @brief Mean Deviation filter
///
/// @par Applciations
/// - The Other CCI
///
template <typename T>
class MeanDevFilter : public MeanFilter
{

protected:
public:
    bool calcOutput(const int idx, MqlRates &rates[])
    {
        const double m = MeanFilter::calcOutput(idx, rates);
        double dsum = DBLZERO;
        for (int nth = 0; nth < period; nth++)
        {
            DEBUG("sdev var [%d] %f", nth, variance);
            dsum += meanFill[nth] - m;
        }
        setState(dsum / period);
        return true;
    }
};

/// referring to the [Spectral Dilation] chapter ...
// class HPRoof : ...

class FilterContext // : public DataBufferList
{
    // FIXME also define a FilteredIndicator class

    /// TBD table of Chartable (chart info)
};

#endif