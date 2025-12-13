//+------------------------------------------------------------------+
//|                                        Core/TG_ErrorHandler.mqh  |
//|                                          Titan Grid EA v1.0      |
//|                               Error Handling & Retry System      |
//+------------------------------------------------------------------+
//| Location: C:\Users\ichza\AppData\Roaming\MetaQuotes\Terminal\   |
//|           D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\         |
//|           TitanGridEA\Core\TG_ErrorHandler.mqh                   |
//|                                                                  |
//| Purpose:  Centralized error handling for trading operations     |
//|           Retry logic for recoverable errors                    |
//|           Error classification and reporting                    |
//|           Dependencies: TG_Definitions.mqh                       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.00"

//+------------------------------------------------------------------+
//| CHANGE LOG                                                        |
//+------------------------------------------------------------------+
// Version 1.00 - 2025-01-20
// [INITIAL] Error handler created
// [ADD] Error classification (Critical/Recoverable/Retryable)
// [ADD] Retry logic with exponential backoff
// [ADD] Error message translation
// [ADD] Error statistics tracking
// [ADD] Alert generation for critical errors
//+------------------------------------------------------------------+

#ifndef TG_ERROR_HANDLER_MQH
#define TG_ERROR_HANDLER_MQH

#include "TG_Definitions.mqh"

//+------------------------------------------------------------------+
//| MQL5 TRADE RETURN CODES (from Trade Server)                      |
//+------------------------------------------------------------------+
// Using actual MQL5 return codes, not error codes
#define TRADE_RETCODE_REQUOTE            10004  // Requote
#define TRADE_RETCODE_REJECT             10006  // Request rejected
#define TRADE_RETCODE_CANCEL             10007  // Request canceled
#define TRADE_RETCODE_PLACED             10008  // Order placed
#define TRADE_RETCODE_DONE               10009  // Request completed
#define TRADE_RETCODE_DONE_PARTIAL       10010  // Partial fill
#define TRADE_RETCODE_ERROR              10011  // Request error
#define TRADE_RETCODE_TIMEOUT            10012  // Request timeout
#define TRADE_RETCODE_INVALID            10013  // Invalid request
#define TRADE_RETCODE_INVALID_VOLUME     10014  // Invalid volume
#define TRADE_RETCODE_INVALID_PRICE      10015  // Invalid price
#define TRADE_RETCODE_INVALID_STOPS      10016  // Invalid stops
#define TRADE_RETCODE_TRADE_DISABLED     10017  // Trade disabled
#define TRADE_RETCODE_MARKET_CLOSED      10018  // Market closed
#define TRADE_RETCODE_NO_MONEY           10019  // No money
#define TRADE_RETCODE_PRICE_CHANGED      10020  // Price changed
#define TRADE_RETCODE_PRICE_OFF          10021  // No prices
#define TRADE_RETCODE_INVALID_EXPIRATION 10022  // Invalid expiration
#define TRADE_RETCODE_ORDER_CHANGED      10023  // Order changed
#define TRADE_RETCODE_TOO_MANY_REQUESTS  10024  // Too many requests
#define TRADE_RETCODE_NO_CHANGES         10025  // No changes
#define TRADE_RETCODE_SERVER_DISABLES_AT 10026  // Autotrading disabled
#define TRADE_RETCODE_CLIENT_DISABLES_AT 10027  // Autotrading disabled by client
#define TRADE_RETCODE_LOCKED             10028  // Request locked
#define TRADE_RETCODE_FROZEN             10029  // Order/position frozen
#define TRADE_RETCODE_INVALID_FILL       10030  // Invalid fill
#define TRADE_RETCODE_CONNECTION         10031  // No connection
#define TRADE_RETCODE_ONLY_REAL          10032  // Only real allowed
#define TRADE_RETCODE_LIMIT_ORDERS       10033  // Orders limit reached
#define TRADE_RETCODE_LIMIT_VOLUME       10034  // Volume limit reached
#define TRADE_RETCODE_INVALID_ORDER      10035  // Invalid order
#define TRADE_RETCODE_POSITION_CLOSED    10036  // Position closed

//+------------------------------------------------------------------+
//| ERROR CATEGORY ENUMERATION                                        |
//+------------------------------------------------------------------+
enum ENUM_ERROR_CATEGORY
{
   ERROR_CAT_NONE,                    // No error
   ERROR_CAT_RETRYABLE,               // Can retry immediately
   ERROR_CAT_WAIT_AND_RETRY,          // Wait then retry
   ERROR_CAT_TERMINAL,                // Terminal issue (restart may help)
   ERROR_CAT_ACCOUNT,                 // Account issue (check settings)
   ERROR_CAT_CRITICAL                 // Critical (stop trading)
};

//+------------------------------------------------------------------+
//| ERROR STATISTICS STRUCTURE                                        |
//+------------------------------------------------------------------+
struct SErrorStatistics
{
   int total_errors;                  // Total errors encountered
   int retryable_errors;              // Errors that were retried
   int successful_retries;            // Retries that succeeded
   int failed_retries;                // Retries that failed
   int critical_errors;               // Critical errors
   datetime last_error_time;          // Last error timestamp
   int last_error_code;               // Last error code
   string last_error_desc;            // Last error description
   
   // Constructor
   SErrorStatistics()
   {
      Reset();
   }
   
   void Reset()
   {
      total_errors = 0;
      retryable_errors = 0;
      successful_retries = 0;
      failed_retries = 0;
      critical_errors = 0;
      last_error_time = 0;
      last_error_code = 0;
      last_error_desc = "";
   }
};

//+------------------------------------------------------------------+
//| ERROR HANDLER CLASS                                               |
//+------------------------------------------------------------------+
class CErrorHandler
{
private:
   int m_max_retries;                             // Maximum retry attempts
   int m_retry_delay_ms;                          // Base delay between retries (ms)
   bool m_use_exponential_backoff;                // Use exponential backoff
   bool m_send_alerts;                            // Send alerts for critical errors
   
   SErrorStatistics m_stats;                      // Error statistics
   
   //+------------------------------------------------------------------+
   //| Get Error Category                                               |
   //+------------------------------------------------------------------+
   ENUM_ERROR_CATEGORY GetErrorCategory(int error_code)
   {
      switch(error_code)
      {
         // === NO ERROR ===
         case ERR_SUCCESS:
         case TRADE_RETCODE_DONE:
         case TRADE_RETCODE_DONE_PARTIAL:
         case TRADE_RETCODE_PLACED:
            return ERROR_CAT_NONE;
         
         // === RETRYABLE IMMEDIATELY ===
         case TRADE_RETCODE_REQUOTE:          // Requote
         case TRADE_RETCODE_PRICE_CHANGED:    // Price changed
         case TRADE_RETCODE_PRICE_OFF:        // No prices
         case TRADE_RETCODE_TIMEOUT:          // Timeout
         case TRADE_RETCODE_TOO_MANY_REQUESTS: // Too many requests
            return ERROR_CAT_RETRYABLE;
         
         // === WAIT AND RETRY ===
         case TRADE_RETCODE_TRADE_DISABLED:   // Trade disabled
         case TRADE_RETCODE_MARKET_CLOSED:    // Market closed
         case TRADE_RETCODE_CONNECTION:       // No connection
         case TRADE_RETCODE_FROZEN:           // Frozen
         case TRADE_RETCODE_LOCKED:           // Locked
            return ERROR_CAT_WAIT_AND_RETRY;
         
         // === TERMINAL ISSUES ===
         case ERR_NOT_ENOUGH_MEMORY:          // Not enough memory
         case TRADE_RETCODE_SERVER_DISABLES_AT: // Server disabled AT
         case TRADE_RETCODE_CLIENT_DISABLES_AT: // Client disabled AT
            return ERROR_CAT_TERMINAL;
         
         // === ACCOUNT ISSUES ===
         case TRADE_RETCODE_NO_MONEY:         // Not enough money
         case TRADE_RETCODE_POSITION_CLOSED:  // Position closed
         case TRADE_RETCODE_LIMIT_ORDERS:     // Orders limit
         case TRADE_RETCODE_LIMIT_VOLUME:     // Volume limit
            return ERROR_CAT_ACCOUNT;
         
         // === CRITICAL ERRORS ===
         case TRADE_RETCODE_INVALID_STOPS:    // Invalid stops
         case TRADE_RETCODE_INVALID_VOLUME:   // Invalid volume
         case TRADE_RETCODE_INVALID_PRICE:    // Invalid price
         case TRADE_RETCODE_INVALID:          // Invalid request
         case TRADE_RETCODE_INVALID_ORDER:    // Invalid order
         case TRADE_RETCODE_INVALID_FILL:     // Invalid fill
         case TRADE_RETCODE_INVALID_EXPIRATION: // Invalid expiration
         case TRADE_RETCODE_ERROR:            // General error
         case TRADE_RETCODE_REJECT:           // Rejected
         default:
            // Unknown errors treated as critical
            return ERROR_CAT_CRITICAL;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get Error Description (Human Readable)                          |
   //+------------------------------------------------------------------+
   string GetErrorDescription(int error_code)
   {
      switch(error_code)
      {
         // Success codes
         case ERR_SUCCESS:
            return "No error";
         case TRADE_RETCODE_DONE:
            return "Request completed successfully";
         case TRADE_RETCODE_DONE_PARTIAL:
            return "Request partially filled";
         case TRADE_RETCODE_PLACED:
            return "Order placed";
         
         // Retryable
         case TRADE_RETCODE_REQUOTE:
            return "Requote received";
         case TRADE_RETCODE_PRICE_CHANGED:
            return "Price changed during execution";
         case TRADE_RETCODE_PRICE_OFF:
            return "No quotes available";
         case TRADE_RETCODE_TIMEOUT:
            return "Trade request timeout";
         case TRADE_RETCODE_TOO_MANY_REQUESTS:
            return "Too many requests";
         
         // Wait and retry
         case TRADE_RETCODE_TRADE_DISABLED:
            return "Trading is disabled";
         case TRADE_RETCODE_MARKET_CLOSED:
            return "Market is closed";
         case TRADE_RETCODE_CONNECTION:
            return "No connection to trade server";
         case TRADE_RETCODE_FROZEN:
            return "Order/position is frozen";
         case TRADE_RETCODE_LOCKED:
            return "Request is locked";
         
         // Terminal issues
         case ERR_NOT_ENOUGH_MEMORY:
            return "Not enough memory";
         case TRADE_RETCODE_SERVER_DISABLES_AT:
            return "AutoTrading disabled by server";
         case TRADE_RETCODE_CLIENT_DISABLES_AT:
            return "AutoTrading disabled by client";
         
         // Account issues
         case TRADE_RETCODE_NO_MONEY:
            return "Not enough money to execute trade";
         case TRADE_RETCODE_POSITION_CLOSED:
            return "Position already closed";
         case TRADE_RETCODE_LIMIT_ORDERS:
            return "Orders limit reached";
         case TRADE_RETCODE_LIMIT_VOLUME:
            return "Volume limit reached";
         
         // Critical errors
         case TRADE_RETCODE_INVALID_STOPS:
            return "Invalid stop loss or take profit";
         case TRADE_RETCODE_INVALID_VOLUME:
            return "Invalid volume (lot size)";
         case TRADE_RETCODE_INVALID_PRICE:
            return "Invalid price";
         case TRADE_RETCODE_INVALID:
            return "Invalid request";
         case TRADE_RETCODE_INVALID_ORDER:
            return "Invalid order";
         case TRADE_RETCODE_INVALID_FILL:
            return "Invalid fill type";
         case TRADE_RETCODE_INVALID_EXPIRATION:
            return "Invalid expiration";
         case TRADE_RETCODE_ERROR:
            return "General trade error";
         case TRADE_RETCODE_REJECT:
            return "Request rejected";
         case TRADE_RETCODE_CANCEL:
            return "Request canceled by trader";
         case TRADE_RETCODE_NO_CHANGES:
            return "No changes in request";
         case TRADE_RETCODE_ORDER_CHANGED:
            return "Order changed";
         case TRADE_RETCODE_ONLY_REAL:
            return "Only real accounts allowed";
         
         default:
            return "Unknown error code: " + IntegerToString(error_code);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Retry Delay (with exponential backoff)                |
   //+------------------------------------------------------------------+
   int CalculateRetryDelay(int attempt)
   {
      if(!m_use_exponential_backoff)
         return m_retry_delay_ms;
      
      // Exponential backoff: base_delay * 2^attempt
      // Example: 100ms, 200ms, 400ms, 800ms...
      int delay = m_retry_delay_ms * (int)MathPow(2, attempt);
      
      // Cap at 5 seconds
      if(delay > 5000)
         delay = 5000;
      
      return delay;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CErrorHandler()
   {
      m_max_retries = MAX_RETRIES;
      m_retry_delay_ms = 100;
      m_use_exponential_backoff = true;
      m_send_alerts = false;
   }
   
   //+------------------------------------------------------------------+
   //| Initialize Error Handler                                         |
   //+------------------------------------------------------------------+
   bool Initialize(int max_retries = 3,
                   int retry_delay_ms = 100,
                   bool exponential_backoff = true,
                   bool send_alerts = false)
   {
      m_max_retries = max_retries;
      m_retry_delay_ms = retry_delay_ms;
      m_use_exponential_backoff = exponential_backoff;
      m_send_alerts = send_alerts;
      
      Print("╔═══════════════════════════════════════════════════════════╗");
      Print("║           ERROR HANDLER INITIALIZED                      ║");
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ Max Retries:          ", m_max_retries);
      Print("║ Retry Delay:          ", m_retry_delay_ms, " ms");
      Print("║ Exponential Backoff:  ", (m_use_exponential_backoff ? "YES" : "NO"));
      Print("║ Send Alerts:          ", (m_send_alerts ? "YES" : "NO"));
      Print("╚═══════════════════════════════════════════════════════════╝");
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Handle Trading Error (Main Function)                            |
   //+------------------------------------------------------------------+
   bool HandleError(int error_code,
                    string operation,
                    ENUM_ERROR_SEVERITY &severity)
   {
      // Update statistics
      m_stats.total_errors++;
      m_stats.last_error_code = error_code;
      m_stats.last_error_time = TimeCurrent();
      m_stats.last_error_desc = GetErrorDescription(error_code);
      
      // Get error category
      ENUM_ERROR_CATEGORY category = GetErrorCategory(error_code);
      
      // Log error
      string error_msg = StringFormat(
         "⚠️ ERROR in %s: [%d] %s",
         operation,
         error_code,
         GetErrorDescription(error_code)
      );
      
      Print(error_msg);
      
      // Determine severity and action
      switch(category)
      {
         case ERROR_CAT_NONE:
            severity = ERROR_SEVERITY_INFO;
            return true; // No error, continue
         
         case ERROR_CAT_RETRYABLE:
            severity = ERROR_SEVERITY_WARNING;
            m_stats.retryable_errors++;
            Print("   → Category: RETRYABLE - Will retry operation");
            return false; // Caller should retry
         
         case ERROR_CAT_WAIT_AND_RETRY:
            severity = ERROR_SEVERITY_WARNING;
            m_stats.retryable_errors++;
            Print("   → Category: WAIT_AND_RETRY - Will wait then retry");
            Sleep(1000); // Wait 1 second
            return false; // Caller should retry
         
         case ERROR_CAT_TERMINAL:
            severity = ERROR_SEVERITY_ERROR;
            Print("   → Category: TERMINAL ISSUE");
            Print("   → Action: Check terminal settings and restart if needed");
            
            if(m_send_alerts)
               Alert("⚠️ Titan Grid EA: Terminal issue detected - ", GetErrorDescription(error_code));
            
            return false; // Cannot proceed
         
         case ERROR_CAT_ACCOUNT:
            severity = ERROR_SEVERITY_ERROR;
            Print("   → Category: ACCOUNT ISSUE");
            Print("   → Action: Check account settings, balance, and permissions");
            
            if(m_send_alerts)
               Alert("⚠️ Titan Grid EA: Account issue - ", GetErrorDescription(error_code));
            
            return false; // Cannot proceed
         
         case ERROR_CAT_CRITICAL:
            severity = ERROR_SEVERITY_CRITICAL;
            m_stats.critical_errors++;
            Print("   → Category: CRITICAL ERROR");
            Print("   → Action: Operation failed, check parameters");
            
            if(m_send_alerts)
               Alert("🚨 Titan Grid EA: CRITICAL ERROR - ", GetErrorDescription(error_code));
            
            return false; // Fatal error
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check Last Error and Report                                      |
   //+------------------------------------------------------------------+
   bool CheckLastError(string operation)
   {
      int error_code = GetLastError();
      
      if(error_code == 0)
         return true; // No error
      
      ENUM_ERROR_SEVERITY severity;
      return HandleError(error_code, operation, severity);
   }
   
   //+------------------------------------------------------------------+
   //| Validate Trade Request (Pre-check before sending)               |
   //+------------------------------------------------------------------+
   bool ValidateTradeRequest(double volume,
                             double price,
                             double sl,
                             double tp,
                             ENUM_ORDER_TYPE order_type,
                             string &error_msg)
   {
      // Get symbol info
      double min_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double max_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      
      // Check volume
      if(volume < min_volume)
      {
         error_msg = StringFormat("Volume %.2f below minimum %.2f", 
                                   volume, min_volume);
         return false;
      }
      
      if(volume > max_volume)
      {
         error_msg = StringFormat("Volume %.2f exceeds maximum %.2f", 
                                   volume, max_volume);
         return false;
      }
      
      // Check volume step
      double remainder = fmod(volume - min_volume, volume_step);
      if(remainder > 0.000001) // Small epsilon for floating point
      {
         error_msg = StringFormat("Volume %.2f not aligned with step %.2f", 
                                   volume, volume_step);
         return false;
      }
      
      // Check price (for pending orders)
      if(order_type == ORDER_TYPE_BUY_STOP || 
         order_type == ORDER_TYPE_BUY_LIMIT ||
         order_type == ORDER_TYPE_SELL_STOP || 
         order_type == ORDER_TYPE_SELL_LIMIT)
      {
         double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         int stop_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         double min_distance = stop_level * point;
         
         if(order_type == ORDER_TYPE_BUY_STOP)
         {
            if(price <= current_ask + min_distance)
            {
               error_msg = StringFormat("BUY STOP price %.5f too close to Ask %.5f (min: %.5f)",
                                        price, current_ask, current_ask + min_distance);
               return false;
            }
         }
         else if(order_type == ORDER_TYPE_SELL_STOP)
         {
            if(price >= current_bid - min_distance)
            {
               error_msg = StringFormat("SELL STOP price %.5f too close to Bid %.5f (min: %.5f)",
                                        price, current_bid, current_bid - min_distance);
               return false;
            }
         }
      }
      
      // Check SL/TP distance
      if(sl > 0 || tp > 0)
      {
         int stop_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         double min_distance = stop_level * point;
         
         if(sl > 0)
         {
            double sl_distance = MathAbs(price - sl);
            if(sl_distance < min_distance)
            {
               error_msg = StringFormat("SL distance %.5f below minimum %.5f",
                                        sl_distance, min_distance);
               return false;
            }
         }
         
         if(tp > 0)
         {
            double tp_distance = MathAbs(price - tp);
            if(tp_distance < min_distance)
            {
               error_msg = StringFormat("TP distance %.5f below minimum %.5f",
                                        tp_distance, min_distance);
               return false;
            }
         }
      }
      
      error_msg = "Validation passed";
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get Statistics                                                    |
   //+------------------------------------------------------------------+
   void GetStatistics(SErrorStatistics &stats)
   {
      stats = m_stats;
   }
   
   //+------------------------------------------------------------------+
   //| Print Statistics                                                  |
   //+------------------------------------------------------------------+
   void PrintStatistics()
   {
      Print("╔═══════════════════════════════════════════════════════════╗");
      Print("║              ERROR HANDLER STATISTICS                    ║");
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ Total Errors:         ", m_stats.total_errors);
      Print("║ Retryable Errors:     ", m_stats.retryable_errors);
      Print("║ Successful Retries:   ", m_stats.successful_retries);
      Print("║ Failed Retries:       ", m_stats.failed_retries);
      Print("║ Critical Errors:      ", m_stats.critical_errors);
      
      if(m_stats.total_errors > 0)
      {
         double success_rate = ((double)m_stats.successful_retries / 
                                (double)m_stats.retryable_errors) * 100.0;
         Print("║ Retry Success Rate:   ", DoubleToString(success_rate, 2), "%");
      }
      
      if(m_stats.last_error_code > 0)
      {
         Print("╠═══════════════════════════════════════════════════════════╣");
         Print("║ Last Error:                                               ║");
         Print("║   Code: ", m_stats.last_error_code);
         Print("║   Desc: ", m_stats.last_error_desc);
         Print("║   Time: ", TimeToString(m_stats.last_error_time));
      }
      
      Print("╚═══════════════════════════════════════════════════════════╝");
   }
   
   //+------------------------------------------------------------------+
   //| Reset Statistics                                                  |
   //+------------------------------------------------------------------+
   void ResetStatistics()
   {
      m_stats.Reset();
      Print("✅ Error statistics reset");
   }
   
   //+------------------------------------------------------------------+
   //| GETTERS                                                           |
   //+------------------------------------------------------------------+
   int GetTotalErrors() { return m_stats.total_errors; }
   int GetCriticalErrors() { return m_stats.critical_errors; }
   int GetLastErrorCode() { return m_stats.last_error_code; }
   string GetLastErrorDesc() { return m_stats.last_error_desc; }
};

//+------------------------------------------------------------------+
//| End of TG_ErrorHandler.mqh                                       |
//+------------------------------------------------------------------+
#endif // TG_ERROR_HANDLER_MQH
