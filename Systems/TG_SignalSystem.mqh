//+------------------------------------------------------------------+
//|                                      Systems/TG_SignalSystem.mqh |
//|                                          Titan Grid EA v1.10     |
//|                          Signal Processing System                |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.00"

#ifndef TG_SIGNAL_SYSTEM_MQH
#define TG_SIGNAL_SYSTEM_MQH

#include <Trade/Trade.mqh>
#include "../Config/TG_Inputs_Signals.mqh"
#include "../Core/TG_Logger.mqh"

class CSignalSystem
{
private:
   CLogger* m_logger;
   int      m_handle_rsi;
   int      m_handle_ma;
   
   double   m_buffer_rsi[];
   double   m_buffer_ma[];

public:
   CSignalSystem() { m_handle_rsi = INVALID_HANDLE; m_handle_ma = INVALID_HANDLE; }
   
   ~CSignalSystem() {
      if(m_handle_rsi != INVALID_HANDLE) IndicatorRelease(m_handle_rsi);
      if(m_handle_ma != INVALID_HANDLE) IndicatorRelease(m_handle_ma);
   }

   bool Initialize(CLogger* logger)
   {
      m_logger = logger;
      
      // Init RSI
      m_handle_rsi = iRSI(_Symbol, _Period, InpRSI_Period, PRICE_CLOSE);
      if(m_handle_rsi == INVALID_HANDLE) {
         if(m_logger) m_logger.Error("❌ Failed to create RSI handle");
         return false;
      }
      
      // Init MA
      m_handle_ma = iMA(_Symbol, _Period, InpMA_Period, 0, InpMA_Method, InpMA_Price);
      if(m_handle_ma == INVALID_HANDLE) {
         if(m_logger) m_logger.Error("❌ Failed to create MA handle");
         return false;
      }
      
      return true;
   }

   // Return: 0=No Signal, 1=BUY, 2=SELL
   int GetSignal()
   {
      if(InpSignalStrategy == SIG_STRAT_ALWAYS_ENTRY) return 1; // Default Buy for test
      
      // Update Buffers
      ArraySetAsSeries(m_buffer_rsi, true);
      ArraySetAsSeries(m_buffer_ma, true);
      
      if(CopyBuffer(m_handle_rsi, 0, 0, 2, m_buffer_rsi) < 2) return 0;
      if(CopyBuffer(m_handle_ma, 0, 0, 2, m_buffer_ma) < 2) return 0;
      
      double rsi = m_buffer_rsi[0]; // Current RSI
      double ma = m_buffer_ma[0];   // Current MA
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      // --- STRATEGY LOGIC ---
      bool buy_signal = false;
      bool sell_signal = false;
      
      // 1. RSI Logic (Reversal)
      bool rsi_buy = (rsi < InpRSI_LowerLevel);
      bool rsi_sell = (rsi > InpRSI_UpperLevel);
      
      // 2. MA Logic (Trend Filter)
      bool trend_up = (price > ma);
      bool trend_down = (price < ma);
      
      switch(InpSignalStrategy)
      {
         case SIG_STRAT_RSI_ONLY:
            if(rsi_buy) buy_signal = true;
            if(rsi_sell) sell_signal = true;
            break;
            
         case SIG_STRAT_MA_CROSS:
            // Simple logic: Price > MA = Buy
            if(trend_up) buy_signal = true;
            if(trend_down) sell_signal = true;
            break;
            
         case SIG_STRAT_RSI_MA_FILTER:
            // RSI Oversold (Murah) TAPI Trend harus NAIK (Pullback di uptrend)
            if(rsi_buy && trend_up) buy_signal = true;
            // RSI Overbought (Mahal) TAPI Trend harus TURUN (Pullback di downtrend)
            if(rsi_sell && trend_down) sell_signal = true;
            break;
      }
      
      if(buy_signal) return 1; // BUY
      if(sell_signal) return 2; // SELL
      
      return 0;
   }
};

#endif