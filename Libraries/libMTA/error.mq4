// error.mq4
#ifndef _ERROR_MQ4
#define _ERROR_MQ4 1

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#property strict
#property library

#include <stdlib.mqh>
#include "testing.mq4"

bool continuable_error(int errno)
{
  switch (errno)
  {
  case ERR_TRADE_NOT_ALLOWED:
    // ensure the EA continues running analysis
    // when auto-trading is disabled
    return true;
  case ERR_TRADE_DISABLED:
    return true;
  case ERR_INVALID_STOPS: // 130
    // handling this as a continuable error unless testing.
    return !(TESTING);
  case ERR_INVALID_TRADE_PARAMETERS:
    // TBD
    return !(TESTING);
  case ERR_TOO_FREQUENT_REQUESTS:
    return !(TESTING);
  case ERR_NO_ERROR:
    return true;
  case ERR_NO_RESULT:
    return true;
  case ERR_SERVER_BUSY:
    return true;
  case ERR_BROKER_BUSY:
    return true;
  case ERR_TRADE_CONTEXT_BUSY:
    return true;
  case ERR_SYSTEM_BUSY:
    return true;
  case ERR_NO_MQLERROR:
    return true;
  default:
    return false;
  }
}

/// @brief print an error message, error code, and standard error string.
///  If the last error is not a continuable condition, remove this expert advisor
/// @param message message to be printed to the experts log. This message
///  will be printed together with the last error code and standard error
///  string for that error code.
void handleError(string message)
{
  int errno = GetLastError();
  printf("%s [%d] %s", message, errno, ErrorDescription(errno));
  if (continuable_error(errno)) {
    Print("Continuable condition");
    ResetLastError();
  }
  else 
  {
    Print("Removing EA");
    ExpertRemove();
  }
}



#endif