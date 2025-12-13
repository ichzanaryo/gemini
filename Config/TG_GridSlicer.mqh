//+------------------------------------------------------------------+
//|                          Systems/TG_GridSlicer.mqh               |
//|                                          Titan Grid EA v1.0      |
//|                    GridSlicer Recovery System                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.00"

#ifndef TG_GRIDSLICER_MQH
#define TG_GRIDSLICER_MQH

#include <Trade/Trade.mqh>
#include "../Core/TG_Definitions.mqh"
#include "../Core/TG_MagicNumbers.mqh"
#include "../Core/TG_StateManager.mqh"
#include "../Core/TG_Logger.mqh"
#include "../Core/TG_ErrorHandler.mqh"
#include "../Utilities/TG_PositionScanner.mqh"
#include "../Utilities/TG_LotCalculation.mqh"
#include "../Utilities/TG_PriceHelpers.mqh"
#include "../Config/TG_Inputs_GridSlicer.mqh"

//+------------------------------------------------------------------+
//| GRIDSLICER PENDING ORDER INFO                                     |
//+------------------------------------------------------------------+
struct SGridSlicerOrder
{
   ulong    ticket;
   int      po_id;              // Unique PO ID (layer * 100 + po_index)
   int      target_layer;       // Target layer untuk recovery
   int      po_index;           // Index PO dalam gap (1-based)
   double   lot;
   double   price;
   double   tp_price;
   double   sl_price;
   datetime placed_time;
   
   void Reset()
   {
      ticket = 0;
      po_id = 0;
      target_layer = 0;
      po_index = 0;
      lot = 0.0;
      price = 0.0;
      tp_price = 0.0;
      sl_price = 0.0;
      placed_time = 0;
   }
};

//+------------------------------------------------------------------+
//| GRIDSLICER CLASS                                                  |
//+------------------------------------------------------------------+
class CGridSlicerSystem
{
private:
   CTrade*              m_trade;
   CMagicNumberManager* m_magic;
   CStateManager*       m_state_manager;
   CLogger*             m_logger;
   CErrorHandler*       m_error_handler;
   CPositionScanner*    m_scanner;
   CLotCalculator*      m_lot_calculator;
   CPriceHelper*        m_price_helper;
   
   long                 m_magic_number;  // Changed to long to match magic manager
   
   // Layer price tracking
   double               m_layer_prices[16];  // Index 1-15 for layer 1-15
   
   // Active orders tracking
   SGridSlicerOrder     m_active_orders[50]; // Max 50 active GS orders
   int                  m_active_order_count;
   
   // Statistics
   int                  m_total_activations;
   int                  m_successful_recoveries;
   double               m_total_profit;
   
   //+------------------------------------------------------------------+
   //| Get Current Martingale Direction                                 |
   //+------------------------------------------------------------------+
   ENUM_POSITION_TYPE GetMartingaleDirection()
   {
      if(m_state_manager == NULL)
         return POSITION_TYPE_BUY;
      
      ENUM_MARTINGALE_MODE mode = m_state_manager.GetCurrentMode();
      return (mode == MODE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Base Lot from Martingale L1                            |
   //+------------------------------------------------------------------+
   double CalculateBaseLot()
   {
      ENUM_POSITION_TYPE direction = GetMartingaleDirection();
      
      // Get first martingale layer lot
      double l1_lot = 0.0;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         
         long magic = PositionGetInteger(POSITION_MAGIC);
         if(m_magic.IsMartingale(magic) &&
            PositionGetInteger(POSITION_TYPE) == direction)
         {
            double lot = PositionGetDouble(POSITION_VOLUME);
            if(l1_lot == 0.0 || lot < l1_lot)
               l1_lot = lot;
         }
      }
      
      if(l1_lot <= 0.0)
      {
         if(m_logger != NULL)
            m_logger.Warning("GridSlicer: No Martingale L1 found, using default 0.01");
         return 0.01;
      }
      
      double base_lot = l1_lot * InpGS_L1LotMultiplier;
      
      // Normalize lot manually (NormalizeLot is private)
      double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      
      if(lot_step > 0)
         base_lot = MathRound(base_lot / lot_step) * lot_step;
      
      base_lot = MathMax(min_lot, MathMin(max_lot, base_lot));
      
      return NormalizeDouble(base_lot, 2);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Strategic Lot (Phase 4A: Progressive only)             |
   //+------------------------------------------------------------------+
   double CalculateStrategicLot(int target_layer, double base_lot)
   {
      double calculated_lot = base_lot;
      
      switch(InpGS_LotStrategy)
      {
         case GS_LOT_FLAT:
            calculated_lot = base_lot;
            break;
         
         case GS_LOT_PROGRESSIVE:
            // +20% per layer
            calculated_lot = base_lot * (1.0 + (target_layer - 1) * 0.2);
            break;
         
         case GS_LOT_AGGRESSIVE:
            // Exponential 1.35x
            calculated_lot = base_lot * MathPow(1.35, target_layer - 1);
            break;
         
         case GS_LOT_CONSERVATIVE:
            // +15% per layer
            calculated_lot = base_lot * (1.0 + (target_layer - 1) * 0.15);
            break;
         
         case GS_LOT_GAP_BASED:
         case GS_LOT_PYRAMID:
            // Phase 4B features
            calculated_lot = base_lot * (1.0 + (target_layer - 1) * 0.2);
            break;
      }
      
      // Add lot increment
      calculated_lot += InpGS_LotAddValue;
      
      // Normalize and cap
      double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      
      if(lot_step > 0)
         calculated_lot = MathRound(calculated_lot / lot_step) * lot_step;
      
      calculated_lot = MathMax(min_lot, MathMin(max_lot, calculated_lot));
      calculated_lot = NormalizeDouble(calculated_lot, 2);
         
      return MathMin(calculated_lot, InpGS_MaxLot);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Recovery Target Price                                  |
   //+------------------------------------------------------------------+
   double CalculateRecoveryTarget(int target_layer, ENUM_POSITION_TYPE direction)
   {
      double target_price = m_layer_prices[target_layer];
      if(target_price <= 0.0)
         return 0.0;
      
      switch(InpGS_TargetStrategy)
      {
         case GS_TARGET_BREAKEVEN:
            // Simple: target = layer price
            return target_price;
         
         case GS_TARGET_PARTIAL:
         case GS_TARGET_FULL:
         case GS_TARGET_DYNAMIC:
         case GS_TARGET_AGGRESSIVE:
            // Phase 4B features - for now use breakeven
            return target_price;
      }
      
      return target_price;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate PO Price in Gap                                        |
   //+------------------------------------------------------------------+
   double CalculatePOPrice(double target_price, double deeper_price, 
                          ENUM_POSITION_TYPE direction, double percent)
   {
      double gap = MathAbs(target_price - deeper_price);
      double distance = gap * (percent / 100.0);
      
      double po_price;
      
      if(direction == POSITION_TYPE_BUY)
      {
         // BUY: deeper is below target
         // PO should be ABOVE deeper price
         po_price = deeper_price + distance;
      }
      else // SELL
      {
         // SELL: deeper is above target
         // PO should be BELOW deeper price
         po_price = deeper_price - distance;
      }
      
      return NormalizeDouble(po_price, _Digits);
   }
   
   //+------------------------------------------------------------------+
   //| Validate PO Price                                                |
   //+------------------------------------------------------------------+
   bool ValidatePOPrice(double po_price, double target_price, double deeper_price,
                       ENUM_POSITION_TYPE direction)
   {
      if(po_price <= 0.0)
         return false;
      
      if(direction == POSITION_TYPE_BUY)
      {
         // BUY: deeper < PO < target
         if(po_price <= deeper_price || po_price >= target_price)
         {
            if(m_logger != NULL)
               m_logger.Error(StringFormat("Invalid BUY PO price: %.5f not between %.5f and %.5f",
                             po_price, deeper_price, target_price));
            return false;
         }
      }
      else // SELL
      {
         // SELL: target < PO < deeper
         if(po_price <= target_price || po_price >= deeper_price)
         {
            if(m_logger != NULL)
               m_logger.Error(StringFormat("Invalid SELL PO price: %.5f not between %.5f and %.5f",
                             po_price, target_price, deeper_price));
            return false;
         }
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Place GridSlicer Order (CORRECT DIRECTION!)                      |
   //+------------------------------------------------------------------+
   ulong PlaceGridSlicerOrder(int po_id, int target_layer, int po_index,
                             ENUM_POSITION_TYPE direction, double lot,
                             double po_price, double tp_price)
   {
      if(m_trade == NULL || m_magic == NULL)
         return 0;
      
      // Determine ORDER TYPE based on Martingale direction
      // CRITICAL: BUY Martingale → BUY STOP (SEARAH!)
      //          SELL Martingale → SELL STOP (SEARAH!)
      ENUM_ORDER_TYPE order_type = (direction == POSITION_TYPE_BUY) ? 
                                   ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP;
      
      // Validate price levels
      double current_price = (direction == POSITION_TYPE_BUY) ? 
                            SymbolInfoDouble(_Symbol, SYMBOL_ASK) :
                            SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      // For BUY STOP: price must be ABOVE current
      // For SELL STOP: price must be BELOW current
      if(direction == POSITION_TYPE_BUY && po_price <= current_price)
      {
         if(m_logger != NULL)
            m_logger.Error(StringFormat("BUY STOP price %.5f must be above current %.5f",
                          po_price, current_price));
         return 0;
      }
      
      if(direction == POSITION_TYPE_SELL && po_price >= current_price)
      {
         if(m_logger != NULL)
            m_logger.Error(StringFormat("SELL STOP price %.5f must be below current %.5f",
                          po_price, current_price));
         return 0;
      }
      
      // Calculate SL (optional)
      double sl_price = 0.0;
      if(InpGS_SLMultiplier > 0.0 && m_price_helper != NULL)
      {
         // Use public method CalculateATRGridDistance (it uses ATR internally)
         double atr_distance = m_price_helper.CalculateATRGridDistance(InpGS_SLMultiplier, 100, 1000);
         
         if(direction == POSITION_TYPE_BUY)
            sl_price = po_price - atr_distance;
         else
            sl_price = po_price + atr_distance;
         
         sl_price = NormalizeDouble(sl_price, _Digits);
      }
      
      // Build comment
      string comment = StringFormat("GS-%s-L%d-PO%d",
                                   (direction == POSITION_TYPE_BUY) ? "BUY" : "SELL",
                                   target_layer, po_index);
      
      // Set magic number
      m_trade.SetExpertMagicNumber(m_magic_number);
      
      // Place order
      bool result = false;
      if(direction == POSITION_TYPE_BUY)
      {
         result = m_trade.BuyStop(lot, po_price, _Symbol, sl_price, tp_price, 
                                 ORDER_TIME_GTC, 0, comment);
      }
      else
      {
         result = m_trade.SellStop(lot, po_price, _Symbol, sl_price, tp_price,
                                  ORDER_TIME_GTC, 0, comment);
      }
      
      if(!result)
      {
         if(m_logger != NULL)
            m_logger.Error(StringFormat("Failed to place %s order: %d - %s",
                          EnumToString(order_type), m_trade.ResultRetcode(),
                          m_trade.ResultRetcodeDescription()));
         return 0;
      }
      
      ulong ticket = m_trade.ResultOrder();
      
      if(m_logger != NULL)
         m_logger.Info(StringFormat("GridSlicer %s placed: Ticket=%I64u, Lot=%.2f, Price=%.5f, TP=%.5f",
                      EnumToString(order_type), ticket, lot, po_price, tp_price));
      
      // Track order
      if(m_active_order_count < 50)
      {
         m_active_orders[m_active_order_count].ticket = ticket;
         m_active_orders[m_active_order_count].po_id = po_id;
         m_active_orders[m_active_order_count].target_layer = target_layer;
         m_active_orders[m_active_order_count].po_index = po_index;
         m_active_orders[m_active_order_count].lot = lot;
         m_active_orders[m_active_order_count].price = po_price;
         m_active_orders[m_active_order_count].tp_price = tp_price;
         m_active_orders[m_active_order_count].sl_price = sl_price;
         m_active_orders[m_active_order_count].placed_time = TimeCurrent();
         m_active_order_count++;
      }
      
      return ticket;
   }
   
   //+------------------------------------------------------------------+
   //| Check if PO Already Exists                                       |
   //+------------------------------------------------------------------+
   bool POAlreadyExists(int po_id)
   {
      // Check active orders array
      for(int i = 0; i < m_active_order_count; i++)
      {
         if(m_active_orders[i].po_id == po_id)
            return true;
      }
      
      // Check actual pending orders
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(!OrderSelect(ticket))
            continue;
         
         if(OrderGetInteger(ORDER_MAGIC) != m_magic_number)
            continue;
         
         string comment = OrderGetString(ORDER_COMMENT);
         if(StringFind(comment, StringFormat("L%d-PO", po_id / 100)) >= 0)
            return true;
      }
      
      return false;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CGridSlicerSystem()
   {
      m_trade = NULL;
      m_magic = NULL;
      m_state_manager = NULL;
      m_logger = NULL;
      m_error_handler = NULL;
      m_scanner = NULL;
      m_lot_calculator = NULL;
      m_price_helper = NULL;
      
      m_magic_number = 0;
      
      ArrayInitialize(m_layer_prices, 0.0);
      
      // Initialize struct array manually
      for(int i = 0; i < 50; i++)
         m_active_orders[i].Reset();
      
      m_active_order_count = 0;
      
      m_total_activations = 0;
      m_successful_recoveries = 0;
      m_total_profit = 0.0;
   }
   
   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   bool Initialize(CTrade* trade,
                   CMagicNumberManager* magic,
                   CStateManager* state_mgr,
                   CLogger* logger,
                   CErrorHandler* error_handler,
                   CPositionScanner* scanner,
                   CLotCalculator* lot_calc,
                   CPriceHelper* price_helper)
   {
      if(trade == NULL || magic == NULL || state_mgr == NULL || logger == NULL)
      {
         Print("GridSlicer: NULL pointer in Initialize");
         return false;
      }
      
      m_trade = trade;
      m_magic = magic;
      m_state_manager = state_mgr;
      m_logger = logger;
      m_error_handler = error_handler;
      m_scanner = scanner;
      m_lot_calculator = lot_calc;
      m_price_helper = price_helper;
      
      m_magic_number = m_magic.GetGridSlicerMagic(0); // Both are long now
      
      if(m_logger != NULL)
         m_logger.Info("GridSlicer System initialized");
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Update Layer Prices from Martingale Positions                    |
   //+------------------------------------------------------------------+
   void UpdateLayerPrices()
   {
      ArrayInitialize(m_layer_prices, 0.0);
      
      ENUM_POSITION_TYPE direction = GetMartingaleDirection();
      
      // Collect all Martingale position prices
      double prices[];
      ArrayResize(prices, 0);
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         
         long magic = PositionGetInteger(POSITION_MAGIC);
         if(m_magic.IsMartingale(magic) &&
            PositionGetInteger(POSITION_TYPE) == direction)
         {
            double price = PositionGetDouble(POSITION_PRICE_OPEN);
            int size = ArraySize(prices);
            ArrayResize(prices, size + 1);
            prices[size] = price;
         }
      }
      
      if(ArraySize(prices) == 0)
         return;
      
      // Sort prices (ascending for BUY, descending for SELL)
      ArraySort(prices);
      
      if(direction == POSITION_TYPE_SELL)
         ArrayReverse(prices); // Reverse for SELL
      
      // Store in layer array
      for(int i = 0; i < ArraySize(prices) && i < 15; i++)
      {
         m_layer_prices[i + 1] = prices[i];
      }
      
      if(m_logger != NULL)
      {
         string log = StringFormat("GridSlicer: Updated %d layer prices for %s",
                                  ArraySize(prices),
                                  (direction == POSITION_TYPE_BUY) ? "BUY" : "SELL");
         m_logger.Debug(log);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get Current Layer Count                                          |
   //+------------------------------------------------------------------+
   int GetCurrentLayerCount()
   {
      int count = 0;
      for(int i = 1; i <= 15; i++)
      {
         if(m_layer_prices[i] > 0.0)
            count++;
         else
            break;
      }
      return count;
   }
   
   //+------------------------------------------------------------------+
   //| Main GridSlicer Management                                       |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      if(!InpGS_Enable)
      {
         if(m_logger != NULL)
            m_logger.Debug("GridSlicer: Disabled (InpGS_Enable = false)");
         return;
      }
      
      if(m_state_manager == NULL || !m_state_manager.IsCycleActive())
      {
         if(m_logger != NULL)
            m_logger.Debug("GridSlicer: No active cycle");
         return;
      }
      
      // Update layer prices
      UpdateLayerPrices();
      
      int current_layers = GetCurrentLayerCount();
      
      if(m_logger != NULL)
         m_logger.Info(StringFormat("GridSlicer: Current layers = %d, Required = %d", 
                                   current_layers, InpGS_StartLayer));
      
      if(current_layers < InpGS_StartLayer)
      {
         // Not enough layers yet
         if(m_logger != NULL)
            m_logger.Info(StringFormat("GridSlicer: Waiting for %d layers (current: %d)", 
                                      InpGS_StartLayer, current_layers));
         return;
      }
      
      ENUM_POSITION_TYPE direction = GetMartingaleDirection();
      double base_lot = CalculateBaseLot();
      double percent = InpGS_BaseDistancePercent; // Phase 4A: fixed percentage
      
      if(m_logger != NULL)
         m_logger.Info(StringFormat("GridSlicer: Processing %d gaps, Direction=%s, BaseLot=%.2f", 
                                   current_layers - 1, 
                                   (direction == POSITION_TYPE_BUY) ? "BUY" : "SELL",
                                   base_lot));
      
      // Process each gap between layers
      for(int target_layer = 1; target_layer < current_layers; target_layer++)
      {
         int deeper_layer = target_layer + 1;
         
         double target_price = m_layer_prices[target_layer];
         double deeper_price = m_layer_prices[deeper_layer];
         
         if(m_logger != NULL)
            m_logger.Debug(StringFormat("GridSlicer: Gap L%d-L%d: Target=%.5f, Deeper=%.5f", 
                                       target_layer, deeper_layer, target_price, deeper_price));
         
         if(target_price <= 0.0 || deeper_price <= 0.0)
         {
            if(m_logger != NULL)
               m_logger.Warning(StringFormat("GridSlicer: Invalid prices for L%d-L%d", 
                                            target_layer, deeper_layer));
            continue;
         }
         
         // Calculate PO ID
         int po_id = (target_layer * 100) + 1; // Phase 4A: only 1 PO per gap
         
         // Check if already exists
         if(POAlreadyExists(po_id))
         {
            if(m_logger != NULL)
               m_logger.Debug(StringFormat("GridSlicer: PO %d already exists, skipping", po_id));
            continue;
         }
         
         // Calculate PO price
         double po_price = CalculatePOPrice(target_price, deeper_price, direction, percent);
         
         if(m_logger != NULL)
            m_logger.Info(StringFormat("GridSlicer: Calculated PO price for L%d: %.5f (%.1f%% of gap)", 
                                      target_layer, po_price, percent));
         
         // Validate
         if(!ValidatePOPrice(po_price, target_price, deeper_price, direction))
         {
            if(m_logger != NULL)
               m_logger.Error(StringFormat("GridSlicer: PO price %.5f validation FAILED for L%d", 
                                          po_price, target_layer));
            continue;
         }
         
         // Calculate lot
         double lot = CalculateStrategicLot(target_layer, base_lot);
         
         // Calculate TP
         double tp_price = CalculateRecoveryTarget(target_layer, direction);
         
         if(m_logger != NULL)
            m_logger.Info(StringFormat("GridSlicer: Placing order L%d: Price=%.5f, Lot=%.2f, TP=%.5f", 
                                      target_layer, po_price, lot, tp_price));
         
         // Place order
         ulong ticket = PlaceGridSlicerOrder(po_id, target_layer, 1, direction,
                                            lot, po_price, tp_price);
         
         if(ticket > 0)
         {
            m_total_activations++;
            if(m_logger != NULL)
               m_logger.Info(StringFormat("GridSlicer: ✅ Order placed successfully! Ticket=%I64u", ticket));
         }
         else
         {
            if(m_logger != NULL)
               m_logger.Error(StringFormat("GridSlicer: ❌ Failed to place order for L%d", target_layer));
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Cancel All GridSlicer Orders                                     |
   //+------------------------------------------------------------------+
   void CancelAllOrders()
   {
      int cancelled = 0;
      
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(!OrderSelect(ticket))
            continue;
         
         if(OrderGetInteger(ORDER_MAGIC) == m_magic_number)
         {
            if(m_trade.OrderDelete(ticket))
               cancelled++;
         }
      }
      
      if(cancelled > 0 && m_logger != NULL)
         m_logger.Info(StringFormat("GridSlicer: Cancelled %d orders", cancelled));
      
      // Clear tracking
      for(int i = 0; i < 50; i++)
         m_active_orders[i].Reset();
      
      m_active_order_count = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Get Statistics                                                    |
   //+------------------------------------------------------------------+
   int GetTotalActivations() const { return m_total_activations; }
   int GetSuccessfulRecoveries() const { return m_successful_recoveries; }
   double GetTotalProfit() const { return m_total_profit; }
   int GetActiveOrderCount() const { return m_active_order_count; }
};

//+------------------------------------------------------------------+
//| End of TG_GridSlicer.mqh                                         |
//+------------------------------------------------------------------+
#endif
