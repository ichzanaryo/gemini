//+------------------------------------------------------------------+
//|                                           Systems/TG_Hedge.mqh   |
//|                                          Titan Grid EA v1.0      |
//|                                       Smart Hedging System       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"

#ifndef TG_HEDGE_MQH
#define TG_HEDGE_MQH

#include <Trade/Trade.mqh>
#include "../Core/TG_Definitions.mqh"
#include "../Core/TG_MagicNumbers.mqh"
#include "../Core/TG_StateManager.mqh"
#include "../Core/TG_Logger.mqh"
#include "../Utilities/TG_PositionScanner.mqh"
#include "../Utilities/TG_PriceHelpers.mqh"
#include "../Config/TG_Inputs_Hedge.mqh"

class CHedgeSystem
{
private:
   CTrade* m_trade;
   CMagicNumberManager* m_magic;
   CStateManager* m_state;
   CLogger* m_logger;
   CPositionScanner* m_scanner;
   CPriceHelper* m_price;
   
   // State Variables
   ENUM_HEDGE_STATE     m_current_state;
   datetime             m_confirm_start_time;
   double               m_trigger_price;
   ulong                m_hedge_ticket; // Stores active hedge ticket
   
   //+------------------------------------------------------------------+
   //| Hitung Volume Lot untuk Hedge                                    |
   //+------------------------------------------------------------------+
   double CalculateHedgeLot(double martingale_total_lot)
   {
      double lot = 0.0;
      
      switch(InpHedge_Type)
      {
         case HEDGE_TYPE_FULL:
            lot = martingale_total_lot * (InpHedge_VolumePercent / 100.0);
            break;
         case HEDGE_TYPE_PARTIAL:
            lot = martingale_total_lot * (InpHedge_VolumePercent / 100.0);
            break;
         case HEDGE_TYPE_FIXED_LOT:
            lot = InpHedge_FixedLot;
            break;
      }
      
      // Normalize
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      
      if(step > 0) lot = MathRound(lot / step) * step;
      if(lot < min) lot = min;
      if(lot > max) lot = max;
      
      return lot;
   }

public:
   CHedgeSystem()
   {
      m_current_state = HEDGE_STATE_INACTIVE;
      m_hedge_ticket = 0;
      m_confirm_start_time = 0;
   }
   
   bool Initialize(CTrade* trade, CMagicNumberManager* magic, CStateManager* state, 
                   CLogger* logger, CPositionScanner* scanner, CPriceHelper* price)
   {
      m_trade = trade; m_magic = magic; m_state = state;
      m_logger = logger; m_scanner = scanner; m_price = price;
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| MAIN LOGIC LOOP                                                  |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      if(!InpHedge_Enable) return;
      if(m_state.IsHedgeStopped()) return;

      // Update position data
      SPositionSummary summary = m_scanner.GetSummary();
      
      // 1. Check if Hedge is already Active
      if(summary.hedge_count > 0)
      {
         m_current_state = HEDGE_STATE_ACTIVE;
         ManageActiveHedge(summary);
         return;
      }
      else
      {
         // Reset state if manually closed
         if(m_current_state == HEDGE_STATE_ACTIVE) m_current_state = HEDGE_STATE_INACTIVE;
      }

      // 2. Monitoring Logic (Trigger Check)
      if(m_current_state == HEDGE_STATE_INACTIVE)
      {
         int current_layer = 0;
         double total_lot = 0;
         ENUM_POSITION_TYPE mart_dir = POSITION_TYPE_BUY; // Default
         
         // Get Martingale Status
         if(summary.mart_buy_count > 0) {
            current_layer = m_scanner.GetHighestMartingaleLayer();
            total_lot = summary.mart_buy_lots;
            mart_dir = POSITION_TYPE_BUY;
         }
         else if(summary.mart_sell_count > 0) {
            current_layer = m_scanner.GetHighestMartingaleLayer();
            total_lot = summary.mart_sell_lots;
            mart_dir = POSITION_TYPE_SELL;
         }
         else {
            return; // No martingale active
         }

         // Trigger Activation
         if(current_layer >= InpHedge_ActivateAtLayer)
         {
            m_logger.Info(StringFormat("🛡️ Hedge Triggered! Layer %d reached. Starting confirmation...", current_layer));
            m_current_state = HEDGE_STATE_CONFIRMING;
            m_confirm_start_time = TimeCurrent();
            m_trigger_price = (mart_dir == POSITION_TYPE_BUY) ? m_price.GetBid() : m_price.GetAsk();
         }
      }

      // 3. Confirmation Logic (Anti-Whipsaw)
      if(m_current_state == HEDGE_STATE_CONFIRMING)
      {
         // A. Time Confirmation
         if(InpHedge_UseTimeConfirm)
         {
            if(TimeCurrent() - m_confirm_start_time >= InpHedge_ConfirmSeconds)
            {
               OpenHedgePosition(summary);
            }
            
            // Check Reversal (Cancel hedge if price bounces back)
            double current_price = (summary.mart_buy_count > 0) ? m_price.GetBid() : m_price.GetAsk();
            double reversal = MathAbs(current_price - m_trigger_price) / m_price.GetPoint();
            
            if(reversal > InpHedge_MaxReversalPoints)
            {
               m_logger.Info("♻️ Hedge Trigger Cancelled: Price Reversed.");
               m_current_state = HEDGE_STATE_INACTIVE;
            }
         }
         else
         {
            // Instant Open
            OpenHedgePosition(summary);
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Open Position Hedge                                              |
   //+------------------------------------------------------------------+
   void OpenHedgePosition(SPositionSummary &summary)
   {
      double mart_lot = (summary.mart_buy_count > 0) ? summary.mart_buy_lots : summary.mart_sell_lots;
      double hedge_lot = CalculateHedgeLot(mart_lot);
      
      // Direction is OPPOSITE to Martingale
      ENUM_ORDER_TYPE type;
      long magic;
      
      if(summary.mart_buy_count > 0) {
         type = ORDER_TYPE_SELL; // Mart is BUY, Hedge is SELL
         magic = m_magic.GetHedgeSellMagic();
      } else {
         type = ORDER_TYPE_BUY; // Mart is SELL, Hedge is BUY
         magic = m_magic.GetHedgeBuyMagic();
      }
      
      m_trade.SetExpertMagicNumber(magic);
      if(type == ORDER_TYPE_BUY) m_trade.Buy(hedge_lot, _Symbol, 0, 0, 0, "Smart Hedge");
      else m_trade.Sell(hedge_lot, _Symbol, 0, 0, 0, "Smart Hedge");
      
      if(m_trade.ResultRetcode() == TRADE_RETCODE_DONE)
      {
         m_logger.Info(StringFormat("✅ HEDGE OPENED: %s %.2f Lots", EnumToString(type), hedge_lot));
         m_current_state = HEDGE_STATE_ACTIVE;
         m_hedge_ticket = m_trade.ResultOrder();
      }
      else
      {
         m_logger.Error("❌ Failed to open Hedge!");
         m_current_state = HEDGE_STATE_INACTIVE; // Retry next tick
      }
   }

   //+------------------------------------------------------------------+
   //| Manage Active Hedge (Exit Logic)                                 |
   //+------------------------------------------------------------------+
   void ManageActiveHedge(SPositionSummary &summary)
   {
      double hedge_profit = summary.hedge_profit; // P/L + Swap + Comm
      double total_net_profit = summary.GetNetPL(); // Basket Profit
      
      // Strategy 1: Individual TP
      if(InpHedge_Strategy == HEDGE_STRAT_INDIVIDUAL_TP)
      {
         if(hedge_profit >= InpHedge_IndividualTP)
         {
            CloseAllHedgePositions();
            m_logger.Info("💰 Hedge Individual TP Reached.");
         }
      }
      
      // Strategy 2: Global Basket (Netting)
      if(InpHedge_Strategy == HEDGE_STRAT_GLOBAL_BASKET)
      {
         if(total_net_profit >= InpHedge_GlobalBasketTP)
         {
            m_logger.Info(StringFormat("🧺 Global Basket Profit ($%.2f) Reached with Hedge!", total_net_profit));
            // Close Everything handled by CloseManager or here
            CloseAllHedgePositions();
            // Important: We signal state manager or let CloseManager handle the rest
            m_state.EndCycle(true); 
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Utility: Close Only Hedge Positions                              |
   //+------------------------------------------------------------------+
   void CloseAllHedgePositions()
   {
      for(int i=PositionsTotal()-1; i>=0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
         {
            long magic = PositionGetInteger(POSITION_MAGIC);
            if(m_magic.IsHedge(magic))
            {
               m_trade.PositionClose(ticket);
            }
         }
      }
      m_current_state = HEDGE_STATE_INACTIVE;
   }
   
   // Getter State
   bool IsHedgeActive() { return (m_current_state == HEDGE_STATE_ACTIVE); }
};

#endif