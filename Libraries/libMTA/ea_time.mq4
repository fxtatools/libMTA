// ea_time.mq4 : Time utilities for EA programs
#ifndef _EA_TIME_MQ4
#define _EA_TIME_MQ4

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#property library
#property strict

extern const int early_minutes = 45; // Minutes to delay orders after 00:00 mkt today 
extern const int late_minutes = 45; // Minutes to delay orders before 00:00 mkt tomorrow

// parameters for late/early time checks    
const int late_seconds =  late_minutes * 60;
const int early_seconds = early_minutes * 60;

datetime zeroTimeTomorrow(MqlDateTime &mdt)
{
    TimeCurrent(mdt);
    mdt.hour = 0;
    mdt.min = 0;
    mdt.sec = 0;
    mdt.day++;
    return StructToTime(mdt);
}

datetime zeroTimeTomorrow()
{
    MqlDateTime mdt();
    return zeroTimeTomorrow(mdt);
}

datetime zeroTimeToday(MqlDateTime &mdt)
{
    TimeCurrent(mdt);
    mdt.hour = 0;
    mdt.min = 0;
    mdt.sec = 0;
    return StructToTime(mdt);
}

datetime zeroTimeToday()
{
    MqlDateTime mdt();
    return zeroTimeToday(mdt);
}

// Implementation note: mdt here does not provide the time to check.
// This function may support reusing an MqlDateTime, here modifying
// the structure in order to check the provided datetime value
bool inLateSeconds(MqlDateTime &mdt, const datetime whence = EMPTY)
{
    if (late_seconds == 0)
    {
        return false;
    }
    const datetime checktime = whence == EMPTY ? TimeCurrent() : whence;
    const datetime zdt = zeroTimeTomorrow(mdt);
    return (checktime <= zdt) && (checktime >= (zdt - late_seconds));
}

bool inLateSeconds(const datetime whence = EMPTY)
{
    if (late_seconds == 0)
    {
        return false;
    }
    MqlDateTime mdt();
    return inLateSeconds(mdt, whence);
}

bool inEarlySeconds(MqlDateTime &mdt, const datetime whence = EMPTY)
{
    if (late_seconds == 0)
    {
        return false;
    }
    const datetime checktime = whence == EMPTY ? TimeCurrent() : whence;
    const datetime zdt = zeroTimeToday(mdt);
    return (checktime >= zdt) && (checktime <= (zdt + early_seconds));
}

bool inEarlySeconds(const datetime whence = EMPTY)
{
    if (late_seconds == 0)
    {
        return false;
    }
    MqlDateTime mdt();
    return inEarlySeconds(mdt, whence);
}


#endif
