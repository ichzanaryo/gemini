//+------------------------------------------------------------------+
//|                                    Systems/TG_Martingale.mqh     |
//|                                          Titan Grid EA v1.0      |
//|                          Martingale Trading System               |
//+------------------------------------------------------------------+
//| Location: C:\Users\ichza\AppData\Roaming\MetaQuotes\Terminal\   |
//|           D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\         |
//|           TitanGridEA\Systems\TG_Martingale.mqh                  |
//|                                                                  |
//| Purpose:  Core martingale trading logic                         |
//|           Layer management, cycle control                       |
//|           Take profit monitoring, position tracking             |
//|           Dependencies: All core utilities                       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.00"

//+------------------------------------------------------------------+
//| CHANGE LOG                                                        |
//+------------------------------------------------------------------+
// Version 1.00 - 2025-01-20
// [INITIAL] Martingale system created
// [ADD] Start cycle (BUY/SELL)
// [ADD] Add layer logic
// [ADD] Check cycle TP
// [ADD] Close cycle
// [ADD] Layer progression
// [ADD] Safety checks (max layers, drawdown)
//+------------------------------------------------------------------+

#ifndef TG_MARTINGALE_MQH
#define TG_MARTINGALE_MQH

#include <Trade/Trade.mqh>
#include "../Core/TG_Definitions.mqh"
#include "../Core/TG_MagicNumbers.mqh"
#include "../Core/TG_StateManager.mqh"
#include "../Core/TG_Logger.mqh"
#include "../Core/TG_ErrorHandler.mqh"
#include "../Utilities/TG_PositionScanner.mqh"
#include "../Utilities/TG_LotCalculation.mqh"
#include "../Utilities/TG_PriceHelpers.mqh"

//+------------------------------------------------------------------+
//| MARTINGALE SYSTEM CLASS                                           |
//+------------------------------------------------------------------+
class CMartingaleSystem
{
private:
   // Core dependencies
   CTrade*                  m_trade;
   CMagicNumberManager*     m_magic_manager;
   CStateManager*           m_state_manager;
   CLogger*                 m_logger;
   CErrorHandler*           m_error_handler;
   CPositionScanner*        m_scanner;
   CLotCalculator*          m_lot_calculator;
   CPriceHelper*            m_price_helper;
   
   // Settings
   string                   m_symbol;
   int                      m_max_layers;
   ENUM_GRID_MODE           m_grid_mode;
   int                      m_fixed_grid_points;
   double                   m_atr_multiplier;
   int                      m_atr_min_points;
   int                      m_atr_max_points;
   bool                     m_use_progressive_grid;
   double                   m_grid_multiplier;
   
   bool                     m_use_cycle_tp;
   double                   m_cycle_tp_amount;
   bool                     m_use_tp_points;
   int                      m_tp_points;
   
   bool                     m_use_max_drawdown_stop;
   double                   m_max_drawdown;
   bool                     m_use_max_layer_stop;
   int                      m_stop_at_layer;
   
   double                   m_max_lot_per_position;
   double                   m_max_total_lot;
   
   // State tracking
   double                   m_last_buy_price;
   double                   m_last_sell_price;
   
   //+------------------------------------------------------------------+
   //| Calculate Grid Distance                                          |
   //+------------------------------------------------------------------+
   double CalculateGridDistance(int layer)
   {
      double base_distance;
      
      // Get base distance based on mode
      if(m_grid_mode == GRID_MODE_FIXED)
      {
         base_distance = m_price_helper.CalculateFixedGridDistance(m_fixed_grid_points);
      }
      else if(m_grid_mode == GRID_MODE_ADAPTIVE_ATR)
      {
         base_distance = m_price_helper.CalculateATRGridDistance(
            m_atr_multiplier,
            m_atr_min_points,
            m_atr_max_points
         );
      }
      else
      {
         base_distance = m_price_helper.CalculateFixedGridDistance(m_fixed_grid_points);
      }
      
      // Apply progressive multiplier if enabled
      if(m_use_progressive_grid && layer > 1)
      {
         base_distance = m_price_helper.CalculateProgressiveGridDistance(
            base_distance,
            layer,
            m_grid_multiplier
         );
      }
      
      return base_distance;
   }
   
   //+------------------------------------------------------------------+
   //| Check if Can Add Layer                                           |
   //+------------------------------------------------------------------+
   bool CanAddLayer(int next_layer, string &error_msg)
   {
      // Check max layers
      if(next_layer > m_max_layers)
      {
         error_msg = StringFormat("Cannot add L%d - exceeds max layers %d",
                                   next_layer, m_max_layers);
         return false;
      }
      
      // Check stop at layer
      if(m_use_max_layer_stop && next_layer > m_stop_at_layer)
      {
         error_msg = StringFormat("Cannot add L%d - stop at layer %d enabled",
                                   next_layer, m_stop_at_layer);
         return false;
      }
      
      // Check drawdown limit
      if(m_use_max_drawdown_stop)
      {
         SPositionSummary summary = m_scanner.GetSummary();
         double current_drawdown = summary.GetMartingaleNetPL();
         
         if(current_drawdown < -m_max_drawdown)
         {
            error_msg = StringFormat("Cannot add layer - drawdown $%.2f exceeds limit $%.2f",
                                      -current_drawdown, m_max_drawdown);
            return false;
         }
      }
      
      // Check total lot limit
      if(m_max_total_lot > 0)
      {
         SPositionSummary summary = m_scanner.GetSummary();
         double current_total_lot = summary.mart_buy_lots + summary.mart_sell_lots;
         
         // Calculate next layer lot
         double prev_lot = m_lot_calculator.CalculateInitialLot();
         if(next_layer > 1)
         {
            // Get last position lot (simplified - should get from scanner)
            prev_lot = current_total_lot / (next_layer - 1);
         }
         
         double next_lot = m_lot_calculator.CalculateNextLayerLot(prev_lot, next_layer);
         
         string check_msg;
         if(!m_lot_calculator.CheckTotalLotLimit(current_total_lot, next_lot, 
                                                   m_max_total_lot, check_msg))
         {
            error_msg = check_msg;
            return false;
         }
      }
      
      error_msg = "Can add layer";
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Execute Trade                                                     |
   //+------------------------------------------------------------------+
   bool ExecuteTrade(ENUM_ORDER_TYPE order_type,
                     double lot,
                     long magic,
                     string comment,
                     ulong &ticket_out)
   {
      ticket_out = 0;
      
      // Validate lot
      string error_msg;
      if(!m_lot_calculator.ValidateLot(lot, error_msg))
      {
         m_logger.Error("Lot validation failed: " + error_msg);
         return false;
      }
      
      // Check margin
      if(!m_lot_calculator.CheckMarginRequirement(lot, order_type, error_msg))
      {
         m_logger.Error("Margin check failed: " + error_msg);
         return false;
      }
      
      // Get price
      double price = (order_type == ORDER_TYPE_BUY) ? 
                     m_price_helper.GetAsk() : 
                     m_price_helper.GetBid();
      
      // Calculate SL/TP
      double sl = 0;
      double tp = 0;
      
      if(m_use_tp_points && m_tp_points > 0)
      {
         ENUM_POSITION_TYPE pos_type = (order_type == ORDER_TYPE_BUY) ? 
                                        POSITION_TYPE_BUY : POSITION_TYPE_SELL;
         tp = m_price_helper.CalculateTPPrice(pos_type, price, m_tp_points);
      }
      
      // Set magic and comment
      m_trade.SetExpertMagicNumber(magic);
      
      // Execute trade
      bool success = false;
      
      if(order_type == ORDER_TYPE_BUY)
      {
         success = m_trade.Buy(lot, m_symbol, price, sl, tp, comment);
      }
      else if(order_type == ORDER_TYPE_SELL)
      {
         success = m_trade.Sell(lot, m_symbol, price, sl, tp, comment);
      }
      
      if(success)
      {
         ticket_out = m_trade.ResultOrder();
         m_logger.LogTrade("OPEN", order_type, lot, price, ticket_out, true, comment);
         return true;
      }
      else
      {
         uint error_code = m_trade.ResultRetcode();
         ENUM_ERROR_SEVERITY severity = ERROR_SEVERITY_MEDIUM;
         m_error_handler.HandleError(error_code, "ExecuteTrade", severity);
         return false;
      }
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CMartingaleSystem()
   {
      m_trade = NULL;
      m_magic_manager = NULL;
      m_state_manager = NULL;
      m_logger = NULL;
      m_error_handler = NULL;
      m_scanner = NULL;
      m_lot_calculator = NULL;
      m_price_helper = NULL;
      
      m_symbol = _Symbol;
      m_max_layers = 15;
      m_last_buy_price = 0;
      m_last_sell_price = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Initialize System                                                |
   //+------------------------------------------------------------------+
   bool Initialize(CTrade* trade,
                   CMagicNumberManager* magic_manager,
                   CStateManager* state_manager,
                   CLogger* logger,
                   CErrorHandler* error_handler,
                   CPositionScanner* scanner,
                   CLotCalculator* lot_calculator,
                   CPriceHelper* price_helper,
                   int max_layers,
                   ENUM_GRID_MODE grid_mode,
                   int fixed_grid_points,
                   double atr_multiplier,
                   int atr_min_points,
                   int atr_max_points,
                   bool use_progressive_grid,
                   double grid_multiplier,
                   bool use_cycle_tp,
                   double cycle_tp_amount,
                   bool use_tp_points,
                   int tp_points,
                   bool use_max_drawdown_stop,
                   double max_drawdown,
                   bool use_max_layer_stop,
                   int stop_at_layer,
                   double max_lot_per_position,
                   double max_total_lot)
   {
      // Validate pointers
      if(trade == NULL || magic_manager == NULL || state_manager == NULL ||
         logger == NULL || error_handler == NULL || scanner == NULL ||
         lot_calculator == NULL || price_helper == NULL)
      {
         Print("❌ Martingale: NULL pointer in Initialize");
         return false;
      }
      
      m_trade = trade;
      m_magic_manager = magic_manager;
      m_state_manager = state_manager;
      m_logger = logger;
      m_error_handler = error_handler;
      m_scanner = scanner;
      m_lot_calculator = lot_calculator;
      m_price_helper = price_helper;
      
      // Store settings
      m_max_layers = max_layers;
      m_grid_mode = grid_mode;
      m_fixed_grid_points = fixed_grid_points;
      m_atr_multiplier = atr_multiplier;
      m_atr_min_points = atr_min_points;
      m_atr_max_points = atr_max_points;
      m_use_progressive_grid = use_progressive_grid;
      m_grid_multiplier = grid_multiplier;
      
      m_use_cycle_tp = use_cycle_tp;
      m_cycle_tp_amount = cycle_tp_amount;
      m_use_tp_points = use_tp_points;
      m_tp_points = tp_points;
      
      m_use_max_drawdown_stop = use_max_drawdown_stop;
      m_max_drawdown = max_drawdown;
      m_use_max_layer_stop = use_max_layer_stop;
      m_stop_at_layer = stop_at_layer;
      
      m_max_lot_per_position = max_lot_per_position;
      m_max_total_lot = max_total_lot;
      
      m_logger.LogBoxStart("MARTINGALE SYSTEM INITIALIZED");
      m_logger.Info("Max Layers: " + IntegerToString(m_max_layers));
      m_logger.Info("Grid Mode: " + EnumToString(m_grid_mode));
      m_logger.Info("Cycle TP: $" + DoubleToString(m_cycle_tp_amount, 2));
      m_logger.LogBoxEnd();
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Start Buy Cycle                                                  |
   //+------------------------------------------------------------------+
   bool StartBuyCycle()
   {
      if(m_state_manager.IsCycleActive())
      {
         m_logger.Warning("Cannot start BUY cycle - cycle already active");
         return false;
      }
      
      m_logger.LogCycleStart(MODE_BUY, m_price_helper.GetAsk(), 
                             m_lot_calculator.CalculateInitialLot());
      
      // Calculate lot for L1
      double lot = m_lot_calculator.CalculateInitialLot();
      
      // Get magic number for L1 BUY
      long magic = m_magic_manager.GetMartingaleBuyMagic(1);
      
      // Execute trade
      ulong ticket;
      if(!ExecuteTrade(ORDER_TYPE_BUY, lot, magic, "Mart BUY L1", ticket))
      {
         m_logger.Error("Failed to start BUY cycle");
         return false;
      }
      
      // Start cycle in state manager
      m_state_manager.StartCycle(MODE_BUY, m_price_helper.GetAsk());
      m_last_buy_price = m_price_helper.GetAsk();
      
      m_logger.Info("✅ BUY cycle started - Ticket: " + IntegerToString(ticket));
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Start Sell Cycle                                                 |
   //+------------------------------------------------------------------+
   bool StartSellCycle()
   {
      if(m_state_manager.IsCycleActive())
      {
         m_logger.Warning("Cannot start SELL cycle - cycle already active");
         return false;
      }
      
      m_logger.LogCycleStart(MODE_SELL, m_price_helper.GetBid(), 
                             m_lot_calculator.CalculateInitialLot());
      
      // Calculate lot for L1
      double lot = m_lot_calculator.CalculateInitialLot();
      
      // Get magic number for L1 SELL
      long magic = m_magic_manager.GetMartingaleSellMagic(1);
      
      // Execute trade
      ulong ticket;
      if(!ExecuteTrade(ORDER_TYPE_SELL, lot, magic, "Mart SELL L1", ticket))
      {
         m_logger.Error("Failed to start SELL cycle");
         return false;
      }
      
      // Start cycle in state manager
      m_state_manager.StartCycle(MODE_SELL, m_price_helper.GetBid());
      m_last_sell_price = m_price_helper.GetBid();
      
      m_logger.Info("✅ SELL cycle started - Ticket: " + IntegerToString(ticket));
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Add Martingale Layer                                             |
   //+------------------------------------------------------------------+
   bool AddLayer()
   {
      if(!m_state_manager.IsCycleActive())
      {
         m_logger.Warning("Cannot add layer - no active cycle");
         return false;
      }
      
      ENUM_MARTINGALE_MODE mode = m_state_manager.GetCurrentMode();
      int current_layer = m_state_manager.GetCurrentLayer();
      int next_layer = current_layer + 1;
      
      // Check if can add layer
      string error_msg;
      if(!CanAddLayer(next_layer, error_msg))
      {
         m_logger.Warning(error_msg);
         return false;
      }
      
      // Scan positions to get previous lot
      m_scanner.Scan();
      SPositionSummary summary = m_scanner.GetSummary();
      
      double prev_lot;
      if(mode == MODE_BUY)
         prev_lot = summary.mart_buy_lots / current_layer;
      else
         prev_lot = summary.mart_sell_lots / current_layer;
      
      // Calculate next layer lot
      double next_lot = m_lot_calculator.CalculateNextLayerLot(prev_lot, next_layer);
      
      // Get price for next layer
      double current_price = (mode == MODE_BUY) ? 
                             m_price_helper.GetAsk() : 
                             m_price_helper.GetBid();
      
      // Get magic number
      long magic;
      ENUM_ORDER_TYPE order_type;
      string comment;
      
      if(mode == MODE_BUY)
      {
         magic = m_magic_manager.GetMartingaleBuyMagic(next_layer);
         order_type = ORDER_TYPE_BUY;
         comment = "Mart BUY L" + IntegerToString(next_layer);
      }
      else
      {
         magic = m_magic_manager.GetMartingaleSellMagic(next_layer);
         order_type = ORDER_TYPE_SELL;
         comment = "Mart SELL L" + IntegerToString(next_layer);
      }
      
      // Execute trade
      ulong ticket;
      if(!ExecuteTrade(order_type, next_lot, magic, comment, ticket))
      {
         m_logger.Error("Failed to add layer L" + IntegerToString(next_layer));
         return false;
      }
      
      // Advance layer in state manager
      m_state_manager.AdvanceLayer();
      
      if(mode == MODE_BUY)
         m_last_buy_price = current_price;
      else
         m_last_sell_price = current_price;
      
      m_logger.LogLayerAdvance(next_layer, current_price, next_lot);
      m_logger.Info("✅ Layer added - L" + IntegerToString(next_layer) + 
                    " Ticket: " + IntegerToString(ticket));
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Check if Should Add Layer                                        |
   //+------------------------------------------------------------------+
   bool ShouldAddLayer()
   {
      if(!m_state_manager.IsCycleActive())
         return false;
      
      ENUM_MARTINGALE_MODE mode = m_state_manager.GetCurrentMode();
      int current_layer = m_state_manager.GetCurrentLayer();
      
      // Check if at max layers
      if(current_layer >= m_max_layers)
         return false;
      
      // Calculate grid distance
      double grid_distance = CalculateGridDistance(current_layer + 1);
      
      // Get current price
      double current_price = (mode == MODE_BUY) ? 
                             m_price_helper.GetBid() : 
                             m_price_helper.GetAsk();
      
      // Check if price has moved enough
      double last_price = (mode == MODE_BUY) ? m_last_buy_price : m_last_sell_price;
      
      if(mode == MODE_BUY)
      {
         // BUY: add layer when price drops
         if(current_price <= last_price - grid_distance)
            return true;
      }
      else
      {
         // SELL: add layer when price rises
         if(current_price >= last_price + grid_distance)
            return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check Cycle Take Profit                                          |
   //+------------------------------------------------------------------+
   bool CheckCycleTP()
   {
      if(!m_state_manager.IsCycleActive())
         return false;
      
      if(!m_use_cycle_tp)
         return false;
      
      // Scan positions
      m_scanner.Scan();
      SPositionSummary summary = m_scanner.GetSummary();
      
      // Check martingale profit
      double mart_profit = summary.GetMartingaleNetPL();
      
      if(mart_profit >= m_cycle_tp_amount)
      {
         m_logger.Info("🎯 Cycle TP reached: $" + DoubleToString(mart_profit, 2));
         return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Close Cycle                                                       |
   //+------------------------------------------------------------------+
   bool CloseCycle(bool success = true)
   {
      if(!m_state_manager.IsCycleActive())
         return false;
      
      ENUM_MARTINGALE_MODE mode = m_state_manager.GetCurrentMode();
      int final_layer = m_state_manager.GetCurrentLayer();
      
      // Get positions to close
      SPositionInfo positions[];
      int count;
      
      if(mode == MODE_BUY)
         count = m_scanner.GetMartingaleBuyPositions(positions);
      else
         count = m_scanner.GetMartingaleSellPositions(positions);
      
      m_logger.Info("Closing " + IntegerToString(count) + " positions...");
      
      // Close all positions
      int closed = 0;
      for(int i = 0; i < count; i++)
      {
         if(m_trade.PositionClose(positions[i].ticket))
         {
            closed++;
            m_logger.Debug("Closed ticket: " + IntegerToString(positions[i].ticket));
         }
         else
         {
            m_logger.Error("Failed to close ticket: " + IntegerToString(positions[i].ticket));
         }
      }
      
      // Calculate cycle profit
      m_scanner.Scan();
      SPositionSummary summary = m_scanner.GetSummary();
      double cycle_profit = summary.GetMartingaleNetPL();
      
      // Get cycle duration
      datetime duration = TimeCurrent() - m_state_manager.GetCycleStartTime();
      
      // End cycle in state manager
      m_state_manager.EndCycle(success);
      
      // Reset prices
      m_last_buy_price = 0;
      m_last_sell_price = 0;
      
      m_logger.LogCycleEnd(mode, final_layer, cycle_profit, (int)duration, success);
      m_logger.Info("✅ Cycle closed - Profit: $" + DoubleToString(cycle_profit, 2));
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Process Tick (Main Logic)                                        |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      static int tick_count = 0;
      tick_count++;
      
      if(tick_count % 100 == 1)
         Print(StringFormat(">>> Martingale OnTick #%d: Cycle Active=%s", 
                           tick_count, m_state_manager.IsCycleActive() ? "TRUE" : "FALSE"));
      
      // Check if cycle TP reached
      if(CheckCycleTP())
      {
         Print(">>> Martingale: Cycle TP REACHED - Closing cycle...");
         CloseCycle(true);
         return;
      }
      
      // Check if should add layer
      if(ShouldAddLayer())
      {
         Print(">>> Martingale: ShouldAddLayer returned TRUE - Calling AddLayer()...");
         bool result = AddLayer();
         Print(StringFormat(">>> Martingale: AddLayer() result = %s", result ? "SUCCESS" : "FAILED"));
      }
   }
};

//+------------------------------------------------------------------+
//| End of TG_Martingale.mqh                                         |
//+------------------------------------------------------------------+
#endif // TG_MARTINGALE_MQH
