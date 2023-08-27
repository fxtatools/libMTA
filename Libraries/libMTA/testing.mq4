#ifndef _TESTING_MQ4
#define _TESTING_MQ4 1

#property library
#property strict

#ifndef TESTING
const bool __testing__ = MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE) || MQLInfoInteger(MQL_PROFILER) || MQLInfoInteger(MQL_DEBUG) || MQLInfoInteger(MQL_OPTIMIZATION) || MQLInfoInteger(MQL_FRAME_MODE);
#define TESTING __testing__
#endif


#endif