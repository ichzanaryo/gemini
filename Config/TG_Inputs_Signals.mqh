//+------------------------------------------------------------------+
//|                                     Config/TG_Inputs_Signals.mqh |
//|                                          Titan Grid EA v1.10     |
//|                            Signal & Filter Input Parameters      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.00"

#ifndef TG_INPUTS_SIGNALS_MQH
#define TG_INPUTS_SIGNALS_MQH

//+------------------------------------------------------------------+
//| SIGNAL ENUMERATIONS                                              |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_STRATEGY
{
   SIG_STRAT_RSI_ONLY,       // RSI Overbought/Oversold
   SIG_STRAT_MA_CROSS,       // Price crosses MA
   SIG_STRAT_RSI_MA_FILTER,  // RSI signal + MA Trend Filter
   SIG_STRAT_ALWAYS_ENTRY    // Entry immediately (for testing)
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== SIGNAL SETTINGS (Entry Method = SIGNAL) ==="
input ENUM_SIGNAL_STRATEGY InpSignalStrategy = SIG_STRAT_RSI_MA_FILTER; // Signal Strategy

input group "=== RSI SETTINGS ==="
input int      InpRSI_Period        = 14;          // RSI Period
input double   InpRSI_UpperLevel    = 70.0;        // RSI Overbought (Sell Signal)
input double   InpRSI_LowerLevel    = 30.0;        // RSI Oversold (Buy Signal)

input group "=== MA TREND FILTER ==="
input int      InpMA_Period         = 200;         // MA Period
input ENUM_MA_METHOD InpMA_Method   = MODE_EMA;    // MA Method
input ENUM_APPLIED_PRICE InpMA_Price= PRICE_CLOSE; // MA Applied Price

#endif