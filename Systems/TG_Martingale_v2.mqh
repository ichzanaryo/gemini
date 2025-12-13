//+------------------------------------------------------------------+
//|                                   Systems/TG_Martingale_v2.mqh   |
//|                                      Titan Grid EA v1.08         |
//|             Martingale V2 FULL (With StartCycle & Avg Trail)     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.08"

#ifndef TG_MARTINGALE_V2_MQH
#define TG_MARTINGALE_V2_MQH

#include <Trade\Trade.mqh>
#include "../Core/TG_Definitions.mqh"
#include "../Core/TG_MagicNumbers.mqh"
#include "../Core/TG_StateManager.mqh"
#include "../Utilities/TG_PositionScanner.mqh"
#include "../Core/TG_Logger.mqh"
#include "../Core/TG_ErrorHandler.mqh"
#include "../Utilities/TG_PriceHelpers.mqh"
#include "../Utilities/TG_LotCalculation.mqh"

class CMartingaleManagerV2
{
private:
   CMagicNumberManager* m_magic;
   CStateManager* m_state;
   CPositionScanner* m_scanner;
   CLogger* m_logger;
   CErrorHandler* m_error_handler;
   CPriceHelper* m_price_helper;
   CLotCalculator* m_lot_calc;
   CTrade                m_trade;
   
   // Settings Basic
   int      m_max_layers;
   double   m_grid_distance_points;
   double   m_lot_multiplier;
   double   m_initial_lot;
   bool     m_use_cycle_tp;
   double   m_cycle_tp_amount;
   
   // Settings Progression
   ENUM_GRID_PROGRESSION_MODE m_grid_progression_mode;
   double   m_grid_multiplier_value;
   int      m_grid_add_value;
   
   // Settings Trailing Average (Phoenix)
   bool     m_use_avg_trail;
   bool     m_use_adaptive_trail;
   int      m_trail_start_points;
   int      m_trail_stop_points;
   
   // State Tracking
   double   m_layer_prices[30];
   int      m_active_layers;
   bool     m_independent_cycle_active;
   ENUM_MARTINGALE_MODE m_independent_mode;
   
   // Trailing State
   double   m_avg_trail_hwm;     // High Water Mark (Points)
   bool     m_avg_trail_active;  // Is trailing active?

   //+------------------------------------------------------------------+
   //| Calculate Grid Distance in Price                                 |
   //+------------------------------------------------------------------+
   double GetGridDistanceInPrice()
   {
      double point = m_price_helper.GetPoint();
      double base_distance = m_grid_distance_points * point;
      
      if(m_active_layers == 0) return base_distance;
      
      double calculated_distance = base_distance;
      switch(m_grid_progression_mode)
      {
         case GRID_PROGRESSION_FIXED: 
            calculated_distance = base_distance; 
            break;
         case GRID_PROGRESSION_ADD: 
            calculated_distance = base_distance + (m_active_layers * m_grid_add_value * point); 
            break;
         case GRID_PROGRESSION_MULTIPLY: 
            calculated_distance = base_distance * (1.0 + (m_active_layers * m_grid_multiplier_value)); 
            break;
         case GRID_PROGRESSION_POWER: 
            calculated_distance = base_distance * MathPow(m_grid_multiplier_value, m_active_layers); 
            break;
      }
      return calculated_distance;
   }
   
   //+------------------------------------------------------------------+
   //| Get Last Layer Price                                             |
   //+------------------------------------------------------------------+
   double GetLastLayerPrice()
   {
      if(m_active_layers < 1) return 0;
      return m_layer_prices[m_active_layers];
   }

   //+------------------------------------------------------------------+
   //| Calculate Lot for Next Layer                                     |
   //+------------------------------------------------------------------+
   double CalculateNextLot()
   {
      if(m_active_layers == 0) return m_initial_lot;
      
      double last_lot = m_initial_lot;
      for(int i = 1; i < m_active_layers; i++) {
         last_lot *= m_lot_multiplier;
      }
      return last_lot * m_lot_multiplier;
   }

   //+------------------------------------------------------------------+
   //| Calculate Weighted Average Price (BEP)                           |
   //+------------------------------------------------------------------+
   double CalculateBEP(ENUM_MARTINGALE_MODE mode)
   {
      SPositionInfo positions[];
      int count = 0;
      
      if(mode == MODE_BUY) count = m_scanner.GetMartingaleBuyPositions(positions);
      else count = m_scanner.GetMartingaleSellPositions(positions);
      
      double total_weighted = 0.0;
      double total_lots = 0.0;
      
      for(int i=0; i<count; i++) {
         total_weighted += positions[i].open_price * positions[i].lots;
         total_lots += positions[i].lots;
      }
      
      if(total_lots > 0) return total_weighted / total_lots;
      return 0.0;
   }

public:
   CMartingaleManagerV2()
   {
      m_magic = NULL; m_state = NULL; m_scanner = NULL; m_logger = NULL; 
      m_max_layers = 15; m_grid_distance_points = 100;
      m_lot_multiplier = 2.0; m_initial_lot = 0.01;
      m_use_cycle_tp = true; m_cycle_tp_amount = 10.0;
      
      m_grid_progression_mode = GRID_PROGRESSION_FIXED;
      m_grid_multiplier_value = 1.5; m_grid_add_value = 500;
      
      m_use_avg_trail = false;
      m_avg_trail_active = false;
      m_avg_trail_hwm = 0.0;
      
      m_active_layers = 0;
      ArrayInitialize(m_layer_prices, 0);
      m_independent_cycle_active = false;
      m_independent_mode = MODE_NONE;
   }
   
   bool Initialize(CMagicNumberManager* magic, CStateManager* state, CPositionScanner* scanner, 
                   CLogger* logger, CErrorHandler* error_handler, CPriceHelper* price_helper, CLotCalculator* lot_calc)
   {
      m_magic = magic; m_state = state; m_scanner = scanner; m_logger = logger;
      m_error_handler = error_handler; m_price_helper = price_helper; m_lot_calc = lot_calc;
      return true;
   }
   
   // --- CONFIGURATION SETTERS ---
   void SetMaxLayers(int max) { m_max_layers = max; }
   void SetGridDistance(double points) { m_grid_distance_points = points; }
   void SetLotMultiplier(double mult) { m_lot_multiplier = mult; }
   void SetInitialLot(double lot) { m_initial_lot = lot; }
   void SetCycleTP(bool use, double amount) { m_use_cycle_tp = use; m_cycle_tp_amount = amount; }
   
   void SetGridProgression(ENUM_GRID_PROGRESSION_MODE mode, double mult, int add) {
      m_grid_progression_mode = mode; m_grid_multiplier_value = mult; m_grid_add_value = add;
   }
   
   void SetAverageTrailing(bool use, bool adaptive, int start, int stop) {
      m_use_avg_trail = use; m_use_adaptive_trail = adaptive;
      m_trail_start_points = start; m_trail_stop_points = stop;
   }
   
   bool IsIndependentCycleActive() const { return m_independent_cycle_active; }
   
   //+------------------------------------------------------------------+
   //| Sync State (Resume Logic)                                        |
   //+------------------------------------------------------------------+
   void SyncState() 
   {
      m_avg_trail_active = false;
      m_avg_trail_hwm = 0.0;
      
      if(m_state.IsCycleActive()) {
         ENUM_MARTINGALE_MODE mode = m_state.GetCurrentMode();
         SPositionInfo positions[];
         int count = (mode == MODE_BUY) ? m_scanner.GetMartingaleBuyPositions(positions) : m_scanner.GetMartingaleSellPositions(positions);
         
         m_active_layers = 0;
         ArrayInitialize(m_layer_prices, 0);
         for(int i=0; i<count; i++) {
            if(positions[i].layer > m_active_layers) m_active_layers = positions[i].layer;
            m_layer_prices[positions[i].layer] = positions[i].open_price;
         }
         m_independent_cycle_active = true;
         m_independent_mode = mode;
         if(m_logger != NULL) m_logger.Info(StringFormat("🔄 State Synced: Mode %s, Layers %d", (mode==MODE_BUY)?"BUY":"SELL", m_active_layers));
      }
   }
   
   //+------------------------------------------------------------------+
   //| Execute Market Order                                             |
   //+------------------------------------------------------------------+
   bool OpenPosition(ENUM_ORDER_TYPE type, double lot, long magic, string comment, double &out_price)
   {
      m_trade.SetExpertMagicNumber(magic);
      bool res = (type==ORDER_TYPE_BUY) ? m_trade.Buy(lot, _Symbol,0,0,0,comment) : m_trade.Sell(lot, _Symbol,0,0,0,comment);
      if(res) {
         out_price = m_trade.ResultPrice();
         if(m_logger != NULL) m_logger.Info(StringFormat("✅ Position Opened: %s %.2f @ %.5f", (type==ORDER_TYPE_BUY)?"BUY":"SELL", lot, out_price));
         return true;
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Start BUY Cycle                                                  |
   //+------------------------------------------------------------------+
   bool StartBuyCycle()
   {
      if(m_state.IsCycleActive()) return false;
      
      m_active_layers = 0;
      ArrayInitialize(m_layer_prices, 0);
      
      // Check existing L1
      double entry_price = 0;
      bool found_existing = false;
      
      // Logic scan simple (fallback)
      for(int i=PositionsTotal()-1; i>=0; i--) {
         ulong t = PositionGetTicket(i);
         if(PositionSelectByTicket(t)) {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
               entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
               found_existing = true;
               break;
            }
         }
      }
      
      if(!found_existing) {
         double lot = m_initial_lot;
         long magic = m_magic.GetMartingaleBuyMagic(1);
         if(!OpenPosition(ORDER_TYPE_BUY, lot, magic, "Mart BUY L1", entry_price)) return false;
      }
      
      m_active_layers = 1;
      m_layer_prices[1] = entry_price;
      m_independent_cycle_active = true;
      m_independent_mode = MODE_BUY;
      
      m_state.StartCycle(MODE_BUY, entry_price);
      SyncState();
      return true;
   }

   //+------------------------------------------------------------------+
   //| Start SELL Cycle                                                 |
   //+------------------------------------------------------------------+
   bool StartSellCycle()
   {
      if(m_state.IsCycleActive()) return false;
      
      m_active_layers = 0;
      ArrayInitialize(m_layer_prices, 0);
      
      double entry_price = 0;
      bool found_existing = false;
      
      for(int i=PositionsTotal()-1; i>=0; i--) {
         ulong t = PositionGetTicket(i);
         if(PositionSelectByTicket(t)) {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
               entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
               found_existing = true;
               break;
            }
         }
      }
      
      if(!found_existing) {
         double lot = m_initial_lot;
         long magic = m_magic.GetMartingaleSellMagic(1);
         if(!OpenPosition(ORDER_TYPE_SELL, lot, magic, "Mart SELL L1", entry_price)) return false;
      }
      
      m_active_layers = 1;
      m_layer_prices[1] = entry_price;
      m_independent_cycle_active = true;
      m_independent_mode = MODE_SELL;
      
      m_state.StartCycle(MODE_SELL, entry_price);
      SyncState();
      return true;
   }

   //+------------------------------------------------------------------+
   //| Add Next Layer                                                   |
   //+------------------------------------------------------------------+
   bool AddLayer()
   {
      if(!m_independent_cycle_active) return false;
      
      ENUM_MARTINGALE_MODE mode = m_independent_mode;
      int next_layer = m_active_layers + 1;
      
      if(next_layer > m_max_layers) return false;
      
      double next_lot = CalculateNextLot();
      long magic;
      ENUM_ORDER_TYPE order_type;
      string comment;
      
      if(mode == MODE_BUY) {
         magic = m_magic.GetMartingaleBuyMagic(next_layer);
         order_type = ORDER_TYPE_BUY;
         comment = "Mart BUY L" + IntegerToString(next_layer);
      } else {
         magic = m_magic.GetMartingaleSellMagic(next_layer);
         order_type = ORDER_TYPE_SELL;
         comment = "Mart SELL L" + IntegerToString(next_layer);
      }
      
      double entry_price;
      if(!OpenPosition(order_type, next_lot, magic, comment, entry_price)) return false;
      
      m_active_layers = next_layer;
      m_layer_prices[next_layer] = entry_price;
      m_state.AdvanceLayer();
      
      return true;
   }

   //+------------------------------------------------------------------+
   //| Check if Should Add Layer                                        |
   //+------------------------------------------------------------------+
   bool ShouldAddLayer()
   {
      if(!m_independent_cycle_active) return false;
      if(m_active_layers >= m_max_layers) return false;
      
      double last_price = GetLastLayerPrice();
      if(last_price == 0) return false;
      
      double current_price = (m_independent_mode == MODE_BUY) ? m_price_helper.GetBid() : m_price_helper.GetAsk();
      double grid_distance = GetGridDistanceInPrice();
      
      if(m_independent_mode == MODE_BUY) {
         double target = last_price - grid_distance;
         if(current_price <= target) return true;
      } else {
         double target = last_price + grid_distance;
         if(current_price >= target) return true;
      }
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check Cycle TP                                                   |
   //+------------------------------------------------------------------+
   bool CheckCycleTP()
   {
      if(!m_use_cycle_tp || !m_state.IsCycleActive()) return false;
      
      // Menggunakan Scanner untuk profit martingale spesifik
      SPositionSummary summary = m_scanner.GetSummary();
      double profit = summary.GetMartingaleNetPL();
      
      if(profit >= m_cycle_tp_amount) return true;
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Close Cycle                                                      |
   //+------------------------------------------------------------------+
   bool CloseCycle()
   {
      if(!m_state.IsCycleActive()) return false;
      
      ENUM_MARTINGALE_MODE mode = m_state.GetCurrentMode();
      SPositionInfo positions[];
      int count = (mode == MODE_BUY) ? m_scanner.GetMartingaleBuyPositions(positions) : m_scanner.GetMartingaleSellPositions(positions);
      
      for(int i=0; i<count; i++) m_trade.PositionClose(positions[i].ticket);
      
      m_state.EndCycle(true);
      m_active_layers = 0;
      ArrayInitialize(m_layer_prices, 0);
      m_independent_cycle_active = false;
      m_independent_mode = MODE_NONE;
      m_avg_trail_active = false;
      
      return true;
   }

   //+------------------------------------------------------------------+
   //| CHECK AVERAGE TRAILING                                           |
   //+------------------------------------------------------------------+
   void CheckAverageTrailing()
   {
      if(m_scanner.GetSummary().hedge_count > 0) return;
      if(m_scanner.GetSummary().recovery_buy_count > 0 || m_scanner.GetSummary().recovery_sell_count > 0) return;
      
      ENUM_MARTINGALE_MODE mode = m_independent_mode;
      double bep = CalculateBEP(mode);
      if(bep == 0) return;
      
      double current_price = (mode == MODE_BUY) ? m_price_helper.GetBid() : m_price_helper.GetAsk();
      double profit_points = 0.0;
      
      if(mode == MODE_BUY) profit_points = (current_price - bep) / m_price_helper.GetPoint();
      else profit_points = (bep - current_price) / m_price_helper.GetPoint();
         
      if(!m_avg_trail_active) {
         if(profit_points >= m_trail_start_points) {
            m_avg_trail_active = true;
            m_avg_trail_hwm = profit_points;
            if(m_logger != NULL) m_logger.Info(StringFormat("🏃 Martingale Avg Trailing ACTIVE! Profit: %.0f pts", profit_points));
         }
      } else {
         if(profit_points > m_avg_trail_hwm) m_avg_trail_hwm = profit_points;
         double drop = m_avg_trail_hwm - profit_points;
         if(drop >= m_trail_stop_points) {
            if(m_logger != NULL) m_logger.Info(StringFormat("🏃 Martingale Avg CLOSE: Drop %.0f pts from HWM %.0f", drop, m_avg_trail_hwm));
            CloseCycle();
         }
      }
   }

   //+------------------------------------------------------------------+
   //| MAIN TICK HANDLER                                                |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      // 1. Cek Trailing Average (Priority Exit)
      if(m_use_avg_trail) CheckAverageTrailing();
      
      if(!m_state.IsCycleActive() && !m_independent_cycle_active) return;
      
      // 2. Check Standard Cycle TP
      if(CheckCycleTP()) {
         if(m_logger != NULL) m_logger.Info("🎯 Cycle TP Reached");
         CloseCycle();
         return;
      }
      
      // 3. Add Layer Logic
      if(ShouldAddLayer()) AddLayer(); 
   }
};

#endif