//+------------------------------------------------------------------+
//|                                  Config/TG_Inputs_Martingale.mqh |
//|                                          Titan Grid EA v1.0      |
//|                              Martingale Input Parameters         |
//+------------------------------------------------------------------+
//| Location: C:\Users\ichza\AppData\Roaming\MetaQuotes\Terminal\   |
//|           D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\         |
//|           TitanGridEA\Config\TG_Inputs_Martingale.mqh            |
//|                                                                  |
//| Purpose:  Martingale system input parameters                    |
//|           Layer settings, grid distance, lot progression        |
//|           Dependencies: TG_Definitions.mqh                       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.00"

//+------------------------------------------------------------------+
//| CHANGE LOG                                                        |
//+------------------------------------------------------------------+
// Version 1.00 - 2025-01-20
// [INITIAL] Martingale input parameters created
// [ADD] Layer settings (max layers, layer limits)
// [ADD] Grid distance settings (fixed/adaptive)
// [ADD] Lot progression settings (multiply/add modes)
// [ADD] Take profit settings (cycle-level)
// [ADD] Safety limits (max lot, max layers)
//+------------------------------------------------------------------+

#ifndef TG_INPUTS_MARTINGALE_MQH
#define TG_INPUTS_MARTINGALE_MQH

#include "../Core/TG_Definitions.mqh"

//+------------------------------------------------------------------+
//| MARTINGALE LAYER SETTINGS                                         |
//+------------------------------------------------------------------+
input group "═══════════ MARTINGALE LAYERS ═══════════"

input int InpMart_MaxLayers = 15;                      // Maximum Martingale Layers (1-15)
input int InpMart_StartLayer = 1;                      // Start Layer (usually 1)

//+------------------------------------------------------------------+
//| GRID DISTANCE SETTINGS                                            |
//+------------------------------------------------------------------+
input group "═══════════ GRID DISTANCE ═══════════"

input ENUM_GRID_MODE InpMart_GridMode = GRID_MODE_FIXED;  // Grid Distance Mode

// Fixed grid settings
input int InpMart_FixedGridPoints = 1000;              // Fixed Grid Distance (Points) - 1000=$5 for XAUUSD

// Adaptive grid settings (ATR-based)
input int InpMart_ATR_Period = 14;                     // ATR Period (for Adaptive)
input double InpMart_ATR_Multiplier = 2.0;             // ATR Multiplier
input int InpMart_ATR_MinPoints = 200;                 // Min Grid Distance (Points)
input int InpMart_ATR_MaxPoints = 1000;                // Max Grid Distance (Points)

//+------------------------------------------------------------------+
//| GRID DISTANCE PROGRESSION (Jarak Antar Layer)                    |
//+------------------------------------------------------------------+
input group "═══════════ GRID PROGRESSION (Layer Distance) ═══════════"

input ENUM_GRID_PROGRESSION_MODE InpMart_GridProgressionMode = GRID_PROGRESSION_FIXED;  // Grid Progression Mode
input double InpMart_GridMultiplierValue = 1.5;        // Multiply: Multiplier Value (e.g., 1.5 = +50% per layer)
input int InpMart_GridAddValue = 500;                  // Add: Add Value in Points (e.g., 500 = +$2.5 per layer)

// Examples for XAUUSD (1000 points = $5):
// FIXED:     1000, 1000, 1000, 1000, ... (same every layer)
// ADD(500):  1000, 1500, 2000, 2500, ... (increase $2.5 per layer)
// MULTIPLY(1.5): 1000, 1500, 2000, 2500, ... (layer 1→2: 1000+(1000×1.5×1)=2500)
// POWER(1.5): 1000, 1500, 2250, 3375, ... (exponential growth)


//+------------------------------------------------------------------+
//| LOT PROGRESSION SETTINGS                                          |
//+------------------------------------------------------------------+
input group "═══════════ LOT PROGRESSION ═══════════"

input ENUM_PROGRESSION_MODE InpMart_ProgressionMode = PROGRESSION_MULTIPLY;  // Lot Progression Mode

// Multiply mode settings
input double InpMart_LotMultiplier = 2.0;              // Lot Multiplier (Geometric)

// Add mode settings  
input double InpMart_LotAddValue = 0.01;               // Lot Add Value (Arithmetic)

// Progressive multiplier (can decrease over layers)
input bool InpMart_UseProgressiveMultiplier = false;   // Use Progressive Multiplier
input double InpMart_MultiplierDecay = 0.1;            // Multiplier Decay per Layer

// Lot limits
input double InpMart_MaxLotPerPosition = 10.0;         // Max Lot per Single Position
input double InpMart_MaxTotalLot = 50.0;               // Max Total Lot Across All Layers

//+------------------------------------------------------------------+
//| TAKE PROFIT SETTINGS                                              |
//+------------------------------------------------------------------+
input group "═══════════ TAKE PROFIT ═══════════"

input bool InpMart_UseCycleTP = true;                  // Use Cycle-Level Take Profit
input double InpMart_CycleTPDollar = 10.0;             // Cycle TP Amount ($)

// Alternative: TP in points
input bool InpMart_UseTPPoints = false;                // Use TP in Points (per position)
input int InpMart_TPPoints = 1000;                     // Take Profit (Points)

// Trailing stop
input bool InpMart_UseTrailingStop = false;            // Use Trailing Stop
input int InpMart_TrailingStopPoints = 500;            // Trailing Stop Distance (Points)
input int InpMart_TrailingStepPoints = 50;             // Trailing Step (Points)

//+------------------------------------------------------------------+
//| SAFETY & LIMITS                                                   |
//+------------------------------------------------------------------+
input group "═══════════ SAFETY LIMITS ═══════════"

input bool InpMart_UseMaxDrawdownStop = false;         // Stop at Max Drawdown
input double InpMart_MaxDrawdownDollar = 100.0;        // Max Drawdown ($)

input bool InpMart_UseMaxLayerStop = true;             // Stop at Max Layer
input int InpMart_StopAtLayer = 10;                    // Stop Opening New Layers At

input bool InpMart_UseBreakEvenStop = false;           // Move to Break Even
input double InpMart_BreakEvenProfitDollar = 5.0;      // Move to BE at Profit ($)

//+------------------------------------------------------------------+
//| RECOVERY SETTINGS                                                 |
//+------------------------------------------------------------------+
input group "═══════════ RECOVERY OPTIONS ═══════════"

input bool InpMart_UsePartialClose = false;            // Use Partial Position Close
input double InpMart_PartialClosePercent = 50.0;       // Close % of Positions at Profit

input bool InpMart_UseLayerClose = false;              // Close Layer by Layer
input double InpMart_LayerCloseProfitDollar = 5.0;     // Close Layer at Profit ($)

//+------------------------------------------------------------------+
//| ADVANCED SETTINGS                                                 |
//+------------------------------------------------------------------+
input group "═══════════ ADVANCED ═══════════"

input bool InpMart_ReopenOnReverse = false;            // Reopen on Price Reverse
input int InpMart_ReopenDistancePoints = 300;          // Reopen Distance (Points)

input bool InpMart_UseDynamicTP = false;               // Dynamic TP Based on Layers
input double InpMart_DynamicTPMultiplier = 1.5;        // TP Multiplier per Layer

input bool InpMart_AllowManualAddition = true;         // Allow Manual Layer Addition
input bool InpMart_ConfirmManualAddition = false;      // Confirm Before Manual Add

//+------------------------------------------------------------------+
//| INPUT VALIDATION FUNCTION                                        |
//+------------------------------------------------------------------+
bool ValidateMartingaleInputs(string &error_msg)
{
   // Validate max layers
   if(InpMart_MaxLayers < 1 || InpMart_MaxLayers > MAX_LAYERS)
   {
      error_msg = StringFormat("Max Layers must be between 1 and %d", MAX_LAYERS);
      return false;
   }
   
   if(InpMart_StartLayer < 1 || InpMart_StartLayer > InpMart_MaxLayers)
   {
      error_msg = "Start Layer must be between 1 and Max Layers";
      return false;
   }
   
   // Validate grid distance
   if(InpMart_GridMode == GRID_MODE_FIXED)
   {
      if(InpMart_FixedGridPoints <= 0)
      {
         error_msg = "Fixed Grid Distance must be greater than 0";
         return false;
      }
   }
   else if(InpMart_GridMode == GRID_MODE_ADAPTIVE_ATR)
   {
      if(InpMart_ATR_Period <= 0)
      {
         error_msg = "ATR Period must be greater than 0";
         return false;
      }
      
      if(InpMart_ATR_Multiplier <= 0)
      {
         error_msg = "ATR Multiplier must be greater than 0";
         return false;
      }
      
      if(InpMart_ATR_MinPoints <= 0 || InpMart_ATR_MaxPoints <= 0)
      {
         error_msg = "ATR Min/Max Points must be greater than 0";
         return false;
      }
      
      if(InpMart_ATR_MinPoints >= InpMart_ATR_MaxPoints)
      {
         error_msg = "ATR Min Points must be less than Max Points";
         return false;
      }
   }
   
   // Validate grid progression
   if(InpMart_GridProgressionMode == GRID_PROGRESSION_ADD)
   {
      if(InpMart_GridAddValue <= 0)
      {
         error_msg = "Grid Add Value must be greater than 0";
         return false;
      }
   }
   else if(InpMart_GridProgressionMode == GRID_PROGRESSION_MULTIPLY || 
           InpMart_GridProgressionMode == GRID_PROGRESSION_POWER)
   {
      if(InpMart_GridMultiplierValue <= 0)
      {
         error_msg = "Grid Multiplier must be greater than 0";
         return false;
      }
   }
   
   // Validate lot progression
   if(InpMart_ProgressionMode == PROGRESSION_MULTIPLY)
   {
      if(InpMart_LotMultiplier <= 0)
      {
         error_msg = "Lot Multiplier must be greater than 0";
         return false;
      }
      
      if(InpMart_LotMultiplier < 1.0)
      {
         error_msg = "Warning: Lot Multiplier < 1.0 will decrease lot size";
         // Not a critical error, just a warning
      }
   }
   else if(InpMart_ProgressionMode == PROGRESSION_ADD)
   {
      if(InpMart_LotAddValue <= 0)
      {
         error_msg = "Lot Add Value must be greater than 0";
         return false;
      }
   }
   
   // Validate progressive multiplier
   if(InpMart_UseProgressiveMultiplier)
   {
      if(InpMart_MultiplierDecay < 0 || InpMart_MultiplierDecay >= 1.0)
      {
         error_msg = "Multiplier Decay must be between 0 and 1";
         return false;
      }
   }
   
   // Validate lot limits
   if(InpMart_MaxLotPerPosition <= 0)
   {
      error_msg = "Max Lot per Position must be greater than 0";
      return false;
   }
   
   if(InpMart_MaxTotalLot <= 0)
   {
      error_msg = "Max Total Lot must be greater than 0";
      return false;
   }
   
   if(InpMart_MaxLotPerPosition > InpMart_MaxTotalLot)
   {
      error_msg = "Max Lot per Position cannot exceed Max Total Lot";
      return false;
   }
   
   // Validate TP settings
   if(InpMart_UseCycleTP)
   {
      if(InpMart_CycleTPDollar <= 0)
      {
         error_msg = "Cycle TP Amount must be greater than 0";
         return false;
      }
   }
   
   if(InpMart_UseTPPoints)
   {
      if(InpMart_TPPoints <= 0)
      {
         error_msg = "TP Points must be greater than 0";
         return false;
      }
   }
   
   // Validate trailing stop
   if(InpMart_UseTrailingStop)
   {
      if(InpMart_TrailingStopPoints <= 0)
      {
         error_msg = "Trailing Stop Distance must be greater than 0";
         return false;
      }
      
      if(InpMart_TrailingStepPoints <= 0)
      {
         error_msg = "Trailing Step must be greater than 0";
         return false;
      }
   }
   
   // Validate safety limits
   if(InpMart_UseMaxDrawdownStop)
   {
      if(InpMart_MaxDrawdownDollar <= 0)
      {
         error_msg = "Max Drawdown must be greater than 0";
         return false;
      }
   }
   
   if(InpMart_UseMaxLayerStop)
   {
      if(InpMart_StopAtLayer < 1 || InpMart_StopAtLayer > InpMart_MaxLayers)
      {
         error_msg = "Stop At Layer must be between 1 and Max Layers";
         return false;
      }
   }
   
   // Validate partial close
   if(InpMart_UsePartialClose)
   {
      if(InpMart_PartialClosePercent <= 0 || InpMart_PartialClosePercent > 100)
      {
         error_msg = "Partial Close Percent must be between 0 and 100";
         return false;
      }
   }
   
   error_msg = "Martingale inputs validated successfully";
   return true;
}

//+------------------------------------------------------------------+
//| PRINT MARTINGALE INPUT SUMMARY                                   |
//+------------------------------------------------------------------+
void PrintMartingaleInputs()
{
   Print("╔═══════════════════════════════════════════════════════════╗");
   Print("║         MARTINGALE SYSTEM - INPUT PARAMETERS             ║");
   Print("╠═══════════════════════════════════════════════════════════╣");
   Print("║ LAYERS:                                                   ║");
   Print("║   Max Layers:      ", InpMart_MaxLayers);
   Print("║   Start Layer:     ", InpMart_StartLayer);
   Print("╠═══════════════════════════════════════════════════════════╣");
   Print("║ GRID DISTANCE:                                            ║");
   Print("║   Mode:            ", EnumToString(InpMart_GridMode));
   
   if(InpMart_GridMode == GRID_MODE_FIXED)
      Print("║   Fixed Distance:  ", InpMart_FixedGridPoints, " points");
   else
   {
      Print("║   ATR Period:      ", InpMart_ATR_Period);
      Print("║   ATR Multiplier:  ", InpMart_ATR_Multiplier);
      Print("║   Range:           ", InpMart_ATR_MinPoints, " - ", InpMart_ATR_MaxPoints, " pts");
   }
   
   Print("╠═══════════════════════════════════════════════════════════╣");
   Print("║ GRID PROGRESSION:                                         ║");
   Print("║   Mode:            ", EnumToString(InpMart_GridProgressionMode));
   
   if(InpMart_GridProgressionMode == GRID_PROGRESSION_ADD)
      Print("║   Add Value:       ", InpMart_GridAddValue, " points");
   else if(InpMart_GridProgressionMode == GRID_PROGRESSION_MULTIPLY || 
           InpMart_GridProgressionMode == GRID_PROGRESSION_POWER)
      Print("║   Multiplier:      ", InpMart_GridMultiplierValue);
   
   Print("╠═══════════════════════════════════════════════════════════╣");
   Print("║ LOT PROGRESSION:                                          ║");
   Print("║   Mode:            ", EnumToString(InpMart_ProgressionMode));
   
   if(InpMart_ProgressionMode == PROGRESSION_MULTIPLY)
      Print("║   Multiplier:      ", InpMart_LotMultiplier);
   else
      Print("║   Add Value:       ", InpMart_LotAddValue);
   
   Print("║   Max Lot/Pos:     ", InpMart_MaxLotPerPosition);
   Print("║   Max Total Lot:   ", InpMart_MaxTotalLot);
   Print("╠═══════════════════════════════════════════════════════════╣");
   Print("║ TAKE PROFIT:                                              ║");
   Print("║   Cycle TP:        ", (InpMart_UseCycleTP ? "$" + DoubleToString(InpMart_CycleTPDollar, 2) : "Disabled"));
   Print("║   TP Points:       ", (InpMart_UseTPPoints ? IntegerToString(InpMart_TPPoints) : "Disabled"));
   Print("║   Trailing Stop:   ", (InpMart_UseTrailingStop ? "Enabled" : "Disabled"));
   Print("╠═══════════════════════════════════════════════════════════╣");
   Print("║ SAFETY:                                                   ║");
   Print("║   Max Drawdown:    ", (InpMart_UseMaxDrawdownStop ? "$" + DoubleToString(InpMart_MaxDrawdownDollar, 2) : "Disabled"));
   Print("║   Stop At Layer:   ", (InpMart_UseMaxLayerStop ? "L" + IntegerToString(InpMart_StopAtLayer) : "Disabled"));
   Print("║   Manual Addition: ", (InpMart_AllowManualAddition ? "Allowed" : "Not Allowed"));
   Print("╚═══════════════════════════════════════════════════════════╝");
}

//+------------------------------------------------------------------+
//| End of TG_Inputs_Martingale.mqh                                  |
//+------------------------------------------------------------------+
#endif // TG_INPUTS_MARTINGALE_MQH