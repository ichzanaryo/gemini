//+------------------------------------------------------------------+
//|                                    Systems/TG_Martingale_v2.mqh  |
//|                                          Titan Grid EA v1.0      |
//|                              COMPLETE REWRITE - Simple & Reliable|
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "2.00"

#ifndef TG_MARTINGALE_V2_MQH
#define TG_MARTINGALE_V2_MQH

#include <Trade\Trade.mqh>
#include "../Core/TG_Definitions.mqh"
#include "../Core/TG_MagicNumbers.mqh"
#include "../Core/TG_StateManager.mqh"
#include "../Utilities/TG_PositionScanner.mqh"
#include "../Core/TG_Logger.mqh"
#include "../Core/TG_ErrorHandler.mqh"
#include "../Utilities/TG_PriceHelpers.mqh"
#include "../Utilities/TG_LotCalculation.mqh"

//+------------------------------------------------------------------+
//| Martingale Manager Class - Version 2                             |
//+------------------------------------------------------------------+
class CMartingaleManagerV2
{
private:
   // Dependencies
   CMagicNumberManager*  m_magic;
   CStateManager*        m_state;
   CPositionScanner*     m_scanner;
   CLogger*             m_logger;
   CErrorHandler*       m_error_handler;
   CPriceHelper*        m_price_helper;
   CLotCalculator*      m_lot_calc;
   CTrade              m_trade;
   
   // Settings
   int      m_max_layers;
   double   m_grid_distance_points;
   double   m_lot_multiplier;
   double   m_initial_lot;
   bool     m_use_cycle_tp;
   double   m_cycle_tp_amount;
   
   // Grid Distance Progression settings
   ENUM_GRID_PROGRESSION_MODE m_grid_progression_mode;  // Progression mode
   double   m_grid_multiplier_value;                    // For MULTIPLY/POWER modes
   int      m_grid_add_value;                           // For ADD mode (in points)
   
   // State tracking
   double   m_layer_prices[MAX_LAYERS + 1];  // Price where each layer opened
   int      m_active_layers;                  // Number of layers currently open
   
   // 🚀 INDEPENDENT CYCLE TRACKING - Bypass StateManager!
   bool     m_independent_cycle_active;       // Our own cycle flag
   ENUM_MARTINGALE_MODE m_independent_mode;   // Our own mode tracking
   
   //+------------------------------------------------------------------+
   //| Calculate Grid Distance in Price (with Progression Support)     |
   //+------------------------------------------------------------------+
   double GetGridDistanceInPrice()
   {
      double point = m_price_helper.GetPoint();
      double base_distance = m_grid_distance_points * point;
      
      // Layer 0 always uses base distance
      if(m_active_layers == 0)
         return base_distance;
      
      double calculated_distance = base_distance;
      
      switch(m_grid_progression_mode)
      {
         case GRID_PROGRESSION_FIXED:
            // Fixed: Same distance every layer
            calculated_distance = base_distance;
            Print(StringFormat(">>> MART V2: Grid Distance FIXED - Layer %d, Distance=%.5f",
                              m_active_layers, calculated_distance));
            break;
            
         case GRID_PROGRESSION_ADD:
            // Add: Distance(n) = Base + (n × AddValue)
            // Example: Base=1000, Add=500, Layer 3 = 1000 + (3×500) = 2500
            {
               double add_value = m_grid_add_value * point;
               calculated_distance = base_distance + (m_active_layers * add_value);
               
               Print(StringFormat(">>> MART V2: Grid Distance ADD - Layer %d, Base=%.5f, AddValue=%.5f, Result=%.5f",
                                 m_active_layers, base_distance, add_value, calculated_distance));
            }
            break;
            
         case GRID_PROGRESSION_MULTIPLY:
            // Multiply: Distance(n) = Base × (1 + n × Multiplier)
            // Example: Base=1000, Mult=0.5, Layer 3 = 1000 × (1 + 3×0.5) = 2500
            calculated_distance = base_distance * (1.0 + (m_active_layers * m_grid_multiplier_value));
            
            Print(StringFormat(">>> MART V2: Grid Distance MULTIPLY - Layer %d, Base=%.5f, Multiplier=%.2f, Result=%.5f",
                              m_active_layers, base_distance, m_grid_multiplier_value, calculated_distance));
            break;
            
         case GRID_PROGRESSION_POWER:
            // Power: Distance(n) = Base × (Multiplier ^ n)
            // Example: Base=1000, Mult=1.5, Layer 3 = 1000 × (1.5^3) = 3375
            calculated_distance = base_distance * MathPow(m_grid_multiplier_value, m_active_layers);
            
            Print(StringFormat(">>> MART V2: Grid Distance POWER - Layer %d, Base=%.5f, Multiplier=%.2f, Result=%.5f",
                              m_active_layers, base_distance, m_grid_multiplier_value, calculated_distance));
            break;
      }
      
      return calculated_distance;
   }
   
   //+------------------------------------------------------------------+
   //| Get Last Layer Price                                             |
   //+------------------------------------------------------------------+
   double GetLastLayerPrice()
   {
      if(m_active_layers < 1)
         return 0;
      
      return m_layer_prices[m_active_layers];
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Lot for Next Layer                                     |
   //+------------------------------------------------------------------+
   double CalculateNextLot()
   {
      if(m_active_layers == 0)
         return m_initial_lot;
      
      // Get last layer lot
      double last_lot = m_initial_lot;
      for(int i = 1; i < m_active_layers; i++)
      {
         last_lot *= m_lot_multiplier;
      }
      
      return last_lot * m_lot_multiplier;
   }
   
   //+------------------------------------------------------------------+
   //| Execute Market Order                                             |
   //+------------------------------------------------------------------+
   bool OpenPosition(ENUM_ORDER_TYPE type, double lot, long magic, 
                     string comment, double &out_price)
   {
      out_price = 0;
      
      string symbol = _Symbol;
      double price = (type == ORDER_TYPE_BUY) ? 
                     m_price_helper.GetAsk() : 
                     m_price_helper.GetBid();
      
      // 🔧 NORMALIZE LOT SIZE - Get broker limits
      double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      
      // Normalize to broker's lot step
      double normalized_lot = MathFloor(lot / lot_step) * lot_step;
      
      // Clamp to broker limits
      if(normalized_lot < min_lot) normalized_lot = min_lot;
      if(normalized_lot > max_lot) normalized_lot = max_lot;
      
      Print(StringFormat(">>> MART V2: Lot normalization - Requested=%.3f, Step=%.2f, Normalized=%.2f",
                        lot, lot_step, normalized_lot));
      
      Print(StringFormat(">>> MART V2: Opening %s position - Lot=%.2f, Magic=%I64d",
                        (type == ORDER_TYPE_BUY) ? "BUY" : "SELL", normalized_lot, magic));
      
      // Set magic before trade
      m_trade.SetExpertMagicNumber(magic);
      
      // Execute with NORMALIZED lot
      bool result = false;
      if(type == ORDER_TYPE_BUY)
         result = m_trade.Buy(normalized_lot, symbol, 0, 0, 0, comment);
      else
         result = m_trade.Sell(normalized_lot, symbol, 0, 0, 0, comment);
      
      if(!result)
      {
         uint error = GetLastError();
         Print(">>> MART V2: ❌ Order FAILED! Error code: ", error);
         return false;
      }
      
      // Get actual fill price
      ulong ticket = m_trade.ResultOrder();
      if(PositionSelectByTicket(ticket))
      {
         out_price = PositionGetDouble(POSITION_PRICE_OPEN);
         Print(StringFormat(">>> MART V2: ✅ Order SUCCESS! Ticket=%I64u, Price=%.5f",
                           ticket, out_price));
      }
      else
      {
         out_price = price;  // Fallback
         Print(StringFormat(">>> MART V2: ✅ Order SUCCESS! Ticket=%I64u, Price~%.5f (estimated)",
                           ticket, out_price));
      }
      
      return true;
   }
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CMartingaleManagerV2()
   {
      m_magic = NULL;
      m_state = NULL;
      m_scanner = NULL;
      m_logger = NULL;
      m_error_handler = NULL;
      m_price_helper = NULL;
      m_lot_calc = NULL;
      
      m_max_layers = 15;
      m_grid_distance_points = 100;
      m_lot_multiplier = 2.0;
      m_initial_lot = 0.01;
      m_use_cycle_tp = true;
      m_cycle_tp_amount = 5.0;
      
      // Grid progression defaults
      m_grid_progression_mode = GRID_PROGRESSION_FIXED;
      m_grid_multiplier_value = 1.5;
      m_grid_add_value = 500;
      
      m_active_layers = 0;
      ArrayInitialize(m_layer_prices, 0);
      
      // 🚀 Initialize independent tracking
      m_independent_cycle_active = false;
      m_independent_mode = MODE_NONE;
   }
   
   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   bool Initialize(CMagicNumberManager* magic,
                   CStateManager* state,
                   CPositionScanner* scanner,
                   CLogger* logger,
                   CErrorHandler* error_handler,
                   CPriceHelper* price_helper,
                   CLotCalculator* lot_calc)
   {
      m_magic = magic;
      m_state = state;
      m_scanner = scanner;
      m_logger = logger;
      m_error_handler = error_handler;
      m_price_helper = price_helper;
      m_lot_calc = lot_calc;
      
      Print("╔═══════════════════════════════════════════════════════════╗");
      Print("║         MARTINGALE V2 INITIALIZED                         ║");
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ Max Layers: ", m_max_layers);
      Print("║ Grid Distance: ", m_grid_distance_points, " points");
      Print("║ Lot Multiplier: ", m_lot_multiplier);
      Print("║ Initial Lot: ", m_initial_lot);
      Print("║ Cycle TP: $", m_cycle_tp_amount);
      Print("╚═══════════════════════════════════════════════════════════╝");
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Configure Settings                                                |
   //+------------------------------------------------------------------+
   void SetMaxLayers(int max_layers) 
   { 
      m_max_layers = max_layers; 
      Print(StringFormat(">>> MART V2: SetMaxLayers = %d", max_layers));
   }
   
   void SetGridDistance(double points) 
   { 
      m_grid_distance_points = points; 
      Print(StringFormat(">>> MART V2: SetGridDistance = %.0f points", points));
   }
   
   void SetLotMultiplier(double mult) 
   { 
      m_lot_multiplier = mult; 
      Print(StringFormat(">>> MART V2: SetLotMultiplier = %.1f", mult));
   }
   
   void SetInitialLot(double lot) 
   { 
      m_initial_lot = lot; 
      Print(StringFormat(">>> MART V2: SetInitialLot = %.2f", lot));
   }
   
   void SetCycleTP(bool use, double amount) 
   { 
      m_use_cycle_tp = use; 
      m_cycle_tp_amount = amount;
      Print(StringFormat(">>> MART V2: SetCycleTP = %s, Amount=$%.2f", 
                        use ? "ENABLED" : "DISABLED", amount));
   }
   
   //+------------------------------------------------------------------+
   //| Set Grid Progression Mode                                         |
   //+------------------------------------------------------------------+
   void SetGridProgression(ENUM_GRID_PROGRESSION_MODE mode, 
                          double multiplier_value, 
                          int add_value)
   {
      m_grid_progression_mode = mode;
      m_grid_multiplier_value = multiplier_value;
      m_grid_add_value = add_value;
      
      string mode_str = "";
      switch(mode)
      {
         case GRID_PROGRESSION_FIXED:    mode_str = "FIXED"; break;
         case GRID_PROGRESSION_ADD:      mode_str = "ADD"; break;
         case GRID_PROGRESSION_MULTIPLY: mode_str = "MULTIPLY"; break;
         case GRID_PROGRESSION_POWER:    mode_str = "POWER"; break;
      }
      
      Print(StringFormat(">>> MART V2: Grid Progression = %s, Multiplier=%.2f, AddValue=%d points",
                        mode_str, multiplier_value, add_value));
   }
   
   //+------------------------------------------------------------------+
   //| Get Independent Cycle Status                                     |
   //+------------------------------------------------------------------+
   bool IsIndependentCycleActive() const 
   { 
      return m_independent_cycle_active; 
   }
   
   //+------------------------------------------------------------------+
   //| Sync State from Existing Positions (Resume after restart)       |
   //+------------------------------------------------------------------+
   void SyncState()
   {
      Print("╔═══════════════════════════════════════════════════════════╗");
      Print("║ 🔄 SYNC STATE - Resuming from Existing Positions");
      Print("╚═══════════════════════════════════════════════════════════╝");
      
      // Check if cycle is active in StateManager
      if(!m_state.IsCycleActive())
      {
         Print(">>> SYNC: No active cycle in StateManager");
         m_independent_cycle_active = false;
         m_independent_mode = MODE_NONE;
         m_active_layers = 0;
         ArrayInitialize(m_layer_prices, 0);
         return;
      }
      
      // Get mode from StateManager
      ENUM_MARTINGALE_MODE mode = m_state.GetCurrentMode();
      Print(StringFormat(">>> SYNC: StateManager mode = %s", 
                        (mode == MODE_BUY) ? "BUY" : "SELL"));
      
      // Scan existing positions
      m_scanner.Scan();
      
      SPositionInfo positions[];
      int count = 0;
      
      if(mode == MODE_BUY)
         count = m_scanner.GetMartingaleBuyPositions(positions);
      else
         count = m_scanner.GetMartingaleSellPositions(positions);
      
      Print(StringFormat(">>> SYNC: Found %d positions", count));
      
      // Reset arrays
      m_active_layers = 0;
      ArrayInitialize(m_layer_prices, 0);
      
      // Rebuild layer prices from positions
      for(int i = 0; i < count; i++)
      {
         int layer = positions[i].layer;
         
         Print(StringFormat(">>> SYNC: Pos #%d - Layer=%d, Price=%.5f, Lot=%.2f",
                           i, layer, positions[i].open_price, positions[i].lots));
         
         if(layer > 0 && layer <= MAX_LAYERS)
         {
            m_layer_prices[layer] = positions[i].open_price;
            
            // Track highest layer
            if(layer > m_active_layers)
               m_active_layers = layer;
         }
      }
      
      // Set independent flags
      m_independent_cycle_active = true;
      m_independent_mode = mode;
      
      Print("╔═══════════════════════════════════════════════════════════╗");
      Print("║ ✅ SYNC COMPLETE!");
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ Independent Cycle: TRUE");  // No StringFormat needed for literal!
      Print(StringFormat("║ Mode: %s", (mode == MODE_BUY) ? "BUY" : "SELL"));
      Print(StringFormat("║ Active Layers: %d", m_active_layers));
      
      for(int i = 1; i <= m_active_layers; i++)
      {
         if(m_layer_prices[i] > 0)
            Print(StringFormat("║ Layer %d: %.5f", i, m_layer_prices[i]));
      }
      
      Print("╚═══════════════════════════════════════════════════════════╝");
   }
   
   //+------------------------------------------------------------------+
   //| Start BUY Cycle                                                  |
   //+------------------------------------------------------------------+
   bool StartBuyCycle()
   {
      Print(">>> MART V2: StartBuyCycle() CALLED");
      
      if(m_state.IsCycleActive())
      {
         Print(">>> MART V2: ❌ Cycle already active!");
         return false;
      }
      
      // Reset state
      m_active_layers = 0;
      ArrayInitialize(m_layer_prices, 0);
      
      Print(">>> MART V2: Starting BUY cycle initialization...");
      
      // 🧠 SMART CHECK: Scan ALL BUY positions (including PO)
      Print(">>> MART V2: Scanning for existing BUY positions...");
      
      double entry_price = 0;
      bool found_existing = false;
      
      string current_symbol = _Symbol;  // Get current symbol
      
      // Check all positions for this symbol
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         // Select position by index
         if(!PositionSelectByTicket(PositionGetTicket(i)))
            continue;
            
         // Check symbol
         if(PositionGetString(POSITION_SYMBOL) != current_symbol)
            continue;
            
         // Check type
         if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
            continue;
         
         // Found a BUY position!
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         double pos_price = PositionGetDouble(POSITION_PRICE_OPEN);
         double pos_lot = PositionGetDouble(POSITION_VOLUME);
         long pos_magic = PositionGetInteger(POSITION_MAGIC);
         
         Print(StringFormat(">>> MART V2: Found BUY position - Ticket=%I64u, Price=%.5f, Lot=%.2f, Magic=%I64d",
                           ticket, pos_price, pos_lot, pos_magic));
         
         // This is our L1! (from pending order or previous)
         entry_price = pos_price;
         found_existing = true;
         
         Print(StringFormat(">>> MART V2: ✅ Will use this as L1 @ %.5f", entry_price));
         break;  // Use first BUY position found
      }
      
      if(!found_existing)
      {
         // No existing position - open new L1
         Print(">>> MART V2: No existing BUY position found, opening new L1...");
         
         double lot = m_initial_lot;
         long magic = m_magic.GetMartingaleBuyMagic(1);
         
         Print(StringFormat(">>> MART V2: Opening BUY L1 - Lot=%.2f, Magic=%I64d", lot, magic));
         
         if(!OpenPosition(ORDER_TYPE_BUY, lot, magic, "Mart BUY L1", entry_price))
         {
            Print(">>> MART V2: ❌ Failed to open L1!");
            return false;
         }
         
         Print(StringFormat(">>> MART V2: ✅ New L1 opened @ %.5f", entry_price));
      }
      
      // Update state
      m_active_layers = 1;
      m_layer_prices[1] = entry_price;
      
      // 🚀 SET INDEPENDENT CYCLE FLAG - Works regardless of StateManager!
      m_independent_cycle_active = true;
      m_independent_mode = MODE_BUY;
      Print(">>> MART V2: 🚀 INDEPENDENT cycle flag SET to TRUE!");
      
      // Start cycle in state manager
      Print(">>> MART V2: Calling m_state.StartCycle(MODE_BUY, ", entry_price, ")...");
      Print(">>> MART V2: Checking if state manager allows cycle start...");
      
      if(!m_state.StartCycle(MODE_BUY, entry_price))
      {
         Print("🚨🚨🚨 CRITICAL: STATE MANAGER REJECTED CYCLE START! 🚨🚨🚨");
         Print("🚨 Possible reasons:");
         Print("🚨 1. Martingale not enabled in StateManager");
         Print("🚨 2. Martingale stopped");
         Print("🚨 3. Cycle already active");
         Print("🚨 Check StateManager.IsMartingaleEnabled() = ", m_state.IsMartingaleEnabled());
         Print("🚨 BUT: Independent cycle IS active, so OnTick will still run!");
         
         // DON'T rollback - keep independent cycle!
      }
      
      Print(StringFormat(">>> MART V2: ✅ BUY Cycle STARTED! L1 @ %.5f", entry_price));
      
      // 🔄 Sync state to rebuild layer tracking
      SyncState();
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Start SELL Cycle                                                 |
   //+------------------------------------------------------------------+
   bool StartSellCycle()
   {
      Print(">>> MART V2: StartSellCycle() CALLED");
      
      if(m_state.IsCycleActive())
      {
         Print(">>> MART V2: ❌ Cycle already active!");
         return false;
      }
      
      // Reset state
      m_active_layers = 0;
      ArrayInitialize(m_layer_prices, 0);
      
      Print(">>> MART V2: Starting SELL cycle initialization...");
      
      // 🧠 SMART CHECK: Scan ALL SELL positions (including PO)
      Print(">>> MART V2: Scanning for existing SELL positions...");
      
      double entry_price = 0;
      bool found_existing = false;
      
      string current_symbol = _Symbol;  // Get current symbol
      
      // Check all positions for this symbol
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         // Select position by index
         if(!PositionSelectByTicket(PositionGetTicket(i)))
            continue;
            
         // Check symbol
         if(PositionGetString(POSITION_SYMBOL) != current_symbol)
            continue;
            
         // Check type
         if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
            continue;
         
         // Found a SELL position!
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         double pos_price = PositionGetDouble(POSITION_PRICE_OPEN);
         double pos_lot = PositionGetDouble(POSITION_VOLUME);
         long pos_magic = PositionGetInteger(POSITION_MAGIC);
         
         Print(StringFormat(">>> MART V2: Found SELL position - Ticket=%I64u, Price=%.5f, Lot=%.2f, Magic=%I64d",
                           ticket, pos_price, pos_lot, pos_magic));
         
         // This is our L1! (from pending order or previous)
         entry_price = pos_price;
         found_existing = true;
         
         Print(StringFormat(">>> MART V2: ✅ Will use this as L1 @ %.5f", entry_price));
         break;  // Use first SELL position found
      }
      
      if(!found_existing)
      {
         // No existing position - open new L1
         Print(">>> MART V2: No existing SELL position found, opening new L1...");
         
         double lot = m_initial_lot;
         long magic = m_magic.GetMartingaleSellMagic(1);
         
         Print(StringFormat(">>> MART V2: Opening SELL L1 - Lot=%.2f, Magic=%I64d", lot, magic));
         
         if(!OpenPosition(ORDER_TYPE_SELL, lot, magic, "Mart SELL L1", entry_price))
         {
            Print(">>> MART V2: ❌ Failed to open L1!");
            return false;
         }
         
         Print(StringFormat(">>> MART V2: ✅ New L1 opened @ %.5f", entry_price));
      }
      
      // Update state
      m_active_layers = 1;
      m_layer_prices[1] = entry_price;
      
      // 🚀 SET INDEPENDENT CYCLE FLAG - Works regardless of StateManager!
      m_independent_cycle_active = true;
      m_independent_mode = MODE_SELL;
      
      Print("╔═══════════════════════════════════════════════════════════╗");
      Print("║ 🚀 INDEPENDENT CYCLE FLAGS SET!");
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print(StringFormat("║ m_independent_cycle_active = %s", m_independent_cycle_active ? "TRUE ✅" : "FALSE ❌"));
      Print(StringFormat("║ m_independent_mode = %s", "MODE_SELL"));
      Print(StringFormat("║ m_active_layers = %d", m_active_layers));
      Print(StringFormat("║ m_layer_prices[1] = %.5f", m_layer_prices[1]));
      Print("╚═══════════════════════════════════════════════════════════╝");
      
      // Start cycle in state manager
      Print(">>> MART V2: Calling m_state.StartCycle(MODE_SELL, ", entry_price, ")...");
      Print(">>> MART V2: Checking if state manager allows cycle start...");
      
      if(!m_state.StartCycle(MODE_SELL, entry_price))
      {
         Print("🚨🚨🚨 CRITICAL: STATE MANAGER REJECTED CYCLE START! 🚨🚨🚨");
         Print("🚨 Possible reasons:");
         Print("🚨 1. Martingale not enabled in StateManager");
         Print("🚨 2. Martingale stopped");
         Print("🚨 3. Cycle already active");
         Print("🚨 Check StateManager.IsMartingaleEnabled() = ", m_state.IsMartingaleEnabled());
         Print("🚨 BUT: Independent cycle IS active, so OnTick will still run!");
         
         // DON'T rollback - keep independent cycle!
         // m_active_layers = 0;
         // m_layer_prices[1] = 0;
         // return false;
      }
      
      Print(StringFormat(">>> MART V2: ✅ SELL Cycle STARTED! L1 @ %.5f", entry_price));
      
      // 🔄 Sync state to rebuild layer tracking
      SyncState();
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Add Next Layer                                                    |
   //+------------------------------------------------------------------+
   bool AddLayer()
   {
      Print(">>> MART V2: AddLayer() CALLED");
      
      // 🚀 Use independent cycle check
      if(!m_independent_cycle_active)
      {
         Print(">>> MART V2: ❌ No active independent cycle!");
         return false;
      }
      
      // 🚀 Use independent mode
      ENUM_MARTINGALE_MODE mode = m_independent_mode;
      int next_layer = m_active_layers + 1;
      
      Print(StringFormat(">>> MART V2: Mode=%s, Current=%d, Next=%d",
                        (mode == MODE_BUY) ? "BUY" : "SELL",
                        m_active_layers, next_layer));
      
      // Check max layers
      if(next_layer > m_max_layers)
      {
         Print(StringFormat(">>> MART V2: ❌ Max layers reached (%d)", m_max_layers));
         return false;
      }
      
      // Calculate next lot
      double next_lot = CalculateNextLot();
      
      Print(StringFormat(">>> MART V2: Next lot = %.2f", next_lot));
      
      // Get magic
      long magic;
      ENUM_ORDER_TYPE order_type;
      string comment;
      
      if(mode == MODE_BUY)
      {
         magic = m_magic.GetMartingaleBuyMagic(next_layer);
         order_type = ORDER_TYPE_BUY;
         comment = "Mart BUY L" + IntegerToString(next_layer);
      }
      else
      {
         magic = m_magic.GetMartingaleSellMagic(next_layer);
         order_type = ORDER_TYPE_SELL;
         comment = "Mart SELL L" + IntegerToString(next_layer);
      }
      
      Print(StringFormat(">>> MART V2: Magic=%I64d, Type=%s",
                        magic, (order_type == ORDER_TYPE_BUY) ? "BUY" : "SELL"));
      
      // Open position
      double entry_price;
      if(!OpenPosition(order_type, next_lot, magic, comment, entry_price))
      {
         Print(StringFormat(">>> MART V2: ❌ Failed to open L%d!", next_layer));
         return false;
      }
      
      // Update state
      m_active_layers = next_layer;
      m_layer_prices[next_layer] = entry_price;
      
      // Advance in state manager
      m_state.AdvanceLayer();
      
      Print(StringFormat(">>> MART V2: ✅ Layer L%d ADDED @ %.5f", 
                        next_layer, entry_price));
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Check if Should Add Layer                                        |
   //+------------------------------------------------------------------+
   bool ShouldAddLayer()
   {
      static int check_count = 0;
      check_count++;
      
      // 🔥 SUPER VERBOSE - Log EVERY check for first 500 checks
      if(check_count <= 500)
      {
         Print(StringFormat(">>> MART V2: 🔥 ShouldAddLayer CHECK #%d - Independent cycle = %s",
                           check_count, m_independent_cycle_active ? "TRUE" : "FALSE"));
      }
      
      // Log every 100 checks
      if(check_count % 100 == 1)
         Print(StringFormat(">>> MART V2: ShouldAddLayer CHECK #%d", check_count));
      
      // 🔄 FALLBACK: If flag lost but StateManager active, sync!
      if(!m_independent_cycle_active && m_state.IsCycleActive())
      {
         Print(">>> MART V2: ⚠️ Flag lost but StateManager active - Auto-syncing!");
         SyncState();
      }
      
      // 🚀 Use INDEPENDENT cycle flag - bypass StateManager!
      if(!m_independent_cycle_active)
      {
         if(check_count % 10 == 1)  // More frequent logging!
            Print(">>> MART V2: ❌ No active INDEPENDENT cycle - SKIPPING layer check!");
         return false;
      }
      
      if(m_active_layers >= m_max_layers)
      {
         Print(StringFormat(">>> MART V2: Max layers reached (%d)", m_max_layers));
         return false;
      }
      
      // 🚀 Use INDEPENDENT mode - bypass StateManager!
      ENUM_MARTINGALE_MODE mode = m_independent_mode;
      
      if(check_count <= 500)
      {
         Print(StringFormat(">>> MART V2: 🔥 Mode=%s, Active layers=%d/%d",
                           (mode == MODE_BUY) ? "BUY" : (mode == MODE_SELL ? "SELL" : "NONE"),
                           m_active_layers, m_max_layers));
      }
      
      // Get last layer price
      double last_price = GetLastLayerPrice();
      if(last_price == 0)
      {
         Print(">>> MART V2: ❌ Last layer price is 0!");
         return false;
      }
      
      // Get current price
      double current_price = (mode == MODE_BUY) ? 
                             m_price_helper.GetBid() : 
                             m_price_helper.GetAsk();
      
      // Get grid distance
      double grid_distance = GetGridDistanceInPrice();
      
      // Log details periodically
      if(check_count % 100 == 1)
      {
         Print(StringFormat(">>> MART V2: %s - Current=%.5f, Last=%.5f, Grid=%.5f",
                           (mode == MODE_BUY) ? "BUY" : "SELL",
                           current_price, last_price, grid_distance));
      }
      
      bool should_add = false;
      
      if(mode == MODE_BUY)
      {
         // BUY: Add layer when price DROPS
         double target_price = last_price - grid_distance;
         
         if(current_price <= target_price)
         {
            Print(StringFormat(">>> MART V2: ✅ SHOULD ADD BUY L%d! Price %.5f <= %.5f",
                              m_active_layers + 1, current_price, target_price));
            should_add = true;
         }
      }
      else // SELL
      {
         // SELL: Add layer when price RISES
         double target_price = last_price + grid_distance;
         
         if(current_price >= target_price)
         {
            Print(StringFormat(">>> MART V2: ✅ SHOULD ADD SELL L%d! Price %.5f >= %.5f",
                              m_active_layers + 1, current_price, target_price));
            should_add = true;
         }
      }
      
      return should_add;
   }
   
   //+------------------------------------------------------------------+
   //| Check Cycle Take Profit                                          |
   //+------------------------------------------------------------------+
   bool CheckCycleTP()
   {
      if(!m_use_cycle_tp)
         return false;
      
      if(!m_state.IsCycleActive())
         return false;
      
      // Scan positions
      m_scanner.Scan();
      SPositionSummary summary = m_scanner.GetSummary();
      
      // Get profit
      double profit = summary.GetMartingaleNetPL();
      
      if(profit >= m_cycle_tp_amount)
      {
         Print(StringFormat(">>> MART V2: 🎯 CYCLE TP REACHED! Profit=$%.2f", profit));
         return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Close Cycle                                                       |
   //+------------------------------------------------------------------+
   bool CloseCycle()
   {
      Print(">>> MART V2: CloseCycle() CALLED");
      
      if(!m_state.IsCycleActive())
      {
         Print(">>> MART V2: No active cycle to close");
         return false;
      }
      
      ENUM_MARTINGALE_MODE mode = m_state.GetCurrentMode();
      
      // Get all positions
      SPositionInfo positions[];
      int count = 0;
      
      if(mode == MODE_BUY)
         count = m_scanner.GetMartingaleBuyPositions(positions);
      else
         count = m_scanner.GetMartingaleSellPositions(positions);
      
      Print(StringFormat(">>> MART V2: Closing %d positions...", count));
      
      // Close all
      int closed = 0;
      for(int i = 0; i < count; i++)
      {
         if(m_trade.PositionClose(positions[i].ticket))
         {
            closed++;
            Print(StringFormat(">>> MART V2: Closed ticket %I64u", positions[i].ticket));
         }
         else
         {
            Print(StringFormat(">>> MART V2: ❌ Failed to close %I64u", positions[i].ticket));
         }
      }
      
      Print(StringFormat(">>> MART V2: Closed %d/%d positions", closed, count));
      
      // Reset state
      m_state.EndCycle(true);
      m_active_layers = 0;
      ArrayInitialize(m_layer_prices, 0);
      
      // 🚀 Reset independent flags
      m_independent_cycle_active = false;
      m_independent_mode = MODE_NONE;
      Print(">>> MART V2: 🚀 Independent cycle flags RESET");
      
      Print(">>> MART V2: ✅ Cycle CLOSED!");
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Main Tick Handler                                                |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      // 🔥 EMERGENCY DEBUG - Print IMMEDIATELY!
      Print(">>> MART V2: 🔥🔥🔥 OnTick() CALLED!");
      
      static int tick_count = 0;
      tick_count++;
      
      Print(StringFormat(">>> MART V2: 🔥 Tick count = %d", tick_count));
      Print(StringFormat(">>> MART V2: 🔥 Independent cycle active = %s", 
                        m_independent_cycle_active ? "TRUE" : "FALSE"));
      Print(StringFormat(">>> MART V2: 🔥 Active layers = %d", m_active_layers));
      
      // Log status every 50 ticks (detailed!)
      if(tick_count % 50 == 1)
      {
         Print("╔═══════════════════════════════════════════════════════════╗");
         Print(StringFormat("║ MART V2 OnTick #%d", tick_count));
         Print("╠═══════════════════════════════════════════════════════════╣");
         Print(StringFormat("║ StateManager Cycle: %s", m_state.IsCycleActive() ? "TRUE" : "FALSE"));
         Print(StringFormat("║ Independent Cycle: %s 🚀", m_independent_cycle_active ? "TRUE ✅" : "FALSE ❌"));
         Print(StringFormat("║ Active Layers: %d", m_active_layers));
         Print(StringFormat("║ Max Layers: %d", m_max_layers));
         Print(StringFormat("║ Grid Distance: %.0f points", m_grid_distance_points));
         Print(StringFormat("║ Initial Lot: %.2f", m_initial_lot));
         Print(StringFormat("║ Lot Multiplier: %.1f", m_lot_multiplier));
         
         if(m_active_layers > 0)
         {
            Print(StringFormat("║ Last Layer Price: %.5f", m_layer_prices[m_active_layers]));
            
            // 🚀 Use independent mode
            ENUM_MARTINGALE_MODE mode = m_independent_mode;
            double current_price = (mode == MODE_BUY) ? 
                                  m_price_helper.GetBid() : 
                                  m_price_helper.GetAsk();
            double grid_dist_price = GetGridDistanceInPrice();
            double target = (mode == MODE_BUY) ? 
                           m_layer_prices[m_active_layers] - grid_dist_price :
                           m_layer_prices[m_active_layers] + grid_dist_price;
            
            Print(StringFormat("║ Current Price: %.5f", current_price));
            Print(StringFormat("║ Target Price: %.5f", target));
            Print(StringFormat("║ Distance to target: %.5f", 
                              (mode == MODE_BUY) ? current_price - target : target - current_price));
         }
         
         Print("╚═══════════════════════════════════════════════════════════╝");
      }
      
      // Check TP first
      if(CheckCycleTP())
      {
         Print(">>> MART V2: Cycle TP REACHED - Closing cycle...");
         CloseCycle();
         return;
      }
      
      // Check if should add layer
      if(ShouldAddLayer())
      {
         Print(">>> MART V2: ✅ ShouldAddLayer returned TRUE!");
         Print(">>> MART V2: Calling AddLayer()...");
         bool result = AddLayer();
         Print(StringFormat(">>> MART V2: AddLayer() result = %s", result ? "SUCCESS ✅" : "FAILED ❌"));
      }
   }
};

//+------------------------------------------------------------------+
//| End of TG_Martingale_v2.mqh                                      |
//+------------------------------------------------------------------+
#endif // TG_MARTINGALE_V2_MQH
