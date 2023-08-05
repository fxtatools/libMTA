// simplified prototype for automated trailing stop

// License: BSD License
// https://spdx.org/licenses/BSD-2-Clause.html

#property strict

#include <stdlib.mqh>

extern const double ts_spread_frac = 1.5; // Fraction of spread for Trailing Stop
// ^ testing with 0.6
extern const double tp_spread_frac = 4.0; // Fraction of spread for Take Profit

static const long __tsl_lots__ = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
static const double __tsl_price__ = NormalizeDouble(__tsl_lots__ * _Point, Digits);

static bool opened_trailing_stop = false;

int nextOrder(int &start, const string symbol = NULL, const int pool = MODE_TRADES)
{
    const string s = symbol == NULL ? _Symbol : symbol;

    for (int n = start; n < OrdersTotal(); n++)
    {
        if (!OrderSelect(n, SELECT_BY_POS, pool))
        {
            continue;
        }
        else if (OrderSymbol() == s)
        {
            return OrderTicket();
            start = n;
        }
    }
    return EMPTY;
}

void handleError(const string message)
{
    const int errno = GetLastError();
    printf("Error [%d] %s : " + message, errno, ErrorDescription(errno));
    ExpertRemove();
}

void OnTick()
{
    if (ts_spread_frac <= 0)
    {
        printf("Unsupported fraction for trailing stop: %f", ts_spread_frac);
        ExpertRemove();
    }

    int start = 0;
    const int ticket = nextOrder(start, _Symbol);
    if (ticket == EMPTY)
    {
        return;
    }

    if (!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
    {
        handleError(StringFormat("Unable to select order %d", ticket));
    }

    /*
    const bool selected = OrderSelect(opened_order, SELECT_BY_TICKET, MODE_TRADES);

    if (selected && OrderCloseTime() != 0) {
        printf("Order %d was closed externally," opened_order);
        return;
    }
    */

    const double opened_price = OrderOpenPrice();
    const double opened_lots = OrderLots();
    const bool opened_sell = OrderType() == OP_SELL;
    const double opened_sl = OrderStopLoss();
    const double opened_tp = OrderTakeProfit();

    const double spread_price = Ask - Bid;
    const double spreadoff = (ts_spread_frac * spread_price) + __tsl_price__;

    // TBD using spread_price here? for initial tstop (this too DNW)
    const double new_sl = NormalizeDouble((opened_trailing_stop ? (opened_sell ? (Ask + spreadoff) : (Bid - spreadoff)) : (opened_sell ? opened_price - spread_price - spreadoff : opened_price + spread_price + spreadoff)), Digits);

    const bool update_stop = (opened_trailing_stop ? (opened_sell ? new_sl < opened_sl : new_sl > opened_sl) : (opened_sell ? Ask < new_sl  : Bid > new_sl ));


    if (update_stop)
    {
        const double tp_spreadoff = (spread_price * tp_spread_frac) + __tsl_price__;
        const double new_tp = NormalizeDouble(opened_sell ? Bid - tp_spreadoff : Ask + tp_spreadoff, Digits);

        printf("Updating order (trailing stop) %d : SL %f, TP %f", ticket, new_sl, new_tp);
        printf("Ask %f, Bid %f, Order opened price %f, spreadoff %f", Ask, Bid, opened_price, spreadoff);
        bool modified = OrderModify(ticket, opened_price, new_sl, new_tp, 0, clrNONE);
        if (modified)
        {
            opened_trailing_stop = true;
        }
        else
        {
            handleError(StringFormat("Unable to update order %d (trailing stop)", ticket));
        }
    }
}
