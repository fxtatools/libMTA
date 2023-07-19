//+------------------------------------------------------------------+
//|                                                      xAdxSto.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+

/*
 *
 * Test information:
 * - AUDCAD M30 2023/06/28 - 2023/06/29
 * 
 **/

#property copyright "Copyright 2023, Sean Champ."
#property link "https://www.example.com/nop"
#property version "1.00"

#property show_inputs
#property strict

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

const bool in_test = MQL_TESTER || MQL_VISUAL_MODE || MQL_PROFILER || MQL_DEBUG || MQL_OPTIMIZATION || MQL_FRAME_MODE;

#define NO_ORDER -1
#define SLIPPAGE_CLOSE 3

extern int start_delay = 5; // seconds
#ifndef DBLZERO_DEFINED
#define DBLZERO_DEFINED 1
const int __dblzero__ = 0.0;
#ifndef DBLZERO
#define DBLZERO __dblzero__
#endif
#endif

#define dbg Print

extern double lot_size = 0.5;

#include <adxcommon.mq4>
#include <stdlib.mqh>
#include <dlib/Lang/Hash.mqh>
 
//// Hash function is from @dingmaotu's mql4-lib
static const int EA_MAGIC = Hash((string) MQL_PROGRAM_NAME);

extern color closing_buy_color = CLR_NONE;
extern color closing_sell_color = CLR_NONE;

bool initializing = true;
bool timer_active = false;
int opened_order = NO_ORDER;
datetime opened_time = NULL;
double opened_lot = NO_ORDER;
int opened_sell = false;

uint init_ms;

int OnInit()
{
  cur_symbol = ChartSymbol();
  cur_timeframe = ChartPeriod();

  init_ms = GetTickCount();

  return (INIT_SUCCEEDED);

  debug = false;
}

/* Unused
void OnDeinit(const int reason)
{
}
*/

void OnTick()
{

  // if opened_order > 1:
  //   * if approaching the zero hour (GMT), close the order, to avoid negative affects
  //     from "Zero hour action" by undisclosed market institutions
  //   * else  detect the next Sto crossover in cur_timeframe
  //     - On event of Sto crossover (current timeframe) under an open order, close the order
  //     - else TBD detect Sto crossover in in some other timeframe, to the same result as in cur_timeframe
  // else, if no EA-managed open order:
  //   - find external orders for cur_symbol. If found, set opened_order to
  //     minus the order ticket number and return from OnTick
  // else, if no external orders:
  //   - search backwards for a favorable (non-cancelling) ADX crossover. If found,
  //     open an order (sell if sell_trend, else buy) and set opened_order accordingly ...

  if (initializing)
  {
    uint cur_ms = GetTickCount();
    int dx = (int)(cur_ms - init_ms);
    if (dx >= start_delay * 1000)
    {
      printf("Initialization delay elapsed: %d ms", dx);
      initializing = false;
    }
    else
    {
      return;
    }
  }

  int start = 0;
  int ticket = next_order(start, cur_symbol);
  if (ticket != NO_ORDER)
  {
    if (OrderMagicNumber() == EA_MAGIC)
    {
      // order was opened under a previous run of this EA
      // e.g under a previous timeframe display in the active chart
      printf("Managing order %d", ticket);
      opened_order = ticket;
      opened_time = OrderOpenTime();
      opened_lot = OrderLots();
      opened_sell = OrderType() == OP_SELL;
    }
    else
    {
      printf("Found external order %d", ticket);
      opened_order = -ticket;
      return;
    }
  }

  if (opened_order > 0)
  {
    // order may have been closed externally, e.g via mobile app or web trader
    bool selected = OrderSelect(opened_order, SELECT_BY_TICKET, MODE_TRADES);
    
    if (!selected || (OrderCloseTime() != 0)) {
      if(selected) {
          Print("Open order was closed externally ", opened_order);
      }
      else {
         string msg = StringFormat("Could not select open order for review: %d", opened_order);
         handle_error(msg);
      }
      opened_order = INT_MIN;
      return;
    }

    // if Sto ... if adx has crossed over, close order
    int offset = iBarShift(cur_symbol, cur_timeframe, opened_time, false);
    // FIXME print once per each new chart tick:
    printf("Reviewing opened order %d, chart offset %d", opened_order, offset);
    if (offset == 0)
    {
      return; //
    }
    XoverIndex xov = XoverIndex();
    bool found = find_adx_xover(xov, 0, offset, cur_timeframe);
    if (found)
    {
      double close_price;

      // RefreshRates(); // TBD
      //// TBD: inverted close-price logic under the MQ4 Strategy Tester (??)
      if(in_test) {
        close_price = opened_sell ? Ask : Bid;
      } else {
        // ????
        close_price = opened_sell ? Bid : Ask;
      }
      color closing_color = opened_sell ? closing_sell_color : closing_buy_color;
      bool closed = OrderClose(opened_order, opened_lot, close_price, SLIPPAGE_CLOSE, closing_color);
      if (closed)
      {
        // FIXME log profit or loss
        printf("Closed order %d", opened_order);
        opened_order = NO_ORDER;
      }
      else
      {
        string msg = StringFormat("Error closing order %d", opened_order);
        handle_error(msg);
      }
    }
    return;
  }

  // search for a favoring ADX crossover & open order if found
  XOver xover = XOver();
  int nr_bars = iBars(cur_symbol, cur_timeframe);
  bool found = find_open_xover(xover, 0, nr_bars, cur_timeframe);
  if (found)
  {
    opened_lot = get_lot_size();
    int order_cmd = xover.sell_trend ? OP_SELL : OP_BUY;
    // RefreshRates(); // TBD
    double open_price = xover.sell_trend ? Bid : Ask;
    double sl = 0; // FIXME implement non-zero stop loss
    double tp = 0; // TBD
    int rslt = OrderSend(cur_symbol, order_cmd, opened_lot, open_price, SLIPPAGE_CLOSE, sl, tp, NULL, EA_MAGIC);
    if (rslt > 0)
    {
      opened_order = rslt;
      bool selected = OrderSelect(rslt, SELECT_BY_TICKET);
      if (selected)
      {
        opened_time = OrderOpenTime();
        printf("Opened order %d", opened_order);
      }
      else
      {
        string msg = "Failed to select recently opened order";
        handle_error(msg);
      }
    }
    else
    {
      string msg = "Error opening order";
      handle_error(msg);
    }
  }
}

double get_lot_size()
{
  return lot_size;
}

int next_order(int &start, string symbol = NULL, int pool = MODE_TRADES)
{
  if (symbol == NULL)
  {
    symbol = cur_symbol;
  }

  for (int n = start; n < OrdersTotal(); n++)
  {
    if (!OrderSelect(n, SELECT_BY_POS, pool))
    {
      continue;
    }
    else if (OrderSymbol() == symbol)
    {
      return OrderTicket();
      start = n;
    }
  }
  return NO_ORDER;
}

void handle_error(string &message)
{
  int errno = GetLastError();
  Print(message, ": ", ErrorDescription(errno));
  Print("Removing EA");
  ExpertRemove();
}
