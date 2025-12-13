//+------------------------------------------------------------------+
//|                         Config/TG_Inputs_GridSlicer.mqh          |
//|                                Titan Grid EA v1.05               |
//|             GridSlicer Input Parameters (V2 FEATURE SET)         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.05"

#ifndef TG_INPUTS_GRIDSLICER_MQH
#define TG_INPUTS_GRIDSLICER_MQH

//+------------------------------------------------------------------+
//| GRIDSLICER ENUMERATIONS                                          |
//+------------------------------------------------------------------+

//--- Lot Strategy Modes
enum ENUM_GS_LOT_STRATEGY
{
   GS_LOT_FLAT,              // Flat - Lot sama semua
   GS_LOT_PROGRESSIVE,       // Progressive - Naik per layer (+20%)
   GS_LOT_AGGRESSIVE,        // Aggressive - Exponential growth (1.35x)
   GS_LOT_CONSERVATIVE,      // Conservative - Linear growth (+15%)
   GS_LOT_GAP_BASED,         // Gap Based - Berdasarkan ukuran gap
   GS_LOT_PYRAMID            // Pyramid - Mengecil per PO (-15%)
};

//--- Recovery Target Strategy
enum ENUM_GS_TARGET_STRATEGY
{
   GS_TARGET_BREAKEVEN,      // Break Even - Target di harga layer target
   GS_TARGET_PARTIAL,        // Partial Recovery - 50% dari drawdown
   GS_TARGET_FULL,           // Full Recovery - Breakeven + profit 20 pips
   GS_TARGET_DYNAMIC,        // Dynamic - Berdasarkan ATR (30%)
   GS_TARGET_AGGRESSIVE,     // Aggressive - Profit lebih besar (50% ATR)
   GS_TARGET_FIXED,          // Fixed Dollar Amount
   GS_TARGET_PROPORTIONAL    // Proportional to Lot Size
};

//+------------------------------------------------------------------+
//| GRIDSLICER INPUT PARAMETERS                                      |
//+------------------------------------------------------------------+

input group "=== GRIDSLICER SYSTEM ==="
input bool    InpGS_Enable = true;                         // Enable GridSlicer
input string  InpGS_Info1 = "--- GridSlicer Recovery System V2 ---"; // Info

input group "=== GS: BASIC SETTINGS ==="
input double  InpGS_L1LotMultiplier = 0.5;                // Multiplier dari L1 Martingale (0.1 - 2.0)
input double  InpGS_LotAddValue = 0.01;                   // Penambahan lot per layer (0.0 - 0.1)
input double  InpGS_MaxLot = 0.5;                         // Maximum lot GridSlicer
input int     InpGS_StartLayer = 2;                       // Mulai aktif di layer ke- (Default 2)

input group "=== GS: DISTANCE & GAP ==="
input double  InpGS_BaseDistancePercent = 30.0;           // Jarak PO dalam % gap (30% recommended)
input int     InpGS_MaxPOPerGap = 3;                      // Max PO per gap (Multi-PO Supported)
input double  InpGS_MinGapForMultiPO = 0.0020;            // Min gap agar Multi-PO aktif (Points)

input group "=== GS: ADAPTIVE LOGIC (V2) ==="
input bool    InpGS_UseAdaptivePercentage = true;         // [V2] Use Adaptive Distance (ATR)
input double  InpGS_VolatilityMultiplier = 1.5;           // [V2] Volatility Multiplier
input double  InpGS_MinPercent = 15.0;                    // [V2] Min Distance %
input double  InpGS_MaxPercent = 60.0;                    // [V2] Max Distance %

input group "=== GS: STRATEGY & TARGET ==="
input ENUM_GS_LOT_STRATEGY InpGS_LotStrategy = GS_LOT_PROGRESSIVE; // Strategi Lot
input ENUM_GS_TARGET_STRATEGY InpGS_TargetStrategy = GS_TARGET_DYNAMIC; // Strategi Target Profit
input double  InpGS_MinProfitPerPO = 1.0;                 // Min Profit ($) per PO

input group "=== GS: RISK MANAGEMENT ==="
input double  InpGS_SLMultiplier = 0.0;                   // SL Multiplier (0=Disabled)
input bool    InpGS_UseBEP = true;                        // Gunakan Break-Even Protection
input int     InpGS_BEP_Points = 50;                      // BEP activation points
input double  InpGS_MaxDrawdownPercent = 30.0;            // Max Drawdown limit for GS (%)
input int     InpGS_MaxTotalPOs = 50;                     // Max Total PO allowed

input group "=== GS: RECOVERY & LEARNING ==="
input bool    InpGS_CloseOnRecovery = true;               // Close All jika Total Profit > 0
input bool    InpGS_CancelOnCycleClose = true;            // Hapus PO saat Martingale selesai
input bool    InpGS_UseLearning = false;                  // [BETA] Enable Learning System
input int     InpGS_MinDataForLearning = 10;              // Min data untuk learning
input double  InpGS_SuccessThreshold = 0.4;               // Success threshold

//+------------------------------------------------------------------+
//| VALIDATION FUNCTIONS                                             |
//+------------------------------------------------------------------+
bool ValidateGridSlicerInputs(string &error_msg)
{
   if(!InpGS_Enable) {
      error_msg = "GridSlicer is disabled";
      return true;
   }
   
   if(InpGS_StartLayer < 2) {
      error_msg = "Start Layer minimal 2";
      return false;
   }
   
   if(InpGS_MaxPOPerGap < 1) {
      error_msg = "Max PO Per Gap minimal 1";
      return false;
   }
   
   if(InpGS_BaseDistancePercent <= 0 || InpGS_BaseDistancePercent >= 100) {
      error_msg = "Distance Percent must be between 1 and 99";
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+
string GetLotStrategyName(ENUM_GS_LOT_STRATEGY strategy)
{
   switch(strategy) {
      case GS_LOT_FLAT: return "Flat";
      case GS_LOT_PROGRESSIVE: return "Progressive";
      case GS_LOT_AGGRESSIVE: return "Aggressive";
      default: return "Unknown";
   }
}

string GetTargetStrategyName(ENUM_GS_TARGET_STRATEGY strategy)
{
   switch(strategy) {
      case GS_TARGET_BREAKEVEN: return "Break Even";
      case GS_TARGET_DYNAMIC: return "Dynamic";
      default: return "Unknown";
   }
}

#endif