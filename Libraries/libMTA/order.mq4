// order.mq4

#ifndef _ORDER_MQ4
#define _ORDER_MQ4 1

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#property strict
#property library

// slippage as a constant for order open (market orders)
#ifndef SLIPPAGE_CLOSE
#define SLIPPAGE_CLOSE 3
#endif

#include "symbol.mq4"
#include "error.mq4"

#include "libMql4.mq4"
#include "chartable.mq4"

#include <dlib/Collection/HashMap.mqh>

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
    digits = digits == EMPTY ? Digits : digits;
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

class OrderManager : public Chartable
{
protected:
    const long sl_lots;    // lots for initial stop loss
    const long tp_lots;    // lots for take profit
    const long tsl_lots;   // lots for trailing stop
    const int order_limit; // max number of orders, EMPTY for unlimited
    const bool handle_ts;  // handle trailing stop?
    const int mcode;       // EA "magic" number
    const long stop_lots;
    const double stop_price;
    const double sl_stopoff;
    const double tp_stopoff;
    const double tsl_stopoff;
    int late_seconds; // (TBD location of this) Minutes before 0:00 market time in which to close any open orders, zero disables

    HashMap<int, bool> *tsl_info;

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
    int selectOrder(int &start, const int pool = EMPTY, const int ticket = EMPTY)
    {
        const int op = pool == EMPTY ? MODE_TRADES : pool;

        for (int n = start; n < OrdersTotal(); n++)
        {
            if (!OrderSelect(n, SELECT_BY_POS, op))
            {
                handleError(StringFormat("Could not select nth order %d", n));
                continue;
            }
            else if (OrderSymbol() == symbol)
            {
                // Implementation note: OrderManager will manage any order
                // in the configured symbol, regardless of EA mcode
                start = n;
                const int ot = OrderTicket();
                if (ticket != EMPTY && ticket != ot)
                {
                    continue;
                }
                if (OrderCloseTime() == 0)
                {
                    return ot;
                }
                else
                {
                    DEBUG("Order was closed externally: %d ", ot);
                    tsl_info.pop(ot);
                    if (ticket == EMPTY)
                        continue;
                    else
                        return EMPTY;
                }
            }
        }
        return EMPTY;
    }

public:
    OrderManager(const long _sl_lots, const long _tp_lots, const long _tsl_lots,
                 const bool ts_p = true,
                 const int orders = 1,
                 const int _mcode = EMPTY,
                 const string _symbol = NULL,
                 const int _timeframe = EMPTY) : sl_lots(_sl_lots),
                                                 tp_lots(_tp_lots),
                                                 tsl_lots(_tsl_lots),
                                                 mcode(_mcode),
                                                 handle_ts(ts_p),
                                                 order_limit(orders),
                                                 late_seconds(0),
                                                 Chartable(_symbol, _timeframe),
                                                 stop_lots(getStopLots(symbol)),
                                                 stop_price(pointsPrice(stop_lots)),
                                                 sl_stopoff(getStopoff(sl_lots, stop_lots, getSymbolDigits())),
                                                 tp_stopoff(getStopoff(tp_lots, stop_lots, getSymbolDigits())),
                                                 tsl_stopoff(getStopoff(tsl_lots, stop_lots, getSymbolDigits()))
    {
        // Implementation Note:
        //
        // manageTrailingStop() is generally reentrant, does not require
        // reinitialization of the tsl_info table
        tsl_info = new HashMap<int, bool>(NULL, true);
    };
    ~OrderManager()
    {
        FREEPTR(tsl_info);
    }

    bool activeOrders()
    {
        int start = 0;
        const int ticket = selectOrder(start);
        return ticket != EMPTY;
    }

    int getLateMinutes() {
        return (int) ceil(late_seconds / 60);
    }

    int getLateSeconds() {
        return late_seconds;
    }

    void setLateMinutes(const int minutes) {
        late_seconds = minutes * 60;
    }

    void setLateSeconds(const int seconds) {
        late_seconds = seconds;
    }

    void clearLateMinutes() {
        setLateSeconds(0);
    }

    void clearLateSeconds() {
        setLateSeconds(0);
    }

    // utility function
    datetime nextZeroTime(MqlDateTime &mdt) {
        TimeCurrent(mdt);
        mdt.hour = 0;
        mdt.min = 0;
        mdt.sec = 0;
        mdt.day++;
        return StructToTime(mdt);        
    }

    datetime nextZeroTime() {
        MqlDateTime mdt();
        return nextZeroTime(mdt);
    }

    // utility function. Known limitation: This does not check for whether the
    // indicated market time time represents a Saturday or Sunday
    bool inLateSeconds(const datetime whence = EMPTY) {
        if (late_seconds == 0) {
            return false;
        }
        const datetime checktime = whence == EMPTY ? TimeCurrent() : whence;
        const datetime zdt = nextZeroTime();
        return (checktime < zdt) && (checktime > (zdt - late_seconds));
    }

    bool trailingStopOrder(const int ticket)
    {
        if (tsl_info.contains(ticket))
        {
            return tsl_info.get(ticket, false);
        }
        else
        {
            return false;
        }
    }

    bool validateStopLoss(const bool sell, const double sl, MqlTick &tick)
    {
        const double _ask_ = tick.ask;
        const double _bid_ = tick.bid;
        return sell ? ((sl - _ask_) >= stop_price) : ((_bid_ - sl) >= stop_price);
    }

    void manageTrailingStop()
    {
        if (!handle_ts)
        {
            return;
        }
        int start = 0;
        int n = 0;
        while (n < order_limit)
        {
            const int ticket = selectOrder(start);
            if (ticket == EMPTY)
            {
                return;
            }
            const double opened_price = OrderOpenPrice();
            const double opened_lots = OrderLots();
            const bool opened_sell = OrderType() == OP_SELL;
            const double opened_sl = OrderStopLoss();
            const double opened_tp = OrderTakeProfit();

            const bool opened_trailing_stop = trailingStopOrder(ticket);

            // FIXME Ask, Bid
            MqlTick tick();
            if (!symbolTickInfo(tick))
            {
                return;
            }
            const double _ask_ = tick.ask;
            const double _bid_ = tick.bid;

            const double start_price = (opened_trailing_stop ? (opened_sell ? _ask_ : _bid_) : opened_price);
            const double new_sl = normalize((opened_trailing_stop ? (opened_sell ? (start_price + tsl_stopoff) : (start_price - tsl_stopoff)) : (opened_sell ? (start_price - tsl_stopoff) : (start_price + tsl_stopoff))));

            const bool update_stop = (opened_trailing_stop ? (opened_sell ? (new_sl < opened_sl) : (new_sl > opened_sl)) : true) && validateStopLoss(opened_sell, new_sl, tick);

            if (opened_sell ? _ask_ < opened_price : _bid_ > opened_price)
            {
                DEBUG("Update TS ? ask %f, bid %f, stopoff %f, new_sl %f", _ask_, _bid_, tsl_stopoff, new_sl);
            }

            if (update_stop)
            {
                const double new_tp = normalize(opened_sell ? _bid_ - tp_stopoff : _ask_ + tp_stopoff);

                printf("Updating order (trailing stop) %d : SL %f => %f, TP %f => %f", ticket, opened_sl, new_sl, opened_tp, new_tp);
                DEBUG("Ask %f, Bid %f, TSL %f, TPL %f, Order opened price %f, tsl_stopoff %f", _ask_, _bid_, tsl_lots, tp_lots, opened_price, tsl_stopoff);
                bool modified = OrderModify(ticket, opened_price, new_sl, new_tp, 0, clrNONE);
                if (modified)
                {
                    tsl_info.set(ticket, true);
                }
                else
                {
                    handleError(StringFormat("Unable to update order %d (trailing stop)", ticket));
                }
            }
            n++;
        }
    }

    void openOrder(const double lots, const bool sell)
    {
        MqlTick tick();
        if (!symbolTickInfo(tick))
        {
            return;
        }
        const double _ask_ = tick.ask;
        const double _bid_ = tick.bid;

        int order_cmd = sell ? OP_SELL : OP_BUY;
        const double open_price = sell ? _bid_ : _ask_;
        string comment = StringFormat("Ask %f, Bid %f", _ask_, _bid_);

        /// for stops, using the other of the tick rate used for open
        const double sl = normalize(sell ? _ask_ + sl_stopoff : _bid_ - sl_stopoff);
        const double tp = normalize(sell ? _ask_ - tp_stopoff : _bid_ + tp_stopoff);

        const color clr_open = clrNONE;
        printf("Opening order (%s) at time %s, P %f, SL %f, TP %f",
               sell ? "Sell" : "Buy",
               TimeToStr(offset_time(0, symbol, timeframe)),
               open_price,
               sl, tp);
        const int ticket = OrderSend(symbol, order_cmd, lots, open_price, SLIPPAGE_CLOSE, sl, tp, comment, mcode, 0, clr_open);
        if (ticket == -1)
        {
            handleError(StringFormat("Unable to open order (%s) at %f, SL %f, TP %f ",

                                     sell ? "Sell" : "Buy",
                                     open_price, sl, tp));
            return;
        }
        tsl_info.set(ticket, false);
    }

    bool closeOrder(const int ticket)
    {
        int oidx = 0;
        const int rslt = selectOrder(oidx, EMPTY, ticket);
        if (rslt == EMPTY)
        {
            printf("Unable to select order %d", ticket);
            return false;
        }
        MqlTick tick();
        if (!symbolTickInfo(tick))
        {
            return false;
        }
        const bool opened_sell = OrderType() == OP_SELL;
        const double close_price = opened_sell ? tick.ask : tick.bid;
        const color closing_color = clrNONE;
        const double opened_lot = OrderLots();

        bool closed = OrderClose(ticket, opened_lot, close_price, SLIPPAGE_CLOSE, closing_color);
        if (closed)
        {
            // FIXME log profit or loss
            printf("Closed order %d", ticket);
            tsl_info.pop(ticket);
            return true;
        }
        else
        {
            handleError(StringFormat("Error closing order %d", ticket));
            return false;
        }
    }
};
#endif