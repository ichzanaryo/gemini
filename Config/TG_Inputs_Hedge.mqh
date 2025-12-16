//+------------------------------------------------------------------+
//|                                     Config/TG_Inputs_Hedge.mqh   |
//|                                          Titan Grid EA v1.0      |
//|                            Smart Hedging Configuration           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"

#ifndef TG_INPUTS_HEDGE_MQH
#define TG_INPUTS_HEDGE_MQH

#include "../Core/TG_Definitions.mqh"

//+------------------------------------------------------------------+
//| [ HEDGE-1 ] ACTIVATION & TYPE                                    |
//+------------------------------------------------------------------+
input group "=== [ HEDGE-1 ] ACTIVATION ==="
input bool    InpHedge_Enable = false;               // Enable Smart Hedging
input int     InpHedge_ActivateAtLayer = 5;          // Activate at Layer X
input ENUM_HEDGE_TYPE InpHedge_Type = HEDGE_TYPE_FULL; // Hedging Volume Type
input double  InpHedge_VolumePercent = 100.0;        // % of Martingale Lot to Hedge (if Partial/Full)
input double  InpHedge_FixedLot = 0.01;              // Fixed Lot (if Type Fixed)

//+------------------------------------------------------------------+
//| [ HEDGE-2 ] CONFIRMATION FILTER                                  |
//+------------------------------------------------------------------+
input group "=== [ HEDGE-2 ] CONFIRMATION ==="
input bool    InpHedge_UseTimeConfirm = true;        // Use Time Confirmation
input int     InpHedge_ConfirmSeconds = 60;          // Wait X Seconds before open
input int     InpHedge_MaxReversalPoints = 50;       // Cancel if price reverses X points
input bool    InpHedge_UseCandleConfirm = false;     // Wait for Candle Close

//+------------------------------------------------------------------+
//| [ HEDGE-3 ] EXIT STRATEGY                                        |
//+------------------------------------------------------------------+
input group "=== [ HEDGE-3 ] EXIT RULES ==="
input ENUM_HEDGE_STRATEGY InpHedge_Strategy = HEDGE_STRAT_GLOBAL_BASKET; // Exit Strategy
input double  InpHedge_IndividualTP = 10.0;          // Individual Hedge TP ($)
input double  InpHedge_GlobalBasketTP = 5.0;         // Basket Profit Target ($) (Netting)

//+------------------------------------------------------------------+
//| VALIDATION                                                       |
//+------------------------------------------------------------------+
bool ValidateHedgeInputs(string &error_msg)
{
   if(InpHedge_Enable)
   {
      if(InpHedge_ActivateAtLayer < 2) {
         error_msg = "Hedge Activation Layer must be >= 2"; return false;
      }
      if(InpHedge_Type == HEDGE_TYPE_PARTIAL && InpHedge_VolumePercent <= 0) {
         error_msg = "Hedge Percent must be > 0"; return false;
      }
   }
   return true;
}

#endif