

#ifndef _RATES_MQ4
#define _RATES_MQ4 1

#ifndef QUOTE_PADDING
#define QUOTE_PADDING 128
#endif

#ifndef DELPTR
#define DELPTR(_PTR_) \
    if (CheckPointer(_PTR_) == POINTER_DYNAMIC) { \
        delete _PTR_; \
    }
#endif

#ifndef FREEPTR
#define FREEPTR(_PTR_) \
    if (_PTR_ != NULL) { \
        DELPTR(_PTR_); \
        _PTR_ = NULL; \
    }
#endif

class RateBuffer
{
protected:
    virtual int extent_scale_padding(const int ext_diff, const int padding = QUOTE_PADDING)
    {
        return (int)(ceil(ext_diff / padding) * padding);
    }
    RateBuffer *next_buffer;

public:
    int expand_extent;
    int extent;
    double data[];

    RateBuffer(const int _extent = 0, const bool as_series = true, const int n_more = 0)
    {
        expand_extent = 0;
        setExtent(_extent);
        setAsSeries(as_series);
        if (n_more == 0)
        {
            next_buffer = NULL;
        }
        else
        {
            next_buffer = new RateBuffer(_extent, as_series, n_more - 1);
        }
    };
    ~RateBuffer()
    {
        ArrayFree(data);
        FREEPTR(next_buffer);
    };

    /// @brief retrieve the next buffer this RateBuffer
    /// @return the next RateBuffer, or NULL if this rate buffer has not
    ///  been defined with a next buffer
    RateBuffer *next()
    {
        return next_buffer;
    }

    /// @brief return the nth linked member of this linked RateBuffer series
    /// @param n relative index of the linked member
    /// @return this rate buffer if `n == 0`,
    //   else NULL if there is no next buffer,
    //   else the {n-1}th next buffer
    RateBuffer *nth(const int n)
    {
        if (n == 0)
        {
            return &this;
        }
        else if (next_buffer == NULL)
        {
            return NULL;
        }
        else
        {
            return next_buffer.nth(n - 1);
        }
    };

    /// @brief return the last linked RateBuffer of this series
    /// @return this buffer, if the next buffer is NULL, else 
    //    the last of the next buffer
    RateBuffer *last() {
        if (next_buffer == NULL) {
            return &this;
        } else {
            return next_buffer.last();
        }
    }

    /// @brief set a RateBuffer as this buffer's next buffer
    /// @param next RateBuffer to set as this buffer's next buffer
    /// @return NULL if no rate buffer was previously defined as the next buffer,
    //   else the previously defined next buffer
    RateBuffer *setNext(RateBuffer *next)
    {
        RateBuffer *prev_next = next_buffer;
        next_buffer = next;
        return prev_next;
    }

    /// @brief increase the length of this and all linked data buffers
    /// @param len new length for linked data buffers
    /// @param value for padding. If a literal value, the value will be used as additional
    ///   buffer padding. if EMPTY, padding will be added under a factor of QUOTE_PADDING. 
    ///   This value may be provided as 0, to indicate no padding.
    /// @return true if the data array for this and all linked buffers was resized, else false
    bool setExtent(int len, const int padding = EMPTY)
    {
        if (len == extent)
        {
            return true;
        }
        else if (len >= expand_extent)
        {
            const int new_ext = (padding == EMPTY ? (expand_extent + extent_scale_padding(len - expand_extent)) : (len + padding));
            const int rslt = ArrayResize(data, new_ext);
            if (rslt == -1)
            {
                extent = -1;
                return false;
            }
            expand_extent = new_ext;
        }
        extent = len;

        if (next_buffer == NULL)
            return true;
        else
            return next_buffer.setExtent(len, padding);
    }

    /// @brief reduce the length of this and all linked data buffers
    /// @param len new length for linked data buffers
    /// @param value for padding. If a literal value, the value will be used as additional
    ///   buffer padding. if EMPTY, padding will be added under a factor of QUOTE_PADDING. 
    ///   This value may be provided as 0, to indicate no padding.
    /// @return true if the data array for this and all linked buffers was resized, else false
    bool reduceExtent(int len, const int padding = EMPTY)
    {
        const int reduced = (padding == EMPTY ? extent_scale_padding(len) : (len + padding));
        const int rslt = ArrayResize(data, reduced);
        if (rslt == -1)
        {
            extent = -1;
            return false;
        }
        else
        {
            extent = len;
            expand_extent = reduced;
            if (next_buffer == NULL)
                return true;
            else
                return next_buffer.setExtent(len, padding);
        }
    }

    //

    /// @brief configure the and all linked data buffers to be accessed as/not as
    //  MetaTrader time-series data
    /// @param as_series boolean flag for MT4 ArraySetAsSeries()
    /// @return true if this and all linked buffers were set as series, else false.
    bool setAsSeries(const bool as_series = true)
    {
        const bool set_p = ArraySetAsSeries(data, as_series);
        if (set_p && (next_buffer != NULL))
            return next_buffer.setAsSeries(as_series);
        else
            return set_p;
    }
};

class BufferMgr
{
public:
    RateBuffer *first_buffer;

    BufferMgr(const int extent = 0, const bool as_series = true, const int n_linked = 0)
    {
        if (CheckPointer(first_buffer) == POINTER_INVALID) {
            first_buffer = NULL;
        }
    }
    ~BufferMgr()
    {
        FREEPTR(first_buffer);
    };

    RateBuffer *nth_buffer(const int n)
    {
        return first_buffer.nth(n);
    };

    RateBuffer *last_buffer() 
    {
        return first_buffer.last();
    }

    virtual bool setExtent(const int extent, const int padding = EMPTY)
    {
        return first_buffer.setExtent(extent, padding);
    };

    virtual bool reduceExtent(const int extent, const int padding = EMPTY)
    {
        return first_buffer.reduceExtent(extent, padding);
    };
};

#endif