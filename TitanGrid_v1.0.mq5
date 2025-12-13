//+------------------------------------------------------------------+
//|                                           TitanGrid_v1.0.mq5     |
//|                                     Titan Grid EA v1.17          |
//|               Main EA: Final Integration (Clean & Robust)        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.17"
#property description "Titan Grid EA - Multi-Strategy Grid System"
#property description "✅ Martingale V2 (Avg Trailing)"
#property description "✅ GridSlicer V2 (Multi-PO Recovery)"
#property description "✅ Entry: ZigZag OCO / Fixed Distance"
#property description "✅ Close Manager (Global Basket Trailing)"

//+------------------------------------------------------------------+
//| 1. CORE INCLUDES                                                 |
//+------------------------------------------------------------------+
#include "Core/TG_Definitions.mqh"
#include "Core/TG_MagicNumbers.mqh"
#include "Core/TG_StateManager.mqh"
#include "Core/TG_ErrorHandler.mqh"
#include "Core/TG_Logger.mqh"

//+------------------------------------------------------------------+
//| 2. INPUT PARAMETERS (TERPUSAT)                                   |
//+------------------------------------------------------------------+
#include "Config/TG_Inputs_Main.mqh"        // Input Utama (Entry, TP, Lot, ZigZag)
#include "Config/TG_Inputs_Martingale.mqh"  // Input Grid (Jarak, Multiplier)
#include "Config/TG_Inputs_GridSlicer.mqh"  // Input Recovery

// Input Lama (NON-AKTIFKAN/HAPUS agar tidak bentrok)
// #include "Config/TG_Inputs_ControlPanel.mqh" 
// #include "Config/TG_Inputs_PendingFilter.mqh" 
// #include "Config/TG_Inputs_Signals.mqh"       

//+------------------------------------------------------------------+
//| 3. SYSTEM INCLUDES                                               |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include "Utilities/TG_PositionScanner.mqh"
#include "Utilities/TG_LotCalculation.mqh"
#include "Utilities/TG_PriceHelpers.mqh"
#include "Systems/TG_Martingale_v2.mqh"
#include "Systems/TG_SignalSystem.mqh"        // Objek Sinyal (Placeholder)
#include "Systems/TG_EntryManager.mqh"
#include "Systems/TG_GridSlicer.mqh"
#include "Systems/TG_CloseManager.mqh" 

//+------------------------------------------------------------------+
//| 4. GLOBAL OBJECTS                                                |
//+------------------------------------------------------------------+
CMagicNumberManager  g_magic_manager;
CStateManager        g_state_manager;
CErrorHandler        g_error_handler;
CLogger              g_logger;

CTrade               g_trade;
CPositionScanner     g_position_scanner;
CLotCalculator       g_lot_calculator;
CPriceHelper         g_price_helper;

CMartingaleManagerV2 g_martingale;
CSignalSystem        g_signal_system;         // Objek Sinyal
CEntryManager        g_entry_manager;
CGridSlicerSystem    g_gridslicer; 
CCloseManager        g_close_manager;

// Variables
datetime g_last_statistics_time = 0;
datetime g_last_daily_reset = 0;

//+------------------------------------------------------------------+
//| INITIALIZATION (OnInit)                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   // --- A. Validate Inputs ---
   string error_msg;
   if(!ValidateMainInputs(error_msg)) {
      Alert("❌ Init Failed: ", error_msg);
      return INIT_PARAMETERS_INCORRECT;
   }
   string gs_err;
   if(!ValidateGridSlicerInputs(gs_err)) {
      Print("❌ GridSlicer Init Failed: " + gs_err);
      return INIT_PARAMETERS_INCORRECT;
   }

   // --- B. Init Core ---
   if(!g_logger.Initialize(LOG_LEVEL_INFO, true, true, 5120)) return INIT_FAILED;
   if(!g_magic_manager.Initialize(InpBaseMagic)) return INIT_FAILED;
   if(!g_error_handler.Initialize(InpMaxRetries, 100)) return INIT_FAILED;
   
   // --- C. Init State & Utilities ---
   // Hedge & Recovery dimatikan (false) karena belum ada logicnya
   if(!g_state_manager.Initialize(InpEnableMartingale, InpEnableGridSlicer, false, false, 
                                  InpCooldownSeconds, &g_magic_manager, &g_trade)) return INIT_FAILED;

   g_trade.SetExpertMagicNumber(InpBaseMagic);
   g_trade.SetDeviationInPoints(InpSlippage);
   
   // [FIX PENTING] Jangan paksa FOK! Biarkan Auto-Detect.
   // g_trade.SetTypeFilling(ORDER_FILLING_FOK); 
   
   if(!g_position_scanner.Initialize(&g_magic_manager)) return INIT_FAILED;
   if(!g_price_helper.Initialize(14)) return INIT_FAILED; // ATR Period default 14
   
   if(!g_lot_calculator.Initialize(InpLotMode, InpFixedLot, 0, 0, 0, 
                                   0.01, InpMaxLot, PROGRESSION_MULTIPLY, 0, 0)) return INIT_FAILED;

   // --- D. Init Signal System (Optional) ---
   g_signal_system.Initialize(&g_logger); 

   // --- E. Init Close Manager (Global Risk & Exit) ---
   if(!g_close_manager.Initialize(&g_trade, &g_magic_manager, &g_state_manager, &g_logger, &g_position_scanner))
      return INIT_FAILED;
      
   // Setup Strategy: Global Basket Trailing (USD)
   g_close_manager.SetGlobalBasketStrategy(InpUseGlobalBasket, InpGlobalTrailStart_Mult, InpGlobalTrailStop_Mult, InpFixedLot);
   // Setup Risk: Equity & Daily Limits
   g_close_manager.SetEquityStop(InpUseEquityStop, InpEquityStopPercent);

   // --- F. Init Strategies ---
   
   // 1. Martingale System
   if(!g_martingale.Initialize(&g_magic_manager, &g_state_manager, &g_position_scanner, &g_logger, 
                               &g_error_handler, &g_price_helper, &g_lot_calculator)) return INIT_FAILED;
                               
   g_martingale.SetMaxLayers(InpMart_MaxLayers);
   g_martingale.SetGridDistance(InpMart_FixedGridPoints);
   g_martingale.SetLotMultiplier(InpMart_LotMultiplier);
   g_martingale.SetInitialLot(g_lot_calculator.CalculateInitialLot());
   
   // TP Strategy: Jika Global Basket ON, matikan TP siklus internal agar tidak konflik
   if(InpUseGlobalBasket) {
       g_martingale.SetCycleTP(false, 0); 
   } else {
       g_martingale.SetCycleTP(true, 10.0); // Default $10 jika global basket mati
   }
   
   // Grid Progression
   g_martingale.SetGridProgression(InpMart_GridProgressionMode, InpMart_GridMultiplierValue, InpMart_GridAddValue);
   
   // Resume State (Sync jika EA restart)
   g_martingale.SyncState();

   // 2. Entry Manager
   // Pass NULL untuk signal sementara ini, karena kita pakai ZigZag internal di EntryManager
   if(!g_entry_manager.Initialize(&g_trade, &g_magic_manager, &g_state_manager, &g_logger, &g_error_handler, 
                                  &g_lot_calculator, &g_price_helper, &g_martingale, NULL, 
                                  InpEntryMethod, InpPO_DistancePoints, InpPO_CancelOnOpposite, 0.01)) return INIT_FAILED;

   // 3. GridSlicer (Recovery)
   if(!g_gridslicer.Initialize(&g_trade, &g_magic_manager, &g_state_manager, &g_logger, &g_error_handler, 
                               &g_position_scanner, &g_lot_calculator, &g_price_helper)) return INIT_FAILED;

   // --- G. Finalize ---
   EventSetTimer(1);
   g_logger.Info("✅ TITAN GRID EA v1.17 READY");
   g_logger.Info(StringFormat("   Entry Method: %s", EnumToString(InpEntryMethod)));
   
   if(InpEntryMethod == ENTRY_METHOD_PENDING_ORDER) {
       g_logger.Info(StringFormat("   ZigZag Filter: %s", InpPO_UseFilter ? "ON" : "OFF (Fixed Distance)"));
   }
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(InpEnableGridSlicer) g_gridslicer.CancelAllOrders(); // Safety cleanup
   g_logger.Info("👋 Titan Grid EA Stopped.");
}

//+------------------------------------------------------------------+
//| MAIN LOOP (OnTick)                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Update Core Data
   g_state_manager.CheckDailyReset();
   g_position_scanner.Scan(); // Wajib scan dulu agar data profit valid
   
   // 2. SAFETY & GLOBAL EXIT (Priority #1)
   //    Mengecek Global Basket, Equity Stop
   g_close_manager.OnTick();
   
   // Jika Close Manager menutup semua posisi (misal kena TP Global), 
   // hentikan logic lain di tick ini dan pastikan state bersih.
   if(PositionsTotal() == 0)
   {
       // Reset Martingale flag jika posisi habis tapi flag masih nyala
       if(g_martingale.IsIndependentCycleActive()) {
           g_martingale.SyncState(); 
       }
       // Jika cycle tidak aktif menurut State Manager, stop disini
       if(!g_state_manager.IsCycleActive()) return; 
   }

   // 3. Track Cycle Status (Untuk Cleanup Logic)
   static bool prev_cycle_active = false;
   bool current_cycle_active = g_state_manager.IsCycleActive() || g_martingale.IsIndependentCycleActive();
   
   // 4. Strategy Execution
   if(!current_cycle_active) {
      // Tidak ada posisi -> Cari Entry Baru (ZigZag / Pending / Signal)
      g_entry_manager.OnTick(); 
   }
   else {
      // Ada posisi -> Manage Martingale (Add Layer)
      g_martingale.OnTick();    
      
      // Manage GridSlicer (Recovery PO jika floating)
      if(InpEnableGridSlicer) {
         g_gridslicer.OnTick(); 
      }
   }
   
   // 5. AUTO CLEANUP LOGIC
   //    Jika siklus berubah dari Aktif -> Mati (kena TP/SL),
   //    Hapus semua Pending Order sisa.
   if(prev_cycle_active && !current_cycle_active)
   {
      g_logger.Info("🔄 Cycle Ended -> Cleanup Triggered.");
      if(InpEnableGridSlicer) g_gridslicer.CancelAllOrders();
      g_entry_manager.CancelAllPendingOrders(); 
   }
   
   prev_cycle_active = current_cycle_active;
}

//+------------------------------------------------------------------+
//| TIMER LOOP                                                       |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Print Stats periodic (Optional, bisa dimatikan via input jika ada)
   static datetime last_print = 0;
   if(TimeCurrent() - last_print >= 3600) { // Tiap 1 jam
      g_logger.LogSeparator("HOURLY STATS");
      g_position_scanner.PrintSummary();
      last_print = TimeCurrent();
   }
}
//+------------------------------------------------------------------+