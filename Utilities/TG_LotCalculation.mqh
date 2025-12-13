//+------------------------------------------------------------------+
//|                              Utilities/TG_LotCalculation.mqh     |
//|                                          Titan Grid EA v1.0      |
//|                              Lot Calculation Engine              |
//+------------------------------------------------------------------+
//| Location: C:\Users\ichza\AppData\Roaming\MetaQuotes\Terminal\   |
//|           D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\         |
//|           TitanGridEA\Utilities\TG_LotCalculation.mqh            |
//|                                                                  |
//| Purpose:  Calculate lot sizes for all scenarios                 |
//|           Fixed, Dynamic Risk, Balance Percent modes            |
//|           Martingale progression (multiply/add)                 |
//|           Lot normalization and validation                      |
//|           Dependencies: TG_Definitions.mqh                       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.00"

//+------------------------------------------------------------------+
//| CHANGE LOG                                                        |
//+------------------------------------------------------------------+
// Version 1.00 - 2025-01-20
// [INITIAL] Lot calculation system created
// [ADD] Fixed lot mode
// [ADD] Dynamic risk calculation
// [ADD] Balance percent calculation
// [ADD] Martingale progression (multiply/add modes)
// [ADD] Progressive multiplier with decay
// [ADD] Lot normalization (volume step, min/max)
// [ADD] Validation with detailed error messages
//+------------------------------------------------------------------+

#ifndef TG_LOT_CALCULATION_MQH
#define TG_LOT_CALCULATION_MQH

#include "../Core/TG_Definitions.mqh"

//+------------------------------------------------------------------+
//| LOT CALCULATOR CLASS                                              |
//+------------------------------------------------------------------+
class CLotCalculator
{
private:
   // Symbol information
   string m_symbol;
   double m_volume_min;                        // Min lot size
   double m_volume_max;                        // Max lot size  
   double m_volume_step;                       // Lot size step
   double m_tick_value;                        // Tick value in account currency
   double m_tick_size;                         // Tick size in price
   int    m_digits;                            // Symbol digits
   
   // Settings
   ENUM_LOT_MODE m_lot_mode;                   // Lot calculation mode
   double m_fixed_lot;                         // Fixed lot size
   double m_risk_percent;                      // Risk percent
   int    m_risk_points;                       // Risk points (for SL calculation)
   double m_balance_percent;                   // Balance percent
   double m_min_lot;                           // Minimum lot (user setting)
   double m_max_lot;                           // Maximum lot (user setting)
   
   // Martingale settings
   ENUM_PROGRESSION_MODE m_progression_mode;   // Progression mode
   double m_lot_multiplier;                    // Lot multiplier
   double m_lot_add_value;                     // Lot add value
   bool   m_use_progressive_multiplier;        // Use progressive multiplier
   double m_multiplier_decay;                  // Multiplier decay per layer
   
   //+------------------------------------------------------------------+
   //| Update Symbol Information                                        |
   //+------------------------------------------------------------------+
   bool UpdateSymbolInfo()
   {
      m_volume_min = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      m_volume_max = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      m_volume_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      m_tick_value = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      m_tick_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      
      if(m_volume_min <= 0 || m_volume_max <= 0 || m_volume_step <= 0)
      {
         Print("❌ Invalid symbol info: ", m_symbol);
         return false;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Normalize Lot Size                                              |
   //+------------------------------------------------------------------+
   double NormalizeLot(double lot)
   {
      // Round to volume step
      double normalized = MathRound(lot / m_volume_step) * m_volume_step;
      
      // Apply min/max limits
      if(normalized < m_volume_min)
         normalized = m_volume_min;
      
      if(normalized > m_volume_max)
         normalized = m_volume_max;
      
      // Apply user limits
      if(normalized < m_min_lot)
         normalized = m_min_lot;
      
      if(normalized > m_max_lot)
         normalized = m_max_lot;
      
      // Format to proper decimals
      normalized = NormalizeDouble(normalized, 2);
      
      return normalized;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CLotCalculator()
   {
      m_symbol = _Symbol;
      m_lot_mode = LOT_MODE_FIXED;
      m_fixed_lot = 0.01;
      m_risk_percent = 1.0;
      m_risk_points = 500;
      m_balance_percent = 1.0;
      m_min_lot = 0.01;
      m_max_lot = 10.0;
      
      m_progression_mode = PROGRESSION_MULTIPLY;
      m_lot_multiplier = 2.0;
      m_lot_add_value = 0.01;
      m_use_progressive_multiplier = false;
      m_multiplier_decay = 0.1;
   }
   
   //+------------------------------------------------------------------+
   //| Initialize Calculator                                            |
   //+------------------------------------------------------------------+
   bool Initialize(ENUM_LOT_MODE lot_mode,
                   double fixed_lot,
                   double risk_percent,
                   int risk_points,
                   double balance_percent,
                   double min_lot,
                   double max_lot,
                   ENUM_PROGRESSION_MODE progression_mode,
                   double lot_multiplier,
                   double lot_add_value,
                   bool use_progressive_multiplier = false,
                   double multiplier_decay = 0.1)
   {
      m_lot_mode = lot_mode;
      m_fixed_lot = fixed_lot;
      m_risk_percent = risk_percent;
      m_risk_points = risk_points;
      m_balance_percent = balance_percent;
      m_min_lot = min_lot;
      m_max_lot = max_lot;
      
      m_progression_mode = progression_mode;
      m_lot_multiplier = lot_multiplier;
      m_lot_add_value = lot_add_value;
      m_use_progressive_multiplier = use_progressive_multiplier;
      m_multiplier_decay = multiplier_decay;
      
      // Update symbol info
      if(!UpdateSymbolInfo())
         return false;
      
      Print("╔═══════════════════════════════════════════════════════════╗");
      Print("║           LOT CALCULATOR INITIALIZED                      ║");
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ Symbol:           ", m_symbol);
      Print("║ Volume Min:       ", m_volume_min);
      Print("║ Volume Max:       ", m_volume_max);
      Print("║ Volume Step:      ", m_volume_step);
      Print("║ Lot Mode:         ", EnumToString(m_lot_mode));
      Print("║ Progression:      ", EnumToString(m_progression_mode));
      Print("╚═══════════════════════════════════════════════════════════╝");
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Initial Lot (Layer 1)                                 |
   //+------------------------------------------------------------------+
   double CalculateInitialLot()
   {
      double lot = 0;
      
      switch(m_lot_mode)
      {
         case LOT_MODE_FIXED:
            lot = m_fixed_lot;
            break;
         
         case LOT_MODE_DYNAMIC_RISK:
            lot = CalculateDynamicRiskLot();
            break;
         
         case LOT_MODE_BALANCE_PERCENT:
            lot = CalculateBalancePercentLot();
            break;
         
         default:
            lot = m_fixed_lot;
            break;
      }
      
      return NormalizeLot(lot);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Dynamic Risk Lot                                       |
   //+------------------------------------------------------------------+
   double CalculateDynamicRiskLot()
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double risk_amount = balance * (m_risk_percent / 100.0);
      
      // Convert points to price
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double risk_price = m_risk_points * point;
      
      // Calculate lot size
      // risk_amount = lot * risk_price * tick_value / tick_size
      double lot = risk_amount / (risk_price * m_tick_value / m_tick_size);
      
      return lot;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Balance Percent Lot                                    |
   //+------------------------------------------------------------------+
   double CalculateBalancePercentLot()
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      
      // Simple formula: lot = (balance * percent) / reference_value
      // Using 10000 as reference (typical lot size relation)
      double lot = (balance * m_balance_percent / 100.0) / 10000.0;
      
      return lot;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Next Layer Lot (Martingale Progression)               |
   //+------------------------------------------------------------------+
   double CalculateNextLayerLot(double previous_lot, int layer)
   {
      if(layer < 1)
      {
         Print("⚠️ Invalid layer: ", layer);
         return previous_lot;
      }
      
      double next_lot = 0;
      
      switch(m_progression_mode)
      {
         case PROGRESSION_MULTIPLY:
            next_lot = CalculateMultiplyProgression(previous_lot, layer);
            break;
         
         case PROGRESSION_ADD:
            next_lot = CalculateAddProgression(previous_lot, layer);
            break;
         
         case PROGRESSION_FIBONACCI:
            next_lot = CalculateFibonacciProgression(previous_lot, layer);
            break;
         
         default:
            next_lot = previous_lot;
            break;
      }
      
      return NormalizeLot(next_lot);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Multiply Progression                                   |
   //+------------------------------------------------------------------+
   double CalculateMultiplyProgression(double previous_lot, int layer)
   {
      double multiplier = m_lot_multiplier;
      
      // Apply progressive multiplier decay if enabled
      if(m_use_progressive_multiplier && layer > 1)
      {
         // Example: Layer 2: 2.0, Layer 3: 1.8, Layer 4: 1.6, etc.
         multiplier = m_lot_multiplier - ((layer - 1) * m_multiplier_decay);
         
         // Don't let multiplier go below 1.0
         if(multiplier < 1.0)
            multiplier = 1.0;
      }
      
      return previous_lot * multiplier;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Add Progression                                        |
   //+------------------------------------------------------------------+
   double CalculateAddProgression(double previous_lot, int layer)
   {
      return previous_lot + m_lot_add_value;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Fibonacci Progression                                  |
   //+------------------------------------------------------------------+
   double CalculateFibonacciProgression(double base_lot, int layer)
   {
      // Fibonacci sequence: 1, 1, 2, 3, 5, 8, 13, 21...
      int fib_current = 1;
      int fib_previous = 1;
      
      for(int i = 2; i <= layer; i++)
      {
         int temp = fib_current;
         fib_current = fib_current + fib_previous;
         fib_previous = temp;
      }
      
      return base_lot * fib_current;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Total Lot for Multiple Layers                         |
   //+------------------------------------------------------------------+
   double CalculateTotalLot(double initial_lot, int layers)
   {
      double total = initial_lot;
      double current_lot = initial_lot;
      
      for(int i = 2; i <= layers; i++)
      {
         current_lot = CalculateNextLayerLot(current_lot, i);
         total += current_lot;
      }
      
      return NormalizeDouble(total, 2);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Lot Array for All Layers                              |
   //+------------------------------------------------------------------+
   void CalculateLotArray(double initial_lot, int max_layers, double &lots[])
   {
      ArrayResize(lots, max_layers);
      
      lots[0] = initial_lot;
      
      for(int i = 1; i < max_layers; i++)
      {
         lots[i] = CalculateNextLayerLot(lots[i-1], i+1);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Validate Lot Size                                                |
   //+------------------------------------------------------------------+
   bool ValidateLot(double lot, string &error_msg)
   {
      // Check against symbol limits
      if(lot < m_volume_min)
      {
         error_msg = StringFormat("Lot %.2f below symbol minimum %.2f", 
                                   lot, m_volume_min);
         return false;
      }
      
      if(lot > m_volume_max)
      {
         error_msg = StringFormat("Lot %.2f exceeds symbol maximum %.2f", 
                                   lot, m_volume_max);
         return false;
      }
      
      // Check against user limits
      if(lot < m_min_lot)
      {
         error_msg = StringFormat("Lot %.2f below user minimum %.2f", 
                                   lot, m_min_lot);
         return false;
      }
      
      if(lot > m_max_lot)
      {
         error_msg = StringFormat("Lot %.2f exceeds user maximum %.2f", 
                                   lot, m_max_lot);
         return false;
      }
      
      // Check volume step alignment
      double remainder = fmod(lot - m_volume_min, m_volume_step);
      if(remainder > 0.000001)
      {
         error_msg = StringFormat("Lot %.2f not aligned with volume step %.2f", 
                                   lot, m_volume_step);
         return false;
      }
      
      error_msg = "Lot validation passed";
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Check if Total Lot Exceeds Limit                                |
   //+------------------------------------------------------------------+
   bool CheckTotalLotLimit(double current_total_lot, 
                          double additional_lot,
                          double max_total_lot,
                          string &error_msg)
   {
      if(max_total_lot <= 0)
      {
         error_msg = "Total lot limit not set";
         return true; // No limit, so always OK
      }
      
      double new_total = current_total_lot + additional_lot;
      
      if(new_total > max_total_lot)
      {
         error_msg = StringFormat("Total lot %.2f + %.2f = %.2f exceeds limit %.2f",
                                   current_total_lot, additional_lot, 
                                   new_total, max_total_lot);
         return false;
      }
      
      error_msg = "Total lot check passed";
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Check Margin Requirements                                        |
   //+------------------------------------------------------------------+
   bool CheckMarginRequirement(double lot, 
                               ENUM_ORDER_TYPE order_type,
                               string &error_msg)
   {
      // Get current free margin
      double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      
      // Calculate required margin for this lot
      double price = (order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_BUY_STOP) ?
                     SymbolInfoDouble(m_symbol, SYMBOL_ASK) :
                     SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      double margin_required = 0;
      
      if(!OrderCalcMargin(order_type, m_symbol, lot, price, margin_required))
      {
         error_msg = "Failed to calculate margin requirement";
         return false;
      }
      
      if(margin_required > free_margin)
      {
         error_msg = StringFormat("Insufficient margin: Required %.2f, Available %.2f",
                                   margin_required, free_margin);
         return false;
      }
      
      error_msg = "Margin check passed";
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Print Lot Progression Table                                      |
   //+------------------------------------------------------------------+
   void PrintLotProgressionTable(int max_layers)
   {
      double initial_lot = CalculateInitialLot();
      
      Print("╔═══════════════════════════════════════════════════════════╗");
      Print("║              LOT PROGRESSION TABLE                        ║");
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ Mode: ", EnumToString(m_lot_mode));
      Print("║ Progression: ", EnumToString(m_progression_mode));
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ Layer │    Lot    │  Cumulative  │  Multiplier            ║");
      Print("╠═══════════════════════════════════════════════════════════╣");
      
      double current_lot = initial_lot;
      double total_lot = initial_lot;
      
      Print("║   L1  │ ", DoubleToString(current_lot, 2), "  │  ", 
            DoubleToString(total_lot, 2), "     │     -              ║");
      
      for(int i = 2; i <= max_layers; i++)
      {
         double next_lot = CalculateNextLayerLot(current_lot, i);
         total_lot += next_lot;
         double multiplier = next_lot / current_lot;
         
         Print("║   L", i, "  │ ", DoubleToString(next_lot, 2), "  │  ", 
               DoubleToString(total_lot, 2), "     │  x", 
               DoubleToString(multiplier, 2), "          ║");
         
         current_lot = next_lot;
      }
      
      Print("╚═══════════════════════════════════════════════════════════╝");
   }
   
   //+------------------------------------------------------------------+
   //| GETTERS                                                           |
   //+------------------------------------------------------------------+
   double GetVolumeMin() { return m_volume_min; }
   double GetVolumeMax() { return m_volume_max; }
   double GetVolumeStep() { return m_volume_step; }
   ENUM_LOT_MODE GetLotMode() { return m_lot_mode; }
   ENUM_PROGRESSION_MODE GetProgressionMode() { return m_progression_mode; }
};

//+------------------------------------------------------------------+
//| End of TG_LotCalculation.mqh                                     |
//+------------------------------------------------------------------+
#endif // TG_LOT_CALCULATION_MQH
