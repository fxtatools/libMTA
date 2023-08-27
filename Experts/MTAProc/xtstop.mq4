// simplified prototype for automated trailing stop

// License: MIT License
// https://spdx.org/licenses/BSD-2-Clause.html

#property strict

extern const long ts_points = 10; // Trailing Stop Points
extern const long tp_points = 60; // Take Profit Points

#include <../Libraries/libMTA/ea.mq4>
EA_MAGIC_DEFINE

OrderManager *order_mgr;

int OnInit()
{
    order_mgr = new OrderManager(0, tp_points, ts_points, true, 1, EA_MAGIC, _Symbol, _Period);
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    FREEPTR(order_mgr);
}

void OnTick()
{
    order_mgr.manageTrailingStop();
 }
