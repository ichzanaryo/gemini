//+------------------------------------------------------------------+
//|                                  Systems/TG_EntryManager.mqh     |
//|                                          Titan Grid EA v1.0      |
//|                          Entry Management System                 |
//+------------------------------------------------------------------+
//| Location: C:\Users\ichza\AppData\Roaming\MetaQuotes\Terminal\   |
//|           D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\         |
//|           TitanGridEA\Systems\TG_EntryManager.mqh                |
//|                                                                  |
//| Purpose:  Manage entry methods (Signal/PO/Manual)               |
//|           Place pending orders, check signals                   |
//|           Trigger martingale cycle starts                       |
//|           Dependencies: All core systems                         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.00"

//+------------------------------------------------------------------+
//| CHANGE LOG                                                        |
//+------------------------------------------------------------------+
// Version 1.00 - 2025-01-20
// [INITIAL] Entry manager created
// [ADD] Signal-based entry checking
// [ADD] Pending order placement and management
// [ADD] Manual entry (from control panel)
// [ADD] Entry validation and cooldown checks
// [ADD] Integration with martingale system
//+------------------------------------------------------------------+

#ifndef TG_ENTRY_MANAGER_MQH
#define TG_ENTRY_MANAGER_MQH

#include <Trade/Trade.mqh>
#include "../Core/TG_Definitions.mqh"
#include "../Core/TG_MagicNumbers.mqh"
#include "../Core/TG_StateManager.mqh"
#include "../Core/TG_Logger.mqh"
#include "../Core/TG_ErrorHandler.mqh"
#include "../Utilities/TG_LotCalculation.mqh"
#include "../Utilities/TG_PriceHelpers.mqh"
#include "TG_Martingale_v2.mqh"  // ← FIXED: Use V2 filename!

//+------------------------------------------------------------------+
//| ENTRY MANAGER CLASS                                               |
//+------------------------------------------------------------------+
class CEntryManager
{
private:
   // Core dependencies
   CTrade*                  m_trade;
   CMagicNumberManager*     m_magic_manager;
   CStateManager*           m_state_manager;
   CLogger*                 m_logger;
   CErrorHandler*           m_error_handler;
   CLotCalculator*          m_lot_calculator;
   CPriceHelper*            m_price_helper;
   CMartingaleManagerV2*    m_martingale;
   
   // Settings
   string                   m_symbol;
   ENUM_ENTRY_METHOD        m_entry_method;
   
   // Pending Order settings
   int                      m_po_distance_points;
   bool                     m_po_cancel_on_opposite;
   
   // Manual entry settings
   double                   m_manual_lot_size;
   
   // State tracking
   ulong                    m_po_buy_ticket;
   ulong                    m_po_sell_ticket;
   bool                     m_po_active;
   
   //+------------------------------------------------------------------+
   //| Check if Can Enter Trade                                         |
   //+------------------------------------------------------------------+
   bool CanEnterTrade(string &error_msg)
   {
      // Check if cycle already active
      if(m_state_manager.IsCycleActive())
      {
         error_msg = "Cannot enter - cycle already active";
         return false;
      }
      
      // Check cooldown
      if(!m_state_manager.IsCooldownPassed())
      {
         int remaining = m_state_manager.GetCooldownRemaining();
         error_msg = StringFormat("Cannot enter - cooldown %d seconds remaining", remaining);
         return false;
      }
      
      // Check if martingale stopped
      if(m_state_manager.IsMartingaleStopped())
      {
         error_msg = "Cannot enter - martingale system stopped";
         return false;
      }
      
      error_msg = "Entry checks passed";
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Place Pending Order                                              |
   //+------------------------------------------------------------------+
   bool PlacePendingOrder(ENUM_ORDER_TYPE order_type, 
                          double lot,
                          long magic,
                          string comment,
                          ulong &ticket_out)
   {
      ticket_out = 0;
      
      // Calculate order price
      double price = m_price_helper.CalculatePendingOrderPrice(order_type, m_po_distance_points);
      
      if(price <= 0)
      {
         m_logger.Error("Invalid pending order price calculated");
         return false;
      }
      
      // Validate price distance
      string error_msg;
      double current_price = (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_BUY_LIMIT) ?
                             m_price_helper.GetAsk() : m_price_helper.GetBid();
      
      if(!m_price_helper.CheckStopLevelDistance(price, current_price, error_msg))
      {
         m_logger.Error("Pending order price validation failed: " + error_msg);
         return false;
      }
      
      // Set magic
      m_trade.SetExpertMagicNumber(magic);
      
      // Place order
      bool success = false;
      
      switch(order_type)
      {
         case ORDER_TYPE_BUY_STOP:
            success = m_trade.BuyStop(lot, price, m_symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
            break;
         
         case ORDER_TYPE_BUY_LIMIT:
            success = m_trade.BuyLimit(lot, price, m_symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
            break;
         
         case ORDER_TYPE_SELL_STOP:
            success = m_trade.SellStop(lot, price, m_symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
            break;
         
         case ORDER_TYPE_SELL_LIMIT:
            success = m_trade.SellLimit(lot, price, m_symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
            break;
         
         default:
            m_logger.Error("Invalid order type for pending order");
            return false;
      }
      
      if(success)
      {
         ticket_out = m_trade.ResultOrder();
         m_logger.Info("✅ Pending order placed: " + EnumToString(order_type) + 
                       " @ " + DoubleToString(price, _Digits) + 
                       " Ticket: " + IntegerToString(ticket_out));
         return true;
      }
      else
      {
         uint error_code = m_trade.ResultRetcode();
         ENUM_ERROR_SEVERITY severity = ERROR_SEVERITY_MEDIUM;
         m_error_handler.HandleError(error_code, "PlacePendingOrder", severity);
         return false;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Cancel Pending Order                                             |
   //+------------------------------------------------------------------+
   bool CancelPendingOrder(ulong ticket)
   {
      if(ticket == 0)
         return false;
      
      if(!m_trade.OrderDelete(ticket))
      {
         m_logger.Warning("Failed to cancel pending order: " + IntegerToString(ticket));
         return false;
      }
      
      m_logger.Info("Pending order cancelled: " + IntegerToString(ticket));
      return true;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CEntryManager()
   {
      m_trade = NULL;
      m_magic_manager = NULL;
      m_state_manager = NULL;
      m_logger = NULL;
      m_error_handler = NULL;
      m_lot_calculator = NULL;
      m_price_helper = NULL;
      m_martingale = NULL;
      
      m_symbol = _Symbol;
      m_entry_method = ENTRY_METHOD_MANUAL;
      m_po_distance_points = 500;
      m_po_cancel_on_opposite = true;
      m_manual_lot_size = 0.01;
      
      m_po_buy_ticket = 0;
      m_po_sell_ticket = 0;
      m_po_active = false;
   }
   
   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   bool Initialize(CTrade* trade,
                   CMagicNumberManager* magic_manager,
                   CStateManager* state_manager,
                   CLogger* logger,
                   CErrorHandler* error_handler,
                   CLotCalculator* lot_calculator,
                   CPriceHelper* price_helper,
                   CMartingaleManagerV2* martingale,
                   ENUM_ENTRY_METHOD entry_method,
                   int po_distance_points,
                   bool po_cancel_on_opposite,
                   double manual_lot_size)
   {
      // Validate pointers
      if(trade == NULL || magic_manager == NULL || state_manager == NULL ||
         logger == NULL || error_handler == NULL || lot_calculator == NULL ||
         price_helper == NULL || martingale == NULL)
      {
         Print("❌ Entry Manager: NULL pointer in Initialize");
         return false;
      }
      
      m_trade = trade;
      m_magic_manager = magic_manager;
      m_state_manager = state_manager;
      m_logger = logger;
      m_error_handler = error_handler;
      m_lot_calculator = lot_calculator;
      m_price_helper = price_helper;
      m_martingale = martingale;
      
      m_entry_method = entry_method;
      m_po_distance_points = po_distance_points;
      m_po_cancel_on_opposite = po_cancel_on_opposite;
      m_manual_lot_size = manual_lot_size;
      
      m_logger.LogBoxStart("ENTRY MANAGER INITIALIZED");
      m_logger.Info("Entry Method: " + EnumToString(m_entry_method));
      
      if(m_entry_method == ENTRY_METHOD_PENDING_ORDER)
      {
         m_logger.Info("PO Distance: " + IntegerToString(m_po_distance_points) + " points");
         m_logger.Info("Cancel on Opposite: " + (m_po_cancel_on_opposite ? "Yes" : "No"));
      }
      else if(m_entry_method == ENTRY_METHOD_MANUAL)
      {
         m_logger.Info("Manual Lot: " + DoubleToString(m_manual_lot_size, 2));
      }
      
      m_logger.LogBoxEnd();
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Place Initial Pending Orders (OCO Style)                         |
   //+------------------------------------------------------------------+
   bool PlaceInitialPendingOrders()
   {
      if(m_entry_method != ENTRY_METHOD_PENDING_ORDER)
      {
         m_logger.Warning("Cannot place pending orders - entry method is not PENDING_ORDER");
         return false;
      }
      
      // Check if can enter
      string error_msg;
      if(!CanEnterTrade(error_msg))
      {
         m_logger.Warning(error_msg);
         return false;
      }
      
      // Calculate lot
      double lot = m_lot_calculator.CalculateInitialLot();
      
      // Get magic numbers
      long buy_magic = m_magic_manager.GetMartingaleBuyMagic(1);
      long sell_magic = m_magic_manager.GetMartingaleSellMagic(1);
      
      // Place BUY STOP above current price
      ulong buy_ticket;
      if(!PlacePendingOrder(ORDER_TYPE_BUY_STOP, lot, buy_magic, 
                            "PO BUY L1", buy_ticket))
      {
         m_logger.Error("Failed to place BUY pending order");
         return false;
      }
      
      // Place SELL STOP below current price
      ulong sell_ticket;
      if(!PlacePendingOrder(ORDER_TYPE_SELL_STOP, lot, sell_magic, 
                            "PO SELL L1", sell_ticket))
      {
         m_logger.Error("Failed to place SELL pending order");
         CancelPendingOrder(buy_ticket); // Cleanup
         return false;
      }
      
      // Store tickets
      m_po_buy_ticket = buy_ticket;
      m_po_sell_ticket = sell_ticket;
      m_po_active = true;
      
      // Update state manager
      m_state_manager.SetPendingOrders(buy_ticket, sell_ticket);
      
      m_logger.Info("✅ Initial pending orders placed (OCO style)");
      m_logger.Info("   BUY STOP: " + IntegerToString(buy_ticket));
      m_logger.Info("   SELL STOP: " + IntegerToString(sell_ticket));
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Check Pending Order Activation                                   |
   //+------------------------------------------------------------------+
   void CheckPendingOrderActivation()
   {
      if(!m_po_active)
         return;
      
      // Check if any order was activated (became a position)
      bool buy_activated = false;
      bool sell_activated = false;
      
      // Check BUY order
      if(m_po_buy_ticket > 0)
      {
         if(!OrderSelect(m_po_buy_ticket))
         {
            // Order not found - either executed or deleted
            if(PositionSelectByTicket(m_po_buy_ticket))
            {
               buy_activated = true;
               m_logger.Info("🎯 BUY pending order activated!");
            }
         }
      }
      
      // Check SELL order
      if(m_po_sell_ticket > 0)
      {
         if(!OrderSelect(m_po_sell_ticket))
         {
            // Order not found - either executed or deleted
            if(PositionSelectByTicket(m_po_sell_ticket))
            {
               sell_activated = true;
               m_logger.Info("🎯 SELL pending order activated!");
            }
         }
      }
      
      // Handle activation
      if(buy_activated)
      {
         m_logger.Info("BUY cycle started via pending order");
         
         // 🚀 FIX: Call Martingale.StartBuyCycle() instead of StateManager directly!
         if(m_martingale.StartBuyCycle())
         {
            m_logger.Info("✅ Martingale BUY cycle started successfully");
         }
         else
         {
            m_logger.Error("❌ Martingale BUY cycle failed to start!");
         }
         
         // Cancel opposite order if enabled
         if(m_po_cancel_on_opposite && m_po_sell_ticket > 0)
         {
            CancelPendingOrder(m_po_sell_ticket);
            m_po_sell_ticket = 0;
         }
         
         m_po_buy_ticket = 0;
         m_po_active = false;
         m_state_manager.ClearPendingOrders();
      }
      else if(sell_activated)
      {
         m_logger.Info("SELL cycle started via pending order");
         
         // 🚀 FIX: Call Martingale.StartSellCycle() instead of StateManager directly!
         if(m_martingale.StartSellCycle())
         {
            m_logger.Info("✅ Martingale SELL cycle started successfully");
         }
         else
         {
            m_logger.Error("❌ Martingale SELL cycle failed to start!");
         }
         
         // Cancel opposite order if enabled
         if(m_po_cancel_on_opposite && m_po_buy_ticket > 0)
         {
            CancelPendingOrder(m_po_buy_ticket);
            m_po_buy_ticket = 0;
         }
         
         m_po_sell_ticket = 0;
         m_po_active = false;
         m_state_manager.ClearPendingOrders();
      }
   }
   
   //+------------------------------------------------------------------+
   //| Cancel All Pending Orders                                        |
   //+------------------------------------------------------------------+
   void CancelAllPendingOrders()
   {
      if(m_po_buy_ticket > 0)
      {
         CancelPendingOrder(m_po_buy_ticket);
         m_po_buy_ticket = 0;
      }
      
      if(m_po_sell_ticket > 0)
      {
         CancelPendingOrder(m_po_sell_ticket);
         m_po_sell_ticket = 0;
      }
      
      m_po_active = false;
      m_state_manager.ClearPendingOrders();
   }
   
   //+------------------------------------------------------------------+
   //| Manual Entry - BUY                                               |
   //+------------------------------------------------------------------+
   bool ManualEntryBuy()
   {
      m_logger.Info("📊 Manual BUY entry requested");
      
      // Check if can enter
      string error_msg;
      if(!CanEnterTrade(error_msg))
      {
         m_logger.Warning(error_msg);
         return false;
      }
      
      // Start BUY cycle via martingale system
      if(m_martingale.StartBuyCycle())
      {
         m_logger.Info("✅ Manual BUY entry successful");
         return true;
      }
      else
      {
         m_logger.Error("❌ Manual BUY entry failed");
         return false;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Manual Entry - SELL                                              |
   //+------------------------------------------------------------------+
   bool ManualEntrySell()
   {
      m_logger.Info("📊 Manual SELL entry requested");
      
      // Check if can enter
      string error_msg;
      if(!CanEnterTrade(error_msg))
      {
         m_logger.Warning(error_msg);
         return false;
      }
      
      // Start SELL cycle via martingale system
      if(m_martingale.StartSellCycle())
      {
         m_logger.Info("✅ Manual SELL entry successful");
         return true;
      }
      else
      {
         m_logger.Error("❌ Manual SELL entry failed");
         return false;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check Signal Entry (Placeholder - will be expanded in Phase 5)  |
   //+------------------------------------------------------------------+
   ENUM_SIGNAL_TYPE CheckSignalEntry()
   {
      // This will be implemented in Phase 5 with Ichimoku integration
      // For now, return no signal
      
      if(m_entry_method != ENTRY_METHOD_SIGNAL)
         return SIGNAL_NONE;
      
      // TODO Phase 5: Check Ichimoku signals
      // - Tenkan/Kijun cross
      // - Price vs Kumo
      // - Chikou span confirmation
      // - etc.
      
      return SIGNAL_NONE;
   }
   
   //+------------------------------------------------------------------+
   //| Process Signal Entry                                             |
   //+------------------------------------------------------------------+
   void ProcessSignalEntry()
   {
      if(m_entry_method != ENTRY_METHOD_SIGNAL)
         return;
      
      ENUM_SIGNAL_TYPE signal = CheckSignalEntry();
      
      if(signal == SIGNAL_BUY)
      {
         m_logger.Info("🎯 BUY signal detected");
         ManualEntryBuy();
      }
      else if(signal == SIGNAL_SELL)
      {
         m_logger.Info("🎯 SELL signal detected");
         ManualEntrySell();
      }
   }
   
   //+------------------------------------------------------------------+
   //| Process Entry Logic (Main OnTick Handler)                        |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      // Handle based on entry method
      switch(m_entry_method)
      {
         case ENTRY_METHOD_PENDING_ORDER:
            // Check if pending orders need to be placed
            if(!m_po_active && !m_state_manager.IsCycleActive())
            {
               PlaceInitialPendingOrders();
            }
            
            // Check for activation
            CheckPendingOrderActivation();
            break;
         
         case ENTRY_METHOD_SIGNAL:
            // Process signal-based entry
            if(!m_state_manager.IsCycleActive())
            {
               ProcessSignalEntry();
            }
            break;
         
         case ENTRY_METHOD_MANUAL:
            // Manual entries are handled via control panel
            // No automatic action needed here
            break;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get Active Pending Orders Info                                   |
   //+------------------------------------------------------------------+
   void GetPendingOrdersInfo(ulong &buy_ticket, ulong &sell_ticket, bool &active)
   {
      buy_ticket = m_po_buy_ticket;
      sell_ticket = m_po_sell_ticket;
      active = m_po_active;
   }
   
   //+------------------------------------------------------------------+
   //| GETTERS                                                           |
   //+------------------------------------------------------------------+
   ENUM_ENTRY_METHOD GetEntryMethod() { return m_entry_method; }
   bool IsPendingOrderActive() { return m_po_active; }
};

//+------------------------------------------------------------------+
//| End of TG_EntryManager.mqh                                       |
//+------------------------------------------------------------------+
#endif // TG_ENTRY_MANAGER_MQH
