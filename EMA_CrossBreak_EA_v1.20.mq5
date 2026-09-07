//+------------------------------------------------------------------+
//|                                      EMA_CrossBreak_EA_v1.20.mq5 |
//|                                  Copyright 2026, Antigravity     |
//|                 Strategy: Candle Piercing EMA 9 & EMA 17 Breakout|
//|                           + Filter Momentum Body vs ATR          |
//+------------------------------------------------------------------+
#property copyright "Antigravity"
#property link      "https://www.mql5.com"
#property version   "1.20"
#property description "EA MT5: Piercing EMA 9 & 17 + Filter Body Candle vs ATR + Max Martingale Basket TP."

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                     |
//+------------------------------------------------------------------+
enum ENUM_LOT_MODE
  {
   LOT_MODE_FIXED = 0,    // Fixed Lot
   LOT_MODE_PERCENT = 1   // Risk % of Balance (Memerlukan SL > 0)
  };

enum ENUM_SL_MODE
  {
   SL_MODE_POINTS = 0,    // Fixed Points
   SL_MODE_CANDLE = 1     // Signal Candle Shift 1 High/Low (+ Buffer)
  };

enum ENUM_MARTINGALE_MODE
  {
   MARTINGALE_STACKING_GLOBAL     = 0, // Stacking Global (Order 1=0.1, Order 2=0.2, Order 3=0.4, dst)
   MARTINGALE_STACKING_BY_TYPE    = 1, // Stacking Per Arah (BUY & SELL Dihitung Terpisah)
   MARTINGALE_AFTER_LOSS_GLOBAL   = 2, // After Loss Global (Hitung Riwayat Loss Trade Apapun)
   MARTINGALE_AFTER_LOSS_BY_TYPE  = 3  // After Loss Per Arah (Riwayat Loss Sesuai BUY/SELL)
  };

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== 1. Pengaturan Timeframe & Indikator EMA ==="
input ENUM_TIMEFRAMES    InpTimeframe           = PERIOD_CURRENT; // Timeframe Sinyal (PERIOD_CURRENT = Ikuti Chart)
input int                InpEmaFastPeriod       = 9;              // Periode Fast EMA
input int                InpEmaSlowPeriod       = 17;             // Periode Slow EMA
input ENUM_MA_METHOD     InpEmaMethod           = MODE_EMA;       // Metode MA (EMA)
input ENUM_APPLIED_PRICE InpEmaAppliedPrice     = PRICE_CLOSE;    // Applied Price

input group "=== 2. Filter Volatilitas & Sideways (Body vs ATR) ==="
input bool               InpEnableAtrFilter     = true;           // Aktifkan Filter Body Candle vs ATR
input int                InpAtrPeriod           = 14;             // Periode ATR
input double             InpMinBodyAtrRatio     = 0.5;            // Min Rasio Body / ATR (0.5 = Body minimal 50% dari ATR)
input int                InpMinBodyPoints       = 0;              // Filter Tambahan: Min Body Candle (Points, 0 = Nonaktif)

input group "=== 3. Aturan Posisi & Stacking ==="
input bool               InpAllowStacking       = true;           // Izinkan Stacking (Buka Posisi Baru saat Sinyal Baru)
input int                InpMaxPositions        = 5;              // Maksimal Posisi Terbuka (0 = Tanpa Batas)
input int                InpMinDistancePoints   = 0;              // Jarak Minimum Antar Posisi Searah (Points, 0 = Nonaktif)

input group "=== 4. Stop Loss & Take Profit ==="
input ENUM_SL_MODE       InpSLMode              = SL_MODE_POINTS; // Mode Stop Loss
input int                InpStopLossPoints      = 300;            // Stop Loss dalam Points (0 = Tanpa SL)
input int                InpTakeProfitPoints    = 600;            // Take Profit dalam Points (0 = Tanpa TP)
input int                InpCandleSLBuffer      = 50;             // Buffer Tambahan jika pakai SL Candle (Points)

input group "=== 5. Aturan Exit Sinyal Berlawanan ==="
input bool               InpCloseOnOpposite     = true;           // Tutup Posisi Lawan saat Muncul Sinyal Baru

input group "=== 6. Trailing Stop & Break-Even ==="
input int                InpTrailingStop        = 0;              // Trailing Stop (Points, 0 = Nonaktif)
input int                InpTrailingStep        = 50;             // Trailing Step (Points)
input int                InpBreakEven           = 0;              // Pemicu Break-Even (Points, 0 = Nonaktif)
input int                InpBreakEvenBuffer     = 10;             // Lock Profit Break-Even (Points)

input group "=== 7. Money Management (Lot) ==="
input ENUM_LOT_MODE      InpLotMode             = LOT_MODE_FIXED; // Mode Perhitungan Lot
input double             InpFixedLot            = 0.01;           // Ukuran Fixed Lot (Base Lot)
input double             InpRiskPercent         = 1.0;            // Risiko per Transaksi (% Saldo)

input group "=== 8. Fitur Martingale ==="
input bool               InpEnableMartingale        = false;          // Aktifkan Fitur Martingale
input ENUM_MARTINGALE_MODE InpMartingaleMode        = MARTINGALE_STACKING_GLOBAL; // Pilihan Model Martingale
input double             InpMartingaleMultiplier    = 2.0;            // Faktor Pengali (Multiplier, misal 2.0 atau 1.5)
input int                InpMaxMartingaleSteps      = 5;              // Maksimal Langkah/Level Martingale (misal 20)
input double             InpMaxMartingaleLot        = 1.0;            // Batas Maksimal Lot Martingale (0 = Tanpa Batas)
input bool               InpEnableMaxStepBasketClose= true;           // Aktifkan Close All saat Max Martingale & Basket Profit Tercapai
input double             InpMaxStepBasketProfit     = 1000.0;         // Target Basket Profit saat Max Step (Money/Currency, misal 1000)

input group "=== 9. Sistem & Filter Eksekusi ==="
input ulong              InpMagicNumber         = 991701;         // EA Magic Number
input int                InpSlippage            = 30;             // Maksimal Toleransi Slippage (Points)
input int                InpMaxSpread           = 50;             // Maksimal Spread Diizinkan (Points, 0 = Bebas)
input string             InpTradeComment        = "EMA9_17_Break";// Komentar Order
input bool               InpShowCloseAllBtn     = true;           // Tampilkan Tombol Close All di Chart

#define BTN_CLOSE_ALL_NAME "btn_close_all_orders"

//+------------------------------------------------------------------+
//| VARIABEL GLOBAL                                                  |
//+------------------------------------------------------------------+
CTrade         m_trade;
CPositionInfo  m_position;
CSymbolInfo    m_symbol;
CAccountInfo   m_account;

int            h_emaFast = INVALID_HANDLE;
int            h_emaSlow = INVALID_HANDLE;
int            h_atr     = INVALID_HANDLE;
datetime       g_lastBarTime = 0;

int CloseAllOrders();

//+------------------------------------------------------------------+
//| Helper: Dapatkan Timeframe Kerja Efektif                         |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetEffectiveTimeframe()
  {
   return (InpTimeframe == PERIOD_CURRENT) ? _Period : InpTimeframe;
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Inisialisasi Symbol
   if(!m_symbol.Name(_Symbol))
     {
      Print("Error: Gagal inisialisasi simbol ", _Symbol);
      return(INIT_FAILED);
     }
   m_symbol.Refresh();

   // Setup Trade Engine
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetDeviationInPoints(InpSlippage);
   m_trade.SetTypeFillingBySymbol(m_symbol.Name());

   ENUM_TIMEFRAMES tf = GetEffectiveTimeframe();

   // Buat Handle Indikator EMA 9 & EMA 17 pada Timeframe yang dipilih
   h_emaFast = iMA(_Symbol, tf, InpEmaFastPeriod, 0, InpEmaMethod, InpEmaAppliedPrice);
   h_emaSlow = iMA(_Symbol, tf, InpEmaSlowPeriod, 0, InpEmaMethod, InpEmaAppliedPrice);

   if(h_emaFast == INVALID_HANDLE || h_emaSlow == INVALID_HANDLE)
     {
      Print("Error: Gagal membuat handle indikator EMA.");
      return(INIT_FAILED);
     }

   // Buat Handle Indikator ATR jika filter diaktifkan
   if(InpEnableAtrFilter)
     {
      h_atr = iATR(_Symbol, tf, InpAtrPeriod);
      if(h_atr == INVALID_HANDLE)
        {
         Print("Error: Gagal membuat handle indikator ATR.");
         return(INIT_FAILED);
        }
     }

   PrintFormat("EMA_CrossBreak_EA v1.20 berhasil dimuat | Simbol: %s | Timeframe Sinyal: %s | ATR Filter: %s", 
               _Symbol, EnumToString(tf), InpEnableAtrFilter ? "ON" : "OFF");

   // Buat Tombol Close All di Chart
   if(InpShowCloseAllBtn)
     {
      CreateCloseAllButton();
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(h_emaFast != INVALID_HANDLE) IndicatorRelease(h_emaFast);
   if(h_emaSlow != INVALID_HANDLE) IndicatorRelease(h_emaSlow);
   if(h_atr     != INVALID_HANDLE) IndicatorRelease(h_atr);
   DestroyCloseAllButton();
   Comment("");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   m_symbol.RefreshRates();

   //--- Cek Basket Profit saat Max Martingale tercapai (Tutup semua order jika target profit terpenuhi)
   CheckMaxMartingaleBasketClose();

   //--- Jalankan Trailing Stop & Break-Even pada posisi aktif setiap tick
   ManageTrailingAndBreakEven();

   //--- Deteksi pembukaan candle baru pada Timeframe yang dipilih
   ENUM_TIMEFRAMES tf = GetEffectiveTimeframe();
   datetime currentBarTime = iTime(_Symbol, tf, 0);
   if(currentBarTime == 0) return;

   // Hanya evaluasi sinyal jika baru saja ganti candle pada timeframe tersebut
   if(currentBarTime != g_lastBarTime)
     {
      CheckSignalAndExecute(tf);
      g_lastBarTime = currentBarTime;
     }

   // Update ringkasan status di chart
   UpdateDashboard(tf);
  }

//+------------------------------------------------------------------+
//| Evaluasi Sinyal Breakout EMA dan Eksekusi Order                  |
//+------------------------------------------------------------------+
void CheckSignalAndExecute(ENUM_TIMEFRAMES tf)
  {
   // Filter Spread
   if(InpMaxSpread > 0 && m_symbol.Spread() > InpMaxSpread)
     {
      Print("Spread saat ini terlalu tinggi: ", m_symbol.Spread(), " points (Batas: ", InpMaxSpread, ")");
      return;
     }

   // Ambil data harga Candle Shift 1 (yang baru saja close/selesai)
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, tf, 1, 1, rates) < 1)
     {
      Print("Gagal mengambil data candle Shift 1 pada timeframe ", EnumToString(tf));
      return;
     }

   double openBar1  = rates[0].open;
   double closeBar1 = rates[0].close;
   double highBar1  = rates[0].high;
   double lowBar1   = rates[0].low;

   // Ambil nilai EMA 9 & EMA 17 pada Shift 1
   double emaFastBuffer[];
   double emaSlowBuffer[];
   ArraySetAsSeries(emaFastBuffer, true);
   ArraySetAsSeries(emaSlowBuffer, true);

   if(CopyBuffer(h_emaFast, 0, 1, 1, emaFastBuffer) < 1 ||
      CopyBuffer(h_emaSlow, 0, 1, 1, emaSlowBuffer) < 1)
     {
      Print("Gagal mengambil buffer nilai EMA pada Shift 1");
      return;
     }

   double emaFastVal = emaFastBuffer[0];
   double emaSlowVal = emaSlowBuffer[0];

   double minEMA = MathMin(emaFastVal, emaSlowVal);
   double maxEMA = MathMax(emaFastVal, emaSlowVal);

   bool buySignal  = false;
   bool sellSignal = false;

   //==================================================================
   // LOGIKA TRIGGER:
   // 1. BUY: Open di bawah kedua EMA dan Close di atas kedua EMA
   //==================================================================
   if(openBar1 < minEMA && closeBar1 > maxEMA)
     {
      buySignal = true;
     }

   //==================================================================
   // LOGIKA TRIGGER:
   // 2. SELL: Open di atas kedua EMA dan Close di bawah kedua EMA
   //==================================================================
   if(openBar1 > maxEMA && closeBar1 < minEMA)
     {
      sellSignal = true;
     }

   // Jika tidak ada sinyal breakout, selesai
   if(!buySignal && !sellSignal) return;

   //==================================================================
   // FILTER VOLATILITAS & MOMENTUM (BODY CANDLE vs ATR)
   // Menyaring candle kecil / doji di kondisi sideways
   //==================================================================
   if(InpEnableAtrFilter)
     {
      double atrBuffer[];
      ArraySetAsSeries(atrBuffer, true);
      if(CopyBuffer(h_atr, 0, 1, 1, atrBuffer) < 1)
        {
         Print("Gagal mengambil buffer nilai ATR pada Shift 1");
         return;
        }

      double atrVal          = atrBuffer[0];
      double bodySize        = MathAbs(closeBar1 - openBar1);
      double minRequiredBody = atrVal * InpMinBodyAtrRatio;

      if(bodySize < minRequiredBody)
        {
         PrintFormat("FILTER ATR: Candle Shift 1 diabaikan (Body: %.1f pt < Min %.0f%% ATR: %.1f pt). Sideways/Low Volatility.",
                     bodySize / _Point, InpMinBodyAtrRatio * 100.0, minRequiredBody / _Point);
         return;
        }

      if(InpMinBodyPoints > 0 && (bodySize / _Point) < InpMinBodyPoints)
        {
         PrintFormat("FILTER BODY: Candle Shift 1 diabaikan (Body: %.1f pt < Min Points: %d pt).",
                     bodySize / _Point, InpMinBodyPoints);
         return;
        }
     }

   //--- 1. Eksekusi Exit Rule: Tutup Posisi Berlawanan jika diaktifkan
   if(InpCloseOnOpposite)
     {
      if(buySignal)  ClosePositionsByType(POSITION_TYPE_SELL);
      if(sellSignal) ClosePositionsByType(POSITION_TYPE_BUY);
     }

   //--- 2. Validasi Stacking & Batas Jumlah Posisi
   int buyCount = 0, sellCount = 0;
   CountCurrentPositions(buyCount, sellCount);
   int totalPositions = buyCount + sellCount;

   if(!InpAllowStacking && totalPositions > 0)
     {
      Print("Stacking dinonaktifkan dan masih ada ", totalPositions, " posisi terbuka. Order dilewati.");
      return;
     }

   if(InpMaxPositions > 0 && totalPositions >= InpMaxPositions)
     {
      Print("Maksimal posisi tercapai (", totalPositions, "/", InpMaxPositions, "). Order dilewati.");
      return;
     }

   //--- 3. Validasi Jarak Minimum antar Posisi Searah
   if(InpMinDistancePoints > 0)
     {
      if(buySignal && !CheckMinDistance(POSITION_TYPE_BUY, InpMinDistancePoints))
        {
         Print("Filter jarak minimum mencegah eksekusi BUY baru.");
         return;
        }
      if(sellSignal && !CheckMinDistance(POSITION_TYPE_SELL, InpMinDistancePoints))
        {
         Print("Filter jarak minimum mencegah eksekusi SELL baru.");
         return;
        }
     }

   //--- 4. Eksekusi Order
   if(buySignal)
     {
      OpenBuy(highBar1, lowBar1);
     }
   else if(sellSignal)
     {
      OpenSell(highBar1, lowBar1);
     }
  }

//+------------------------------------------------------------------+
//| Buka Order BUY                                                   |
//+------------------------------------------------------------------+
void OpenBuy(double shift1High, double shift1Low)
  {
   m_symbol.RefreshRates();
   double ask = m_symbol.Ask();
   double sl = 0.0;
   double tp = 0.0;

   // Hitung SL
   if(InpSLMode == SL_MODE_POINTS)
     {
      if(InpStopLossPoints > 0)
         sl = ask - (InpStopLossPoints * _Point);
     }
   else if(InpSLMode == SL_MODE_CANDLE)
     {
      sl = shift1Low - (InpCandleSLBuffer * _Point);
     }

   // Hitung TP
   if(InpTakeProfitPoints > 0)
     {
      tp = ask + (InpTakeProfitPoints * _Point);
     }

   // Normalisasi harga
   if(sl > 0) sl = NormalizeDouble(sl, _Digits);
   if(tp > 0) tp = NormalizeDouble(tp, _Digits);

   double lotSize = CalculateLotSize(ask, sl, POSITION_TYPE_BUY);

   PrintFormat("TRIGGER BUY | Ask: %f | SL: %f | TP: %f | Lot: %.2f", ask, sl, tp, lotSize);

   if(!m_trade.Buy(lotSize, _Symbol, ask, sl, tp, InpTradeComment))
     {
      Print("Gagal open BUY. Error: ", m_trade.ResultRetcode(), " - ", m_trade.ResultRetcodeDescription());
     }
   else
     {
      Print("Order BUY berhasil dibuka! Ticket: ", m_trade.ResultOrder());
     }
  }

//+------------------------------------------------------------------+
//| Buka Order SELL                                                  |
//+------------------------------------------------------------------+
void OpenSell(double shift1High, double shift1Low)
  {
   m_symbol.RefreshRates();
   double bid = m_symbol.Bid();
   double sl = 0.0;
   double tp = 0.0;

   // Hitung SL
   if(InpSLMode == SL_MODE_POINTS)
     {
      if(InpStopLossPoints > 0)
         sl = bid + (InpStopLossPoints * _Point);
     }
   else if(InpSLMode == SL_MODE_CANDLE)
     {
      sl = shift1High + (InpCandleSLBuffer * _Point);
     }

   // Hitung TP
   if(InpTakeProfitPoints > 0)
     {
      tp = bid - (InpTakeProfitPoints * _Point);
     }

   // Normalisasi harga
   if(sl > 0) sl = NormalizeDouble(sl, _Digits);
   if(tp > 0) tp = NormalizeDouble(tp, _Digits);

   double lotSize = CalculateLotSize(bid, sl, POSITION_TYPE_SELL);

   PrintFormat("TRIGGER SELL | Bid: %f | SL: %f | TP: %f | Lot: %.2f", bid, sl, tp, lotSize);

   if(!m_trade.Sell(lotSize, _Symbol, bid, sl, tp, InpTradeComment))
     {
      Print("Gagal open SELL. Error: ", m_trade.ResultRetcode(), " - ", m_trade.ResultRetcodeDescription());
     }
   else
     {
      Print("Order SELL berhasil dibuka! Ticket: ", m_trade.ResultOrder());
     }
  }

//+------------------------------------------------------------------+
//| Model 1: Hitung Loss Streak Global (Semua Trade Tertutup)        |
//+------------------------------------------------------------------+
int GetLossStreakGlobal()
  {
   if(!HistorySelect(0, TimeCurrent())) return 0;

   int streak = 0;
   int totalDeals = HistoryDealsTotal();

   for(int i = totalDeals - 1; i >= 0; i--)
     {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0)
        {
         if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) == _Symbol &&
            HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == InpMagicNumber)
           {
            ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
            if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT || entry == DEAL_ENTRY_OUT_BY)
              {
               double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                             + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                             + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

               if(profit < 0)
                  streak++;
               else if(profit > 0)
                  break;
              }
           }
        }
     }
   return streak;
  }

//+------------------------------------------------------------------+
//| Model 2: Hitung Loss Streak Sesuai Arah Posisi (BUY / SELL)      |
//+------------------------------------------------------------------+
int GetLossStreakByType(ENUM_POSITION_TYPE posType)
  {
   if(!HistorySelect(0, TimeCurrent())) return 0;

   int streak = 0;
   int totalDeals = HistoryDealsTotal();
   ENUM_DEAL_TYPE targetCloseDealType = (posType == POSITION_TYPE_BUY) ? DEAL_TYPE_SELL : DEAL_TYPE_BUY;

   for(int i = totalDeals - 1; i >= 0; i--)
     {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0)
        {
         if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) == _Symbol &&
            HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == InpMagicNumber)
           {
            ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
            if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT || entry == DEAL_ENTRY_OUT_BY)
              {
               ENUM_DEAL_TYPE dType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
               if(dType == targetCloseDealType)
                 {
                  double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                                + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                                + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

                  if(profit < 0)
                     streak++;
                  else if(profit > 0)
                     break;
                 }
              }
           }
        }
     }
   return streak;
  }

//+------------------------------------------------------------------+
//| Model 3: Hitung Total Semua Posisi yang Sedang Terbuka (Global)  |
//+------------------------------------------------------------------+
int GetCurrentStackGlobal()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
            count++;
        }
     }
   return count;
  }

//+------------------------------------------------------------------+
//| Model 4: Hitung Posisi yang Terbuka Khusus Searah (BUY / SELL)   |
//+------------------------------------------------------------------+
int GetCurrentStackByType(ENUM_POSITION_TYPE posType)
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
           {
            if(m_position.PositionType() == posType)
               count++;
           }
        }
     }
   return count;
  }

//+------------------------------------------------------------------+
//| Dapatkan Step Martingale Tertinggi / Aktif Saat Ini              |
//+------------------------------------------------------------------+
int GetCurrentMartingaleStep()
  {
   int currentStep = 0;
   switch(InpMartingaleMode)
     {
      case MARTINGALE_STACKING_GLOBAL:
         currentStep = GetCurrentStackGlobal();
         break;
      case MARTINGALE_STACKING_BY_TYPE:
         currentStep = MathMax(GetCurrentStackByType(POSITION_TYPE_BUY), GetCurrentStackByType(POSITION_TYPE_SELL));
         break;
      case MARTINGALE_AFTER_LOSS_GLOBAL:
         currentStep = GetLossStreakGlobal();
         break;
      case MARTINGALE_AFTER_LOSS_BY_TYPE:
         currentStep = MathMax(GetLossStreakByType(POSITION_TYPE_BUY), GetLossStreakByType(POSITION_TYPE_SELL));
         break;
     }
   return currentStep;
  }

//+------------------------------------------------------------------+
//| Hitung Total Floating Profit Bersih Semua Posisi EA Ini          |
//+------------------------------------------------------------------+
double GetTotalBasketProfit()
  {
   double totalProfit = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
           {
            totalProfit += m_position.Profit() + m_position.Swap();
           }
        }
     }
   return totalProfit;
  }

//+------------------------------------------------------------------+
//| Cek & Tutup Semua Posisi jika Max Martingale & Target Tercapai   |
//+------------------------------------------------------------------+
void CheckMaxMartingaleBasketClose()
  {
   if(!InpEnableMartingale || !InpEnableMaxStepBasketClose) return;
   if(InpMaxMartingaleSteps <= 0 || InpMaxStepBasketProfit <= 0.0) return;

   int currentStep = GetCurrentMartingaleStep();

   // Pemicu: Jika step martingale sudah mencapai atau melampaui batas maksimal yang diset
   if(currentStep >= InpMaxMartingaleSteps)
     {
      double basketProfit = GetTotalBasketProfit();
      if(basketProfit >= InpMaxStepBasketProfit)
        {
         PrintFormat("BASKET TP TERCAPAI: Martingale mencapai batas maksimal (%d >= %d) dan Basket Profit tercapai (%.2f >= %.2f). Menutup semua order!",
                     currentStep, InpMaxMartingaleSteps, basketProfit, InpMaxStepBasketProfit);
         int closed = CloseAllOrders();
         PrintFormat("BASKET TP SELESAI: Berhasil menutup %d posisi aktif.", closed);
        }
     }
  }

//+------------------------------------------------------------------+
//| Hitung Ukuran Lot (dengan Dukungan 4 Model Martingale)            |
//+------------------------------------------------------------------+
double CalculateLotSize(double entryPrice, double stopLossPrice, ENUM_POSITION_TYPE posType)
  {
   double baseLot = InpFixedLot;

   if(InpLotMode == LOT_MODE_PERCENT && stopLossPrice > 0)
     {
      double riskMoney = m_account.Balance() * (InpRiskPercent / 100.0);
      double slDistPoints = MathAbs(entryPrice - stopLossPrice) / _Point;

      if(slDistPoints > 0)
        {
         double tickValue = m_symbol.TickValue();
         double tickSize  = m_symbol.TickSize();
         if(tickSize > 0 && tickValue > 0)
           {
            double pointValue = tickValue * (_Point / tickSize);
            baseLot = riskMoney / (slDistPoints * pointValue);
           }
        }
     }

   double lot = baseLot;

   //--- Penerapan Fitur Martingale Berdasarkan Model yang Dipilih
   if(InpEnableMartingale)
     {
      int step = 0;
      switch(InpMartingaleMode)
        {
         case MARTINGALE_STACKING_GLOBAL:
            step = GetCurrentStackGlobal();
            break;
         case MARTINGALE_STACKING_BY_TYPE:
            step = GetCurrentStackByType(posType);
            break;
         case MARTINGALE_AFTER_LOSS_GLOBAL:
            step = GetLossStreakGlobal();
            break;
         case MARTINGALE_AFTER_LOSS_BY_TYPE:
            step = GetLossStreakByType(posType);
            break;
        }

      if(step > 0)
        {
         int effectiveStep = (InpMaxMartingaleSteps > 0) ? MathMin(step, InpMaxMartingaleSteps) : step;
         lot = baseLot * MathPow(InpMartingaleMultiplier, effectiveStep);
         PrintFormat("Martingale Aktif [Mode: %d | Step: %d (Maks: %d)] -> Lot: %.2f (Base: %.2f)",
                     (int)InpMartingaleMode, step, InpMaxMartingaleSteps, lot, baseLot);
        }
     }

   // Batasi jika melebihi batas InpMaxMartingaleLot
   if(InpEnableMartingale && InpMaxMartingaleLot > 0 && lot > InpMaxMartingaleLot)
     {
      lot = InpMaxMartingaleLot;
      PrintFormat("Lot dibatasi oleh InpMaxMartingaleLot: %.2f", lot);
     }

   // Batasi sesuai spesifikasi broker (MinLot, MaxLot, LotStep)
   double minLot  = m_symbol.LotsMin();
   double maxLot  = m_symbol.LotsMax();
   double lotStep = m_symbol.LotsStep();

   lot = MathFloor(lot / lotStep) * lotStep;
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;

   return NormalizeDouble(lot, 2);
  }

//+------------------------------------------------------------------+
//| Hitung Posisi Aktif Berdasarkan Magic Number & Simbol            |
//+------------------------------------------------------------------+
void CountCurrentPositions(int &buyCount, int &sellCount)
  {
   buyCount = 0;
   sellCount = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
           {
            if(m_position.PositionType() == POSITION_TYPE_BUY)
               buyCount++;
            else if(m_position.PositionType() == POSITION_TYPE_SELL)
               sellCount++;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Cek Jarak Minimum terhadap Posisi Terakhir yang Searah           |
//+------------------------------------------------------------------+
bool CheckMinDistance(ENUM_POSITION_TYPE posType, int minPoints)
  {
   m_symbol.RefreshRates();
   double currentPrice = (posType == POSITION_TYPE_BUY) ? m_symbol.Ask() : m_symbol.Bid();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
           {
            if(m_position.PositionType() == posType)
              {
               double posOpenPrice = m_position.PriceOpen();
               double dist = MathAbs(currentPrice - posOpenPrice) / _Point;
               if(dist < minPoints)
                 {
                  return false;
                 }
              }
           }
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Tutup Posisi Berdasarkan Arah (BUY / SELL)                       |
//+------------------------------------------------------------------+
void ClosePositionsByType(ENUM_POSITION_TYPE posType)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
           {
            if(m_position.PositionType() == posType)
              {
               m_trade.PositionClose(m_position.Ticket());
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Manajemen Trailing Stop & Break-Even                             |
//+------------------------------------------------------------------+
void ManageTrailingAndBreakEven()
  {
   if(InpTrailingStop <= 0 && InpBreakEven <= 0) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Symbol() != _Symbol || m_position.Magic() != InpMagicNumber) continue;

      ulong  ticket    = m_position.Ticket();
      double openPrice = m_position.PriceOpen();
      double curSL     = m_position.StopLoss();
      double curTP     = m_position.TakeProfit();

      // Posisi BUY
      if(m_position.PositionType() == POSITION_TYPE_BUY)
        {
         double bid = m_symbol.Bid();

         // 1. Break-Even
         if(InpBreakEven > 0)
           {
            double beTriggerPrice = openPrice + (InpBreakEven * _Point);
            double beNewSL        = openPrice + (InpBreakEvenBuffer * _Point);
            if(bid >= beTriggerPrice && (curSL < beNewSL || curSL == 0.0))
              {
               m_trade.PositionModify(ticket, NormalizeDouble(beNewSL, _Digits), curTP);
               continue;
              }
           }

         // 2. Trailing Stop
         if(InpTrailingStop > 0)
           {
            double targetSL = bid - (InpTrailingStop * _Point);
            if(bid - openPrice > InpTrailingStop * _Point)
              {
               if(targetSL > curSL + (InpTrailingStep * _Point) || curSL == 0.0)
                 {
                  m_trade.PositionModify(ticket, NormalizeDouble(targetSL, _Digits), curTP);
                 }
              }
           }
        }
      // Posisi SELL
      else if(m_position.PositionType() == POSITION_TYPE_SELL)
        {
         double ask = m_symbol.Ask();

         // 1. Break-Even
         if(InpBreakEven > 0)
           {
            double beTriggerPrice = openPrice - (InpBreakEven * _Point);
            double beNewSL        = openPrice - (InpBreakEvenBuffer * _Point);
            if(ask <= beTriggerPrice && (curSL > beNewSL || curSL == 0.0))
              {
               m_trade.PositionModify(ticket, NormalizeDouble(beNewSL, _Digits), curTP);
               continue;
              }
           }

         // 2. Trailing Stop
         if(InpTrailingStop > 0)
           {
            double targetSL = ask + (InpTrailingStop * _Point);
            if(openPrice - ask > InpTrailingStop * _Point)
              {
               if(targetSL < curSL - (InpTrailingStep * _Point) || curSL == 0.0)
                 {
                  m_trade.PositionModify(ticket, NormalizeDouble(targetSL, _Digits), curTP);
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Dashboard Info di Chart                                          |
//+------------------------------------------------------------------+
void UpdateDashboard(ENUM_TIMEFRAMES tf)
  {
   int buyCount = 0, sellCount = 0;
   CountCurrentPositions(buyCount, sellCount);

   double emaF[1], emaS[1];
   CopyBuffer(h_emaFast, 0, 1, 1, emaF);
   CopyBuffer(h_emaSlow, 0, 1, 1, emaS);

   string slDesc = (InpSLMode == SL_MODE_POINTS) ? 
                   (IntegerToString(InpStopLossPoints) + " Points") : 
                   ("Candle Shift 1 (+ " + IntegerToString(InpCandleSLBuffer) + " pt)");

   string martDesc = "DISABLED";
   if(InpEnableMartingale)
     {
      int currentStep = GetCurrentMartingaleStep();
      string modeName = "";

      switch(InpMartingaleMode)
        {
         case MARTINGALE_STACKING_GLOBAL:
            modeName = "Stacking Global";
            break;
         case MARTINGALE_STACKING_BY_TYPE:
            modeName = "Stacking Per Arah";
            break;
         case MARTINGALE_AFTER_LOSS_GLOBAL:
            modeName = "After Loss Global";
            break;
         case MARTINGALE_AFTER_LOSS_BY_TYPE:
            modeName = "After Loss Per Arah";
            break;
        }

      martDesc = StringFormat("%s (Step: %d | Mult: %.1fx)", modeName, currentStep, InpMartingaleMultiplier);
     }

   double currentBasketProfit = GetTotalBasketProfit();
   string basketProfitDesc    = StringFormat("%.2f %s", currentBasketProfit, m_account.Currency());

   string maxStepBasketDesc   = "DISABLED";
   if(InpEnableMartingale && InpEnableMaxStepBasketClose)
     {
      maxStepBasketDesc = StringFormat("ACTIVE (Step >= %d & Profit >= %.2f %s)", 
                                       InpMaxMartingaleSteps, InpMaxStepBasketProfit, m_account.Currency());
     }

   string atrFilterDesc = "DISABLED";
   if(InpEnableAtrFilter)
     {
      double atrBuf[1];
      double currentATR = 0.0;
      if(CopyBuffer(h_atr, 0, 1, 1, atrBuf) > 0) currentATR = atrBuf[0] / _Point;
      atrFilterDesc = StringFormat("ACTIVE (Ratio: %.0f%% ATR | ATR: %.1f pt)", 
                                   InpMinBodyAtrRatio * 100.0, currentATR);
     }

   string text = "========================================\n" +
                 "   EMA 9 & 17 BREAKOUT EA v1.20 (MT5)   \n" +
                 "========================================\n" +
                 " Simbol        : " + _Symbol + "\n" +
                 " TF Sinyal     : " + EnumToString(tf) + ((InpTimeframe == PERIOD_CURRENT) ? " (Chart)" : " (Locked)") + "\n" +
                 " EMA " + IntegerToString(InpEmaFastPeriod) + " (Shift 1): " + DoubleToString(emaF[0], _Digits) + "\n" +
                 " EMA " + IntegerToString(InpEmaSlowPeriod) + " (Shift 1): " + DoubleToString(emaS[0], _Digits) + "\n" +
                 " ATR Filter    : " + atrFilterDesc + "\n" +
                 " Spread        : " + IntegerToString(m_symbol.Spread()) + " Points\n" +
                 " Posisi BUY    : " + IntegerToString(buyCount) + " Posisi\n" +
                 " Posisi SELL   : " + IntegerToString(sellCount) + " Posisi\n" +
                 " Basket Profit : " + basketProfitDesc + "\n" +
                 " Stacking      : " + (InpAllowStacking ? "ENABLED (Max: " + IntegerToString(InpMaxPositions) + ")" : "DISABLED") + "\n" +
                 " Martingale    : " + martDesc + "\n" +
                 " MaxStep Basket: " + maxStepBasketDesc + "\n" +
                 " Close Opposite: " + (InpCloseOnOpposite ? "YES" : "NO") + "\n" +
                 " SL Mode       : " + slDesc + "\n" +
                 " TP Target     : " + (InpTakeProfitPoints > 0 ? IntegerToString(InpTakeProfitPoints) + " Points" : "Tanpa TP") + "\n" +
                 "========================================";

   Comment(text);
  }

//+------------------------------------------------------------------+
//| Buat Tombol Close All di Chart                                   |
//+------------------------------------------------------------------+
void CreateCloseAllButton()
  {
   // Hapus jika tombol lama masih ada
   ObjectDelete(0, BTN_CLOSE_ALL_NAME);

   if(!ObjectCreate(0, BTN_CLOSE_ALL_NAME, OBJ_BUTTON, 0, 0, 0))
     {
      Print("Gagal membuat tombol Close All pada chart");
      return;
     }

   // Atur Posisi & Tampilan Tombol
   ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_XDISTANCE, 15);
   ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_YDISTANCE, 275);
   ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_XSIZE, 185);
   ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_YSIZE, 32);
   ObjectSetString(0,  BTN_CLOSE_ALL_NAME, OBJPROP_TEXT, "CLOSE ALL ORDERS");
   ObjectSetString(0,  BTN_CLOSE_ALL_NAME, OBJPROP_FONT, "Trebuchet MS");
   ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_BGCOLOR, C'190,40,40');
   ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_BORDER_COLOR, clrWhite);
   ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_ZORDER, 100);

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Hapus Tombol Close All dari Chart                                |
//+------------------------------------------------------------------+
void DestroyCloseAllButton()
  {
   ObjectDelete(0, BTN_CLOSE_ALL_NAME);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Tutup SEMUA Posisi Aktif EA Ini                                  |
//+------------------------------------------------------------------+
int CloseAllOrders()
  {
   int closedCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(m_position.SelectByIndex(i))
        {
         if(m_position.Symbol() == _Symbol && m_position.Magic() == InpMagicNumber)
           {
            if(m_trade.PositionClose(m_position.Ticket()))
              {
               closedCount++;
              }
           }
        }
     }
   return closedCount;
  }

//+------------------------------------------------------------------+
//| Chart Event Handler: Menangkap Klik Tombol di Chart / Backtest   |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam == BTN_CLOSE_ALL_NAME)
        {
         Print("Tombol 'CLOSE ALL ORDERS' diklik!");
         int totalClosed = CloseAllOrders();
         PrintFormat("Berhasil menutup %d posisi aktif.", totalClosed);

         // Kembalikan status tombol agar tidak terkunci (unpress)
         ObjectSetInteger(0, BTN_CLOSE_ALL_NAME, OBJPROP_STATE, false);
         ChartRedraw(0);
        }
     }
  }
//+------------------------------------------------------------------+
