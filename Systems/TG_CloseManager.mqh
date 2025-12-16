//+------------------------------------------------------------------+
//|                                       Systems/TG_CloseManager.mqh|
//|                                          Titan Grid EA v1.08     |
//|                  Close Manager:  Global Basket Trailing Logic     |
//|             ✅ ENHANCED: Better GridSlicer cleanup               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.08"

#ifndef TG_CLOSE_MANAGER_MQH
#define TG_CLOSE_MANAGER_MQH

#include <Trade/Trade.mqh>
#include "../Core/TG_Definitions.mqh"
#include "../Core/TG_MagicNumbers.mqh"
#include "../Core/TG_StateManager.mqh"
#include "../Core/TG_Logger.mqh"
#include "../Utilities/TG_PositionScanner.mqh"

class CCloseManager
{
private:
   CTrade* m_trade;
   CMagicNumberManager* m_magic;
   CStateManager* m_state;
   CLogger* m_logger;
   CPositionScanner* m_scanner;
   
   // --- GLOBAL BASKET SETTINGS ---
   bool     m_use_global_basket;
   double   m_trail_start_mult;
   double   m_trail_stop_mult;
   double   m_base_lot_l1;       // Lot Layer 1 untuk referensi kalkulasi
   
   // Internal Tracking for Basket
   double   m_basket_hwm;        // High Water Mark (Profit Tertinggi)
   bool     m_basket_active;     // Apakah trailing sedang aktif? 
   
   // Risk Settings
   bool     m_use_equity_stop;
   double   m_equity_stop_percent;
   double   m_max_daily_profit;
   double   m_max_daily_loss;
   
   // Daily Tracking
   double   m_start_balance_day;
   int      m_last_day_check;

   //+------------------------------------------------------------------+
   //| Helper:  Close Position by Ticket                                 |
   //+------------------------------------------------------------------+
   bool CloseTicket(ulong ticket, string reason)
   {
      if(m_trade.PositionClose(ticket))
      {
         // Log dipindahkan ke level strategi utama agar tidak spam
         return true;
      }
      return false;
   }

public:
   CCloseManager() 
   {
      m_trade = NULL;
      m_start_balance_day = 0;
      m_last_day_check = -1;
      m_base_lot_l1 = 0.01;
      m_basket_hwm = 0.0;
      m_basket_active = false;
   }

   //+------------------------------------------------------------------+
   //| Initialize - 5 Parameters (sesuai TitanGrid_v1.0.mq5 line 115)  |
   //+------------------------------------------------------------------+
   bool Initialize(CTrade* trade, CMagicNumberManager* magic, CStateManager* state, 
                   CLogger* logger, CPositionScanner* scanner)
   {
      if(trade == NULL || magic == NULL || state == NULL || scanner == NULL) return false;
      
      m_trade = trade;
      m_magic = magic;
      m_state = state;
      m_logger = logger;
      m_scanner = scanner;
      
      m_start_balance_day = AccountInfoDouble(ACCOUNT_BALANCE);
      
      return true;
   }

   //+------------------------------------------------------------------+
   //| CONFIGURATION SETTERS                                            |
   //+------------------------------------------------------------------+
   void SetGlobalBasketStrategy(bool use, double start_mult, double stop_mult, double base_lot) 
   {
      m_use_global_basket = use; 
      m_trail_start_mult = start_mult; 
      m_trail_stop_mult = stop_mult;
      m_base_lot_l1 = base_lot;
      
      if(m_base_lot_l1 <= 0) m_base_lot_l1 = 0.01; // Safety
   }
   
   void SetEquityStop(bool use, double percent) {
      m_use_equity_stop = use; m_equity_stop_percent = percent;
   }
   
   void SetDailyLimits(double max_profit, double max_loss) {
      m_max_daily_profit = max_profit; m_max_daily_loss = max_loss;
   }

   //+------------------------------------------------------------------+
   //| MAIN LOGIC (OnTick)                                              |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      CheckNewDay();
      
      // Ambil Ringkasan Posisi Global
      SPositionSummary summary = m_scanner. GetSummary();
      
      // 1. Emergency Checks
      if(CheckEquityStop()) return;
      if(CheckDailyTargets()) return;
      
      // 2. Global Basket Trailing (Blueprint Logic)
      if(m_use_global_basket && summary.total_positions > 0)
      {
         ProcessGlobalBasketTrailing(summary. total_profit);
      }
      else
      {
         // Reset state jika tidak ada posisi
         m_basket_hwm = 0.0;
         m_basket_active = false;
      }
   }

   //+------------------------------------------------------------------+
   //| GLOBAL BASKET TRAILING ENGINE (PHOENIX LOGIC)                    |
   //+------------------------------------------------------------------+
   void ProcessGlobalBasketTrailing(double current_profit)
   {
      // Hitung Target Dinamis berdasarkan Lot L1
      double target_usd_start = m_base_lot_l1 * m_trail_start_mult;
      double trail_step_usd   = m_base_lot_l1 * m_trail_stop_mult;
      
      // A. Aktivasi Trailing
      if(! m_basket_active)
      {
         if(current_profit >= target_usd_start)
         {
            m_basket_active = true;
            m_basket_hwm = current_profit;
            m_logger.Info(StringFormat("🦅 Global Basket Activated!  Profit: $%.2f (Target: $%.2f)", 
                                       current_profit, target_usd_start));
         }
      }
      
      // B.  Logic Trailing (Jika Aktif)
      if(m_basket_active)
      {
         // Update High Water Mark (HWM) jika profit naik
         if(current_profit > m_basket_hwm)
         {
            m_basket_hwm = current_profit;
         }
         
         // Cek Exit Condition (Profit turun dari HWM sebesar step)
         double exit_level = m_basket_hwm - trail_step_usd;
         
         if(current_profit <= exit_level)
         {
            m_logger.Info(StringFormat("💰 GLOBAL BASKET CLOSE:  Profit $%.2f <= Exit $%.2f (HWM: $%.2f)", 
                                       current_profit, exit_level, m_basket_hwm));
            
            CloseAllPositions("Global Basket Trailing");
            
            m_basket_active = false;
            m_basket_hwm = 0.0;
         }
      }
   }

   //+------------------------------------------------------------------+
   //| CLOSE ALL POSITIONS (ENHANCED:  Better logging)                   |
   //+------------------------------------------------------------------+
   void CloseAllPositions(string reason)
   {
      int total = PositionsTotal();
      if(total == 0) return;
      
      m_logger. Info("🛑 CLOSE ALL TRIGGERED:  " + reason);
      
      int closed_mart = 0;
      int closed_gs = 0;
      int closed_other = 0;
      
      for(int i = total - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0)
         {
            long magic = PositionGetInteger(POSITION_MAGIC);
            
            if(m_magic. IsMagicOurs(magic))
            {
               // Track what we're closing
               if(m_magic.IsMartingale(magic)) closed_mart++;
               else if(m_magic.IsGridSlicer(magic)) closed_gs++;
               else closed_other++;
               
               CloseTicket(ticket, reason);
            }
         }
      }
      
      // ✅ Enhanced logging
      if(m_logger != NULL) {
         m_logger.Info(StringFormat("✅ Closed:  %d Martingale + %d GridSlicer + %d Other positions", 
                                    closed_mart, closed_gs, closed_other));
      }
      
      // Reset Main State
      m_state.EndCycle(true); 
   }

   //+------------------------------------------------------------------+
   //| DAILY & EQUITY CHECKS                                            |
   //+------------------------------------------------------------------+
   void CheckNewDay()
   {
      MqlDateTime dt;
      TimeCurrent(dt);
      if(dt.day_of_year != m_last_day_check) {
         m_start_balance_day = AccountInfoDouble(ACCOUNT_BALANCE);
         m_last_day_check = dt.day_of_year;
      }
   }
   
   bool CheckDailyTargets()
   {
      if(m_max_daily_profit <= 0 && m_max_daily_loss <= 0) return false;
      double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double daily_pl = current_equity - m_start_balance_day;
      
      if(m_max_daily_profit > 0 && daily_pl >= m_max_daily_profit) {
         m_logger.Info("🎯 DAILY PROFIT TARGET REACHED");
         CloseAllPositions("Daily Target Profit");
         return true;
      }
      if(m_max_daily_loss > 0 && daily_pl <= -m_max_daily_loss) {
         m_logger.Warning("🛑 DAILY LOSS LIMIT REACHED");
         CloseAllPositions("Daily Loss Limit");
         return true;
      }
      return false;
   }
   
   bool CheckEquityStop()
   {
      if(!m_use_equity_stop || m_equity_stop_percent <= 0) return false;
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double dd = (balance - equity) / balance * 100.0;
      
      if(dd >= m_equity_stop_percent) {
         m_logger.Error(StringFormat("💀 EQUITY STOP:  Drawdown %.2f%%", dd));
         CloseAllPositions("Equity Stop");
         return true;
      }
      return false;
   }
};

#endif