//+------------------------------------------------------------------+
//|                                          Core/TG_Definitions.mqh |
//|                                          Titan Grid EA v1.0      |
//|                               Core Definitions & Data Structures |
//+------------------------------------------------------------------+
//| Location: TitanGridEA/Core/TG_Definitions.mqh                    |
//| Purpose:  Base definitions, enums, constants, and structures     |
//|           Used by all other modules - NO DEPENDENCIES            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.00"

//+------------------------------------------------------------------+
//| CHANGE LOG                                                        |
//+------------------------------------------------------------------+
// Version 1.00 - 2025-01-20
// [INITIAL] Base definitions created
// [ADD] All core enums defined
// [ADD] Color constants for UI
// [ADD] System constants
// [ADD] Data structures for position tracking
//+------------------------------------------------------------------+

#ifndef TG_DEFINITIONS_MQH
#define TG_DEFINITIONS_MQH

//+------------------------------------------------------------------+
//| VERSION INFORMATION                                               |
//+------------------------------------------------------------------+
#define TITAN_VERSION       "1.0"
#define TITAN_BUILD_DATE    "2025-01-20"
#define TITAN_PRODUCT_NAME  "Titan Grid EA"
#define TITAN_DESCRIPTION   "Advanced Grid Martingale System"

//+------------------------------------------------------------------+
//| SYSTEM CONSTANTS                                                  |
//+------------------------------------------------------------------+
#define MAX_LAYERS              15      // Maximum martingale layers
#define MAX_GRIDSLICER_POS      20      // Maximum GridSlicer pending orders
#define MIN_LOT_STEP            0.01    // Minimum lot increment
#define DEFAULT_COOLDOWN        5       // Default cooldown seconds
#define MAX_RETRIES             3       // Maximum trade retry attempts
#define TIMER_INTERVAL_MS       1000    // Timer interval (1 second)

//+------------------------------------------------------------------+
//| UI COLOR CONSTANTS - DARK THEME (Default)                        |
//+------------------------------------------------------------------+
// Panel Background & Structure
#define COLOR_PANEL_BG              clrDarkSlateGray    // Main background
#define COLOR_PANEL_BORDER          clrWhite            // Border lines
#define COLOR_PANEL_HEADER_BG       clrBlack            // Header section
#define COLOR_PANEL_SECTION_BG      clr DimGray          // Section backgrounds

// Text Colors
#define COLOR_TEXT_NORMAL           clrWhite            // Normal text
#define COLOR_TEXT_HEADER           clrGold             // Header text
#define COLOR_TEXT_PROFIT           clrLimeGreen        // Profit values
#define COLOR_TEXT_LOSS             clrRed              // Loss values
#define COLOR_TEXT_WARNING          clrOrange           // Warning messages
#define COLOR_TEXT_INFO             clrDeepSkyBlue      // Info messages
#define COLOR_TEXT_DISABLED         clrGray             // Disabled elements

// Button Colors
#define COLOR_BUTTON_NORMAL         clrDimGray          // Default button
#define COLOR_BUTTON_HOVER          clrGray             // Hover state
#define COLOR_BUTTON_ACTIVE         clrDodgerBlue       // Active/Selected
#define COLOR_BUTTON_BUY            clrDodgerBlue       // Buy buttons
#define COLOR_BUTTON_SELL           clrOrangeRed        // Sell buttons
#define COLOR_BUTTON_CLOSE          clrRed              // Close buttons
#define COLOR_BUTTON_STOP           clrCrimson          // Stop buttons
#define COLOR_BUTTON_RESUME         clrLimeGreen        // Resume buttons
#define COLOR_BUTTON_DISABLED       clrDarkGray         // Disabled buttons

// Status Indicators
#define COLOR_STATUS_ACTIVE         clrLimeGreen        // System active
#define COLOR_STATUS_INACTIVE       clrGray             // System inactive
#define COLOR_STATUS_WARNING        clrOrange           // Warning state
#define COLOR_STATUS_ERROR          clrRed              // Error state

//+------------------------------------------------------------------+
//| UI COLOR CONSTANTS - LIGHT THEME                                 |
//+------------------------------------------------------------------+
#define COLOR_LIGHT_PANEL_BG        clrWhiteSmoke
#define COLOR_LIGHT_PANEL_BORDER    clrBlack
#define COLOR_LIGHT_TEXT_NORMAL     clrBlack
#define COLOR_LIGHT_TEXT_PROFIT     clrGreen
#define COLOR_LIGHT_TEXT_LOSS       clrDarkRed

//+------------------------------------------------------------------+
//| TRADING MODE ENUMERATION                                          |
//+------------------------------------------------------------------+
enum ENUM_MARTINGALE_MODE
{
   MODE_NONE = 0,     // No active martingale cycle
   MODE_BUY  = 1,     // Active BUY cycle
   MODE_SELL = 2      // Active SELL cycle
};
// ... (Kode sebelumnya tetap sama)

//+------------------------------------------------------------------+
//| HEDGING ENUMERATIONS                                              |
//+------------------------------------------------------------------+
enum ENUM_HEDGE_TYPE
{
   HEDGE_TYPE_FULL = 0,       // Lock 100% Volume
   HEDGE_TYPE_PARTIAL = 1,    // Lock % Volume (e.g. 50%)
   HEDGE_TYPE_FIXED_LOT = 2   // Lock Fixed Lot
};

enum ENUM_HEDGE_STRATEGY
{
   HEDGE_STRAT_LOCK = 0,         // Hold until manual/basket exit
   HEDGE_STRAT_INDIVIDUAL_TP = 1,// Close Hedge only on TP
   HEDGE_STRAT_GLOBAL_BASKET = 2 // Close All (Mart + Hedge) on Profit
};

enum ENUM_HEDGE_STATE
{
   HEDGE_STATE_INACTIVE = 0,
   HEDGE_STATE_MONITORING = 1,   // Trigger reached, validating
   HEDGE_STATE_CONFIRMING = 2,   // Timer/Candle check
   HEDGE_STATE_ACTIVE = 3        // Position Open
};

// ... (Sisanya tetap sama)
//+------------------------------------------------------------------+
//| SIGNAL TYPE ENUMERATION                                           |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_TYPE
{
   SIGNAL_NONE = 0,   // No signal
   SIGNAL_BUY  = 1,   // Buy signal
   SIGNAL_SELL = 2    // Sell signal
};

//+------------------------------------------------------------------+
//| ENTRY METHOD ENUMERATION                                          |
//+------------------------------------------------------------------+
enum ENUM_ENTRY_METHOD
{
   ENTRY_METHOD_SIGNAL,           // Signal-based entry (indicators)
   ENTRY_METHOD_PENDING_ORDER,    // Pending order breakout
   ENTRY_METHOD_MANUAL            // Manual entry only (from panel)
};

//+------------------------------------------------------------------+
//| LOT CALCULATION MODE                                              |
//+------------------------------------------------------------------+
enum ENUM_LOT_MODE
{
   LOT_MODE_FIXED,                // Fixed lot size
   LOT_MODE_DYNAMIC_RISK,         // Dynamic based on risk %
   LOT_MODE_BALANCE_PERCENT       // Percentage of balance
};

//+------------------------------------------------------------------+
//| GRID DISTANCE MODE                                                |
//+------------------------------------------------------------------+
enum ENUM_GRID_MODE
{
   GRID_MODE_FIXED,               // Fixed distance in points
   GRID_MODE_ADAPTIVE_ATR         // Adaptive based on ATR
};

//+------------------------------------------------------------------+
//| GRID DISTANCE PROGRESSION MODE                                    |
//+------------------------------------------------------------------+
enum ENUM_GRID_PROGRESSION_MODE
{
   GRID_PROGRESSION_FIXED,        // Fixed: Same distance every layer
   GRID_PROGRESSION_ADD,          // Add: Distance(n) = Base + (n × AddValue)
   GRID_PROGRESSION_MULTIPLY,     // Multiply: Distance(n) = Base × (1 + n × Multiplier)
   GRID_PROGRESSION_POWER         // Power: Distance(n) = Base × (Multiplier ^ n)
};

//+------------------------------------------------------------------+
//| LOT PROGRESSION MODE                                              |
//+------------------------------------------------------------------+
enum ENUM_PROGRESSION_MODE
{
   PROGRESSION_MULTIPLY,          // Geometric: Lot(n) = Lot(n-1) × Multiplier
   PROGRESSION_ADD,               // Arithmetic: Lot(n) = Lot(n-1) + AddValue
   PROGRESSION_FIBONACCI          // Fibonacci: Lot(n) = Lot × Fib(n)
};

//+------------------------------------------------------------------+
//| TREND DIRECTION                                                   |
//+------------------------------------------------------------------+
enum ENUM_TREND_DIRECTION
{
   TREND_UP = 1,                  // Uptrend
   TREND_DOWN = -1,               // Downtrend
   TREND_NEUTRAL = 0              // Sideways/Unclear
};

//+------------------------------------------------------------------+
//| ERROR SEVERITY LEVELS                                             |
//+------------------------------------------------------------------+
enum ENUM_ERROR_SEVERITY
{
   ERROR_SEVERITY_INFO,           // Informational - can be ignored
   ERROR_SEVERITY_WARNING,        // Warning - should be noted
   ERROR_SEVERITY_ERROR,          // Error - operation failed
   ERROR_SEVERITY_CRITICAL,       // Critical - system halt required
   ERROR_SEVERITY_LOW,            // Low severity - minor issue
   ERROR_SEVERITY_MEDIUM,         // Medium severity - needs attention
   ERROR_SEVERITY_HIGH            // High severity - serious problem
};

//+------------------------------------------------------------------+
//| PANEL POSITION                                                    |
//+------------------------------------------------------------------+
enum ENUM_PANEL_POSITION
{
   PANEL_POS_TOP_LEFT,            // Top-left corner
   PANEL_POS_TOP_RIGHT,           // Top-right corner
   PANEL_POS_BOTTOM_LEFT,         // Bottom-left corner
   PANEL_POS_BOTTOM_RIGHT,        // Bottom-right corner
   PANEL_POS_CENTER_LEFT,         // Center-left
   PANEL_POS_CENTER_RIGHT,        // Center-right
   PANEL_POS_CUSTOM               // Custom X, Y coordinates
};

//+------------------------------------------------------------------+
//| PANEL SIZE/MODE                                                   |
//+------------------------------------------------------------------+
enum ENUM_PANEL_SIZE
{
   PANEL_SIZE_COMPACT,            // Compact mode (minimal info)
   PANEL_SIZE_NORMAL,             // Normal mode (standard)
   PANEL_SIZE_FULL                // Full mode (all features)
};

//+------------------------------------------------------------------+
//| PANEL THEME                                                       |
//+------------------------------------------------------------------+
enum ENUM_PANEL_THEME
{
   PANEL_THEME_DARK,              // Dark theme (default)
   PANEL_THEME_LIGHT,             // Light theme
   PANEL_THEME_BLUE,              // Blue theme
   PANEL_THEME_GREEN,             // Green theme
   PANEL_THEME_CUSTOM             // Custom colors
};

//+------------------------------------------------------------------+
//| LOG LEVELS                                                        |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL
{
   LOG_LEVEL_NONE,                // No logging
   LOG_LEVEL_ERROR,               // Errors only
   LOG_LEVEL_WARNING,             // Warnings and errors
   LOG_LEVEL_INFO,                // Info, warnings, errors
   LOG_LEVEL_DEBUG                // Everything (verbose)
};

//+------------------------------------------------------------------+
//| POSITION INFORMATION STRUCTURE                                    |
//+------------------------------------------------------------------+
struct SPositionInfo
{
   ulong             ticket;          // Position ticket
   ENUM_POSITION_TYPE type;           // BUY or SELL
   double            open_price;      // Open price
   double            current_price;   // Current price
   double            lots;            // Lot size
   double            profit;          // Current profit/loss
   double            swap;            // Swap
   double            commission;      // Commission
   datetime          open_time;       // Open time
   string            comment;         // Comment
   long              magic;           // Magic number
   int               layer;           // Layer number (if applicable)
   
   // Constructor
   SPositionInfo()
   {
      ticket = 0;
      type = POSITION_TYPE_BUY;
      open_price = 0;
      current_price = 0;
      lots = 0;
      profit = 0;
      swap = 0;
      commission = 0;
      open_time = 0;
      comment = "";
      magic = 0;
      layer = 0;
   }
};

//+------------------------------------------------------------------+
//| PENDING ORDER INFORMATION STRUCTURE                               |
//+------------------------------------------------------------------+
struct SPendingOrderInfo
{
   ulong             ticket;          // Order ticket
   ENUM_ORDER_TYPE   type;            // Order type (STOP/LIMIT)
   double            price;           // Order price
   double            lots;            // Lot size
   datetime          time_setup;      // Setup time
   datetime          expiration;      // Expiration (if any)
   string            comment;         // Comment
   long              magic;           // Magic number
   int               layer;           // Target layer (if applicable)
   
   // Constructor
   SPendingOrderInfo()
   {
      ticket = 0;
      type = ORDER_TYPE_BUY_STOP;
      price = 0;
      lots = 0;
      time_setup = 0;
      expiration = 0;
      comment = "";
      magic = 0;
      layer = 0;
   }
};

//+------------------------------------------------------------------+
//| POSITION SUMMARY STRUCTURE (Optimized Scanner Output)            |
//+------------------------------------------------------------------+
struct SPositionSummary
{
   // === MARTINGALE POSITIONS ===
   int               mart_buy_count;          // BUY positions count
   int               mart_sell_count;         // SELL positions count
   double            mart_buy_lots;           // Total BUY lots
   double            mart_sell_lots;          // Total SELL lots
   double            mart_buy_avg_price;      // Average BUY price
   double            mart_sell_avg_price;     // Average SELL price
   double            mart_buy_profit;         // BUY profit (including swap)
   double            mart_sell_profit;        // SELL profit (including swap)
   ulong             mart_buy_newest_ticket;  // Newest BUY ticket
   ulong             mart_sell_newest_ticket; // Newest SELL ticket
   datetime          mart_buy_newest_time;    // Newest BUY time
   datetime          mart_sell_newest_time;   // Newest SELL time
   
   // === GRIDSLICER POSITIONS ===
   int               gridslicer_count;        // GridSlicer positions
   double            gridslicer_profit;       // GridSlicer profit
   double            gridslicer_lots;         // GridSlicer lots
   
   // === HEDGE POSITIONS ===
   int               hedge_count;             // Hedge positions
   double            hedge_profit;            // Hedge profit
   double            hedge_lots;              // Hedge lots
   
   // === RECOVERY POSITIONS ===
   int               recovery_buy_count;      // Recovery BUY count
   int               recovery_sell_count;     // Recovery SELL count
   double            recovery_buy_profit;     // Recovery BUY profit
   double            recovery_sell_profit;    // Recovery SELL profit
   double            recovery_buy_lots;       // Recovery BUY lots
   double            recovery_sell_lots;      // Recovery SELL lots
   
   // === TOTALS ===
   double            total_profit;            // Total profit
   double            total_swap;              // Total swap
   double            total_commission;        // Total commission
   int               total_positions;         // Total positions
   double            total_lots;              // Total lots
   
   // Constructor - Initialize all to zero
   SPositionSummary()
   {
      Reset();
   }
   
   // Reset function
   void Reset()
   {
      mart_buy_count = 0;
      mart_sell_count = 0;
      mart_buy_lots = 0;
      mart_sell_lots = 0;
      mart_buy_avg_price = 0;
      mart_sell_avg_price = 0;
      mart_buy_profit = 0;
      mart_sell_profit = 0;
      mart_buy_newest_ticket = 0;
      mart_sell_newest_ticket = 0;
      mart_buy_newest_time = 0;
      mart_sell_newest_time = 0;
      
      gridslicer_count = 0;
      gridslicer_profit = 0;
      gridslicer_lots = 0;
      
      hedge_count = 0;
      hedge_profit = 0;
      hedge_lots = 0;
      
      recovery_buy_count = 0;
      recovery_sell_count = 0;
      recovery_buy_profit = 0;
      recovery_sell_profit = 0;
      recovery_buy_lots = 0;
      recovery_sell_lots = 0;
      
      total_profit = 0;
      total_swap = 0;
      total_commission = 0;
      total_positions = 0;
      total_lots = 0;
   }
   
   // Get net P&L (profit + swap + commission)
   double GetNetPL() const
   {
      return total_profit + total_swap + total_commission;
   }
   
   // Get martingale net P&L
   double GetMartingaleNetPL() const
   {
      return mart_buy_profit + mart_sell_profit;
   }
};

//+------------------------------------------------------------------+
//| STATISTICS STRUCTURE                                              |
//+------------------------------------------------------------------+
struct SStatistics
{
   // Daily statistics
   double            daily_profit;            // Today's profit
   double            daily_loss;              // Today's loss
   int               daily_trades;            // Today's trades
   int               daily_wins;              // Today's winning trades
   int               daily_losses;            // Today's losing trades
   datetime          daily_reset_time;        // Last reset time
   
   // Overall statistics
   double            max_drawdown;            // Maximum drawdown
   double            max_profit;              // Maximum profit
   int               total_cycles;            // Total cycles completed
   int               successful_cycles;       // Successful cycles
   int               failed_cycles;           // Failed cycles
   
   // Constructor
   SStatistics()
   {
      Reset();
   }
   
   void Reset()
   {
      daily_profit = 0;
      daily_loss = 0;
      daily_trades = 0;
      daily_wins = 0;
      daily_losses = 0;
      daily_reset_time = 0;
      
      max_drawdown = 0;
      max_profit = 0;
      total_cycles = 0;
      successful_cycles = 0;
      failed_cycles = 0;
   }
   
   // Calculate daily net
   double GetDailyNet() const
   {
      return daily_profit + daily_loss;
   }
   
   // Calculate win rate
   double GetWinRate() const
   {
      if(daily_trades == 0) return 0;
      return ((double)daily_wins / (double)daily_trades) * 100.0;
   }
   
   // Calculate success rate (cycles)
   double GetSuccessRate() const
   {
      if(total_cycles == 0) return 0;
      return ((double)successful_cycles / (double)total_cycles) * 100.0;
   }
};

//+------------------------------------------------------------------+
//| DASHBOARD DATA STRUCTURE (For UI Display)                        |
//+------------------------------------------------------------------+
struct SDashboardData
{
   // Account info
   double            balance;
   double            equity;
   double            margin_used;
   double            margin_free;
   double            margin_level;
   
   // Trading state
   ENUM_MARTINGALE_MODE current_mode;
   int               current_layer;
   bool              cycle_active;
   
   // P&L
   double            floating_pl;
   double            daily_pl;
   
   // Position summary
   SPositionSummary  positions;
   
   // Statistics
   SStatistics       stats;
   
   // System status flags
   bool              martingale_stopped;
   bool              gridslicer_stopped;
   bool              hedge_stopped;
   bool              recovery_stopped;
   
   // Timestamps
   datetime          last_update;
   datetime          last_trade_time;
   
   // Constructor
   SDashboardData()
   {
      Reset();
   }
   
   void Reset()
   {
      balance = 0;
      equity = 0;
      margin_used = 0;
      margin_free = 0;
      margin_level = 0;
      
      current_mode = MODE_NONE;
      current_layer = 0;
      cycle_active = false;
      
      floating_pl = 0;
      daily_pl = 0;
      
      positions.Reset();
      stats.Reset();
      
      martingale_stopped = false;
      gridslicer_stopped = false;
      hedge_stopped = false;
      recovery_stopped = false;
      
      last_update = 0;
      last_trade_time = 0;
   }
};

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS (Inline)                                        |
//+------------------------------------------------------------------+

// Convert MODE enum to string
string ModeToString(ENUM_MARTINGALE_MODE mode)
{
   switch(mode)
   {
      case MODE_NONE: return "NONE";
      case MODE_BUY:  return "BUY";
      case MODE_SELL: return "SELL";
      default:        return "UNKNOWN";
   }
}

// Convert SIGNAL enum to string
string SignalToString(ENUM_SIGNAL_TYPE signal)
{
   switch(signal)
   {
      case SIGNAL_NONE: return "NONE";
      case SIGNAL_BUY:  return "BUY";
      case SIGNAL_SELL: return "SELL";
      default:          return "UNKNOWN";
   }
}

// Get color for P&L display
color GetPLColor(double pl)
{
   if(pl > 0) return COLOR_TEXT_PROFIT;
   if(pl < 0) return COLOR_TEXT_LOSS;
   return COLOR_TEXT_NORMAL;
}

// Get status color
color GetStatusColor(bool active)
{
   return active ? COLOR_STATUS_ACTIVE : COLOR_STATUS_INACTIVE;
}

//+------------------------------------------------------------------+
//| End of TG_Definitions.mqh                                        |
//+------------------------------------------------------------------+
#endif // TG_DEFINITIONS_MQH
