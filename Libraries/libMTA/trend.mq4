#ifndef _TREND_MQ4
#define _TREND_MQ4 1

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#property library
#property strict

#include "indicator.mq4"

template <typename T>
class TrendBase
{
    // Implementation note: "Near" values will generally have a lower index
    // than "Far" values here

protected:
    datetime t_near;
    datetime t_far;
    T near_a;
    T far_a;

public:
    TrendBase()
    {
        clear();
    }

    virtual void clear()
    {
        t_near = 0;
        t_far = 0;
        near_a = EMPTY_VALUE;
        far_a = EMPTY_VALUE;
    }

    virtual datetime nearTime()
    {
        return t_near;
    }

    virtual datetime farTime()
    {
        return t_far;
    }

    virtual T nearVal()
    {
        return near_a;
    }

    virtual T farVal()
    {
        return far_a;
    }

    virtual bool bind(T near_val, T far_val, datetime near_t, datetime far_t)
    {
        near_a = near_val;
        far_a = far_val;
        t_near = near_t;
        t_far = far_t;
        return true;
    }
};

template <typename T>
class ReversalBase : public TrendBase<T>
{
protected:
    T minmax;
    bool is_max;

public:
    virtual void clear()
    {
        TrendBase<T>::clear();
        minmax = EMPTY_VALUE;
        is_max = false;
    }

    virtual bool isMaximum()
    {
        return is_max;
    }

    virtual T minmaxVal() {
        return minmax;
    }

    virtual bool bind(T extval, bool max_p, T near, T far, datetime near_t, datetime far_t)
    {
        minmax = extval;
        is_max = max_p;
        TrendBase<T>::bind(near, far, near_t, far_t);
        return true;
    }
};

template <typename T>
class CrossoverBase : public TrendBase<T>
{

protected:
    T near_b;
    T far_b;

public:
    T nearValB()
    {
        return near_b;
    };

    T farValB()
    {
        return far_b;
    }

    virtual void clear()
    {
        TrendBase<T>::clear();
        near_b = EMPTY_VALUE;
        near_a = EMPTY_VALUE;
    }

    virtual bool bind(T _near_a, T _far_a, T _near_b, T _far_b, datetime near_t, datetime far_t)
    {
        near_b = _near_b;
        far_b = _far_b;
        return TrendBase<T>::bind(_near_a, _far_a, near_t, far_t);
    }

    
    virtual bool bind(const T &data_a[], const T &data_b[], Chartable &chartinfo, const int start = 0, const int far = EMPTY)
    {
        const int last = (far == EMPTY ?  fmin(ArraySize(data_a), ArraySize(data_b)) - 1 : far);

        bool found = false;
        double a_cur, b_cur;

        if (start >= last)
            return false;

        double a_nr = data_a[start]; // originally for +DI
        double b_nr = data_b[start]; // originally for -DI

        for (int n = start + 1; n <= last; n++)
        {
            a_cur = data_a[n];
            b_cur = data_b[n];

            if ((a_nr > b_nr) && (a_cur < b_cur))
            {
                found = true;
                // sell_trend = false;
            }
            else if ((a_nr < b_nr) && (a_cur > b_cur))
            {
                found = true;
                // sell_trend = true;
            }

            if (found)
            {
                const int tf = chartinfo.getTimeframe();
                const string s = chartinfo.getSymbol();
                t_near = offset_time(n, s, tf);
                t_far = offset_time(n - 1, s, tf);
                // bind(a_cur, a_nr, b_cur, b_nr, t_near, t_far);
                bind(a_nr, a_cur, b_nr, b_cur, t_near, t_far);
                return true;
            }
            else
            {
                a_nr = a_cur;
                b_nr = b_cur;
            }
        }
        return false;
    };


    virtual T rate()
    {
        // determine the effective level of +DI/-DI crossover,
        // using a linear transformation onto any bound
        // time and rates data
        //
        // for calculating an intersection in a linear space,
        // for the extension of two line sections
        // https://alienryderflex.com/intersect/
        //
        // For MQL5, which provides a determinant function, refer to
        // https://stackoverflow.com/a/51781408/1061095

        if (t_near == 0)
            return DBLZERO;

        // line 1 in system
        T a_bgn = nearVal();
        T a_end = farVal();
        // line 2 in sysetm
        T b_bgn = nearValB();
        T b_end = farValB();

        // translate the system so the start is at origin
        const datetime shift_end = farTime() - nearTime();
        const T val_shift = b_bgn < a_bgn ? b_bgn : a_bgn;
        a_bgn -= val_shift;
        a_end -= val_shift;
        b_bgn -= val_shift;
        b_end -= val_shift;

        // calculate the value at translated crossover
        const T slope_p = (a_end - a_bgn) / shift_end;
        const T slope_m = (b_end - b_bgn) / shift_end;

        // find x, where:
        //   slope_p * x + a_bgn = slope_m * x + b_bgn
        const T xover_dt = (b_bgn - a_bgn) / (slope_p - slope_m);

        // calculate y = mx + b and return the de-shifted value
        const T shifted_val = (slope_p * xover_dt) + a_bgn;
        return shifted_val + val_shift;
    }
};

class PriceXOver : public CrossoverBase<double>
{
protected:
    bool _bearish;

public:

    virtual bool bearish() {
        return _bearish;
    }

    virtual void setBearish(const bool bearish_p) {
        _bearish = bearish_p;
    }

    virtual bool bind(const bool bearish_p, const double _near_a, const double _far_a, const double _near_b, const double _far_b, const datetime near_t, const datetime far_t)
    {
        if (!CrossoverBase<double>::bind(_near_a, _far_a, _near_b, _far_b, near_t, far_t))
            return false;
        setBearish(bearish_p);
        return true;
    }

};

class PriceReversal : public ReversalBase<double>
{
public:
};

class VolReversal : public ReversalBase<long>
{
public:
};

#endif