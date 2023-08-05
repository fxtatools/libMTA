// zzindicator.mqh
//
// common indicator include

#ifndef ZZINDICATOR_H
#define ZZINDICATOR_H 1

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#property description "ZZWave Common Features"
#property library
#property strict

extern const int zzwave_retrace = 5;                        // Retrace interval >= 3 for leading analysis

static int __initial_rates_total__ = EMPTY;

#include <../Libraries/libZZWave/libZZWave.mq4>
// dblzero:
#include <libMql4.mq4>

#define BUFFER_PADDING 256
#define ZZ_BUFFER_COUNT 2

void zz_update_buffers(const int size, double &linebuff[], double &statebuff[]) {
    // this section needs to be called on each recharting,
    // or resize the buffers when rates_total > initial_rates_total
    //
    // see zz_pre_update() in zzindicator.mq4
    ArrayResize(linebuff, size, BUFFER_PADDING);
    ArrayResize(statebuff, size, BUFFER_PADDING);
}


/// @brief Initialize buffers for ZZWave or ZZPrice calculation
/// @param linebuff ZZ line buffer
/// @param statebuff ZZ state buffer
/// @param shortname indicator short name for the the ZZ line buffer, if provided
/// @param index start index for ZZ indicator buffers
/// @param len length of indicator buffers, if provided
/// @return number of buffers initialized
int zz_init_buffers(double &linebuff[], double &statebuff[], const string shortname = NULL, const int index = 0, const int len = EMPTY) {
    // IndicatorBuffers(nr_indicators);
    SetIndexBuffer(index, linebuff, INDICATOR_DATA);
    if (shortname != NULL) SetIndexLabel(index, shortname);
    SetIndexStyle(index, DRAW_SECTION);
    SetIndexEmptyValue(index, DBLZERO);

    //// Implementation Note:
    //// MT4, MT5 would not accept an int buffer as an indicator buffer

    int statebuff_index = index+1;
    SetIndexBuffer(statebuff_index, statebuff, INDICATOR_CALCULATIONS); 
    SetIndexLabel(statebuff_index, NULL);
    SetIndexStyle(statebuff_index, DRAW_NONE);

    ArraySetAsSeries(linebuff, true);
    ArraySetAsSeries(statebuff, true);
    
    const int size = len == EMPTY ? iBars(_Symbol, _Period) + 1 : len;
    zz_update_buffers(size, linebuff, statebuff);

    return statebuff_index + 1;
} 

/// @brief common initialization for ZZWave, ZZPrice indicators
/// @param shortname indicator short name
/// @param pricebuff ZZ price buffer
/// @param statebuff ZZ state buffer
/// @param index indicator index for ZZ buffer
/// @return INIT_SUCCEEDED if indicator buffer allocation succeeded, else INIT_FAILED
int zz_init(const string shortname, double &pricebuff[], double &statebuff[], int index = 0)
{
    // common on_init handling for ZZWave indicator, state buffers

    bool buffers_alloc = IndicatorBuffers(ZZ_BUFFER_COUNT);
    zz_init_buffers(pricebuff, statebuff, shortname, index);

    // int nrubffers = zz_init_buffers(pricebuff, statebuff, shortname, index);
    /// MQL NOTE: The value to IndicatorBuffers() may be greater than the value
    /// set under #property indicator_buffers or in a containing MQL project
    ///
    /// see example: MQL4 ATR implementation
    // bool buffers_alloc = IndicatorBuffers(nrubffers);
    //// ^ FIXME may need to be called first

    IndicatorShortName(shortname);
    IndicatorDigits(Digits);

    return (buffers_alloc ? INIT_SUCCEEDED : INIT_FAILED);
}

void zz_pre_update(double &pricebuff[], double &statebuff[], const int rates_total, const int prev_calculated) {
    if (__initial_rates_total__ == EMPTY) {
    __initial_rates_total__ = rates_total;
  } else if (rates_total > __initial_rates_total__ && (rates_total - __initial_rates_total__ >= BUFFER_PADDING  )) {
    __initial_rates_total__ = rates_total;
    zz_update_buffers(rates_total, pricebuff, statebuff);
  }
}

int zz_retrace_end(const double &pricebuff[], const int prev_calculated, const int rates_total) {
  
  if (prev_calculated == 0) {
    return rates_total;
  }
  const int retrace_new = rates_total - prev_calculated;
  if (retrace_new == 0 || prev_calculated < rates_total) {
    // generally (retrace_new == 0 || retrace_new == 1) in application for a chart indicator
    // subsequent of the first indicator pass
    const int start = retrace_new == 0 ? 1 : retrace_new;
    const int count = MathMax(zzwave_retrace, 3);
    int reversals = 0;
    for(int n = start; n < rates_total; n++) {
        if(pricebuff[n] != DBLZERO) {
          if(reversals == count) {
              return n + start;
          } else {
            reversals++;
          }
        }
      }
  }
  // default return value
  return rates_total;
}

#endif
