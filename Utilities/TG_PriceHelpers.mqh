//+------------------------------------------------------------------+
//|                                Utilities/TG_PriceHelpers.mqh     |
//|                                          Titan Grid EA v1.0      |
//|                          Price Utilities & Grid Calculator       |
//+------------------------------------------------------------------+
//| Location: C:\Users\ichza\AppData\Roaming\MetaQuotes\Terminal\   |
//|           D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\         |
//|           TitanGridEA\Utilities\TG_PriceHelpers.mqh              |
//|                                                                  |
//| Purpose:  Price-related calculations and utilities              |
//|           Grid distance calculation (fixed/ATR)                 |
//|           Price normalization and validation                    |
//|           Spread, stop level checks                             |
//|           Dependencies: TG_Definitions.mqh                       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.00"

//+------------------------------------------------------------------+
//| CHANGE LOG                                                        |
//+------------------------------------------------------------------+
// Version 1.00 - 2025-01-20
// [INITIAL] Price helpers created
// [ADD] Grid distance calculation (fixed/ATR)
// [ADD] Price normalization
// [ADD] Distance in points/price conversion
// [ADD] Spread and stop level checks
// [ADD] Pending order price calculation
// [ADD] Break-even price calculation
//+------------------------------------------------------------------+

#ifndef TG_PRICE_HELPERS_MQH
#define TG_PRICE_HELPERS_MQH

#include "../Core/TG_Definitions.mqh"

//+------------------------------------------------------------------+
//| PRICE HELPER CLASS                                                |
//+------------------------------------------------------------------+
class CPriceHelper
{
private:
   string m_symbol;
   double m_point;                              // Point size
   int    m_digits;                             // Price digits
   double m_tick_size;                          // Tick size
   int    m_stops_level;                        // Minimum stop level
   
   // ATR settings
   int    m_atr_handle;                         // ATR indicator handle
   int    m_atr_period;                         // ATR period
   double m_atr_values[];                       // ATR values buffer
   
   //+------------------------------------------------------------------+
   //| Update Symbol Information                                        |
   //+------------------------------------------------------------------+
   bool UpdateSymbolInfo()
   {
      m_point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      m_tick_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      m_stops_level = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
      
      if(m_point <= 0 || m_digits < 0)
      {
         Print("❌ Invalid symbol info for: ", m_symbol);
         return false;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Initialize ATR Indicator                                         |
   //+------------------------------------------------------------------+
   bool InitializeATR(int period)
   {
      m_atr_period = period;
      
      m_atr_handle = iATR(m_symbol, PERIOD_CURRENT, m_atr_period);
      
      if(m_atr_handle == INVALID_HANDLE)
      {
         Print("❌ Failed to create ATR indicator");
         return false;
      }
      
      ArraySetAsSeries(m_atr_values, true);
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get ATR Value                                                    |
   //+------------------------------------------------------------------+
   double GetATRValue(int shift = 0)
   {
      if(m_atr_handle == INVALID_HANDLE)
         return 0;
      
      if(CopyBuffer(m_atr_handle, 0, shift, 1, m_atr_values) <= 0)
      {
         Print("⚠️ Failed to get ATR value");
         return 0;
      }
      
      return m_atr_values[0];
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CPriceHelper()
   {
      m_symbol = _Symbol;
      m_atr_handle = INVALID_HANDLE;
      m_atr_period = 14;
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~CPriceHelper()
   {
      if(m_atr_handle != INVALID_HANDLE)
         IndicatorRelease(m_atr_handle);
   }
   
   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   bool Initialize(int atr_period = 14)
   {
      if(!UpdateSymbolInfo())
         return false;
      
      if(!InitializeATR(atr_period))
         return false;
      
      Print("✅ Price Helper initialized");
      Print("   Symbol: ", m_symbol);
      Print("   Point: ", m_point);
      Print("   Digits: ", m_digits);
      Print("   Stops Level: ", m_stops_level);
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Normalize Price                                                   |
   //+------------------------------------------------------------------+
   double NormalizePrice(double price)
   {
      return NormalizeDouble(price, m_digits);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Grid Distance (Fixed Mode)                             |
   //+------------------------------------------------------------------+
   double CalculateFixedGridDistance(int points)
   {
      return points * m_point;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Grid Distance (ATR Mode)                               |
   //+------------------------------------------------------------------+
   double CalculateATRGridDistance(double multiplier, 
                                   int min_points, 
                                   int max_points)
   {
      double atr = GetATRValue();
      
      if(atr <= 0)
      {
         Print("⚠️ Invalid ATR, using min distance");
         return min_points * m_point;
      }
      
      // Calculate distance based on ATR
      double distance = atr * multiplier;
      
      // Apply min/max limits
      double min_distance = min_points * m_point;
      double max_distance = max_points * m_point;
      
      if(distance < min_distance)
         distance = min_distance;
      
      if(distance > max_distance)
         distance = max_distance;
      
      return NormalizePrice(distance);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Grid Distance (with Progressive Multiplier)            |
   //+------------------------------------------------------------------+
   double CalculateProgressiveGridDistance(double base_distance,
                                           int layer,
                                           double multiplier)
   {
      if(layer <= 1)
         return base_distance;
      
      // Progressive grid: distance increases with layer
      double distance = base_distance * MathPow(multiplier, layer - 1);
      
      return NormalizePrice(distance);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Next Layer Price                                       |
   //+------------------------------------------------------------------+
   double CalculateNextLayerPrice(double current_price,
                                  double grid_distance,
                                  ENUM_POSITION_TYPE direction)
   {
      double next_price;
      
      if(direction == POSITION_TYPE_BUY)
      {
         // BUY: next layer below current price
         next_price = current_price - grid_distance;
      }
      else
      {
         // SELL: next layer above current price
         next_price = current_price + grid_distance;
      }
      
      return NormalizePrice(next_price);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Break-Even Price                                       |
   //+------------------------------------------------------------------+
   double CalculateBreakEvenPrice(double total_buy_lots,
                                  double total_buy_weighted_price,
                                  double total_sell_lots,
                                  double total_sell_weighted_price)
   {
      // Weighted average of all positions
      double total_lots = total_buy_lots + total_sell_lots;
      
      if(total_lots <= 0)
         return 0;
      
      double weighted_sum = (total_buy_weighted_price * total_buy_lots) +
                           (total_sell_weighted_price * total_sell_lots);
      
      return NormalizePrice(weighted_sum / total_lots);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Pending Order Price                                    |
   //+------------------------------------------------------------------+
   double CalculatePendingOrderPrice(ENUM_ORDER_TYPE order_type,
                                     int distance_points)
   {
      double current_ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double current_bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double distance = distance_points * m_point;
      
      double price = 0;
      
      switch(order_type)
      {
         case ORDER_TYPE_BUY_STOP:
            // Above current ask
            price = current_ask + distance;
            break;
         
         case ORDER_TYPE_BUY_LIMIT:
            // Below current ask
            price = current_ask - distance;
            break;
         
         case ORDER_TYPE_SELL_STOP:
            // Below current bid
            price = current_bid - distance;
            break;
         
         case ORDER_TYPE_SELL_LIMIT:
            // Above current bid
            price = current_bid + distance;
            break;
         
         default:
            Print("⚠️ Invalid order type for pending order");
            return 0;
      }
      
      return NormalizePrice(price);
   }
   
   //+------------------------------------------------------------------+
   //| Convert Points to Price                                          |
   //+------------------------------------------------------------------+
   double PointsToPrice(int points)
   {
      return points * m_point;
   }
   
   //+------------------------------------------------------------------+
   //| Convert Price to Points                                          |
   //+------------------------------------------------------------------+
   int PriceToPoints(double price_distance)
   {
      return (int)(price_distance / m_point);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Distance Between Prices (in points)                    |
   //+------------------------------------------------------------------+
   int CalculateDistancePoints(double price1, double price2)
   {
      return (int)(MathAbs(price1 - price2) / m_point);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Distance Between Prices (in price)                     |
   //+------------------------------------------------------------------+
   double CalculateDistancePrice(double price1, double price2)
   {
      return NormalizePrice(MathAbs(price1 - price2));
   }
   
   //+------------------------------------------------------------------+
   //| Check if Distance Meets Minimum Stop Level                       |
   //+------------------------------------------------------------------+
   bool CheckStopLevelDistance(double price1, double price2, string &error_msg)
   {
      if(m_stops_level == 0)
      {
         error_msg = "Stop level check passed (no minimum)";
         return true;
      }
      
      int distance_points = CalculateDistancePoints(price1, price2);
      
      if(distance_points < m_stops_level)
      {
         error_msg = StringFormat("Distance %d points below minimum %d points",
                                   distance_points, m_stops_level);
         return false;
      }
      
      error_msg = "Stop level check passed";
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get Current Spread                                               |
   //+------------------------------------------------------------------+
   int GetSpreadPoints()
   {
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      return CalculateDistancePoints(ask, bid);
   }
   
   //+------------------------------------------------------------------+
   //| Get Current Spread in Price                                      |
   //+------------------------------------------------------------------+
   double GetSpreadPrice()
   {
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      return NormalizePrice(ask - bid);
   }
   
   //+------------------------------------------------------------------+
   //| Check if Spread is Acceptable                                    |
   //+------------------------------------------------------------------+
   bool CheckSpread(int max_spread_points, string &error_msg)
   {
      int current_spread = GetSpreadPoints();
      
      if(current_spread > max_spread_points)
      {
         error_msg = StringFormat("Spread %d points exceeds maximum %d points",
                                   current_spread, max_spread_points);
         return false;
      }
      
      error_msg = "Spread check passed";
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get Current Ask                                                  |
   //+------------------------------------------------------------------+
   double GetAsk()
   {
      return SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   }
   
   //+------------------------------------------------------------------+
   //| Get Current Bid                                                  |
   //+------------------------------------------------------------------+
   double GetBid()
   {
      return SymbolInfoDouble(m_symbol, SYMBOL_BID);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Stop Loss Price                                        |
   //+------------------------------------------------------------------+
   double CalculateSLPrice(ENUM_POSITION_TYPE position_type,
                          double entry_price,
                          int sl_points)
   {
      if(sl_points <= 0)
         return 0;
      
      double sl_price;
      
      if(position_type == POSITION_TYPE_BUY)
      {
         sl_price = entry_price - (sl_points * m_point);
      }
      else
      {
         sl_price = entry_price + (sl_points * m_point);
      }
      
      return NormalizePrice(sl_price);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Take Profit Price                                      |
   //+------------------------------------------------------------------+
   double CalculateTPPrice(ENUM_POSITION_TYPE position_type,
                          double entry_price,
                          int tp_points)
   {
      if(tp_points <= 0)
         return 0;
      
      double tp_price;
      
      if(position_type == POSITION_TYPE_BUY)
      {
         tp_price = entry_price + (tp_points * m_point);
      }
      else
      {
         tp_price = entry_price - (tp_points * m_point);
      }
      
      return NormalizePrice(tp_price);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Profit in Currency                                     |
   //+------------------------------------------------------------------+
   double CalculateProfitCurrency(ENUM_POSITION_TYPE position_type,
                                  double entry_price,
                                  double exit_price,
                                  double lot)
   {
      double point_value = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double tick_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      
      double price_diff;
      
      if(position_type == POSITION_TYPE_BUY)
         price_diff = exit_price - entry_price;
      else
         price_diff = entry_price - exit_price;
      
      double profit = (price_diff / tick_size) * point_value * lot;
      
      return NormalizeDouble(profit, 2);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Required Price Move for Target Profit                  |
   //+------------------------------------------------------------------+
   double CalculateRequiredPriceMove(ENUM_POSITION_TYPE position_type,
                                     double entry_price,
                                     double lot,
                                     double target_profit)
   {
      double point_value = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double tick_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      
      // Calculate required price move
      double required_move = (target_profit / (point_value * lot)) * tick_size;
      
      double target_price;
      
      if(position_type == POSITION_TYPE_BUY)
         target_price = entry_price + required_move;
      else
         target_price = entry_price - required_move;
      
      return NormalizePrice(target_price);
   }
   
   //+------------------------------------------------------------------+
   //| Validate Price                                                    |
   //+------------------------------------------------------------------+
   bool ValidatePrice(double price, string &error_msg)
   {
      if(price <= 0)
      {
         error_msg = "Price must be greater than 0";
         return false;
      }
      
      // Check if price is reasonable (not too far from current)
      double current_price = (GetAsk() + GetBid()) / 2;
      double max_deviation = current_price * 0.5; // 50% deviation max
      
      if(MathAbs(price - current_price) > max_deviation)
      {
         error_msg = StringFormat("Price %.5f too far from current %.5f",
                                   price, current_price);
         return false;
      }
      
      error_msg = "Price validation passed";
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Print Price Information                                          |
   //+------------------------------------------------------------------+
   void PrintPriceInfo()
   {
      double ask = GetAsk();
      double bid = GetBid();
      int spread = GetSpreadPoints();
      double atr = GetATRValue();
      
      Print("╔═══════════════════════════════════════════════════════════╗");
      Print("║                 PRICE INFORMATION                         ║");
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ Symbol:        ", m_symbol);
      Print("║ Ask:           ", DoubleToString(ask, m_digits));
      Print("║ Bid:           ", DoubleToString(bid, m_digits));
      Print("║ Spread:        ", spread, " points");
      Print("║ Point Size:    ", m_point);
      Print("║ Digits:        ", m_digits);
      Print("║ Stops Level:   ", m_stops_level, " points");
      Print("║ ATR Value:     ", DoubleToString(atr, m_digits));
      Print("╚═══════════════════════════════════════════════════════════╝");
   }
   
   //+------------------------------------------------------------------+
   //| GETTERS                                                           |
   //+------------------------------------------------------------------+
   double GetPoint() { return m_point; }
   int GetDigits() { return m_digits; }
   int GetStopsLevel() { return m_stops_level; }
   double GetATR() { return GetATRValue(); }
};

//+------------------------------------------------------------------+
//| End of TG_PriceHelpers.mqh                                       |
//+------------------------------------------------------------------+
#endif // TG_PRICE_HELPERS_MQH
