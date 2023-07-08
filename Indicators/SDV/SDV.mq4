//+------------------------------------------------------------------+
//|                                                          SDV.mq4 |
//|                                       Copyright 2023, Sean Champ |
//|                                      https://www.example.com/nop |
//+------------------------------------------------------------------+
#property strict
//--- input parameters
input int      sd_period=5;
input int      sd_applied_price;
input int      sd_method;
input int      sd_shift=0;

double         SDVBuffer[];

int OnInit()
  {
   SetIndexBuffer(0,SDVBuffer);
   
   return(INIT_SUCCEEDED);
  }

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {

   return(rates_total);
  }
