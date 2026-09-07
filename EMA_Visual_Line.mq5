//+------------------------------------------------------------------+
//|                                              EMA_Visual_Line.mq5 |
//|                                  Copyright 2026, Antigravity     |
//|                    Custom Indicator Visual EMA dengan Warna Putih|
//+------------------------------------------------------------------+
#property copyright "Antigravity"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrWhite
#property indicator_width1  2
#property indicator_label1  "EMA Visual"

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input int                InpMaPeriod       = 125;        // Periode EMA
input ENUM_MA_METHOD     InpMaMethod       = MODE_EMA;   // Metode MA
input ENUM_APPLIED_PRICE InpMaAppliedPrice = PRICE_CLOSE;// Applied Price
input color              InpMaColor        = clrWhite;   // Warna Garis
input int                InpMaWidth        = 2;          // Ketebalan Garis

//+------------------------------------------------------------------+
//| Indicator Buffers & Handles                                      |
//+------------------------------------------------------------------+
double MaBuffer[];
int    h_ma = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, MaBuffer, INDICATOR_DATA);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpMaColor);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpMaWidth);

   string shortName = StringFormat("EMA_Visual(%d)", InpMaPeriod);
   IndicatorSetString(INDICATOR_SHORTNAME, shortName);
   PlotIndexSetString(0, PLOT_LABEL, shortName);

   h_ma = iMA(_Symbol, _Period, InpMaPeriod, 0, InpMaMethod, InpMaAppliedPrice);
   if(h_ma == INVALID_HANDLE)
     {
      Print("Error: Gagal membuat handle iMA di EMA_Visual_Line");
      return(INIT_FAILED);
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(h_ma != INVALID_HANDLE)
      IndicatorRelease(h_ma);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
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
   if(rates_total < InpMaPeriod) return 0;

   int toCopy = rates_total - prev_calculated;
   if(toCopy > rates_total) toCopy = rates_total;
   if(prev_calculated > 0) toCopy++;

   if(CopyBuffer(h_ma, 0, 0, toCopy, MaBuffer) <= 0)
     {
      return 0;
     }

   return rates_total;
  }
//+------------------------------------------------------------------+
