//+------------------------------------------------------------------+
//|                                   Systems/TG_EntryManager.mqh    |
//|                                      Titan Grid EA v1.17         |
//|                  Entry Manager: ZigZag + Fixed + Diagnostics     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.17"

#ifndef TG_ENTRY_MANAGER_MQH
#define TG_ENTRY_MANAGER_MQH

#include <Trade/Trade.mqh>
#include "../Core/TG_Definitions.mqh"
#include "../Core/TG_MagicNumbers.mqh"
#include "../Core/TG_StateManager.mqh"
#include "../Core/TG_Logger.mqh"
#include "../Core/TG_ErrorHandler.mqh"
#include "../Utilities/TG_LotCalculation.mqh"
#include "../Utilities/TG_PriceHelpers.mqh"
#include "TG_Martingale_v2.mqh" 
#include "TG_ZigZagFilter.mqh"
#include "TG_PendingOrderManager.mqh"

class CEntryManager
{
private:
   CTrade* m_trade;
   CMagicNumberManager* m_magic_manager;
   CStateManager* m_state_manager;
   CLogger* m_logger;
   CLotCalculator* m_lot_calculator;
   CPriceHelper* m_price_helper;
   CMartingaleManagerV2* m_martingale; 
   
   CZigZagFilter m_zigzag;
   CPendingOrderManager m_pending_manager;
   
   ENUM_ENTRY_METHOD     m_entry_method;
   int                   m_po_distance_points;
   bool                  m_po_cancel_on_opposite;
   
   ulong                 m_po_buy_ticket;
   ulong                 m_po_sell_ticket;
   bool                  m_po_active;
   
   // Timer untuk mencegah spam log
   datetime              m_last_check;
   datetime              m_last_log_wait;

public:
   CEntryManager() { m_trade = NULL; m_po_active = false; m_last_check=0; m_last_log_wait=0; }
   
   //+------------------------------------------------------------------+
   //| INITIALIZATION                                                   |
   //+------------------------------------------------------------------+
   bool Initialize(CTrade* trade, CMagicNumberManager* magic, CStateManager* state, 
                   CLogger* logger, CErrorHandler* err, CLotCalculator* lot, 
                   CPriceHelper* price, CMartingaleManagerV2* mart,
                   void* signal, // Placeholder signal
                   ENUM_ENTRY_METHOD method, int dist, bool cancel_opp, double manual_lot)
   {
      m_trade = trade; m_magic_manager = magic; m_state_manager = state;
      m_logger = logger; m_lot_calculator = lot;
      m_price_helper = price; m_martingale = mart;
      
      m_entry_method = method;
      m_po_distance_points = dist;
      m_po_cancel_on_opposite = cancel_opp;
      
      // Init ZigZag (Critical)
      if(!m_zigzag.Initialize()) {
         Print("⚠️ WARNING: ZigZag Indicator Init Failed. Check 'Examples/ZigZag.ex5'.");
      }
      m_pending_manager.Initialize(trade, &m_zigzag, logger);
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| MAIN TICK LOGIC                                                  |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      // 1. Cek Blokir Utama (Cycle/Cooldown)
      if(m_state_manager.IsCycleActive()) return; 
      
      if(!m_state_manager.IsCooldownPassed()) {
         // Debug log tiap 5 detik
         if(TimeCurrent() - m_last_log_wait > 5) {
            Print(StringFormat("⏳ Cooldown Active (%d sec remaining)", m_state_manager.GetCooldownRemaining()));
            m_last_log_wait = TimeCurrent();
         }
         return; 
      }
      
      // 2. Jika PO sudah ada, cek apakah tereksekusi
      if(m_po_active) {
         CheckPendingOrderActivation();
         return; 
      }
      
      // 3. Throttle Placement (Cek entry tiap 1 detik)
      if(TimeCurrent() - m_last_check < 1) return;
      m_last_check = TimeCurrent();
      
      PlaceEntryOrders();
   }
   
   //+------------------------------------------------------------------+
   //| PLACE ORDERS (ZigZag or Fixed)                                   |
   //+------------------------------------------------------------------+
   void PlaceEntryOrders()
   {
      double lot = m_lot_calculator.CalculateInitialLot();
      
      // Inisialisasi tiket dengan 0
      ulong tb = 0; 
      ulong ts = 0;
      
      // =================================================================
      // STRATEGI 1: ZIGZAG FILTER (Breakout Swing)
      // =================================================================
      if(InpPO_UseFilter) 
      {
         m_zigzag.Refresh();
         double high = m_zigzag.GetLastSwingHigh();
         double low = m_zigzag.GetLastSwingLow();
         
         // Jika data ZigZag belum siap (masih 0)
         if(high == 0 || low == 0) {
            if(TimeCurrent() - m_last_log_wait > 5) {
               Print("⏳ Waiting for ZigZag Swing Data...");
               m_last_log_wait = TimeCurrent();
            }
            return; 
         }
         
         double buf = InpPO_BufferPoints * _Point;
         double buy_price = high + buf;
         double sell_price = low - buf;
         
         // Validasi Jarak Aman (Stops Level)
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double stop_lvl = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
         double safe_dist = stop_lvl + (20 * _Point);
         
         // Auto-Adjust: Jika harga sudah lewat swing, pasang di atas harga sekarang
         if(buy_price <= ask + safe_dist) buy_price = ask + safe_dist;
         if(sell_price >= bid - safe_dist) sell_price = bid - safe_dist;
         
         // Normalisasi
         buy_price = NormalizeDouble(buy_price, _Digits);
         sell_price = NormalizeDouble(sell_price, _Digits);
         
         // Kirim Order BUY STOP
         m_trade.SetExpertMagicNumber(m_magic_manager.GetMartingaleBuyMagic(1));
         if(m_trade.BuyStop(lot, buy_price, _Symbol, 0, 0, ORDER_TIME_GTC, 0, "ZZ-Buy")) {
            tb = m_trade.ResultOrder();
         } else {
            Print("❌ BuyStop Error: ", m_trade.ResultRetcodeDescription());
         }
         
         // Kirim Order SELL STOP
         m_trade.SetExpertMagicNumber(m_magic_manager.GetMartingaleSellMagic(1));
         if(m_trade.SellStop(lot, sell_price, _Symbol, 0, 0, ORDER_TIME_GTC, 0, "ZZ-Sell")) {
            ts = m_trade.ResultOrder();
         } else {
            Print("❌ SellStop Error: ", m_trade.ResultRetcodeDescription());
         }
         
         // Sukses?
         if(tb > 0 && ts > 0) {
            m_po_buy_ticket = tb; m_po_sell_ticket = ts; m_po_active = true;
            m_state_manager.SetPendingOrders(tb, ts);
            m_logger.Info(StringFormat("✅ ZigZag OCO Placed (High: %.5f, Low: %.5f)", high, low));
         }
      }
      // =================================================================
      // STRATEGI 2: FIXED DISTANCE (Fallback)
      // =================================================================
      else 
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double dist = m_po_distance_points * _Point;
         
         // Kirim BUY STOP
         m_trade.SetExpertMagicNumber(m_magic_manager.GetMartingaleBuyMagic(1));
         if(m_trade.BuyStop(lot, ask + dist, _Symbol, 0, 0, ORDER_TIME_GTC, 0, "Fix-Buy")) tb = m_trade.ResultOrder();
         
         // Kirim SELL STOP
         m_trade.SetExpertMagicNumber(m_magic_manager.GetMartingaleSellMagic(1));
         if(m_trade.SellStop(lot, bid - dist, _Symbol, 0, 0, ORDER_TIME_GTC, 0, "Fix-Sell")) ts = m_trade.ResultOrder();
         
         if(tb > 0 && ts > 0) {
            m_po_buy_ticket = tb; m_po_sell_ticket = ts; m_po_active = true;
            m_state_manager.SetPendingOrders(tb, ts);
            m_logger.Info(StringFormat("✅ Fixed OCO Placed (Dist: %d pts)", m_po_distance_points));
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| CHECK IF PENDING ORDER BECAME POSITION                           |
   //+------------------------------------------------------------------+
   void CheckPendingOrderActivation()
   {
      bool b_act = (m_po_buy_ticket > 0 && PositionSelectByTicket(m_po_buy_ticket));
      bool s_act = (m_po_sell_ticket > 0 && PositionSelectByTicket(m_po_sell_ticket));
      
      // Jika Buy Stop kena -> Start Martingale Buy -> Hapus Sell Stop
      if(b_act) {
         m_logger.Info("🚀 BUY PO Triggered -> Starting Cycle");
         m_martingale.StartBuyCycle();
         if(m_po_cancel_on_opposite) CancelAll();
         Reset();
      }
      // Jika Sell Stop kena -> Start Martingale Sell -> Hapus Buy Stop
      else if(s_act) {
         m_logger.Info("🚀 SELL PO Triggered -> Starting Cycle");
         m_martingale.StartSellCycle();
         if(m_po_cancel_on_opposite) CancelAll();
         Reset();
      }
   }
   
   // --- UTILITIES ---
   
   void CancelAll() {
      if(m_po_buy_ticket > 0) m_trade.OrderDelete(m_po_buy_ticket);
      if(m_po_sell_ticket > 0) m_trade.OrderDelete(m_po_sell_ticket);
   }
   
   void CancelAllPendingOrders() {
      CancelAll();
      Reset();
   }
   
   void Reset() {
      m_po_active = false; m_po_buy_ticket=0; m_po_sell_ticket=0;
      m_state_manager.ClearPendingOrders();
   }
};

#endif