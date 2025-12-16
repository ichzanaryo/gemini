//+------------------------------------------------------------------+
//|                               Config/TG_Inputs_Martingale.mqh    |
//|                                     Titan Grid EA v1.01          |
//|                     Cleaned & Grouped Martingale Parameters      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.01"

#ifndef TG_INPUTS_MARTINGALE_MQH
#define TG_INPUTS_MARTINGALE_MQH

#include "../Core/TG_Definitions.mqh"

//+------------------------------------------------------------------+
//| [ MART-1 ] LAYER CONFIGURATION                                   |
//+------------------------------------------------------------------+
input group "=== [ MART-1 ] LAYER SETTINGS ==="
input int InpMart_MaxLayers = 15;                      // Max Layers (Hard Limit)
input int InpMart_StartLayer = 1;                      // Start Layer Index

//+------------------------------------------------------------------+
//| [ MART-2 ] GRID DISTANCE SETUP                                   |
//+------------------------------------------------------------------+
input group "=== [ MART-2 ] GRID DISTANCE (GAP) ==="
input ENUM_GRID_MODE InpMart_GridMode = GRID_MODE_FIXED; // Grid Calculation Mode

// --- Fixed Mode ---
input int InpMart_FixedGridPoints = 1000;              // [Fixed] Distance (Points)

// --- Adaptive ATR Mode ---
input int InpMart_ATR_Period = 14;                     // [ATR] Period
input double InpMart_ATR_Multiplier = 2.0;             // [ATR] Multiplier
input int InpMart_ATR_MinPoints = 200;                 // [ATR] Min Distance Limit
input int InpMart_ATR_MaxPoints = 1000;                // [ATR] Max Distance Limit

//+------------------------------------------------------------------+
//| [ MART-3 ] DYNAMIC DISTANCE (EXPANSION)                          |
//+------------------------------------------------------------------+
input group "=== [ MART-3 ] GRID EXPANSION ==="
input ENUM_GRID_PROGRESSION_MODE InpMart_GridProgressionMode = GRID_PROGRESSION_FIXED; // Expansion Mode
input double InpMart_GridMultiplierValue = 1.5;        // [Multiply] Expansion Coeff
input int InpMart_GridAddValue = 500;                  // [Add] Points Addition

//+------------------------------------------------------------------+
//| [ MART-4 ] LOT SIZE PROGRESSION                                  |
//+------------------------------------------------------------------+
input group "=== [ MART-4 ] LOT PROGRESSION ==="
input ENUM_PROGRESSION_MODE InpMart_ProgressionMode = PROGRESSION_MULTIPLY; // Lot Mode
input double InpMart_LotMultiplier = 2.0;              // [Multiply] Lot Multiplier
input double InpMart_LotAddValue = 0.01;               // [Add] Lot Addition

// --- Progressive Multiplier Logic ---
input bool InpMart_UseProgressiveMultiplier = false;   // Enable Progressive Decay
input double InpMart_MultiplierDecay = 0.1;            // Decay Value per Layer

// --- Volume Safety ---
input double InpMart_MaxLotPerPosition = 10.0;         // Max Lot Single Position
input double InpMart_MaxTotalLot = 50.0;               // Max Total Lot (Martingale Only)

//+------------------------------------------------------------------+
//| [ MART-5 ] BACKUP EXIT (SECONDARY)                               |
//+------------------------------------------------------------------+
// Note: Primary Exit is now in Main Inputs (Phoenix Logic).
// These settings act as a hard-stop backup or redundant check.
input group "=== [ MART-5 ] BACKUP EXIT (Use as Hard Stop) ==="
input bool InpMart_UseCycleTP = false;                 // Use Fixed TP ($)
input double InpMart_CycleTPDollar = 1000.0;           // Fixed TP Amount (Set High for Backup)

input bool InpMart_UseTPPoints = false;                // Use Fixed TP (Points)
input int InpMart_TPPoints = 1000;                     // TP Points per Position

input bool InpMart_UseTrailingStop = false;            // Use Classic Trailing
input int InpMart_TrailingStopPoints = 500;            // Trailing Start
input int InpMart_TrailingStepPoints = 50;             // Trailing Step

//+------------------------------------------------------------------+
//| [ MART-6 ] ADVANCED RECOVERY & SAFETY                            |
//+------------------------------------------------------------------+
//input group "=== [ MART-6 ] ADVANCED SAFETY ==="
//input bool InpMart_UseMaxDrawdownStop = false;         // Stop at Specific DD ($)
//input double InpMart_MaxDrawdownDollar = 100.0;        // Max Drawdown Amount ($)

//input bool InpMart_UseMaxLayerStop = true;             // Stop Adding Layers
//input int InpMart_StopAtLayer = 10;                    // Stop Layer Number

//input bool InpMart_UseBreakEvenStop = false;           // Force BEP Logic
//input double InpMart_BreakEvenProfitDollar = 5.0;      // BEP Trigger ($)

// --- Partial Close ---
//input bool InpMart_UsePartialClose = false;            // Enable Partial Close
//input double InpMart_PartialClosePercent = 50.0;       // % to Close

// --- Reopen Logic ---
//input bool InpMart_ReopenOnReverse = false;            // Reopen on Reversal
//input int InpMart_ReopenDistancePoints = 300;          // Reopen Distance

//input bool InpMart_UseDynamicTP = false;               // Dynamic TP Logic
//input double InpMart_DynamicTPMultiplier = 1.5;        // Dynamic TP Multiplier

//input bool InpMart_AllowManualAddition = true;         // Allow Manual Layering
//input bool InpMart_ConfirmManualAddition = false;      // Confirm Manual Action


// ==========================================================================
// [MART-6] ADVANCED SAFETY (HIDDEN & DISABLED)
// Fitur ini disembunyikan dari menu Input dan dimatikan (False)
// agar tidak bentrok dengan logika baru.
// ==========================================================================

// input group "=== [ MART-6 ] ADVANCED SAFETY ===" <-- Baris ini dihapus atau dikomentari
   
bool   StopAtSpecificDD     = false;  // HIDDEN: Stop at Specific DD ($)
double MaxDrawdownAmount    = 100.0;  // HIDDEN: Max Drawdown Amount ($)
bool   StopAddingLayers     = false;  // HIDDEN: Stop Adding Layers
int    StopLayerNumber      = 10;     // HIDDEN: Stop Layer Number
bool   ForceBEPLogic        = false;  // HIDDEN: Force BEP Logic
double BEPTrigger           = 5.0;    // HIDDEN: BEP Trigger ($)
bool   EnablePartialClose   = false;  // HIDDEN: Enable Partial Close
double PercentToClose       = 50.0;   // HIDDEN: % to Close
bool   ReopenOnReversal     = false;  // HIDDEN: Reopen on Reversal
int    ReopenDistance       = 300;    // HIDDEN: Reopen Distance
bool   DynamicTPLogic       = false;  // HIDDEN: Dynamic TP Logic
double DynamicTPMultiplier  = 1.5;    // HIDDEN: Dynamic TP Multiplier
bool   AllowManualLayering  = false;  // HIDDEN: Allow Manual Layering (Safety: False)
bool   ConfirmManualAction  = false;  // HIDDEN: Confirm Manual Action



//+------------------------------------------------------------------+
//| VALIDATION FUNCTION                                              |
//+------------------------------------------------------------------+
bool ValidateMartingaleInputs(string &error_msg)
{
   if(InpMart_MaxLayers < 1 || InpMart_MaxLayers > MAX_LAYERS) {
      error_msg = StringFormat("Max Layers must be between 1 and %d", MAX_LAYERS); return false;
   }
   if(InpMart_StartLayer < 1 || InpMart_StartLayer > InpMart_MaxLayers) {
      error_msg = "Start Layer must be between 1 and Max Layers"; return false;
   }
   if(InpMart_GridMode == GRID_MODE_FIXED && InpMart_FixedGridPoints <= 0) {
      error_msg = "Fixed Grid Distance must be > 0"; return false;
   }
   // ... (Additional validations kept implicitly or can be added here)
   
   return true;
}

void PrintMartingaleInputs()
{
   Print("--- Martingale Inputs Loaded ---");
}

#endif // TG_INPUTS_MARTINGALE_MQH