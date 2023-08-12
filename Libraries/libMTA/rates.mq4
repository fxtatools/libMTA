
#ifndef _RATES_MQ4
#define _RATES_MQ4 1

#property library
#property strict

#ifndef QUOTE_PADDING
#define QUOTE_PADDING 512
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

template <typename T>
class DataBuffer
{
protected:
    virtual int extent_scale_padding(const int ext_diff, const int padding = QUOTE_PADDING)
    {
        return (((int)ceil(ext_diff / padding) + 1) * padding);
    }

    T initial_state; // intermediate state storage for implementations.
    // ^ MQL compiler fails to compile any pointer declaration `T *initial_state` here

public:
    int expand_extent;
    int extent;
    T data[];

    DataBuffer(const int _extent = 0, const bool as_series = true)
    {
        expand_extent = 0;
        setExtent(_extent);
        setAsSeries(as_series);
    };
    ~DataBuffer()
    {
        ArrayFree(data);
    };

    /// @brief increase the length of this and all linked data buffers
    /// @param len new length for linked data buffers
    /// @param value for padding. If a literal value, the value will be used as additional
    ///   buffer padding. if EMPTY, padding will be added under a factor of QUOTE_PADDING.
    ///   This value may be provided as 0, to indicate no padding.
    /// @return true if the data array for this and all linked buffers was resized, else false
    virtual bool setExtent(int len, const int padding = EMPTY)
    {
        if (len == extent)
        {
            return true;
        }
        else if (len >= expand_extent)
        {
            const int new_ext = (padding == EMPTY ? (expand_extent + extent_scale_padding(len - expand_extent)) : (len + padding));
            // DEBUG
            if (new_ext < len)
                printf("Data Buffer: %d => New extent %d is less than requested length %d (%d %f)", expand_extent, new_ext, len, extent_scale_padding(len - expand_extent), ceil((len - expand_extent) / QUOTE_PADDING));
            const int rslt = ArrayResize(data, new_ext);
            if (rslt == -1)
            {
                extent = -1;
                return false;
            }
            expand_extent = new_ext;
        }
        extent = len;
        return true;
    };

    /// @brief reduce the length of this and all linked data buffers
    /// @param len new length for linked data buffers
    /// @param value for padding. If a literal value, the value will be used as additional
    ///   buffer padding. if EMPTY, padding will be added under a factor of QUOTE_PADDING.
    ///   This value may be provided as 0, to indicate no padding.
    /// @return true if the data array for this and all linked buffers was resized, else false
    virtual bool reduceExtent(int len, const int padding = EMPTY)
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
            return true;
        }
    };

    /// @brief configure the and all linked data buffers to be accessed as/not as
    //  MetaTrader time-series data
    /// @param as_series boolean flag for MT4 ArraySetAsSeries()
    /// @return true if this and all linked buffers were set as series, else false.
    bool setAsSeries(const bool as_series = true)
    {
        return ArraySetAsSeries(data, as_series);
    };
};

template <typename T>
class ValueBuffer : public DataBuffer<T>
{

public:
    ValueBuffer(const int _extent = 0, const bool as_series = true) : DataBuffer(_extent, as_series){};

    T get(const int idx)
    {
        // unchecked call - this assumes that a value has been initialized
        // at idx and that the buffer's extent is > idx
        return data[idx];
    };

    T getState()
    {
        return initial_state;
    }

    void set(const int idx, const T datum)
    {
        // unchecked call - this assumes that the buffer's extent is > idx
        data[idx] = datum;
    };

    void set(const int idx) {
        // DEBUG(__FUNCSIG__ + "set(%d) extent %d len %d", idx, extent, ArraySize(data));
        data[idx] = getState();
    }

    void setState(const T datum)
    {
        initial_state = datum;
    };
};

template <typename T>
class LinkedBuffer : public ValueBuffer<T>
{
protected:

public:
    // pointer for the next linked buffer. This value is wholly untyped, 
    // to allow for linking with other linked indicator buffers, regardless
    // of th e data type for values stored in each.
    void *next_buffer;


    LinkedBuffer() : next_buffer(NULL){};

    LinkedBuffer(const int _extent = 0, const bool as_series = true) :  next_buffer(NULL), ValueBuffer<T>(_extent, as_series){};

    ~LinkedBuffer()
    {
        FREEPTR(next_buffer);
    };

    /// @brief retrieve the next buffer to this LinkedBuffer
    /// @return the next LinkedBuffer, or NULL if this linked buffer has not
    ///   been defined with a next buffer
    template <typename Tv>
    Tv *next()
    {
        // return next_buffer;
        // return dynamic_cast<LinkedBuffer<Tv>*>(next_buffer);
        return dynamic_cast<Tv*>(next_buffer);
    };

    /// @brief return the nth linked member of this LinkedBuffer series
    /// @param n relative index of the linked member
    /// @return this rate buffer when `n == 0`,
    //    else NULL when there is no next buffer,
    //    else the {n-1}th next buffer
    template <typename Tv>
    Tv *nth(const int n)
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
            // return dynamic_cast<LinkedBuffer<Tv>*>(next_buffer.nth(n - 1));
            return dynamic_cast<Tv*>(next_buffer.nth(n - 1));
        }
    };

    /// @brief return the last linked LinkedBuffer of this series
    /// @return this buffer, if the next buffer is NULL, else
    //    the last of the next buffer
    template <typename Tv>
    Tv *last(const int n)
    {
        if (next_buffer == NULL)
        {
            return &this;
        }
        else
        {
            // return dynamic_cast<LinkedBuffer<Tv>*>(next_buffer.last());
            return dynamic_cast<Tv*>(next_buffer.last());
        }
    };

    /// @brief set a LinkedBuffer as this buffer's next buffer
    /// @param next LinkedBuffer to set as this buffer's next buffer
    /// @return NULL if no rate buffer was previously defined as the next buffer,
    //   else the previously defined next buffer
    void setNext(void *next)
    {
        next_buffer = next;
    };

    /// @brief increase the length of this and all linked data buffers
    /// @param len new length for linked data buffers
    /// @param value for padding. If a literal value, the value will be used as additional
    ///   buffer padding. if EMPTY, padding will be added under a factor of QUOTE_PADDING.
    ///   This value may be provided as 0, to indicate no padding.
    /// @return true if the data array for this and all linked buffers was resized, else false
    virtual bool setExtent(int len, const int padding = EMPTY)
    {
        const bool rslt = DataBuffer<T>::setExtent(len, padding);
        if (rslt && (next_buffer != NULL))
            return (dynamic_cast<DataBuffer<T>*>(next_buffer)).setExtent(len, padding);
        else
            return rslt;
    };
    

    /// @brief reduce the length of this and all linked data buffers
    /// @param len new length for linked data buffers
    /// @param value for padding. If a literal value, the value will be used as additional
    ///   buffer padding. if EMPTY, padding will be added under a factor of QUOTE_PADDING.
    ///   This value may be provided as 0, to indicate no padding.
    /// @return true if the data array for this and all linked buffers was resized, else false
    virtual bool reduceExtent(int len, const int padding = EMPTY)
    {
        const bool rslt = DataBuffer<T>::reduceExtent(len, padding);
        if (rslt && (next_buffer != NULL))
            return (dynamic_cast<DataBuffer<T>*>(next_buffer)).reduceExtent(len, padding);
        else
            return rslt;
    };

    /// @brief configure the and all linked data buffers to be accessed as/not as
    //  MetaTrader time-series data
    /// @param as_series boolean flag for MT4 ArraySetAsSeries()
    /// @return true if this and all linked buffers were set as series, else false.
    virtual bool setAsSeries(const bool as_series = true)
    {
        const bool rslt = DataBuffer<T>::setAsSeries(as_series);
        if (rslt && (next_buffer != NULL))
            return (dynamic_cast<DataBuffer<T>*>(next_buffer)).setAsSeries(as_series);
        else
            return rslt;
    };
    
};

template <typename T>
class BufferMgr
{
public:
    // T *primary_buffer;
    void *primary_buffer; // untyped here, to work around some compiler features
    int extent;

    BufferMgr()
    {
        primary_buffer = NULL;
        extent = EMPTY;
    };
    ~BufferMgr()
    {
        FREEPTR(primary_buffer);
    };

    BufferMgr(const int _extent, const bool as_series = true) : extent(_extent)
    {
        primary_buffer = new T(_extent, as_series);
    };

    template <typename Tv>
    Tv* primaryBuffer() {
        // an ostensibly low-level feature of this data buffer API,
        // this method may generally require casting at the call site
        return dynamic_cast<Tv*>(primary_buffer);
    }

    virtual bool setExtent(const int _extent, const int padding = EMPTY)
    {
        if (_extent == extent)
            return true;
        const bool rslt = dynamic_cast<T*>(primary_buffer).setExtent(_extent, padding);
        if (rslt)
        {
            extent = _extent;
            return true;
        }
        return false;
    };

    virtual bool reduceExtent(const int _extent, const int padding = EMPTY)
    {
        if (_extent == extent)
            return true;
        const bool rslt = dynamic_cast<T*>(primary_buffer).reduceExtent(_extent, padding);
        if (rslt)
        {
            extent = _extent;
            return true;
        }
        return false;
    };
};

/// @brief Template class for Buffer Manager implementations
/// @tparam T DataBuffer implementation class for this Buffer Manager
template <typename T>
class LinkedBufferMgr : public BufferMgr<T>
{
public:
    LinkedBufferMgr(const int _extent = 0, const bool as_series = true, const int n_linked = 0)
    {
        extent = _extent;
        primary_buffer = new T(_extent, as_series, n_linked);
    };

   /*
    T *nth_buffer(const int n)
    {
        return primary_buffer.nth(n);
    };

    T *last_buffer()
    {
        return primary_buffer.last();
    };
    */
};

class PriceBuffer : public LinkedBuffer<double>
{
public:
    PriceBuffer(const int _extent = 0, const bool as_series = true, const int n_more = 0) : LinkedBuffer<double>(_extent, as_series)
    {
        if (n_more == 0)
        {
           // this.setNext(NULL);
            // this.clearNext();
            next_buffer = NULL;
        }
        else
        {
            this.setNext(new PriceBuffer(_extent, as_series, n_more - 1));
        }
    };

};

class PriceMgr : public LinkedBufferMgr<PriceBuffer>
{
public:
    PriceMgr(const int _extent = 0, const bool as_series = true, const int n_linked = 0) : LinkedBufferMgr<PriceBuffer>(_extent, as_series, n_linked){};
};

#endif
