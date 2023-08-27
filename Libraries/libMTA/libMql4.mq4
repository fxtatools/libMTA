//+------------------------------------------------------------------+
//|                                                      libMql4.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

#ifndef _LIBMQL4_MQ4
#define _LIBMQL4_MQ4 1

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#include <stdlib.mqh>

#property copyright "Copyright 2023, Sean Champ"
#property link "https://www.example.com/nop"
#property library
#property strict

#ifndef THIS_CAST
#define THIS_CAST(_typ_) dynamic_cast<_typ_ *>(GetPointer(this))
#endif

#ifndef DBLZERO_DEFINED
#define DBLZERO_DEFINED 1
static const double __dblzero__ = 0.0;
#ifndef DBLZERO
#define DBLZERO __dblzero__
#endif
#endif

#ifndef DBLEMPTY_DEFINED
#define DBLEMPTY_DEFINED 1
static const double __dblempty__ = EMPTY_VALUE;
#ifndef DBLEMPTY
#define DBLEMPTY __dblempty__
#endif
#endif

#ifndef DEBUG

/// after the enum example in
/// https://stackoverflow.com/a/33971769/1061095
///
/// if implemented as preprocessor constants,
/// the values would not need to be coerced
/// to int (e.g for ctors)

enum DEBUG_FLAGS
{
    DEBUG_NONE = 0,                        // No Debugging
    DEBUG_PROGRAM = (1 << 0),              // Program Features
    DEBUG_CALC = (1 << 1) & DEBUG_PROGRAM, // Calculations (Verbose)
};

// extern int debug_flags = 0; // Debug Flags

extern DEBUG_FLAGS debug_flags = DEBUG_NONE; // Debug Level

bool debugLevel(const int flag)
{
    return ((debug_flags & flag) != 0);
};

#define DEBUG        \
    if (debug_flags) \
    printf

/// FIXME redefine all DEBUG calls as FDEBUG
/// then remove DEBUG and rename FDEBUG => DEBUG

/// conditional debug
/// - syntax e.g: FDEBUG(DEBUG_CALC, (__FUNCTION__ + " %s calc %d %f", label, idx, val));
#define FDEBUG(_fl_, _expr_)         \
    if ((debug_flags & (_fl_)) != 0) \
    {                                \
        printf _expr_;               \
    }

/// implemented absent of varargs macro support in MQL4
/// - cannot inject the __FUNCTION__ label in FDEBUG
/// - cannot extend FDEBUG for any implementing class

#endif

#ifndef DELPTR
#define DELPTR(_PTR_)                           \
    if (CheckPointer(_PTR_) == POINTER_DYNAMIC) \
    {                                           \
        delete _PTR_;                           \
    }
#endif

#ifndef FREEPTR
#define FREEPTR(_PTR_) \
    if (_PTR_ != NULL) \
    {                  \
        DELPTR(_PTR_); \
        _PTR_ = NULL;  \
    }
#endif

void printError(const string message = NULL, const int errno = EMPTY)
{
    const int ecode = (errno == EMPTY ? GetLastError() : errno);
    printf("[%d] %s" + (message == NULL ? "" : ": " + message), ecode, ErrorDescription(ecode));
}

#ifndef ERRMSG
/// print a formatted error messaage
///
/// Syntax: This macro should be referenced as e.g
///
///   ERRMSG(("[%d] static text %s", intarg, strarg))
///
/// This may serve as a sort of a partial workaround after
/// the absence of any varargs macro support in MQL4
///
/// See also: ERRMSGC
#define ERRMSG(_EXPR_) printError((StringFormat _EXPR_))
#endif

#ifndef ERRMSGC
/// print a formatted error message with error code
///
/// See also: ERRMSG
#define ERRMSGC(_EXPR_, _ECODE_) printError((StringFormat _EXPR_), (_ECODE_))
#endif

/// @brief return a value for geometric weighting, with weights produced in the
//   form of a quadrant of an ellipse
/// @param n initial index for the weights sequence, generally beginning with 1
/// @param period period for the containing moving average
/// @param b_factor elliptical 'b' factor. Higher values will result in wider
///  scaling. The largest scaled weight will not be greater than one plus this value.
/// @return the numeric weight for the provided input factors
double weightFor(const int n, const int period, const double b_factor = 1.1)
{
    // generally weight = sqrt(B^2 ( 1 - ( ( N  - P/2 )^2 ) / (P/2)^2 )) + 1

    if (((debug_flags & DEBUG_PROGRAM) != 0) && (n > period))
    {
        printf(__FUNCSIG__ + " Received index value %d greater than period %d", n, period);
    }
    /// convention in the codebase has been to begin the weight index at 1,
    /// for index <= period
    ///
    /// this method of geometric scaling begins with an initial index 0
    /// for index < period
    const double n_zero = n - 1;
    // const double a_factor = period/2; // providing a higher weight to middle values
    const double a_factor = period; // providing a higher weight to most recent values
    return sqrt(pow(b_factor, 2) * (1 - pow((n_zero - a_factor), 2) / pow((a_factor), 2))) + 1;
}

#include "pricemode.mq4"

#ifndef TIME_COMPLETE
#define TIME_COMPLETE TIME_DATE | TIME_MINUTES | TIME_SECONDS
#endif

/**
 * Return the time at a given offset, as a single datetime value
 **/
datetime offset_time(const int shift, const string symbol = NULL, const int timeframe = EMPTY)
{
    datetime dtbuff[1];
    const string s = symbol == NULL ? _Symbol : symbol;
    const int tf = timeframe == EMPTY ? _Period : timeframe;
    CopyTime(s, tf, shift, 1, dtbuff);
    return dtbuff[0];
};

string offset_time_str(const int shift, const string symbol = NULL, const int timeframe = EMPTY)
{
    return TimeToStr(offset_time(shift, symbol, timeframe));
};

/// @brief return an index for a provided datetime value whitn an MqlRates array
/// @param dt the datetime value for search
/// @param rates the rates array for search
/// @param extent length for the search. If not provided, the size of the rates array will be used
/// @param accuracy accuracy for the search, in units of seconds. If not provded, the search will use one half the difference of times in the first two indexes of the provided rates array
/// @return the index for the nearest matching time, or -1 if no match is found
int timeShift(const datetime dt, MqlRates &rates[], const int extent = EMPTY, const int accuracy = EMPTY)
{
    // inspired by the implementation of BinarySearch<T> in dlib/Lang/Array.mqh
    // with further reference to https://www.geeksforgeeks.org/binary-search/
    //
    // this implementation assumes that the rates array is configured for
    // time-series access
    const int acsy = accuracy == EMPTY ? (int)floor((rates[0].time - rates[1].time) / 2) : accuracy;
    const int last = ArraySize(rates) - 1;
    int rhs = (extent == EMPTY ? last : extent);
    int lhs = 0, mid = 0;
    bool foundp = false;
    while (lhs <= rhs)
    {
        mid = rhs + ((lhs - rhs) / 2);

        const datetime mtime = rates[mid].time;
        if (mtime == dt)
        {
            return mid;
        }
        const int preidx = mid == last ? mid : mid + 1;
        const int nextidx = mid == 0 ? 0 : mid - 1;
        const datetime predt = rates[preidx].time;
        const datetime nextdt = rates[nextidx].time;
        if (((dt - predt) <= acsy) && (nextdt - dt) <= acsy)
        {
            return mid;
        }
        else if ((mtime + acsy >= dt) && (mtime - acsy <= dt))
        {
            return mid;
        }

        /// the binary search logic is inverted here, due to the
        /// characteristics of datetime values in time series,
        /// such that A > B for A being a datetime more recent than B
        /// while the time series index for A < the index for B
        if ((mtime < (dt + acsy) || mtime < (dt - acsy)))
        {

            // lhs = mid + 1;
            rhs = mid - 1;
        }
        else
        {
            // rhs = mid - 1;
            lhs = mid + 1;
        }
    }
    // DEBUG(__FUNCSIG__ + " No Result %s ... %s", toString(dt), toString(rates[mid].time));
    return EMPTY;
}

bool dblEql(const double d1, const double d2)
{
    // for high-precision comparison with float values, see also
    // https://randomascii.wordpress.com/2012/02/25/comparing-floating-point-numbers-2012-edition/
    //// symbol-dependent
    // return NormalizeDouble(fabs(d2 - d1), Digits) == 0;
    //// symbol-independent
    return fabs(d2 - d1) <= DBL_EPSILON;
};

bool dblZero(const double d)
{
    return ((d == DBLZERO) || dblEql(d, DBLZERO));
};

//
// EMA
//

// utility function for Standard EMA
double ema_factor(const double period)
{
    return (2.0 / (sqrt(period) + 1.0));
};

// calculate the conventioanl exponential moving average of a
// previous value and current over a fixed period
double ema(const double pre, const double cur, const double period)
{
    // references:
    // Pruitt, G. (2016). Stochastics and Averages and RSI! Oh, My.
    // In The Ultimate Algorithmic Trading System Toolbox + Website (pp. 25–76).
    // John Wiley & Sons, Inc. https://doi.org/10.1002/9781119262992.ch2
    // https://en.wikipedia.org/wiki/Exponential_smoothing
    // https://www.investopedia.com/ask/answers/122314/what-exponential-moving-average-ema-formula-and-how-ema-calculated.asp

    // return ((cur - pre) * ema_factor(period)) + pre;

    /// Referncing Ehlers:
    const double fact = ema_factor(period);
    return ((fact * cur)) + ((1 - fact) * pre);
};

/// @brief an application of John F. Ehlers' Super Smoother filter,
///  adapted here for MQL4
///
/// @par References
///
/// Ehlers, John. F. (2013). The Hilbert Transformer. In Cycle Analytics
///   for Traders: Advanced Technical Trading Concepts (pp. 175–194). 
///   John Wiley & Sons, Incorporated.
///
/// @param period period for the smoothed data series
/// @param in0 the current output value from some function applied to the data series
/// @param in1 the next recent output value from some function applied to the data series,
//    or EMPTY_VALUE
/// @param out0 nearest previous ouput value from smoothed(), or EMPTY_VALUE
/// @param out1 next previous ouput value from smoothed(), or EMPTY_VALUE
/// @return the output value of the Super Smoother filter, in this MQL4 adaptation
double smoothed(const int period, const double in0, const double in1 = EMPTY_VALUE, const double out0 = EMPTY_VALUE, const double out1 = EMPTY_VALUE)
{
    /// implementation note: Porting from EasyLanguage
    /// - Trignometric functions in EasyLanguage would return values in degrees
    /// - in MQL4, trigonmetic functions are implemented to use radians
    const double p = (double)period;
    static const double sqr2 = sqrt(2);
    static const double fact1 = (-sqr2) * M_PI;
    static const double fact2 = sqr2 * M_PI;
    const double a = exp(fact1 / p);
    const double b = 2.0 * a * cos(fact2 / p);
    const double c2 = b;
    const double c3 = (-a) * a;
    const double c1 = 1.0 - c2 - c3;
    return (c1 * ((in1 == (double)EMPTY_VALUE || in0 == in1) ? in0 : ((in0 + in1) / 2.0))) + (out0 == (double)EMPTY_VALUE ? DBLZERO : (c2 * out0)) + (out1 == (double)EMPTY_VALUE ? DBLZERO : (c3 * out1));
}

// calculate a shifted EMA for a previous value and current
// value over a fixed period
//
// a shift of 1 produces an EMA in the method of ADX EMA developed
// originally by Welles Wilder
//
//
// general formula:
//   (pre * (period - shift) + (cur * shift)) / period
//
double emaShifted(const double pre, const double cur, const double period, const double shift = 1.0)
{
    // an optionally shifted variant of the ADX EMA [Wilder]
    //
    // This differs significantly to the EMA calculation used above,
    // which is applied in the RSIpp indicator to an effect of
    // substantial smoothing of the RSI line.
    const double shifted_period = period - shift;
    return ((pre * shifted_period) + (cur * shift)) / period;
};

// calculate the mean of values in a provided data arrary
double mean(const double period, double &data[], const int start = 0)
{
    double sum = DBLZERO;
    for (int n = start, p = 0; p < period; n++, p++)
    {
        sum += data[n];
    }
    return sum / period;
}

// calculate the standard deviation of values in a provided data arrary
//
// if a mean is provided, this value will be used as the mean for
// the calculation of standard deviation. If mean is EMPTY, the mean
// will be calcualted as with mean()
double sdev(const double period, double &data[], const int start = 0, const double _mean = (double)EMPTY_VALUE)
{
    const double m = (_mean == (double)EMPTY_VALUE ? mean(period, data, start) : _mean);
    double variance = DBLZERO;
    for (int n = start, p = 0; p < period; n++, p++)
    {
        FDEBUG(DEBUG_CALC, ("sdev var [%d] %f", n, variance));
        variance += pow(data[n] - m, 2);
    }
    variance /= (double)(period - 1);
    return sqrt(variance);
}

// calculate the mean of price for a provided extent within open,
// high, low, and close quote data
double mean(const int period, const int price_mode, const double &open[], const double &high[], const double &low[], const double &close[], const int start = 0)
{
    double sum = DBLZERO;
    for (int n = start, p = 0; p < period; n++, p++)
    {
        sum += priceFor(n, price_mode, open, high, low, close);
    }
    return sum / (double)period;
}

// calculate the standard deviation of price within open, high, low
// and close quote data
//
// if a mean is provided, this value will be used as the mean for
// the calculation of standard deviation. If mean is EMPTY, the mean
// will be calcualted as with mean()
double sdev(const int period, const int price_mode, const double &open[], const double &high[], const double &low[], const double &close[], const int start = 0, const double _mean = (double)EMPTY_VALUE)
{
    const double m = (_mean == (double)EMPTY_VALUE ? mean(period, price_mode, open, high, low, close, start) : _mean);
    double variance = DBLZERO;
    for (int n = start, p = 0; p < period; n++, p++)
    {
        variance += pow(priceFor(n, price_mode, open, high, low, close) - m, 2);
    }
    variance /= (double)(period - 1);
    return sqrt(variance);
}

// calculate the mean of price for a provided extent within open,
// high, low, and close quote data
double mean(const int period, const int price_mode, MqlRates &rates[], const int start = 0)
{
    double sum = DBLZERO;
    for (int n = start, p = 0; p < period; n++, p++)
    {
        sum += priceFor(n, price_mode, rates);
    }
    return sum / (double)period;
}

// calculate the standard deviation of price within open, high, low
// and close quote data
//
// if a mean is provided, this value will be used as the mean for
// the calculation of standard deviation. If mean is EMPTY, the mean
// will be calcualted as with mean()
double sdev(const int period, const int price_mode, MqlRates &rates[], const int start = 0, const double _mean = (double)EMPTY_VALUE)
{
    const double m = (_mean == (double)EMPTY_VALUE ? mean(period, price_mode, rates, start) : _mean);
    double variance = DBLZERO;
    for (int n = start, p = 0; p < period; n++, p++)
    {
        variance += pow(priceFor(n, price_mode, rates) - m, 2);
    }
    variance /= (double)(period - 1);
    return sqrt(variance);
}

// debugging support

string toString(const bool value)
{
    return value ? "True" : "False";
}

string toString(const int value)
{
    return IntegerToString(value);
}

string toString(const double value)
{
    return DoubleToString(value);
}

string toString(const string str)
{
    return str;
}

string toString(const datetime dt, int flags)
{
    return TimeToString(dt, flags);
}

string toString(const datetime dt, bool complete = false)
{
    return TimeToString(dt, complete ? (TIME_COMPLETE) : (TIME_DATE | TIME_MINUTES));
}

//
// Trivial Debugging support - ALERT + StringFormat macros
//

#ifndef ALERTF_1
#define ALERTF_1(_MSG_, _ARG1_) Alert(StringFormat(_MSG_, _ARG1_))
#endif

#ifndef ALERTF_2
#define ALERTF_2(_MSG_, _ARG1_, _ARG2_) Alert(StringFormat(_MSG_, _ARG1_, _ARG2_))
#endif

#ifndef ALERTF_3
#define ALERTF_3(_MSG_, _ARG1_, _ARG2_, _ARG3_) Alert(StringFormat(_MSG_, _ARG1_, _ARG2_, _ARG3_))
#endif

#ifndef ALERTF_4
#define ALERTF_4(_MSG_, _ARG1_, _ARG2_, _ARG3_, _ARG4_) Alert(StringFormat(_MSG_, _ARG1_, _ARG2_, _ARG3_, _ARG4_))
#endif

// ...

#endif
