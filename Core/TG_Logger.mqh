//+------------------------------------------------------------------+
//|                                             Core/TG_Logger.mqh   |
//|                                          Titan Grid EA v1.0      |
//|                                     Logging & Debug System       |
//+------------------------------------------------------------------+
//| Location: C:\Users\ichza\AppData\Roaming\MetaQuotes\Terminal\   |
//|           D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\         |
//|           TitanGridEA\Core\TG_Logger.mqh                         |
//|                                                                  |
//| Purpose:  Centralized logging system for debugging and auditing |
//|           Multiple log levels (Debug, Info, Warning, Error)     |
//|           File logging with rotation                            |
//|           Dependencies: TG_Definitions.mqh                       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.00"

//+------------------------------------------------------------------+
//| CHANGE LOG                                                        |
//+------------------------------------------------------------------+
// Version 1.00 - 2025-01-20
// [INITIAL] Logger system created
// [ADD] Multiple log levels (None, Error, Warning, Info, Debug)
// [ADD] File logging with daily rotation
// [ADD] Console logging with color coding
// [ADD] Trade operation logging
// [ADD] Performance statistics logging
// [ADD] Log file management (size limit, archiving)
//+------------------------------------------------------------------+

#ifndef TG_LOGGER_MQH
#define TG_LOGGER_MQH

#include "TG_Definitions.mqh"

//+------------------------------------------------------------------+
//| LOGGER CLASS                                                      |
//+------------------------------------------------------------------+
class CLogger
{
private:
   ENUM_LOG_LEVEL m_log_level;                    // Current log level
   bool           m_log_to_file;                  // Enable file logging
   bool           m_log_to_console;               // Enable console logging
   string         m_log_file_path;                // Current log file path
   int            m_log_file_handle;              // File handle
   datetime       m_log_file_date;                // Current log file date
   
   // Statistics
   int            m_total_logs;                   // Total log entries
   int            m_error_count;                  // Error count
   int            m_warning_count;                // Warning count
   int            m_info_count;                   // Info count
   int            m_debug_count;                  // Debug count
   
   // Settings
   int            m_max_file_size_kb;             // Max file size before rotation
   bool           m_include_timestamp;            // Include timestamp in logs
   bool           m_include_level;                // Include log level in logs
   
   //+------------------------------------------------------------------+
   //| Get Log Level String                                            |
   //+------------------------------------------------------------------+
   string GetLogLevelString(ENUM_LOG_LEVEL level)
   {
      switch(level)
      {
         case LOG_LEVEL_ERROR:   return "ERROR";
         case LOG_LEVEL_WARNING: return "WARN ";
         case LOG_LEVEL_INFO:    return "INFO ";
         case LOG_LEVEL_DEBUG:   return "DEBUG";
         default:                return "     ";
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get Log Level Emoji                                             |
   //+------------------------------------------------------------------+
   string GetLogLevelEmoji(ENUM_LOG_LEVEL level)
   {
      switch(level)
      {
         case LOG_LEVEL_ERROR:   return "❌";
         case LOG_LEVEL_WARNING: return "⚠️";
         case LOG_LEVEL_INFO:    return "ℹ️";
         case LOG_LEVEL_DEBUG:   return "🔧";
         default:                return "  ";
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check if should log based on level                              |
   //+------------------------------------------------------------------+
   bool ShouldLog(ENUM_LOG_LEVEL level)
   {
      // If logging is disabled
      if(m_log_level == LOG_LEVEL_NONE)
         return false;
      
      // Check if message level is important enough
      return (level <= m_log_level);
   }
   
   //+------------------------------------------------------------------+
   //| Format Log Message                                               |
   //+------------------------------------------------------------------+
   string FormatLogMessage(ENUM_LOG_LEVEL level, string message)
   {
      string formatted = "";
      
      // Add timestamp
      if(m_include_timestamp)
      {
         formatted += TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + " ";
      }
      
      // Add log level
      if(m_include_level)
      {
         formatted += "[" + GetLogLevelString(level) + "] ";
      }
      
      // Add emoji (for console only)
      if(m_log_to_console)
      {
         formatted += GetLogLevelEmoji(level) + " ";
      }
      
      // Add message
      formatted += message;
      
      return formatted;
   }
   
   //+------------------------------------------------------------------+
   //| Check and Rotate Log File                                       |
   //+------------------------------------------------------------------+
   bool CheckAndRotateLogFile()
   {
      // Check if date changed
      MqlDateTime now;
      TimeToStruct(TimeCurrent(), now);
      
      MqlDateTime file_date;
      TimeToStruct(m_log_file_date, file_date);
      
      bool date_changed = (now.day != file_date.day || 
                          now.mon != file_date.mon || 
                          now.year != file_date.year);
      
      // Check file size
      bool size_exceeded = false;
      
      if(m_log_file_handle != INVALID_HANDLE)
      {
         ulong file_size = FileSize(m_log_file_handle);
         size_exceeded = (file_size > (ulong)(m_max_file_size_kb * 1024));
      }
      
      // Rotate if needed
      if(date_changed || size_exceeded)
      {
         CloseLogFile();
         
         string reason = date_changed ? "Date changed" : "Size limit reached";
         Print("📁 Log file rotation: ", reason);
         
         return OpenLogFile();
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Open Log File                                                    |
   //+------------------------------------------------------------------+
   bool OpenLogFile()
   {
      if(!m_log_to_file)
         return true;
      
      // Generate file name with date
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      string date_str = StringFormat("%04d%02d%02d", dt.year, dt.mon, dt.day);
      string filename = StringFormat("TitanGrid_%s.log", date_str);
      
      m_log_file_path = filename;
      m_log_file_date = TimeCurrent();
      
      // Open file (append mode)
      m_log_file_handle = FileOpen(filename, FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI);
      
      if(m_log_file_handle == INVALID_HANDLE)
      {
         Print("❌ Failed to open log file: ", filename);
         Print("   Error: ", GetLastError());
         return false;
      }
      
      // Move to end of file
      FileSeek(m_log_file_handle, 0, SEEK_END);
      
      // Write header
      string header = "\n" + StringFormat("%79s\n", "=");
      header += "Titan Grid EA - Session Start: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\n";
      header += StringFormat("%79s\n", "=");
      
      FileWriteString(m_log_file_handle, header);
      FileFlush(m_log_file_handle);
      
      Print("✅ Log file opened: ", filename);
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Close Log File                                                   |
   //+------------------------------------------------------------------+
   void CloseLogFile()
   {
      if(m_log_file_handle != INVALID_HANDLE)
      {
         // Write footer
         string footer = "\n" + StringFormat("%79s\n", "-");
         footer += "Session End: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\n";
         footer += "Total Logs: " + IntegerToString(m_total_logs);
         footer += " (Errors: " + IntegerToString(m_error_count);
         footer += ", Warnings: " + IntegerToString(m_warning_count);
         footer += ", Info: " + IntegerToString(m_info_count);
         footer += ", Debug: " + IntegerToString(m_debug_count) + ")\n";
         footer += StringFormat("%79s\n\n", "=");
         
         FileWriteString(m_log_file_handle, footer);
         FileFlush(m_log_file_handle);
         FileClose(m_log_file_handle);
         
         m_log_file_handle = INVALID_HANDLE;
         
         Print("📁 Log file closed: ", m_log_file_path);
      }
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CLogger()
   {
      m_log_level = LOG_LEVEL_INFO;
      m_log_to_file = true;
      m_log_to_console = true;
      m_log_file_handle = INVALID_HANDLE;
      m_log_file_date = 0;
      
      m_total_logs = 0;
      m_error_count = 0;
      m_warning_count = 0;
      m_info_count = 0;
      m_debug_count = 0;
      
      m_max_file_size_kb = 5120; // 5 MB default
      m_include_timestamp = true;
      m_include_level = true;
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~CLogger()
   {
      CloseLogFile();
   }
   
   //+------------------------------------------------------------------+
   //| Initialize Logger                                                |
   //+------------------------------------------------------------------+
   bool Initialize(ENUM_LOG_LEVEL level = LOG_LEVEL_INFO,
                   bool log_to_file = true,
                   bool log_to_console = true,
                   int max_file_size_kb = 5120)
   {
      m_log_level = level;
      m_log_to_file = log_to_file;
      m_log_to_console = log_to_console;
      m_max_file_size_kb = max_file_size_kb;
      
      Print("╔═══════════════════════════════════════════════════════════╗");
      Print("║               LOGGER INITIALIZED                          ║");
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ Log Level:        ", EnumToString(m_log_level));
      Print("║ File Logging:     ", (m_log_to_file ? "ENABLED" : "DISABLED"));
      Print("║ Console Logging:  ", (m_log_to_console ? "ENABLED" : "DISABLED"));
      Print("║ Max File Size:    ", m_max_file_size_kb, " KB");
      Print("╚═══════════════════════════════════════════════════════════╝");
      
      if(m_log_to_file)
      {
         if(!OpenLogFile())
         {
            Print("⚠️ File logging disabled (cannot open file - may be Strategy Tester restriction)");
            Print("   Continuing with console logging only...");
            m_log_to_file = false; // Disable file logging, continue with console
         }
      }
      
      return true; // Always return true - console logging is enough
   }
   
   //+------------------------------------------------------------------+
   //| Core Log Function                                                |
   //+------------------------------------------------------------------+
   void Log(ENUM_LOG_LEVEL level, string message)
   {
      if(!ShouldLog(level))
         return;
      
      // Update statistics
      m_total_logs++;
      
      switch(level)
      {
         case LOG_LEVEL_ERROR:   m_error_count++;   break;
         case LOG_LEVEL_WARNING: m_warning_count++; break;
         case LOG_LEVEL_INFO:    m_info_count++;    break;
         case LOG_LEVEL_DEBUG:   m_debug_count++;   break;
      }
      
      // Format message
      string formatted = FormatLogMessage(level, message);
      
      // Log to console
      if(m_log_to_console)
      {
         Print(formatted);
      }
      
      // Log to file
      if(m_log_to_file)
      {
         CheckAndRotateLogFile();
         
         if(m_log_file_handle != INVALID_HANDLE)
         {
            FileWriteString(m_log_file_handle, formatted + "\n");
            FileFlush(m_log_file_handle);
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Convenience Functions                                            |
   //+------------------------------------------------------------------+
   void Debug(string message)   { Log(LOG_LEVEL_DEBUG, message); }
   void Info(string message)    { Log(LOG_LEVEL_INFO, message); }
   void Warning(string message) { Log(LOG_LEVEL_WARNING, message); }
   void Error(string message)   { Log(LOG_LEVEL_ERROR, message); }
   
   //+------------------------------------------------------------------+
   //| Trade Operation Logging                                          |
   //+------------------------------------------------------------------+
   void LogTrade(string operation, 
                 ENUM_ORDER_TYPE order_type,
                 double volume,
                 double price,
                 ulong ticket,
                 bool success,
                 string comment = "")
   {
      string msg = StringFormat(
         "TRADE %s: %s %.2f lots @ %.5f | Ticket: #%I64u | %s",
         operation,
         EnumToString(order_type),
         volume,
         price,
         ticket,
         (success ? "SUCCESS ✓" : "FAILED ✗")
      );
      
      if(comment != "")
         msg += " | " + comment;
      
      if(success)
         Info(msg);
      else
         Error(msg);
   }
   
   //+------------------------------------------------------------------+
   //| Cycle Logging                                                    |
   //+------------------------------------------------------------------+
   void LogCycleStart(ENUM_MARTINGALE_MODE mode, double entry_price, double lot)
   {
      string msg = StringFormat(
         "═══ CYCLE START: %s | Entry: %.5f | Lot: %.2f ═══",
         ModeToString(mode),
         entry_price,
         lot
      );
      
      Info(msg);
   }
   
   void LogCycleEnd(ENUM_MARTINGALE_MODE mode, 
                    int final_layer,
                    double profit,
                    datetime duration,
                    bool success)
   {
      string msg = StringFormat(
         "═══ CYCLE END: %s | Layer: L%d | P/L: $%.2f | Duration: %d sec | %s ═══",
         ModeToString(mode),
         final_layer,
         profit,
         (int)duration,
         (success ? "SUCCESS ✓" : "FAILED ✗")
      );
      
      if(success)
         Info(msg);
      else
         Warning(msg);
   }
   
   void LogLayerAdvance(int new_layer, double price, double lot)
   {
      string msg = StringFormat(
         "➡️ LAYER ADVANCE: L%d | Price: %.5f | Lot: %.2f",
         new_layer,
         price,
         lot
      );
      
      Info(msg);
   }
   
   //+------------------------------------------------------------------+
   //| System Status Logging                                            |
   //+------------------------------------------------------------------+
   void LogSystemStatus(string system, bool stopped)
   {
      string msg = StringFormat(
         "SYSTEM: %s → %s",
         system,
         (stopped ? "STOPPED 🛑" : "RUNNING ▶️")
      );
      
      Warning(msg);
   }
   
   //+------------------------------------------------------------------+
   //| Performance Logging                                              |
   //+------------------------------------------------------------------+
   void LogPerformance(double balance,
                      double equity,
                      double daily_pl,
                      double floating_pl,
                      int total_positions)
   {
      string msg = StringFormat(
         "PERFORMANCE | Balance: $%.2f | Equity: $%.2f | Daily: $%.2f | Floating: $%.2f | Positions: %d",
         balance,
         equity,
         daily_pl,
         floating_pl,
         total_positions
      );
      
      Debug(msg);
   }
   
   //+------------------------------------------------------------------+
   //| Separator Lines                                                  |
   //+------------------------------------------------------------------+
   void LogSeparator(string title = "")
   {
      if(title == "")
      {
         Info(StringFormat("%79s", "─"));
      }
      else
      {
         int title_len = StringLen(title);
         int dash_count = (79 - title_len - 2) / 2;
         
         string separator = "";
         for(int i = 0; i < dash_count; i++)
            separator += "─";
         
         Info(separator + " " + title + " " + separator);
      }
   }
   
   void LogBoxStart(string title)
   {
      Info(StringFormat("%79s", "═"));
      Info("║ " + title);
      Info(StringFormat("%79s", "═"));
   }
   
   void LogBoxEnd()
   {
      Info(StringFormat("%79s", "═"));
   }
   
   //+------------------------------------------------------------------+
   //| Statistics                                                        |
   //+------------------------------------------------------------------+
   void PrintStatistics()
   {
      Print("╔═══════════════════════════════════════════════════════════╗");
      Print("║               LOGGER STATISTICS                           ║");
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ Total Logs:       ", m_total_logs);
      Print("║ Errors:           ", m_error_count);
      Print("║ Warnings:         ", m_warning_count);
      Print("║ Info:             ", m_info_count);
      Print("║ Debug:            ", m_debug_count);
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ Current Log File: ", m_log_file_path);
      
      if(m_log_file_handle != INVALID_HANDLE)
      {
         ulong file_size = FileSize(m_log_file_handle);
         Print("║ File Size:        ", file_size, " bytes (", file_size/1024, " KB)");
      }
      
      Print("╚═══════════════════════════════════════════════════════════╝");
   }
   
   void ResetStatistics()
   {
      m_total_logs = 0;
      m_error_count = 0;
      m_warning_count = 0;
      m_info_count = 0;
      m_debug_count = 0;
      
      Info("✅ Logger statistics reset");
   }
   
   //+------------------------------------------------------------------+
   //| Getters                                                           |
   //+------------------------------------------------------------------+
   ENUM_LOG_LEVEL GetLogLevel() { return m_log_level; }
   int GetTotalLogs() { return m_total_logs; }
   int GetErrorCount() { return m_error_count; }
   int GetWarningCount() { return m_warning_count; }
   string GetLogFilePath() { return m_log_file_path; }
   
   //+------------------------------------------------------------------+
   //| Setters                                                           |
   //+------------------------------------------------------------------+
   void SetLogLevel(ENUM_LOG_LEVEL level)
   {
      m_log_level = level;
      Info("Log level changed to: " + EnumToString(level));
   }
   
   void SetFileLogging(bool enabled)
   {
      if(enabled && !m_log_to_file)
      {
         m_log_to_file = true;
         OpenLogFile();
      }
      else if(!enabled && m_log_to_file)
      {
         m_log_to_file = false;
         CloseLogFile();
      }
   }
   
   void SetConsoleLogging(bool enabled)
   {
      m_log_to_console = enabled;
   }
};

//+------------------------------------------------------------------+
//| End of TG_Logger.mqh                                             |
//+------------------------------------------------------------------+
#endif // TG_LOGGER_MQH
