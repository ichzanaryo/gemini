//+------------------------------------------------------------------+
//|                                           TitanGrid_v1.0.mq5     |
//|                                          Titan Grid EA v2.0      |
//|                        Integrasi: Martingale V2 + GridSlicer + Hedge |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "2.00"
#property description "Titan Grid EA - Ultimate Grid System"
#property description "✅ Martingale V2 | GridSlicer V2 | Smart Hedge"
#property description "✅ Phoenix Exit Strategy (Basket & Avg Trail)"

//+------------------------------------------------------------------+
//| 1. CORE INCLUDES                                                 |
//+------------------------------------------------------------------+
#include "Core/TG_Definitions.mqh"
#include "Core/TG_MagicNumbers.mqh"
#include "Core/TG_StateManager.mqh"
#include "Core/TG_ErrorHandler.mqh"
#include "Core/TG_Logger.mqh"

//+------------------------------------------------------------------+
//| 2. INPUT PARAMETERS                                              |
//+------------------------------------------------------------------+
#include "Config/TG_Inputs_Main.mqh"
#include "Config/TG_Inputs_Martingale.mqh"
#include "Config/TG_Inputs_Hedge.mqh"        // [BARU] Input Hedge
#include "Config/TG_Inputs_GridSlicer.mqh"
#include "Config/TG_Inputs_ControlPanel.mqh" // UI Inputs (Hidden/Grouped)

//+------------------------------------------------------------------+
//| 3. SYSTEM INCLUDES                                               |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include "Utilities/TG_PositionScanner.mqh"
#include "Utilities/TG_LotCalculation.mqh"
#include "Utilities/TG_PriceHelpers.mqh"

// Strategy Modules
#include "Systems/TG_Martingale_v2.mqh"
#include "Systems/TG_EntryManager.mqh"
#include "Systems/TG_GridSlicer.mqh"
#include "Systems/TG_Hedge.mqh"              // [BARU] System Hedge
#include "Systems/TG_CloseManager.mqh"

// UI Modules
#include "Interface/TG_ControlPanel_v2.mqh"

//+------------------------------------------------------------------+
//| 4. GLOBAL OBJECTS                                                |
//+------------------------------------------------------------------+
// Core Objects
CMagicNumberManager  g_magic_manager;
CStateManager        g_state_manager;
CErrorHandler        g_error_handler;
CLogger              g_logger;
CTrade               g_trade;

// Utilities
CPositionScanner     g_position_scanner;
CLotCalculator       g_lot_calculator;
CPriceHelper         g_price_helper;

// Systems
CMartingaleManagerV2 g_martingale;
CEntryManager        g_entry_manager;
CGridSlicerSystem    g_gridslicer;
CHedgeSystem         g_hedge;                // [BARU] Objek Hedge
CCloseManager        g_close_manager;

// Interface
CControlPanel        g_control_panel;

// Global Variables
datetime g_last_statistics_time = 0;

//+------------------------------------------------------------------+
//| INITIALIZATION (OnInit)                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   // --- A. VALIDATE INPUTS ---
   string error_msg;
   
   // 1. Main Inputs
   if(!ValidateMainInputs(error_msg)) {
      Alert("❌ Main Init Failed: ", error_msg);
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // 2. Martingale Inputs
   if(!ValidateMartingaleInputs(error_msg)) {
      Alert("❌ Martingale Init Failed: ", error_msg);
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // 3. GridSlicer Inputs
   string gs_err;
   if(!ValidateGridSlicerInputs(gs_err)) {
      Alert("❌ GridSlicer Init Failed: ", gs_err);
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // 4. Hedge Inputs [BARU]
   string hedge_err;
   if(!ValidateHedgeInputs(hedge_err)) {
      Alert("❌ Hedge Init Failed: ", hedge_err);
      return INIT_PARAMETERS_INCORRECT;
   }

   // --- B. INIT CORE COMPONENTS ---
   if(!g_logger.Initialize(InpLogLevel, InpLogToFile, InpLogToConsole, InpMaxLogFileSizeKB)) return INIT_FAILED;
   if(!g_magic_manager.Initialize(InpBaseMagic)) return INIT_FAILED;
   if(!g_error_handler.Initialize(InpMaxRetries, InpRetryDelayMS)) return INIT_FAILED;
   
   // --- C. INIT STATE & UTILITIES ---
   // Note: Hedge enable flag passed to StateManager
   if(!g_state_manager.Initialize(InpEnableMartingale, InpGS_Enable, InpHedge_Enable, InpEnableRecovery, 
                                  InpCooldownSeconds, &g_magic_manager, &g_trade)) return INIT_FAILED;
                                  
   g_trade.SetExpertMagicNumber(InpBaseMagic);
   g_trade.SetDeviationInPoints(InpSlippage);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK); // Atau ORDER_FILLING_IOC tergantung broker
   
   if(!g_position_scanner.Initialize(&g_magic_manager)) return INIT_FAILED;
   if(!g_price_helper.Initialize(InpMart_ATR_Period)) return INIT_FAILED;
   
   if(!g_lot_calculator.Initialize(InpLotMode, InpFixedLot, InpRiskPercent, InpRiskPoints, InpBalancePercent, 
                                   InpMinLot, InpMaxLot, InpMart_ProgressionMode, InpMart_LotMultiplier, 
                                   InpMart_LotAddValue)) return INIT_FAILED;

   // --- D. INIT RISK CONTROL (CLOSE MANAGER) ---
   if(!g_close_manager.Initialize(&g_trade, &g_magic_manager, &g_state_manager, &g_logger, &g_position_scanner, &g_lot_calculator))
      return INIT_FAILED;
   // Set Daily Limits
   g_close_manager.SetDailyLimits(InpMaxDailyProfit, InpMaxDailyLoss);

   // --- E. INIT TRADING STRATEGIES ---
   
   // 1. Martingale V2
   if(!g_martingale.Initialize(&g_magic_manager, &g_state_manager, &g_position_scanner, &g_logger, 
                               &g_error_handler, &g_price_helper, &g_lot_calculator)) return INIT_FAILED;
   
   // Push Settings to Martingale Object
   g_martingale.SetMaxLayers(InpMart_MaxLayers);
   g_martingale.SetGridDistance(InpMart_FixedGridPoints);
   g_martingale.SetLotMultiplier(InpMart_LotMultiplier);
   g_martingale.SetInitialLot(g_lot_calculator.CalculateInitialLot());
   g_martingale.SetCycleTP(InpMart_UseCycleTP, InpMart_CycleTPDollar); // Internal TP as backup
   g_martingale.SetGridProgression(InpMart_GridProgressionMode, InpMart_GridMultiplierValue, InpMart_GridAddValue);
   
   // Sync State (Resume logic for V2)
   g_martingale.SyncState();

   // 2. Entry Manager
   if(!g_entry_manager.Initialize(&g_trade, &g_magic_manager, &g_state_manager, &g_logger, &g_error_handler, 
                                  &g_lot_calculator, &g_price_helper, &g_martingale, 
                                  InpEntryMethod, InpPO_DistancePoints, InpPO_CancelOnOpposite, InpManualLotSize)) return INIT_FAILED;

   // 3. GridSlicer V2
   if(!g_gridslicer.Initialize(&g_trade, &g_magic_manager, &g_state_manager, &g_logger, &g_error_handler, 
                               &g_position_scanner, &g_lot_calculator, &g_price_helper)) return INIT_FAILED;
                               
   // 4. Hedge System [BARU]
   if(!g_hedge.Initialize(&g_trade, &g_magic_manager, &g_state_manager, &g_logger, 
                          &g_position_scanner, &g_price_helper)) return INIT_FAILED;

   // --- F. INIT UI ---
   // Panel V2 (Info + Buttons)
   if(!g_control_panel.Initialize(&g_state_manager, &g_logger, &g_position_scanner))
   {
      g_logger.Warning("Control Panel Init Failed - Continuing without UI");
   }
   else
   {
      // Set dependencies for buttons (Entry & Martingale)
    //  g_control_panel.SetDependencies(&g_entry_manager, &g_martingale); blokir sementara
      g_control_panel.Create();
   }

   // --- G. FINALIZE ---
   EventSetTimer(1); // Timer for statistics & UI update
   g_logger.Info("✅ TITAN GRID EA v2.0 FULLY INITIALIZED");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION (OnDeinit)                                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   
   // Cleanup Objects
   g_control_panel.Destroy();
   
   // Safety Cleanup for GridSlicer
   if(InpGS_Enable) g_gridslicer.CancelAllOrders(); 
   
   g_logger.Info("👋 Titan Grid EA Stopped.");
}

//+------------------------------------------------------------------+
//| MAIN LOOP (OnTick)                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. UPDATE CORE DATA
   //    Ensure all data is fresh before making decisions
   g_state_manager.CheckDailyReset();
   g_position_scanner.Scan(); 
   
   // Update UI (throttled internally inside class)
   g_control_panel.Update();

   // 2. EXIT STRATEGY & RISK CONTROL (Priority #1)
   //    Handles Global Basket, Martingale Avg Trail, Equity Stop
   g_close_manager.OnTick();

   // Sync check: If positions closed by manager, ensure MartingaleV2 knows
   if(g_position_scanner.GetTotalCount() == 0 && g_martingale.IsIndependentCycleActive())
   {
      g_martingale.SyncState();
   }

   // 3. DETERMINE CYCLE STATUS
   //    Cycle is active if StateManager says so OR MartingaleV2 has internal tracking
   static bool prev_cycle_active = false;
   bool current_cycle_active = g_state_manager.IsCycleActive() || g_martingale.IsIndependentCycleActive();
   
   // 4. STRATEGY EXECUTION
   if(!current_cycle_active) 
   {
      // --- PHASE 1: NO POSITIONS ---
      // Search for new Entry
      g_entry_manager.OnTick();
   }
   else 
   {
      // --- PHASE 2: MANAGING CYCLE ---
      
      // A. Martingale Logic (Add Layers)
      g_martingale.OnTick();
      
      // B. GridSlicer Logic (Recovery POs)
      if(InpGS_Enable) {
         g_gridslicer.OnTick();
      }
      
      // C. Hedge Logic (Protection) [BARU]
      if(InpHedge_Enable) {
         g_hedge.OnTick();
      }
   }
   
   // 5. AUTO CLEANUP LOGIC
   //    If cycle just ended (Profit/Loss), clean up pending orders
   if(prev_cycle_active && !current_cycle_active)
   {
      g_logger.Info("🔄 Cycle Ended -> Cleanup triggered.");
      if(InpGS_Enable) g_gridslicer.CancelAllOrders();
      g_entry_manager.CancelAllPendingOrders(); 
   }
   
   prev_cycle_active = current_cycle_active;
}

//+------------------------------------------------------------------+
//| TIMER LOOP (OnTimer)                                             |
//+------------------------------------------------------------------+
void OnTimer()
{
   // 1. Update UI (Periodic refresh for timer labels etc)
   g_control_panel.Update();

   // 2. Periodic Statistics Logging
   if(InpPrintStatistics && InpStatisticsIntervalMinutes > 0) {
      if(TimeCurrent() - g_last_statistics_time >= InpStatisticsIntervalMinutes * 60) {
         g_logger.LogSeparator("STATS");
         g_position_scanner.PrintSummary();
         g_last_statistics_time = TimeCurrent();
      }
   }
}

//+------------------------------------------------------------------+
//| CHART EVENT HANDLER (OnChartEvent)                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // Pass events to Control Panel (Button Clicks)
   g_control_panel.OnChartEvent(id, lparam, dparam, sparam);
}
//+------------------------------------------------------------------+