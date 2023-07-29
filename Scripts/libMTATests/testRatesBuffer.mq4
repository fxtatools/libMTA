// testing for RatesMgr virtual buffer / array compat

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#include <../Libraries/libMTA/ratesbuffer.mq4>
#include <libMql4.mq4>

// https://stackoverflow.com/questions/10128159/pass-an-array-as-template-type
/*
template<class T, int N >
T* end(T(&array)[N]) {
    return array + N;
}
*/

// N/A in MQL, it cannot even parse this
/*
template<typename T, int N>
T at(int idx, const T(&array)[N]) {
    return array[idx];
}
*/

template<typename T>
// mangled syntax for the MQL compiler
T at(const int idx, const T &array[]) {
    return array[idx];
}


template<typename T>
double at(const int idx, const T &obj) {
    return obj[idx];
}

// [...] portable [...] cheaply hacked operator[] application with macros for MQL
// still not sufficient for type compatibility in function args
#define AT(IDX, DATA) DATA[IDX]


void OnStart() {
    RatesMgr *mgr = new RatesMgr(1000);
    mgr.getRates();
    ALERTF_1("First open rate %f", mgr.open[0]);
    ALERTF_1("Last open rate %f", mgr.open[999]);
    ALERTF_1("Last open time %s", TimeToString(mgr.time[0]));
    ALERTF_1("Last open time %s", TimeToString(mgr.time[999]));

    // NOP
    /*
    int thunk(int arg) {
        printf("Thunk %d", arg)
    };
    thunk(5);
    */

    const double thunk_data[5] = {0.1, 0.2, 0.3, 0.4, 0.5};
    ALERTF_1("Thunk %f", at(1, thunk_data));
   
    ALERTF_1("Thunk again %f", at(1, mgr.open)); // not quite ...

    // [...]
    ALERTF_1("Thunk C %f", AT(1, thunk_data));
    ALERTF_1("Thunk D %f", AT(1, mgr.open));

    delete mgr;  
}
