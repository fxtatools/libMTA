
#ifndef _RATES_MQ4
#define _RATES_MQ4 1

#property library
#property strict

#include "libMql4.mq4"
#include <stdlib.mqh>

/// @brief Abstract base class for indexed structures
class Indexed
{
protected:
    const bool managed_p;
    // const string label; /// for purpose of hash table storage & iteration, e.g for filter buffers


public:
    Indexed(const bool managed = true) : managed_p(managed)
    {
        /// One might not be able to call a virtual function within
        /// the ctor of the declaring class, in MQL4.
        ///
        // setExtent(_extent);
    }

    virtual bool setExtent(int len) = 0;
    virtual bool shiftExtent(int count) = 0;
    virtual int getExtent() = 0;

    virtual bool getManagedP()
    {
        return managed_p;
    }

};

/// @brief Base class for buffer implementations
/// @tparam T buffer value type
///
/// @par Implementation Notes
///
/// This API has not been tested for non-time-series data access
///
template <typename T>
class SeriesBuffer : public Indexed
{
protected:
    /// intermediate state storage for implementations.
    T state_cur;
    /// array-as-series flag
    const bool series_p;
    /// local caching for the data extent (may be removed)
    int extent;


public:
    T data[];

    SeriesBuffer(const int _extent = 0,
                 const bool as_series = true,
                 const bool managed = true) : Indexed(managed),
                                              extent(0),
                                              series_p(as_series)
    {
        ArraySetAsSeries(data, as_series);
    };
    ~SeriesBuffer()
    {
        ArrayFree(data);
    };

    bool getAsSeries() {
        return series_p;
    }

    bool getAsSeries() const {
        return series_p;
    }

    /// @brief set the length of this buffer's data array
    /// @param len new length for the data array
    /// @return true if the data was resized, else false
    bool setExtent(int len)
    {
        if (len == extent)
        {
            return true;
        }
        else if (managed_p)
        {
            extent = len;
            return true;
        }
        const int rslt = ArrayResize(data, len);
        if (rslt == -1)
        {
            extent = -1;
            return false;
        }
        extent = len;
        return true;
    };

    /// @brief resize the buffer's data array to extent + count, shifting all
    ///  array data points by the value of the count.
    /// @param count number of data points for the shift. A negative value will in effect
    ///  trim that many of the most recent elements the data array. To shrink the data
    //   array while trimming the least recent elements, refer to setExtent()
    /// @return true if the buffer extent was successfully changed,, else false.
    bool shiftExtent(int count)
    {
        if (count == 0 || managed_p)
        {
            return true;
        }

        ArraySetAsSeries(data, !series_p);
        const bool rslt = setExtent(extent + count);
        ArraySetAsSeries(data, series_p);
        return rslt;
    }

    bool shiftExtent() {
        return shiftExtent(1);
    }

    int getExtent()
    {
        return ArraySize(data);
    }

    T get(const int idx)
    {
        if (((debug_flags & DEBUG_PROGRAM) != 0) && (idx > getExtent()))
        {
            printf(__FUNCSIG__ + ": Buffer access for %d is further than extent %d", idx, getExtent());
        }
        return data[idx];
    };

    T getState()
    {
        return state_cur;
    }



    
    virtual void restoreFrom(const int idx)
    {
        state_cur = data[idx];
    }


    /// @brief store a referenced value or an object at a provided index in the
    ///  internal data buffer. This method will not change the current internal state
    /// @param idx the index for storage
    /// @param datum a reference to the value or object to store
    void storeState(const int idx, const T &datum)
    {
        if (((debug_flags & DEBUG_PROGRAM) != 0) && (idx > getExtent()))
        {
            printf(__FUNCSIG__ + ": Buffer access for %d is further than extent %d", idx, getExtent());
        }
        const T _cur = datum;
        data[idx] = _cur;
    };

    /// @brief store the current internal state at a provided index in the internal data buffer
    /// @param idx the index for storage
    void storeState(const int idx)
    {
        if (((debug_flags & DEBUG_PROGRAM) != 0) && (idx > getExtent()))
        {
            printf(__FUNCSIG__ + ": Buffer access for %d is further than extent %d", idx, getExtent());
        }
        data[idx] = getState();
    }


    /// @brief set the buffer's current internal state
    /// @param datum a reference to the value or object for the new state
    void setState(const T &datum)
    {
        const T _cur = datum;
        state_cur = _cur;
    };


};

template <typename T>
class ValueBuffer : public SeriesBuffer<T>
{
public:
    ValueBuffer(const int _extent = 0, const bool as_series = true, const bool managed = true) : SeriesBuffer(_extent, as_series, managed){};
};

template <typename T>
class ObjectBuffer : public SeriesBuffer<T>
{

public:
    ObjectBuffer(const int _extent = 0, const bool as_series = true) : SeriesBuffer(_extent, as_series){};

};

/// Buffer Lists

#include <dlib/Collection/LinkedList.mqh>
#include <dlib/Collection/Collection.mqh>

template <typename T>
class BufferMgr : public LinkedList<T>
{
protected:
    int extent;
    const bool series_p;
    const bool managed_p;

public:
    BufferMgr(const bool as_series = true,
              const bool managed = true) : series_p(as_series),
                                           managed_p(managed)
    {
    }

    /// LinkedList<T> provides a dtor via LinkedListBase<T>

    int getExtent()
    {
        return extent;
    }

    bool setExtent(const int ext)
    {

        if (ext != extent)
        {
            /// manual iterator, to set extent on all linked buffers
            int n = 0;
            T buf = get(n++);
            ResetLastError();
            while (buf != NULL)
            {
                if (!buf.setExtent(ext))
                {
                    const int errno = GetLastError();
                    printf(__FUNCSIG__ + "Failed to set extent %d for buffer %d", errno, ext, n);
                    printf("[%d] %s", errno, ErrorDescription(errno));
                    return false;
                }
                buf = get(n++);
            }
            extent = ext;
        }
        return true;
    }

    /// shift extent for every buffer, if not managed
    bool shiftExtent(const int count)
    {

        int n = 0;
        T buf = get(n++);
        int newext = extent;
        while (buf != NULL)
        {
            if (!buf.shiftExtent(count))
            {
                printf(__FUNCSIG__ + ": Failed to shift extent %d for buffer %d", count, n);
                return false;
            }
            newext = buf.getExtent();
            buf = get(n++);
        }
        // using the new extent from the last buffer
        // as the new extent for the buffer
        extent = newext;
        return true;
    }

    bool addBuffer(T &buf)
    {
        push(buf);
        if (!managed_p && !buf.setExtent(extent))
        {
            printf(__FUNCSIG__ + ": Failed to set extent %d when adding buffer", extent);
            return false;
        }
        else if (managed_p != buf.getManagedP())
        {
            printf(__FUNCSIG__ + ": Failed to add %s buffer to %s buffer manager", (managed_p ? "unmanaged" : "managed"), (managed_p ? "managed" : "unmanaged"));
            return false;
        }

        return true;
    }
};

template <typename T>
class ValueBufferList : public BufferMgr<ValueBuffer<T> *>
{
public:
    ValueBufferList(const bool as_series = true,
                    const int nr_buff = 0,
                    bool managed = true) : BufferMgr<ValueBuffer<T> *>(as_series, managed)
    {
        // printf("Initializing %d value buffers", nr_buff); // DEBUG
        for (int count = 0; count < nr_buff; count++)
        {
            // printf("Intiializing value buffer %d", count);
            ValueBuffer<T> *buf = new ValueBuffer<T>(0, as_series, managed_p);
            push(buf);
        }
    };

    ValueBuffer<T> *first()
    {
        /// may return null
        return get(0);
    }

    ValueBuffer<T> *nth(const int n)
    {
        /// may return null
        return get(n);
    }
};

class DataBufferList : public ValueBufferList<double>
{
public:
    DataBufferList(const bool as_series = true,
                   const int nr_buff = 0,
                   const bool managed = true) : ValueBufferList(as_series, nr_buff, managed){};
};

#endif
