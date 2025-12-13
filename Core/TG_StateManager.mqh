//+------------------------------------------------------------------+
//|                                         Core/TG_StateManager.mqh |
//|                                          Titan Grid EA v1.0      |
//|                            State & Cycle Management System       |
//+------------------------------------------------------------------+
//| Location: C:\Users\ichza\AppData\Roaming\MetaQuotes\Terminal\   |
//|           D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\         |
//|           TitanGridEA\Core\TG_StateManager.mqh                   |
//|                                                                  |
//| Purpose:  Manages EA state, trading cycles, cooldown timers     |
//|           Tracks current mode, layer, and system status         |
//|           Dependencies: TG_Definitions.mqh                       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.00"

//+------------------------------------------------------------------+
//| CHANGE LOG                                                        |
//+------------------------------------------------------------------+
// Version 1.00 - 2025-01-20
// [INITIAL] State manager created
// [ADD] Trading state management (MODE, layer tracking)
// [ADD] Cycle state tracking
// [ADD] System enable/disable flags
// [ADD] Cooldown timer management
// [ADD] Last trade time tracking
// [ADD] State persistence (for recovery after restart)
//+------------------------------------------------------------------+

#ifndef TG_STATE_MANAGER_MQH
#define TG_STATE_MANAGER_MQH

#include "TG_Definitions.mqh"
#include <Trade\Trade.mqh>

// Forward declarations
class CMagicNumberManager;

// Include after forward declaration
#include "TG_MagicNumbers.mqh"

//+------------------------------------------------------------------+
//| STATE MANAGER CLASS                                               |
//+------------------------------------------------------------------+
class CStateManager
{
private:
   //+------------------------------------------------------------------+
   //| CORE TRADING STATE                                               |
   //+------------------------------------------------------------------+
   ENUM_MARTINGALE_MODE m_current_mode;          // Current trading mode
   int                   m_current_layer;         // Current layer (1-15)
   bool                  m_cycle_active;          // Cycle in progress
   datetime              m_cycle_start_time;      // Cycle start timestamp
   double                m_cycle_start_price;     // Entry price of L1
   
   //+------------------------------------------------------------------+
   //| SYSTEM STATUS FLAGS                                              |
   //+------------------------------------------------------------------+
   bool m_martingale_stopped;                     // Martingale system stopped
   bool m_gridslicer_stopped;                     // GridSlicer system stopped
   bool m_hedge_stopped;                          // Hedge system stopped
   bool m_recovery_stopped;                       // Recovery system stopped
   
   bool m_martingale_enabled;                     // Martingale enabled (from input)
   bool m_gridslicer_enabled;                     // GridSlicer enabled (from input)
   bool m_hedge_enabled;                          // Hedge enabled (from input)
   bool m_recovery_enabled;                       // Recovery enabled (from input)
   
   //+------------------------------------------------------------------+
   //| PENDING ORDER STATE                                              |
   //+------------------------------------------------------------------+
   bool   m_po_active;                            // Pending orders placed
   ulong  m_po_buy_ticket;                        // BUY STOP ticket
   ulong  m_po_sell_ticket;                       // SELL STOP ticket
   
   //+------------------------------------------------------------------+
   //| COOLDOWN MANAGEMENT                                              |
   //+------------------------------------------------------------------+
   datetime m_last_trade_time;                    // Last trade execution time
   int      m_cooldown_seconds;                   // Cooldown period in seconds
   bool     m_in_cooldown;                        // Currently in cooldown
   
   //+------------------------------------------------------------------+
   //| STATISTICS & TRACKING                                            |
   //+------------------------------------------------------------------+
   int      m_total_cycles_completed;             // Total cycles finished
   int      m_successful_cycles;                  // Successful (profit) cycles
   int      m_failed_cycles;                      // Failed cycles
   datetime m_daily_reset_time;                   // Last daily reset
   
   //+------------------------------------------------------------------+
   //| INTERNAL FLAGS                                                   |
   //+------------------------------------------------------------------+
   bool m_initialized;                            // Manager initialized
   
   //+------------------------------------------------------------------+
   //| DEPENDENCIES                                                     |
   //+------------------------------------------------------------------+
   CMagicNumberManager* m_magic;                  // Magic number manager
   CTrade*              m_trade;                  // Trade execution
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CStateManager()
   {
      // Initialize all to safe defaults
      ResetToDefaults();
      m_initialized = false;
      m_magic = NULL;
      m_trade = NULL;
   }
   
   //+------------------------------------------------------------------+
   //| Initialize State Manager                                         |
   //+------------------------------------------------------------------+
   bool Initialize(bool enable_mart = true,
                   bool enable_gs = false,
                   bool enable_hedge = false,
                   bool enable_recovery = false,
                   int cooldown_seconds = 5,
                   CMagicNumberManager* magic = NULL,
                   CTrade* trade = NULL)
   {
      Print("╔═══════════════════════════════════════════════════════════╗");
      Print("║            STATE MANAGER INITIALIZATION                  ║");
      Print("╠═══════════════════════════════════════════════════════════╣");
      
      // Store dependencies
      m_magic = magic;
      m_trade = trade;
      
      // Set system enable flags from inputs
      m_martingale_enabled = enable_mart;
      m_gridslicer_enabled = enable_gs;
      m_hedge_enabled = enable_hedge;
      m_recovery_enabled = enable_recovery;
      m_cooldown_seconds = cooldown_seconds;
      
      Print("║ Martingale:  ", (m_martingale_enabled ? "ENABLED ✓" : "DISABLED ✗"));
      Print("║ GridSlicer:  ", (m_gridslicer_enabled ? "ENABLED ✓" : "DISABLED ✗"));
      Print("║ Hedge:       ", (m_hedge_enabled ? "ENABLED ✓" : "DISABLED ✗"));
      Print("║ Recovery:    ", (m_recovery_enabled ? "ENABLED ✓" : "DISABLED ✗"));
      Print("║ Cooldown:    ", m_cooldown_seconds, " seconds");
      Print("╠═══════════════════════════════════════════════════════════╣");
      
      // Try to load previous state (if EA restarted)
      if(LoadState())
      {
         Print("║ State loaded from previous session ✓                     ║");
         PrintCurrentState();
      }
      else
      {
         Print("║ Fresh start - No previous state found                    ║");
         ResetToDefaults();
      }
      
      Print("╚═══════════════════════════════════════════════════════════╝");
      
      m_initialized = true;
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Reset State to Defaults                                          |
   //+------------------------------------------------------------------+
   void ResetToDefaults()
   {
      // Core state
      m_current_mode = MODE_NONE;
      m_current_layer = 0;
      m_cycle_active = false;
      m_cycle_start_time = 0;
      m_cycle_start_price = 0;
      
      // System flags (stopped = false means running)
      m_martingale_stopped = false;
      m_gridslicer_stopped = false;
      m_hedge_stopped = false;
      m_recovery_stopped = false;
      
      // Pending orders
      m_po_active = false;
      m_po_buy_ticket = 0;
      m_po_sell_ticket = 0;
      
      // Cooldown
      m_last_trade_time = 0;
      m_in_cooldown = false;
      
      // Statistics
      m_total_cycles_completed = 0;
      m_successful_cycles = 0;
      m_failed_cycles = 0;
      m_daily_reset_time = TimeCurrent();
   }
   
   //+------------------------------------------------------------------+
   //| CYCLE MANAGEMENT                                                 |
   //+------------------------------------------------------------------+
   
   // Start a new martingale cycle
   bool StartCycle(ENUM_MARTINGALE_MODE mode, double entry_price)
   {
      if(!m_martingale_enabled)
      {
         Print("⚠️ Cannot start cycle: Martingale is DISABLED");
         return false;
      }
      
      if(m_martingale_stopped)
      {
         Print("⚠️ Cannot start cycle: Martingale is STOPPED");
         return false;
      }
      
      if(m_cycle_active)
      {
         Print("⚠️ Cannot start cycle: Cycle already active (", ModeToString(m_current_mode), ")");
         return false;
      }
      
      if(mode == MODE_NONE)
      {
         Print("❌ Cannot start cycle with MODE_NONE");
         return false;
      }
      
      // Start cycle
      m_current_mode = mode;
      m_current_layer = 1;
      m_cycle_active = true;
      m_cycle_start_time = TimeCurrent();
      m_cycle_start_price = entry_price;
      
      Print("✅ CYCLE STARTED: ", ModeToString(m_current_mode));
      Print("   Layer: L1");
      Print("   Entry Price: ", DoubleToString(entry_price, _Digits));
      Print("   Time: ", TimeToString(m_cycle_start_time));
      
      SaveState(); // Persist state
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Close All Positions AND Orders (Martingale + GridSlicer)        |
   //+------------------------------------------------------------------+
   bool CloseAllPositions(string reason = "Cycle Ended")
   {
      if(m_magic == NULL || m_trade == NULL)
      {
         Print("⚠️ Cannot close positions: Missing dependencies!");
         return false;
      }
      
      Print("╔═══════════════════════════════════════════════════════════╗");
      Print("║  CLOSING ALL POSITIONS & ORDERS - ", reason);
      Print("╠═══════════════════════════════════════════════════════════╣");
      
      int total_closed = 0;
      int failed_close = 0;
      int total_deleted = 0;
      int failed_delete = 0;
      
      // STEP 1: Close all POSITIONS
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         
         // Check if position belongs to our EA
         long magic = PositionGetInteger(POSITION_MAGIC);
         
         // Close if Martingale or GridSlicer
         bool is_our_position = false;
         if(m_magic != NULL)
         {
            bool is_mart = false;
            bool is_gs = false;
            
            is_mart = m_magic.IsMartingale(magic);
            is_gs = m_magic.IsGridSlicer(magic);
            
            if(is_mart || is_gs)
               is_our_position = true;
         }
         
         if(is_our_position)
         {
            string symbol = PositionGetString(POSITION_SYMBOL);
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double volume = PositionGetDouble(POSITION_VOLUME);
            double profit = PositionGetDouble(POSITION_PROFIT);
            
            Print("   Closing Position #", ticket, ": ", 
                  (type == POSITION_TYPE_BUY ? "BUY" : "SELL"), 
                  " ", volume, " lots, P/L: $", DoubleToString(profit, 2));
            
            // Close position
            bool close_success = false;
            if(m_trade != NULL)
               close_success = m_trade.PositionClose(ticket);
            
            if(close_success)
            {
               total_closed++;
               Print("   ✅ Closed successfully");
            }
            else
            {
               failed_close++;
               Print("   ❌ Failed to close! Error: ", GetLastError());
            }
         }
      }
      
      // STEP 2: Delete all PENDING ORDERS
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(!OrderSelect(ticket))
            continue;
         
         // Check if order belongs to our EA
         long magic = OrderGetInteger(ORDER_MAGIC);
         
         // Delete if Martingale or GridSlicer
         bool is_our_order = false;
         if(m_magic != NULL)
         {
            bool is_mart = false;
            bool is_gs = false;
            
            is_mart = m_magic.IsMartingale(magic);
            is_gs = m_magic.IsGridSlicer(magic);
            
            if(is_mart || is_gs)
               is_our_order = true;
         }
         
         if(is_our_order)
         {
            ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            double volume = OrderGetDouble(ORDER_VOLUME_CURRENT);
            double price = OrderGetDouble(ORDER_PRICE_OPEN);
            
            string type_str = "";
            if(order_type == ORDER_TYPE_BUY_STOP) type_str = "BUY STOP";
            else if(order_type == ORDER_TYPE_SELL_STOP) type_str = "SELL STOP";
            else if(order_type == ORDER_TYPE_BUY_LIMIT) type_str = "BUY LIMIT";
            else if(order_type == ORDER_TYPE_SELL_LIMIT) type_str = "SELL LIMIT";
            
            Print("   Deleting Order #", ticket, ": ", type_str, " ", volume, " @ ", price);
            
            // Delete order
            bool delete_success = false;
            if(m_trade != NULL)
               delete_success = m_trade.OrderDelete(ticket);
            
            if(delete_success)
            {
               total_deleted++;
               Print("   ✅ Deleted successfully");
            }
            else
            {
               failed_delete++;
               Print("   ❌ Failed to delete! Error: ", GetLastError());
            }
         }
      }
      
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ Positions Closed: ", total_closed, " (Failed: ", failed_close, ")");
      Print("║ Orders Deleted: ", total_deleted, " (Failed: ", failed_delete, ")");
      Print("╚═══════════════════════════════════════════════════════════╝");
      
      return (failed_close == 0 && failed_delete == 0);
   }
   
   // Advance to next layer
   bool AdvanceLayer()
   {
      if(!m_cycle_active)
      {
         Print("⚠️ Cannot advance layer: No active cycle");
         return false;
      }
      
      if(m_current_layer >= MAX_LAYERS)
      {
         Print("⚠️ Cannot advance: Already at maximum layer (", MAX_LAYERS, ")");
         return false;
      }
      
      m_current_layer++;
      
      Print("➡️ LAYER ADVANCED: L", m_current_layer);
      
      SaveState();
      
      return true;
   }
   
   // End current cycle
   void EndCycle(bool success = true)
   {
      if(!m_cycle_active)
      {
         Print("⚠️ No active cycle to end");
         return;
      }
      
      ENUM_MARTINGALE_MODE finished_mode = m_current_mode;
      int finished_layer = m_current_layer;
      datetime duration = TimeCurrent() - m_cycle_start_time;
      
      // Update statistics
      m_total_cycles_completed++;
      
      if(success)
      {
         m_successful_cycles++;
         Print("✅ CYCLE COMPLETED SUCCESSFULLY");
      }
      else
      {
         m_failed_cycles++;
         Print("❌ CYCLE FAILED");
      }
      
      Print("   Mode: ", ModeToString(finished_mode));
      Print("   Final Layer: L", finished_layer);
      Print("   Duration: ", duration, " seconds (", duration/60, " minutes)");
      Print("   Success Rate: ", GetSuccessRate(), "%");
      
      // CRITICAL: Close all positions before ending cycle
      Print("🔄 Closing all positions before cycle end...");
      CloseAllPositions(success ? "Cycle Completed" : "Cycle Failed");
      
      // Reset cycle state
      m_current_mode = MODE_NONE;
      m_current_layer = 0;
      m_cycle_active = false;
      m_cycle_start_time = 0;
      m_cycle_start_price = 0;
      
      SaveState();
   }
   
   //+------------------------------------------------------------------+
   //| COOLDOWN MANAGEMENT                                              |
   //+------------------------------------------------------------------+
   
   // Mark that a trade was executed
   void MarkTradeExecuted()
   {
      m_last_trade_time = TimeCurrent();
      m_in_cooldown = true;
      
      Print("🕐 Cooldown started: ", m_cooldown_seconds, " seconds");
   }
   
   // Check if cooldown period has passed
   bool IsCooldownPassed()
   {
      if(!m_in_cooldown)
         return true;
      
      datetime elapsed = TimeCurrent() - m_last_trade_time;
      
      if(elapsed >= m_cooldown_seconds)
      {
         m_in_cooldown = false;
         Print("✅ Cooldown period ended");
         return true;
      }
      
      return false;
   }
   
   // Get remaining cooldown time
   int GetCooldownRemaining()
   {
      if(!m_in_cooldown)
         return 0;
      
      int elapsed = (int)(TimeCurrent() - m_last_trade_time);
      int remaining = m_cooldown_seconds - elapsed;
      
      return (remaining > 0) ? remaining : 0;
   }
   
   //+------------------------------------------------------------------+
   //| SYSTEM CONTROL (STOP/RESUME)                                    |
   //+------------------------------------------------------------------+
   
   // Stop Martingale
   void StopMartingale()
   {
      if(!m_martingale_stopped)
      {
         m_martingale_stopped = true;
         Print("🛑 MARTINGALE STOPPED");
         SaveState();
      }
   }
   
   // Resume Martingale
   void ResumeMartingale()
   {
      if(m_martingale_stopped)
      {
         m_martingale_stopped = false;
         Print("▶️ MARTINGALE RESUMED");
         SaveState();
      }
   }
   
   // Stop GridSlicer
   void StopGridSlicer()
   {
      if(!m_gridslicer_stopped)
      {
         m_gridslicer_stopped = true;
         Print("🛑 GRIDSLICER STOPPED");
         SaveState();
      }
   }
   
   // Resume GridSlicer
   void ResumeGridSlicer()
   {
      if(m_gridslicer_stopped)
      {
         m_gridslicer_stopped = false;
         Print("▶️ GRIDSLICER RESUMED");
         SaveState();
      }
   }
   
   // Stop Hedge
   void StopHedge()
   {
      if(!m_hedge_stopped)
      {
         m_hedge_stopped = true;
         Print("🛑 HEDGE STOPPED");
         SaveState();
      }
   }
   
   // Resume Hedge
   void ResumeHedge()
   {
      if(m_hedge_stopped)
      {
         m_hedge_stopped = false;
         Print("▶️ HEDGE RESUMED");
         SaveState();
      }
   }
   
   // Stop Recovery
   void StopRecovery()
   {
      if(!m_recovery_stopped)
      {
         m_recovery_stopped = true;
         Print("🛑 RECOVERY STOPPED");
         SaveState();
      }
   }
   
   // Resume Recovery
   void ResumeRecovery()
   {
      if(m_recovery_stopped)
      {
         m_recovery_stopped = false;
         Print("▶️ RECOVERY RESUMED");
         SaveState();
      }
   }
   
   // Resume ALL systems
   void ResumeAll()
   {
      ResumeMartingale();
      ResumeGridSlicer();
      ResumeHedge();
      ResumeRecovery();
      
      Print("✅ ALL SYSTEMS RESUMED");
   }
   
   //+------------------------------------------------------------------+
   //| PENDING ORDER MANAGEMENT                                         |
   //+------------------------------------------------------------------+
   
   void SetPendingOrders(ulong buy_ticket, ulong sell_ticket)
   {
      m_po_buy_ticket = buy_ticket;
      m_po_sell_ticket = sell_ticket;
      m_po_active = (buy_ticket > 0 || sell_ticket > 0);
      
      if(m_po_active)
         Print("✅ Pending orders tracked: BUY #", buy_ticket, ", SELL #", sell_ticket);
   }
   
   void ClearPendingOrders()
   {
      m_po_buy_ticket = 0;
      m_po_sell_ticket = 0;
      m_po_active = false;
      
      Print("🗑️ Pending orders cleared");
   }
   
   //+------------------------------------------------------------------+
   //| STATE PERSISTENCE (Save/Load)                                    |
   //+------------------------------------------------------------------+
   
   // Save state to global variables (survives EA restart)
   void SaveState()
   {
      string prefix = "TG_State_";
      
      GlobalVariableSet(prefix + "Mode", (double)m_current_mode);
      GlobalVariableSet(prefix + "Layer", (double)m_current_layer);
      GlobalVariableSet(prefix + "CycleActive", m_cycle_active ? 1.0 : 0.0);
      GlobalVariableSet(prefix + "CycleStartTime", (double)m_cycle_start_time);
      GlobalVariableSet(prefix + "CycleStartPrice", m_cycle_start_price);
      
      GlobalVariableSet(prefix + "MartStopped", m_martingale_stopped ? 1.0 : 0.0);
      GlobalVariableSet(prefix + "GSStopped", m_gridslicer_stopped ? 1.0 : 0.0);
      GlobalVariableSet(prefix + "HedgeStopped", m_hedge_stopped ? 1.0 : 0.0);
      GlobalVariableSet(prefix + "RecoveryStopped", m_recovery_stopped ? 1.0 : 0.0);
      
      GlobalVariableSet(prefix + "POActive", m_po_active ? 1.0 : 0.0);
      GlobalVariableSet(prefix + "POBuy", (double)m_po_buy_ticket);
      GlobalVariableSet(prefix + "POSell", (double)m_po_sell_ticket);
      
      GlobalVariableSet(prefix + "LastTradeTime", (double)m_last_trade_time);
      
      GlobalVariableSet(prefix + "TotalCycles", (double)m_total_cycles_completed);
      GlobalVariableSet(prefix + "SuccessfulCycles", (double)m_successful_cycles);
      GlobalVariableSet(prefix + "FailedCycles", (double)m_failed_cycles);
   }
   
   // Load state from global variables
   bool LoadState()
   {
      string prefix = "TG_State_";
      
      if(!GlobalVariableCheck(prefix + "Mode"))
         return false; // No saved state
      
      m_current_mode = (ENUM_MARTINGALE_MODE)(int)GlobalVariableGet(prefix + "Mode");
      m_current_layer = (int)GlobalVariableGet(prefix + "Layer");
      m_cycle_active = (GlobalVariableGet(prefix + "CycleActive") > 0.5);
      m_cycle_start_time = (datetime)GlobalVariableGet(prefix + "CycleStartTime");
      m_cycle_start_price = GlobalVariableGet(prefix + "CycleStartPrice");
      
      m_martingale_stopped = (GlobalVariableGet(prefix + "MartStopped") > 0.5);
      m_gridslicer_stopped = (GlobalVariableGet(prefix + "GSStopped") > 0.5);
      m_hedge_stopped = (GlobalVariableGet(prefix + "HedgeStopped") > 0.5);
      m_recovery_stopped = (GlobalVariableGet(prefix + "RecoveryStopped") > 0.5);
      
      m_po_active = (GlobalVariableGet(prefix + "POActive") > 0.5);
      m_po_buy_ticket = (ulong)GlobalVariableGet(prefix + "POBuy");
      m_po_sell_ticket = (ulong)GlobalVariableGet(prefix + "POSell");
      
      m_last_trade_time = (datetime)GlobalVariableGet(prefix + "LastTradeTime");
      
      m_total_cycles_completed = (int)GlobalVariableGet(prefix + "TotalCycles");
      m_successful_cycles = (int)GlobalVariableGet(prefix + "SuccessfulCycles");
      m_failed_cycles = (int)GlobalVariableGet(prefix + "FailedCycles");
      
      return true;
   }
   
   // Delete saved state
   void DeleteSavedState()
   {
      string prefix = "TG_State_";
      
      GlobalVariableDel(prefix + "Mode");
      GlobalVariableDel(prefix + "Layer");
      GlobalVariableDel(prefix + "CycleActive");
      GlobalVariableDel(prefix + "CycleStartTime");
      GlobalVariableDel(prefix + "CycleStartPrice");
      GlobalVariableDel(prefix + "MartStopped");
      GlobalVariableDel(prefix + "GSStopped");
      GlobalVariableDel(prefix + "HedgeStopped");
      GlobalVariableDel(prefix + "RecoveryStopped");
      GlobalVariableDel(prefix + "POActive");
      GlobalVariableDel(prefix + "POBuy");
      GlobalVariableDel(prefix + "POSell");
      GlobalVariableDel(prefix + "LastTradeTime");
      GlobalVariableDel(prefix + "TotalCycles");
      GlobalVariableDel(prefix + "SuccessfulCycles");
      GlobalVariableDel(prefix + "FailedCycles");
      
      Print("✅ Saved state deleted");
   }
   
   //+------------------------------------------------------------------+
   //| GETTERS                                                           |
   //+------------------------------------------------------------------+
   ENUM_MARTINGALE_MODE GetCurrentMode() const { return m_current_mode; }
   int GetCurrentLayer() const { return m_current_layer; }
   bool IsCycleActive() const { return m_cycle_active; }
   datetime GetCycleStartTime() const { return m_cycle_start_time; }
   double GetCycleStartPrice() const { return m_cycle_start_price; }
   
   bool IsMartingaleStopped() const { return m_martingale_stopped; }
   bool IsGridSlicerStopped() const { return m_gridslicer_stopped; }
   bool IsHedgeStopped() const { return m_hedge_stopped; }
   bool IsRecoveryStopped() const { return m_recovery_stopped; }
   
   bool IsMartingaleEnabled() const { return m_martingale_enabled; }
   bool IsGridSlicerEnabled() const { return m_gridslicer_enabled; }
   bool IsHedgeEnabled() const { return m_hedge_enabled; }
   bool IsRecoveryEnabled() const { return m_recovery_enabled; }
   
   bool ArePendingOrdersActive() const { return m_po_active; }
   ulong GetPOBuyTicket() const { return m_po_buy_ticket; }
   ulong GetPOSellTicket() const { return m_po_sell_ticket; }
   
   datetime GetLastTradeTime() const { return m_last_trade_time; }
   bool IsInCooldown() const { return m_in_cooldown; }
   
   int GetTotalCycles() const { return m_total_cycles_completed; }
   int GetSuccessfulCycles() const { return m_successful_cycles; }
   int GetFailedCycles() const { return m_failed_cycles; }
   
   double GetSuccessRate() const
   {
      if(m_total_cycles_completed == 0) return 0;
      return ((double)m_successful_cycles / (double)m_total_cycles_completed) * 100.0;
   }
   
   SStatistics GetStatistics() const
   {
      SStatistics stats;
      stats.total_cycles = m_total_cycles_completed;
      stats.successful_cycles = m_successful_cycles;
      stats.failed_cycles = m_failed_cycles;
      stats.daily_profit = 0; // TODO: Implement daily tracking
      stats.daily_loss = 0;
      stats.daily_trades = 0;
      stats.daily_wins = 0;
      stats.daily_losses = 0;
      stats.max_drawdown = 0; // TODO: Implement drawdown tracking
      stats.max_profit = 0;
      return stats;
   }
   
   //+------------------------------------------------------------------+
   //| SETTERS (Use with caution)                                       |
   //+------------------------------------------------------------------+
   void SetCurrentLayer(int layer)
   {
      if(layer >= 1 && layer <= MAX_LAYERS)
      {
         m_current_layer = layer;
         SaveState();
      }
   }
   
   //+------------------------------------------------------------------+
   //| DAILY RESET                                                       |
   //+------------------------------------------------------------------+
   void CheckDailyReset()
   {
      datetime current_time = TimeCurrent();
      MqlDateTime now;
      TimeToStruct(current_time, now);
      
      MqlDateTime last_reset;
      TimeToStruct(m_daily_reset_time, last_reset);
      
      // Check if date changed
      if(now.day != last_reset.day || now.mon != last_reset.mon || now.year != last_reset.year)
      {
         Print("📅 DAILY RESET TRIGGERED");
         m_daily_reset_time = current_time;
         SaveState();
      }
   }
   
   //+------------------------------------------------------------------+
   //| DEBUG: PRINT CURRENT STATE                                       |
   //+------------------------------------------------------------------+
   void PrintCurrentState()
   {
      Print("╔═══════════════════════════════════════════════════════════╗");
      Print("║                  CURRENT EA STATE                         ║");
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ Mode:         ", ModeToString(m_current_mode));
      Print("║ Layer:        ", (m_cycle_active ? "L" + IntegerToString(m_current_layer) : "N/A"));
      Print("║ Cycle Active: ", (m_cycle_active ? "YES ✓" : "NO"));
      
      if(m_cycle_active)
      {
         Print("║ Cycle Start:  ", TimeToString(m_cycle_start_time));
         Print("║ Entry Price:  ", DoubleToString(m_cycle_start_price, _Digits));
         datetime duration = TimeCurrent() - m_cycle_start_time;
         Print("║ Duration:     ", duration, " sec (", duration/60, " min)");
      }
      
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ SYSTEM STATUS                                             ║");
      Print("║ Martingale:   ", (m_martingale_stopped ? "STOPPED 🛑" : "RUNNING ✓"));
      Print("║ GridSlicer:   ", (m_gridslicer_stopped ? "STOPPED 🛑" : "RUNNING ✓"));
      Print("║ Hedge:        ", (m_hedge_stopped ? "STOPPED 🛑" : "RUNNING ✓"));
      Print("║ Recovery:     ", (m_recovery_stopped ? "STOPPED 🛑" : "RUNNING ✓"));
      
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ Pending Orders: ", (m_po_active ? "ACTIVE" : "NONE"));
      
      if(m_po_active)
      {
         if(m_po_buy_ticket > 0)
            Print("║   BUY:  #", m_po_buy_ticket);
         if(m_po_sell_ticket > 0)
            Print("║   SELL: #", m_po_sell_ticket);
      }
      
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ STATISTICS                                                ║");
      Print("║ Total Cycles:     ", m_total_cycles_completed);
      Print("║ Successful:       ", m_successful_cycles);
      Print("║ Failed:           ", m_failed_cycles);
      Print("║ Success Rate:     ", DoubleToString(GetSuccessRate(), 2), "%");
      Print("╚═══════════════════════════════════════════════════════════╝");
   }
};

//+------------------------------------------------------------------+
//| End of TG_StateManager.mqh                                       |
//+------------------------------------------------------------------+
#endif // TG_STATE_MANAGER_MQH
