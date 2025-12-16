//+------------------------------------------------------------------+
//|                                Config/TG_Inputs_GridSlicer.mqh   |
//|                                     Titan Grid EA v1.06          |
//|                     Cleaned & Grouped GridSlicer Parameters      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.06"

#ifndef TG_INPUTS_GRIDSLICER_MQH
#define TG_INPUTS_GRIDSLICER_MQH

//+------------------------------------------------------------------+
//| GRIDSLICER ENUMERATIONS                                          |
//+------------------------------------------------------------------+
enum ENUM_GS_LOT_STRATEGY {
   GS_LOT_FLAT, GS_LOT_PROGRESSIVE, GS_LOT_AGGRESSIVE, 
   GS_LOT_CONSERVATIVE, GS_LOT_GAP_BASED, GS_LOT_PYRAMID
};

enum ENUM_GS_TARGET_STRATEGY {
   GS_TARGET_BREAKEVEN, GS_TARGET_PARTIAL, GS_TARGET_FULL, 
   GS_TARGET_DYNAMIC, GS_TARGET_AGGRESSIVE, GS_TARGET_FIXED, 
   GS_TARGET_PROPORTIONAL
};

//+------------------------------------------------------------------+
//| [ GS-1 ] SYSTEM ACTIVATION                                       |
//+------------------------------------------------------------------+
input group "=== [ GS-1 ] SYSTEM STATUS ==="
input bool    InpGS_Enable = true;                       // Enable GridSlicer V2
input string  InpGS_Info1 = "--- GridSlicer V2 ---";     // Info Label

//+------------------------------------------------------------------+
//| [ GS-2 ] BASIC CONFIGURATION                                     |
//+------------------------------------------------------------------+
input group "=== [ GS-2 ] BASIC SETUP ==="
input double  InpGS_L1LotMultiplier = 0.5;               // Lot Multiplier (from Martingale L1)
input double  InpGS_LotAddValue = 0.01;                  // Lot Addition Step
input double  InpGS_MaxLot = 0.5;                        // Max Lot per GS Order
input int     InpGS_StartLayer = 2;                      // Start Active at Layer X

//+------------------------------------------------------------------+
//| [ GS-3 ] DISTANCE & GAP LOGIC                                    |
//+------------------------------------------------------------------+
input group "=== [ GS-3 ] GAP MANAGEMENT ==="
input double  InpGS_BaseDistancePercent = 30.0;          // PO Distance (% of Gap)
input int     InpGS_MaxPOPerGap = 3;                     // Max PO per Gap (Slices)
input double  InpGS_MinGapForMultiPO = 0.0020;           // Min Gap Size for Multi-PO

//+------------------------------------------------------------------+
//| [ GS-4 ] ADAPTIVE LOGIC (ATR)                                    |
//+------------------------------------------------------------------+
input group "=== [ GS-4 ] ADAPTIVE ATR (V2) ==="
input bool    InpGS_UseAdaptivePercentage = true;        // Use ATR for Distance
input double  InpGS_VolatilityMultiplier = 1.5;          // Volatility Coefficient
input double  InpGS_MinPercent = 15.0;                   // Min Distance %
input double  InpGS_MaxPercent = 60.0;                   // Max Distance %

//+------------------------------------------------------------------+
//| [ GS-5 ] TARGET & PROFIT                                         |
//+------------------------------------------------------------------+
input group "=== [ GS-5 ] TARGET STRATEGY ==="
input ENUM_GS_LOT_STRATEGY InpGS_LotStrategy = GS_LOT_PROGRESSIVE;       // Lot Calculation Mode
input ENUM_GS_TARGET_STRATEGY InpGS_TargetStrategy = GS_TARGET_DYNAMIC;  // Target Calculation Mode
input double  InpGS_MinProfitPerPO = 1.0;                // Min Profit ($) per PO

//+------------------------------------------------------------------+
//| [ GS-6 ] SAFETY & RECOVERY                                       |
//+------------------------------------------------------------------+
input group "=== [ GS-6 ] RISK MANAGEMENT ==="
input double  InpGS_SLMultiplier = 0.0;                  // SL Multiplier (0=Disabled)
input bool    InpGS_UseBEP = true;                       // Enable Break-Even Protection
input int     InpGS_BEP_Points = 50;                     // BEP Activation Points
input double  InpGS_MaxDrawdownPercent = 30.0;           // Max GS Drawdown %
input int     InpGS_MaxTotalPOs = 50;                    // Max Active POs

input group "=== [ GS-7 ] LEARNING & CLEANUP ==="
input bool    InpGS_CloseOnRecovery = true;              // Close All if Profit > 0
input bool    InpGS_CancelOnCycleClose = true;           // Auto Cancel PO on Cycle End
input bool    InpGS_UseLearning = false;                 // [BETA] Enable Learning
input int     InpGS_MinDataForLearning = 10;             // Learning Data Samples
input double  InpGS_SuccessThreshold = 0.4;              // Learning Threshold

//+------------------------------------------------------------------+
//| VALIDATION                                                       |
//+------------------------------------------------------------------+
bool ValidateGridSlicerInputs(string &error_msg)
{
   if(!InpGS_Enable) {
      error_msg = "GridSlicer is disabled"; return true;
   }
   if(InpGS_StartLayer < 2) {
      error_msg = "Start Layer minimal 2"; return false;
   }
   if(InpGS_MaxPOPerGap < 1) {
      error_msg = "Max PO Per Gap minimal 1"; return false;
   }
   if(InpGS_BaseDistancePercent <= 0 || InpGS_BaseDistancePercent >= 100) {
      error_msg = "Distance Percent must be between 1 and 99"; return false;
   }
   return true;
}

#endif