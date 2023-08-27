// tests for time search

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#property strict

#property show_inputs

#include <../Libraries/libMTA/ratesbuffer.mq4>

#ifndef NRQUOTES
#define NRQUOTES 1440
#endif

RatesBuffer *rbuff;

void cleanup()
{
    FREEPTR(rbuff);
}

void OnStart()
{
    DEBUG("Init quotes");
    rbuff = new RatesBuffer(NRQUOTES, true, _Symbol, _Period);
    const int copied = rbuff.getRates();
    if (copied == -1)
    {
        ERRMSG(("Unable to copy %d quotes", NRQUOTES));
        cleanup();
        return;
    }

    const int time_full = TIME_DATE | TIME_MINUTES | TIME_SECONDS;

    DEBUG("Search times [%d]", ArraySize(rbuff.data));
    for (int acsy = 0; acsy < 120; acsy++)
    {
        for (int n = fmin(iBars(_Symbol, _Period), NRQUOTES) - 1; n >= 0; n--)
        {
            const datetime idt = rbuff.data[n].time - (int)floor(acsy / 2);
            const int rshift = timeShift(idt, rbuff.data, EMPTY, acsy);
            if (rshift == EMPTY)
            {
                printf("Failed search [%d] timeShift(...) for accuracy %d did not locate %s",
                       n, acsy, toString(idt, time_full));
                continue;
            }
            const datetime rdt = rbuff.data[rshift].time;
            if (rshift != n && (idt + acsy < rdt || idt - acsy > rdt))
            {
                printf("Failed search [%d] at %s. timeShift(...) => %d (%s) for accuracy %d, expected %d (%s)",
                       n, toString(idt, time_full),
                       rshift, toString(rbuff.data[rshift].time, time_full),
                       acsy, n, toString(rbuff.data[n].time, time_full));
            }
        }
    }
    cleanup();
}