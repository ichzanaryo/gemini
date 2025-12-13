//+------------------------------------------------------------------+
//|                               Systems/TG_PendingOrderManager.mqh |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.16"

#ifndef TG_PENDING_ORDER_MANAGER_MQH
#define TG_PENDING_ORDER_MANAGER_MQH

#include <Trade/Trade.mqh>
// PERBAIKAN: Arahkan ke Main Inputs
#include "../Config/TG_Inputs_Main.mqh" 
#include "TG_ZigZagFilter.mqh"
#include "../Core/TG_Logger.mqh"

class CPendingOrderManager
{
private:
   CTrade* m_trade;
   CZigZagFilter* m_zigzag;
   CLogger* m_logger;
   ulong m_pending_ticket;
   datetime m_placed_time;
   int m_placed_bar; 
   
public:
   CPendingOrderManager() { m_pending_ticket = 0; m_placed_time = 0; m_trade = NULL; m_zigzag = NULL; }

   bool Initialize(CTrade* trade, CZigZagFilter* zigzag, CLogger* logger)
   {
      m_trade = trade; m_zigzag = zigzag; m_logger = logger;
      return true;
   }

   bool PlacePendingEntry(ENUM_POSITION_TYPE direction, double lot, long magic)
   {
      m_zigzag.Refresh();
      double entry_price = 0;
      double buffer = InpPO_BufferPoints * _Point; // Menggunakan Input dari Main
      
      if(direction == POSITION_TYPE_BUY) {
         double swing_high = m_zigzag.GetLastSwingHigh();
         if(swing_high == 0) return false;
         entry_price = swing_high + buffer;
         
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(entry_price <= ask) entry_price = ask + buffer; 
         
         m_trade.SetExpertMagicNumber(magic);
         if(m_trade.BuyStop(lot, entry_price, _Symbol, 0, 0, ORDER_TIME_GTC, 0, "TG-ZigZag-BuyStop")) {
            m_pending_ticket = m_trade.ResultOrder();
            m_placed_time = TimeCurrent();
            m_placed_bar = iBars(_Symbol, _Period);
            m_logger.Info(StringFormat("✅ BUY STOP Placed @ %.5f", entry_price));
            return true;
         }
      }
      else { // SELL
         double swing_low = m_zigzag.GetLastSwingLow();
         if(swing_low == 0) return false;
         entry_price = swing_low - buffer;
         
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry_price >= bid) entry_price = bid - buffer;
         
         m_trade.SetExpertMagicNumber(magic);
         if(m_trade.SellStop(lot, entry_price, _Symbol, 0, 0, ORDER_TIME_GTC, 0, "TG-ZigZag-SellStop")) {
            m_pending_ticket = m_trade.ResultOrder();
            m_placed_time = TimeCurrent();
            m_placed_bar = iBars(_Symbol, _Period);
            m_logger.Info(StringFormat("✅ SELL STOP Placed @ %.5f", entry_price));
            return true;
         }
      }
      return false;
   }

   void CheckTimeout()
   {
      if(m_pending_ticket == 0 || !InpPO_UseFilter) return;
      int bars_passed = iBars(_Symbol, _Period) - m_placed_bar;
      if(bars_passed > InpPO_TimeoutBars) {
         m_logger.Info("⏳ Pending Order Timeout. Cancelling...");
         CancelPendingOrder();
      }
   }
   
   bool IsPendingTriggered()
   {
      if(m_pending_ticket == 0) return false;
      if(!OrderSelect(m_pending_ticket) && PositionSelectByTicket(m_pending_ticket)) {
         m_logger.Info("🚀 Pending Order TRIGGERED!");
         m_pending_ticket = 0; 
         return true;
      }
      return false;
   }
   
   void CancelPendingOrder() {
      if(m_pending_ticket != 0) { m_trade.OrderDelete(m_pending_ticket); m_pending_ticket = 0; }
   }
   
   bool HasActivePending() { return m_pending_ticket != 0; }
};
#endif