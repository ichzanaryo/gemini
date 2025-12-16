//+------------------------------------------------------------------+
//|                                       Systems/TG_CloseManager.mqh|
//|                                          Titan Grid EA v1.07     |
//|                Centralized Exit Strategy (Phoenix Logic)         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.07"

#ifndef TG_CLOSE_MANAGER_MQH
#define TG_CLOSE_MANAGER_MQH

#include <Trade/Trade.mqh>
#include "../Core/TG_Definitions.mqh"
#include "../Core/TG_MagicNumbers.mqh"
#include "../Core/TG_StateManager.mqh"
#include "../Core/TG_Logger.mqh"
#include "../Utilities/TG_PositionScanner.mqh"
#include "../Utilities/TG_LotCalculation.mqh"
#include "../Config/TG_Inputs_Main.mqh" // Access to inputs

class CCloseManager
{
private:
   CTrade* m_trade;
   CMagicNumberManager* m_magic;
   CStateManager* m_state;
   CLogger* m_logger;
   CPositionScanner* m_scanner;
   CLotCalculator* m_lot_calc; // Added to get initial lot info
   
   // --- GLOBAL BASKET STATE ---
   double m_global_hwm;    // High Water Mark for Global Profit ($)
   bool   m_global_trail_active;
   
   // --- MARTINGALE AVERAGE STATE ---
   double m_mart_hwm_points; // High Water Mark for Avg Points
   bool   m_mart_trail_active;
   
   // Daily Limits
   double m_max_daily_profit;
   double m_max_daily_loss;
   double m_start_balance_day;
   int    m_last_day_check;

   // Helper to close ticket
   bool CloseTicket(ulong ticket, string reason)
   {
      if(m_trade.PositionClose(ticket)) {
         if(m_logger != NULL) m_logger.Info(StringFormat("🔒 Closed #%d | %s", ticket, reason));
         return true;
      }
      return false;
   }

public:
   CCloseManager() {
      m_trade = NULL;
      m_start_balance_day = 0;
      m_last_day_check = -1;
      ResetState();
   }

   void ResetState() {
      m_global_hwm = -999999;
      m_global_trail_active = false;
      m_mart_hwm_points = -999999;
      m_mart_trail_active = false;
   }

   bool Initialize(CTrade* trade, CMagicNumberManager* magic, CStateManager* state, 
                   CLogger* logger, CPositionScanner* scanner, CLotCalculator* lot_calc)
   {
      if(trade == NULL || magic == NULL || state == NULL || scanner == NULL) return false;
      m_trade = trade;
      m_magic = magic;
      m_state = state;
      m_logger = logger;
      m_scanner = scanner;
      m_lot_calc = lot_calc;
      m_start_balance_day = AccountInfoDouble(ACCOUNT_BALANCE);
      return true;
   }

   void SetDailyLimits(double max_profit, double max_loss) {
      m_max_daily_profit = max_profit; m_max_daily_loss = max_loss;
   }

   //+------------------------------------------------------------------+
   //| MAIN TICK LOGIC                                                  |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      CheckNewDay();
      SPositionSummary summary = m_scanner.GetSummary();
      if(summary.total_positions == 0) {
         ResetState();
         return;
      }

      if(CheckEquityStop()) return;
      if(CheckDailyTargets()) return;

      // 1. Global Basket Trailing (Priority #1)
      CheckGlobalBasket(summary);

      // 2. Martingale Average Trailing (Priority #2 - Only if No Hedge)
      if(InpUseMartingaleAvgTrail && summary.hedge_count == 0) {
         CheckMartingaleAverage(summary);
      }
   }

   //+------------------------------------------------------------------+
   //| STRATEGY 1: GLOBAL BASKET TRAILING (Dynamic USD)                |
   //+------------------------------------------------------------------+
   void CheckGlobalBasket(SPositionSummary &summary)
   {
      // Calculate Dynamic Targets based on Initial Lot
      // Note: Using InpFixedLot directly or calculating from L1
      double initial_lot = InpFixedLot; // Or use m_lot_calc->CalculateInitialLot()
      
      double start_usd = initial_lot * InpGlobalTrailStart_Multiplier;
      double stop_usd = initial_lot * InpGlobalTrailStop_Multiplier;
      double current_profit = summary.total_profit; // Net PL (Profit+Swap+Comm)

      // Activation
      if(current_profit >= start_usd) {
         if(!m_global_trail_active) {
            m_global_trail_active = true;
            m_global_hwm = current_profit;
            if(m_logger) m_logger.Info(StringFormat("🚀 Global Basket Trail ACTIVATED. Profit: $%.2f > Start: $%.2f", current_profit, start_usd));
         }
      }

      // Trailing Logic
      if(m_global_trail_active)
      {
         // Update High Water Mark
         if(current_profit > m_global_hwm) {
            m_global_hwm = current_profit;
         }

         // Check Exit Condition
         double exit_level = m_global_hwm - stop_usd;
         
         // Logging (Throttle to avoid spam)
         // Print(StringFormat("Global Trail: Curr=$%.2f, HWM=$%.2f, Exit=$%.2f", current_profit, m_global_hwm, exit_level));

         if(current_profit <= exit_level) {
            if(m_logger) m_logger.Info(StringFormat("💰 Global Basket CLOSED. Profit: $%.2f (HWM: $%.2f - Step: $%.2f)", current_profit, m_global_hwm, stop_usd));
            CloseAllPositions("Global Basket Profit");
            ResetState();
         }
      }
   }

   //+------------------------------------------------------------------+
   //| STRATEGY 2: MARTINGALE AVERAGE TRAILING (Points)                |
   //+------------------------------------------------------------------+
   void CheckMartingaleAverage(SPositionSummary &summary)
   {
      // Determine active cycle direction
      double avg_price = 0;
      ENUM_POSITION_TYPE dir = POSITION_TYPE_BUY;
      
      if(summary.mart_buy_count > 0 && summary.mart_sell_count == 0) {
         avg_price = summary.mart_buy_avg_price;
         dir = POSITION_TYPE_BUY;
      } else if(summary.mart_sell_count > 0 && summary.mart_buy_count == 0) {
         avg_price = summary.mart_sell_avg_price;
         dir = POSITION_TYPE_SELL;
      } else {
         return; // Hedged or No positions, handled by Global Basket
      }

      double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      // Calculate Distance in Points (Profit)
      double dist_points = 0;
      if(dir == POSITION_TYPE_BUY) {
         dist_points = (current_bid - avg_price) / point;
      } else {
         dist_points = (avg_price - current_ask) / point;
      }

      // Setup Parameters
      double start_pts = InpTrailingStartAV;
      double stop_pts = InpTrailingStop;

      // Activation
      if(dist_points >= start_pts) {
         if(!m_mart_trail_active) {
            m_mart_trail_active = true;
            m_mart_hwm_points = dist_points;
            if(m_logger) m_logger.Info(StringFormat("📉 Martingale Avg Trail ACTIVATED. Dist: %.0f pts > Start: %.0f pts", dist_points, start_pts));
         }
      }

      // Trailing Logic
      if(m_mart_trail_active)
      {
         if(dist_points > m_mart_hwm_points) {
            m_mart_hwm_points = dist_points;
         }

         double exit_threshold = m_mart_hwm_points - stop_pts;
         
         if(dist_points <= exit_threshold) {
            if(m_logger) m_logger.Info(StringFormat("🔪 Martingale Avg CLOSED. Points: %.0f (HWM: %.0f)", dist_points, m_mart_hwm_points));
            // Close only Martingale positions
            CloseMartingalePositions(); 
            ResetState();
         }
      }
   }

   //+------------------------------------------------------------------+
   //| UTILS: Close Functions                                           |
   //+------------------------------------------------------------------+
   void CloseAllPositions(string reason)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(m_magic.IsMagicOurs(PositionGetInteger(POSITION_MAGIC))) CloseTicket(ticket, reason);
      }
      m_state.EndCycle(true);
   }

   void CloseMartingalePositions()
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         long magic = PositionGetInteger(POSITION_MAGIC);
         if(m_magic.IsMartingale(magic)) CloseTicket(ticket, "Martingale Avg Exit");
      }
      m_state.EndCycle(true);
   }

   //+------------------------------------------------------------------+
   //| UTILS: Safety Checks                                             |
   //+------------------------------------------------------------------+
   void CheckNewDay() {
      MqlDateTime dt; TimeCurrent(dt);
      if(dt.day_of_year != m_last_day_check) {
         m_start_balance_day = AccountInfoDouble(ACCOUNT_BALANCE);
         m_last_day_check = dt.day_of_year;
      }
   }

   bool CheckDailyTargets() {
      double pl = AccountInfoDouble(ACCOUNT_EQUITY) - m_start_balance_day;
      if(m_max_daily_profit > 0 && pl >= m_max_daily_profit) { CloseAllPositions("Daily TP"); return true; }
      if(m_max_daily_loss > 0 && pl <= -m_max_daily_loss) { CloseAllPositions("Daily SL"); return true; }
      return false;
   }

   bool CheckEquityStop() {
      if(!InpUseEquityStop) return false;
      double dd = (AccountInfoDouble(ACCOUNT_BALANCE) - AccountInfoDouble(ACCOUNT_EQUITY)) / AccountInfoDouble(ACCOUNT_BALANCE) * 100.0;
      if(dd >= InpEquityStopPercent) { CloseAllPositions("Equity Hard Stop"); return true; }
      return false;
   }
};

#endif