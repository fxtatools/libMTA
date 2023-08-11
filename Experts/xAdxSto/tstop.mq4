// simplified prototype for automated trailing stop

// License: MIT License
// https://spdx.org/licenses/BSD-2-Clause.html

#property strict

extern const long ts_points = 10; // Trailing Stop Points
extern const long tp_points = 60; // Take Profit Points

#include <stdlib.mqh>
#include <libMql4.mq4>

bool opened_trailing_stop = false;

/// @brief return the points value (lots, pips) for a value in units of price
/// @param price the value in units of price
/// @return the points value (lots, pips) for the provided price value
///
/// @par Known Limitations
///
/// This function is applicable only for the current symbol at time of call
long pricePoints(const double price)
{
    return (long)(price / _Point);
}

/// @brief return the price value for a value in units of points (lots, pips)
/// @param lots the value in units of points
/// @return the price value for the provided point value
////
/// @par Known Limitations
///
/// This function is applicable only for the current symbol at time of call
double pointsPrice(const long lots)
{
    return NormalizeDouble(lots * _Point, Digits);
}

/// @brief Utility function for market symbol information
/// @param var [out] variable for the symbol info
/// @param prop [in] property for the symbol info
/// @param symbol [in] symbol for the symbol info
/// @return true if the symbol information was available, else false
bool symbolInfo(double &var, const int prop, const string symbol = NULL)
{
    return SymbolInfoDouble(symbol == NULL ? _Symbol : symbol, prop, var);
}

/// @brief Utility function for market symbol information
/// @param var [out] variable for the symbol info
/// @param prop [in] property for the symbol info
/// @param symbol [in] symbol for the symbol info
/// @return true if the symbol information was available, else false
bool symbolInfo(int &var, const int prop, const string symbol = NULL)
{
    long tmp;
    if (SymbolInfoInteger(symbol == NULL ? _Symbol : symbol, prop, tmp))
    {
        var = (int)tmp;
        return true;
    }
    else
    {
        return false;
    }
}

/// @brief Utility function for market symbol information
/// @param var [out] variable for the symbol info
/// @param prop [in] property for the symbol info
/// @param symbol [in] symbol for the symbol info
/// @return true if the symbol information was available, else false
bool symbolInfo(long &var, const int prop, const string symbol = NULL)
{
    return SymbolInfoInteger(symbol == NULL ? _Symbol : symbol, prop, var);
}

/// @brief Return the stops limit in units of points (lots, pips) for a given symbol
/// @param symbol [in] symbol for the stops limit.
//   If NULL, the current symbol will be used
/// @return the stops limit, in units of points (lots, pips)
long getStopLots(const string symbol = NULL)
{
    long stops = EMPTY_VALUE;
    const bool rslt = symbolInfo(stops, SYMBOL_TRADE_STOPS_LEVEL, symbol);
    if (rslt)
    {
        return stops;
    }
    else
    {
        return EMPTY;
    }
}

/// @brief Return the stops limit in units of price for a given symbol
/// @param symbol [in] symbol for the stops limit.
//   If NULL, the current symbol will be used
/// @return the stops limit, in units of price
double getStopPrice(const string symbol = NULL)
{
    const long lots = getStopLots(symbol);
    if (lots == 0)
    {
        // broker allows a zero stops range, or no stops level could be determined
        return 0;
    }
    else
    {
        return pointsPrice(lots);
    }
}

/// @brief return a factored stopoff price, depending on factor and broker limit, both values in points/lot
//
/// @param factor [in] configured stopoff factor in units off points (lots, pips),
//   such as for stop loss, take profit, or trailing stop
//
/// @param limit [in] broker limit for stop loss / take profit, in units of points (lots, pips).
//   This value can be retrieved as via `SymbolInfoInteger(string s, SYMBOL_TRADE_STOPS_LEVEL)`
//   and other calls to this overloaded function.
//
//  @param digits [in] symbol-specific decimal precision for market rates and order prices.
//  If provided as EMPTY, the current symbol's `Digits` value will be used. This parameter
//  will be used when normalizing the adjusted `factor` value as converted to units of price.
//
// @return the factored stopoff value, converted from points to units of price
//
// @par Implementation Notes
//
// Some brokers may allow a stops limit of zero. In these instances, this function will
// convert the `factor` value directly to units of price
//
// For brokers using a stops limit greater than zero, this function will endeavor to absorb
// the stops limt value within the factored portion, when the provided factor is greater than
// the stops limit.
//
// If the stops limit is greater than the provided factor, the stops limit will be returned
// as converted to points.
//
// The value returned from this function may be applied relative to ask price, bid price,
// or order open price, depending on the nature of the applied stop (e.g take profit,
// initial stop loss, or trailing stop loss)
//
double getStopoff(const long factor, const long limit, int digits = EMPTY)
{
    digits = digits == EMPTYU ? Digits : digits;
    if (limit == 0)
    {
        // FIXME assumes current symbol @ Digits
        return NormalizeDouble(pointsPrice(factor), digits);
    }
    else
    {
        // Needs test with a broker using a stop 0 < limit < 50
        //
        // absorbing the stops limit within the factored portion,
        // when the factored portion > limit
        return NormalizeDouble(pointsPrice((long)(MathMax((double)limit, (double)factor - limit))), digits);
    }
}

/// @brief select the next available order for terminal order information,
/// and return the order's ticket number, beginning with a provided index value
///
/// @param start [in] variable storing the initial start index for orders
///  within the terminal order system, 0 for the first order
///
/// @param symbol symbol to use when checking for open orders, NULL for the current symbol
///
/// @param pool enum value indicating the order pool to search for open orders,
///   default is MODE_TRADES
///
/// @return the order ticket number, updating the `start` reference for the selected
///  order's index. If no matching orders are found, returns EMPTY
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

/// @brief print an error message, error code, and standard error string
///  and remove this expert advisor
/// @param message message to be printed to the experts log. This message
///  will be printed together with the last error code and standard error
///  string for that error code.
void handleError(const string message)
{
    const int errno = GetLastError();
    printf("Error [%d] %s : " + message, errno, ErrorDescription(errno));
    ExpertRemove();
}

// stop limit in lots, for stopopff calculation
const long __tsl_lots__ = getStopLots();
// stop limit in units of price, for next-stop calculation
const double __tsl_price__ = getStopPrice();

/// @brief Primary EA event function
void OnTick()
{
    // Implementation Notes:
    // - For Take Profit, Sell closes on the position of the Ask price
    //
    // TA/Market Notes:
    //
    // - Market rate slumps or (less often) rate spikes at 0:00 market time
    //   may be accompanied with an immediate increase in spread, corresponding
    //   to or greater than the rate change. Consequently, it may be non-trivial
    //   to "follow" an abrupt 0:00 market rate change.
    //
    //   Seen in EURGPB, GPBUSD. Not so much so, in USDJPY
    //
    // - When there is a certain gap between current open and previous close
    //   prices, e.g in an approximate range of 50 to 100 points of a gap, it
    //   may indicate a recent  "market rate spike"  as such.

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

    const double tsl_stop = getStopoff(ts_points, __tsl_lots__);

    const double new_sl = NormalizeDouble((opened_trailing_stop ? (opened_sell ? (Ask + tsl_stop) : (Bid - tsl_stop)) : (opened_sell ? (opened_price - tsl_stop) : (opened_price + tsl_stop))), Digits);

    const bool update_stop = (opened_trailing_stop ? (opened_sell ? ((new_sl < opened_sl) && ((new_sl - Ask) >= __tsl_price__)) : ((new_sl > opened_sl) && ((Bid - new_sl) >= __tsl_price__))) : (opened_sell ? ((new_sl - Ask) >= __tsl_price__) : ((Bid - new_sl) >= __tsl_price__)));

    if (opened_sell ? Ask < opened_price : Bid > opened_price)
    {
        DEBUG("Update TS ? ask %f, bid %f, stopoff %f, new_sl %f", Ask, Bid, tsl_stop, new_sl);
    }

    if (update_stop)
    {
        const double new_tp = getStopoff(tp_points, __tsl_lots__);

        printf("Updating order (trailing stop) %d : SL  %f => %f, TP %f => %f", ticket, opened_sl, new_sl, opened_tp, new_tp);
        printf("Ask %f, Bid %f, TSL %f, TPL %f, Order opened price %f, tsl_stop %f", Ask, Bid, ts_points, tp_points, opened_price, tsl_stop);
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
