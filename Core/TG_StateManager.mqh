//+------------------------------------------------------------------+
//|                                         Core/TG_StateManager.mqh |
//|                                          Titan Grid EA v1.0      |
//|                            State & Cycle Management System       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "2.00"

#ifndef TG_STATE_MANAGER_MQH
#define TG_STATE_MANAGER_MQH

#include "TG_Definitions.mqh"
#include <Trade\Trade.mqh>

// Forward declaration
class CMagicNumberManager;
// Include setelah forward declaration jika diperlukan, tapi biasanya di main.
// Disini kita asumsikan file ini di-include setelah Definitions.

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
   int                   m_current_layer;        // Current layer (1-15)
   bool                  m_cycle_active;         // Cycle in progress
   datetime              m_cycle_start_time;     // Cycle start timestamp
   double                m_cycle_start_price;    // Entry price of L1
   
   //+------------------------------------------------------------------+
   //| SYSTEM STATUS FLAGS (STOP/RESUME)                                |
   //+------------------------------------------------------------------+
   bool m_martingale_stopped;                    // Martingale system stopped
   bool m_gridslicer_stopped;                    // GridSlicer system stopped
   bool m_hedge_stopped;                         // Hedge system stopped (NEW)
   bool m_recovery_stopped;                      // Recovery system stopped
   
   //+------------------------------------------------------------------+
   //| ENABLE FLAGS (FROM INPUTS)                                       |
   //+------------------------------------------------------------------+
   bool m_martingale_enabled;
   bool m_gridslicer_enabled;
   bool m_hedge_enabled;                         // (NEW)
   bool m_recovery_enabled;
   
   //+------------------------------------------------------------------+
   //| PENDING ORDER STATE                                              |
   //+------------------------------------------------------------------+
   bool   m_po_active;                           // Pending orders placed
   ulong  m_po_buy_ticket;                       // BUY STOP ticket
   ulong  m_po_sell_ticket;                      // SELL STOP ticket
   
   //+------------------------------------------------------------------+
   //| COOLDOWN MANAGEMENT                                              |
   //+------------------------------------------------------------------+
   datetime m_last_trade_time;                   // Last trade execution time
   int      m_cooldown_seconds;                  // Cooldown period in seconds
   bool     m_in_cooldown;                       // Currently in cooldown
   
   //+------------------------------------------------------------------+
   //| STATISTICS                                                       |
   //+------------------------------------------------------------------+
   int      m_total_cycles_completed;
   int      m_successful_cycles;
   int      m_failed_cycles;
   datetime m_daily_reset_time;
   
   //+------------------------------------------------------------------+
   //| DEPENDENCIES                                                     |
   //+------------------------------------------------------------------+
   CMagicNumberManager* m_magic;
   CTrade* m_trade;
   
   bool m_initialized;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CStateManager()
   {
      ResetToDefaults();
      m_initialized = false;
      m_magic = NULL;
      m_trade = NULL;
   }
   
   //+------------------------------------------------------------------+
   //| Initialize State Manager                                         |
   //+------------------------------------------------------------------+
   bool Initialize(bool enable_mart,
                   bool enable_gs,
                   bool enable_hedge,
                   bool enable_recovery,
                   int cooldown_seconds,
                   CMagicNumberManager* magic,
                   CTrade* trade)
   {
      Print("╔═══════════════════════════════════════════════════════════╗");
      Print("║            STATE MANAGER INITIALIZATION                  ║");
      Print("╠═══════════════════════════════════════════════════════════╣");
      
      m_magic = magic;
      m_trade = trade;
      
      // Set enable flags from inputs
      m_martingale_enabled = enable_mart;
      m_gridslicer_enabled = enable_gs;
      m_hedge_enabled = enable_hedge;
      m_recovery_enabled = enable_recovery;
      m_cooldown_seconds = cooldown_seconds;
      
      Print("║ Martingale:  ", (m_martingale_enabled ? "ENABLED ✓" : "DISABLED ✗"));
      Print("║ GridSlicer:  ", (m_gridslicer_enabled ? "ENABLED ✓" : "DISABLED ✗"));
      Print("║ Hedge:       ", (m_hedge_enabled ? "ENABLED ✓" : "DISABLED ✗"));
      Print("║ Recovery:    ", (m_recovery_enabled ? "ENABLED ✓" : "DISABLED ✗"));
      
      // Try load previous state (Persistence)
      if(LoadState())
      {
         Print("║ ✅ State loaded from previous session                    ║");
         PrintCurrentState();
      }
      else
      {
         Print("║ 🆕 Fresh start - No previous state found                 ║");
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
      m_current_mode = MODE_NONE;
      m_current_layer = 0;
      m_cycle_active = false;
      m_cycle_start_time = 0;
      m_cycle_start_price = 0;
      
      // Default: All systems RUNNING (not stopped)
      m_martingale_stopped = false;
      m_gridslicer_stopped = false;
      m_hedge_stopped = false;
      m_recovery_stopped = false;
      
      m_po_active = false;
      m_po_buy_ticket = 0;
      m_po_sell_ticket = 0;
      
      m_last_trade_time = 0;
      m_in_cooldown = false;
      
      m_total_cycles_completed = 0;
      m_successful_cycles = 0;
      m_failed_cycles = 0;
      m_daily_reset_time = TimeCurrent();
   }
   
   //+------------------------------------------------------------------+
   //| CYCLE MANAGEMENT                                                 |
   //+------------------------------------------------------------------+
   
   // Start a new cycle
   bool StartCycle(ENUM_MARTINGALE_MODE mode, double entry_price)
   {
      if(!m_martingale_enabled) return false;
      if(m_martingale_stopped) return false;
      // Note: Independent Martingale V2 might force this true, so we allow update if same mode
      if(m_cycle_active && m_current_mode != mode) return false; 
      
      m_current_mode = mode;
      m_current_layer = 1;
      m_cycle_active = true;
      m_cycle_start_time = TimeCurrent();
      m_cycle_start_price = entry_price;
      
      Print("✅ STATE: Cycle Started -> ", ModeToString(mode));
      SaveState();
      return true;
   }
   
   // Advance Layer
   bool AdvanceLayer()
   {
      if(!m_cycle_active) return false;
      if(m_current_layer >= MAX_LAYERS) return false;
      
      m_current_layer++;
      Print("➡️ STATE: Layer Advanced -> L", m_current_layer);
      SaveState();
      return true;
   }
   
   // End Cycle
   void EndCycle(bool success = true)
   {
      if(!m_cycle_active) return;
      
      // Stats
      m_total_cycles_completed++;
      if(success) m_successful_cycles++; else m_failed_cycles++;
      
      Print(StringFormat("🏁 STATE: Cycle Ended (%s). Duration: %d sec", 
            success ? "SUCCESS" : "FAILED", (int)(TimeCurrent()-m_cycle_start_time)));
      
      // Reset Cycle Flags
      m_current_mode = MODE_NONE;
      m_current_layer = 0;
      m_cycle_active = false;
      m_cycle_start_time = 0;
      m_cycle_start_price = 0;
      
      SaveState();
   }
   
   //+------------------------------------------------------------------+
   //| SYSTEM CONTROL (STOP/RESUME)                                     |
   //+------------------------------------------------------------------+
   
   // --- MARTINGALE ---
   void StopMartingale()   { if(!m_martingale_stopped) { m_martingale_stopped = true; Print("🛑 Martingale STOPPED"); SaveState(); } }
   void ResumeMartingale() { if(m_martingale_stopped)  { m_martingale_stopped = false; Print("▶️ Martingale RESUMED"); SaveState(); } }
   
   // --- GRIDSLICER ---
   void StopGridSlicer()   { if(!m_gridslicer_stopped) { m_gridslicer_stopped = true; Print("🛑 GridSlicer STOPPED"); SaveState(); } }
   void ResumeGridSlicer() { if(m_gridslicer_stopped)  { m_gridslicer_stopped = false; Print("▶️ GridSlicer RESUMED"); SaveState(); } }
   
   // --- HEDGE (NEW) ---
   void StopHedge()        { if(!m_hedge_stopped) { m_hedge_stopped = true; Print("🛑 Hedge STOPPED"); SaveState(); } }
   void ResumeHedge()      { if(m_hedge_stopped)  { m_hedge_stopped = false; Print("▶️ Hedge RESUMED"); SaveState(); } }
   
   // --- RECOVERY ---
   void StopRecovery()     { if(!m_recovery_stopped) { m_recovery_stopped = true; Print("🛑 Recovery STOPPED"); SaveState(); } }
   void ResumeRecovery()   { if(m_recovery_stopped)  { m_recovery_stopped = false; Print("▶️ Recovery RESUMED"); SaveState(); } }
   
   // Resume ALL
   void ResumeAll()
   {
      ResumeMartingale();
      ResumeGridSlicer();
      ResumeHedge();
      ResumeRecovery();
      Print("✅ ALL SYSTEMS RESUMED");
   }
   
   // Stop ALL
   void StopAll()
   {
      StopMartingale();
      StopGridSlicer();
      StopHedge();
      StopRecovery();
      Print("🛑 ALL SYSTEMS STOPPED");
   }

   //+------------------------------------------------------------------+
   //| PENDING ORDER MANAGEMENT                                         |
   //+------------------------------------------------------------------+
   void SetPendingOrders(ulong buy_ticket, ulong sell_ticket)
   {
      m_po_buy_ticket = buy_ticket;
      m_po_sell_ticket = sell_ticket;
      m_po_active = (buy_ticket > 0 || sell_ticket > 0);
      SaveState();
   }
   
   void ClearPendingOrders()
   {
      m_po_buy_ticket = 0;
      m_po_sell_ticket = 0;
      m_po_active = false;
      SaveState();
   }
   
   //+------------------------------------------------------------------+
   //| COOLDOWN                                                         |
   //+------------------------------------------------------------------+
   void MarkTradeExecuted()
   {
      m_last_trade_time = TimeCurrent();
      m_in_cooldown = true;
      SaveState();
   }
   
   bool IsCooldownPassed()
   {
      if(!m_in_cooldown) return true;
      if(TimeCurrent() - m_last_trade_time >= m_cooldown_seconds) {
         m_in_cooldown = false;
         return true;
      }
      return false;
   }
   
   int GetCooldownRemaining()
   {
      if(!m_in_cooldown) return 0;
      int rem = m_cooldown_seconds - (int)(TimeCurrent() - m_last_trade_time);
      return (rem > 0) ? rem : 0;
   }
   
   //+------------------------------------------------------------------+
   //| DAILY RESET                                                      |
   //+------------------------------------------------------------------+
   void CheckDailyReset()
   {
      MqlDateTime now, last;
      TimeToStruct(TimeCurrent(), now);
      TimeToStruct(m_daily_reset_time, last);
      
      if(now.day != last.day) {
         Print("📅 Daily Reset Triggered");
         m_daily_reset_time = TimeCurrent();
         // Reset daily stats here if needed
         SaveState();
      }
   }

   //+------------------------------------------------------------------+
   //| PERSISTENCE (SAVE/LOAD)                                          |
   //+------------------------------------------------------------------+
   void SaveState()
   {
      string p = "TG_State_"; // Prefix
      GlobalVariableSet(p + "Mode", (double)m_current_mode);
      GlobalVariableSet(p + "Layer", (double)m_current_layer);
      GlobalVariableSet(p + "CycleActive", m_cycle_active ? 1.0 : 0.0);
      GlobalVariableSet(p + "CycleStart", (double)m_cycle_start_time);
      GlobalVariableSet(p + "CyclePrice", m_cycle_start_price);
      
      GlobalVariableSet(p + "StopMart", m_martingale_stopped ? 1.0 : 0.0);
      GlobalVariableSet(p + "StopGS", m_gridslicer_stopped ? 1.0 : 0.0);
      GlobalVariableSet(p + "StopHedge", m_hedge_stopped ? 1.0 : 0.0); // NEW
      GlobalVariableSet(p + "StopRec", m_recovery_stopped ? 1.0 : 0.0);
      
      GlobalVariableSet(p + "POActive", m_po_active ? 1.0 : 0.0);
      GlobalVariableSet(p + "POBuy", (double)m_po_buy_ticket);
      GlobalVariableSet(p + "POSell", (double)m_po_sell_ticket);
      
      GlobalVariableSet(p + "LastTrade", (double)m_last_trade_time);
      GlobalVariableSet(p + "TotalCycles", (double)m_total_cycles_completed);
      GlobalVariableSet(p + "SuccessCycles", (double)m_successful_cycles);
      GlobalVariableSet(p + "FailedCycles", (double)m_failed_cycles);
   }
   
   bool LoadState()
   {
      string p = "TG_State_";
      if(!GlobalVariableCheck(p + "Mode")) return false;
      
      m_current_mode = (ENUM_MARTINGALE_MODE)(int)GlobalVariableGet(p + "Mode");
      m_current_layer = (int)GlobalVariableGet(p + "Layer");
      m_cycle_active = (GlobalVariableGet(p + "CycleActive") > 0.5);
      m_cycle_start_time = (datetime)GlobalVariableGet(p + "CycleStart");
      m_cycle_start_price = GlobalVariableGet(p + "CyclePrice");
      
      m_martingale_stopped = (GlobalVariableGet(p + "StopMart") > 0.5);
      m_gridslicer_stopped = (GlobalVariableGet(p + "StopGS") > 0.5);
      m_hedge_stopped = (GlobalVariableGet(p + "StopHedge") > 0.5); // NEW
      m_recovery_stopped = (GlobalVariableGet(p + "StopRec") > 0.5);
      
      m_po_active = (GlobalVariableGet(p + "POActive") > 0.5);
      m_po_buy_ticket = (ulong)GlobalVariableGet(p + "POBuy");
      m_po_sell_ticket = (ulong)GlobalVariableGet(p + "POSell");
      
      m_last_trade_time = (datetime)GlobalVariableGet(p + "LastTrade");
      m_total_cycles_completed = (int)GlobalVariableGet(p + "TotalCycles");
      m_successful_cycles = (int)GlobalVariableGet(p + "SuccessCycles");
      m_failed_cycles = (int)GlobalVariableGet(p + "FailedCycles");
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| GETTERS                                                          |
   //+------------------------------------------------------------------+
   ENUM_MARTINGALE_MODE GetCurrentMode() const { return m_current_mode; }
   int GetCurrentLayer() const { return m_current_layer; }
   bool IsCycleActive() const { return m_cycle_active; }
   datetime GetCycleStartTime() const { return m_cycle_start_time; }
   
   bool IsMartingaleStopped() const { return m_martingale_stopped; }
   bool IsGridSlicerStopped() const { return m_gridslicer_stopped; }
   bool IsHedgeStopped() const { return m_hedge_stopped; } // NEW
   bool IsRecoveryStopped() const { return m_recovery_stopped; }
   
   bool IsMartingaleEnabled() const { return m_martingale_enabled; }
   bool IsGridSlicerEnabled() const { return m_gridslicer_enabled; }
   bool IsHedgeEnabled() const { return m_hedge_enabled; } // NEW
   bool IsRecoveryEnabled() const { return m_recovery_enabled; }
   
   bool ArePendingOrdersActive() const { return m_po_active; }
   ulong GetPOBuyTicket() const { return m_po_buy_ticket; }
   ulong GetPOSellTicket() const { return m_po_sell_ticket; }
   
   int GetTotalCycles() const { return m_total_cycles_completed; }
   int GetSuccessfulCycles() const { return m_successful_cycles; }
   int GetFailedCycles() const { return m_failed_cycles; }
   
   double GetSuccessRate() const {
      if(m_total_cycles_completed == 0) return 0;
      return ((double)m_successful_cycles / (double)m_total_cycles_completed) * 100.0;
   }
   
   // DEBUG
   void PrintCurrentState()
   {
      Print(StringFormat("State: Mode=%s, Layer=%d, Active=%s", 
            ModeToString(m_current_mode), m_current_layer, m_cycle_active?"YES":"NO"));
      Print(StringFormat("Flags: Mart=%s, GS=%s, Hedge=%s",
            m_martingale_stopped?"STOP":"RUN", m_gridslicer_stopped?"STOP":"RUN", m_hedge_stopped?"STOP":"RUN"));
   }
};

#endif // TG_STATE_MANAGER_MQH