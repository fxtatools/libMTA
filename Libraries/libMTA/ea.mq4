#ifndef _EA_MQ4
#define _EA_MQ4 1

#property library
#property strict

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#include "ea_time.mq4"
#include "testing.mq4"
#include "order.mq4"
#include "data.mq4"

// #include "trade.mq4" // TBD

#ifndef EA_MAGIC
#include <dlib/Lang/Hash.mqh>
/// Hash function is from @dingmaotu's mql4-lib
#define EA_MAGIC_DEFINE
const int _ea_magic_ = Hash((string)MQL_PROGRAM_NAME);
#define EA_MAGIC _ea_magic_
#endif


/// @brief return a limit value for history analysis in units of chart bars,
///         given the provided timeframe
/// @param timeframe timeframe for limit, or -1 to use current timeframe
/// @return the number of chart bars
/// @par Known Limitations
//   Does not support a start time for limit
int tracebackExtent(const int timeframe = EMPTY)
{
  switch (timeframe == EMPTY ? _Period : timeframe)
  {
  case PERIOD_M1:
    // minutes in a day
    return 1440;
  case PERIOD_M5:
    // 5-minute periods in three days
    return 864;
  case PERIOD_M15:
    // 5-minute periods in ten days
    return 960;
  case PERIOD_M30:
    // half-hour periods in fifteen days
    return 720;
  case PERIOD_H1:
    // hours for 1 market week (five days) x 4
    return 480;
  case PERIOD_H4:
    // 1/6-day periods for 1 month of market weeks x 3 months, approx
    return 360;
  case PERIOD_D1:
    // days for 1 month of market weeks x 3 months, approx
    return 66;
  case PERIOD_W1:
    // one quarter year ...
    return 16;
  case PERIOD_MN1:
    // one year ...
    return 12;
  default:
    // FIXME other timeframes are not yet well supported here
    return 180;
  }
}

#endif