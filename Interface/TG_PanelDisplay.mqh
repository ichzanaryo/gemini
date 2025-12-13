//+------------------------------------------------------------------+
//|                           Interface/TG_PanelDisplay.mqh          |
//|                                          Titan Grid EA v1.0      |
//|                      Panel Display & Updates                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.00"

#ifndef TG_PANEL_DISPLAY_MQH
#define TG_PANEL_DISPLAY_MQH

#include "../Core/TG_Definitions.mqh"
#include "../Core/TG_StateManager.mqh"
#include "../Core/TG_Logger.mqh"
#include "../Utilities/TG_PositionScanner.mqh"

//+------------------------------------------------------------------+
//| LABEL ID ENUMERATION                                              |
//+------------------------------------------------------------------+
enum ENUM_LABEL_ID
{
   LBL_HEADER,
   LBL_ACCOUNT_HEADER,
   LBL_BALANCE,
   LBL_EQUITY,
   LBL_MARGIN,
   LBL_MARGIN_LEVEL,
   LBL_CYCLE_HEADER,
   LBL_CYCLE_MODE,
   LBL_CYCLE_LAYER,
   LBL_CYCLE_DURATION,
   LBL_POSITION_HEADER,
   LBL_MART_BUY,
   LBL_MART_SELL,
   LBL_HEDGE,
   LBL_TOTAL_POSITIONS,
   LBL_PL_HEADER,
   LBL_FLOATING_PL,
   LBL_DAILY_PL,
   LBL_STATS_HEADER,
   LBL_TOTAL_CYCLES,
   LBL_WIN_RATE,
   LBL_STATUS_HEADER,
   LBL_STATUS_MART,
   LBL_STATUS_GS,
   LBL_STATUS_HEDGE,
   LBL_COUNT
};

//+------------------------------------------------------------------+
//| LABEL INFO STRUCTURE                                              |
//+------------------------------------------------------------------+
struct SLabelInfo
{
   string   name;
   int      x;
   int      y;
   
   void Reset()
   {
      name = "";
      x = 0;
      y = 0;
   }
};

//+------------------------------------------------------------------+
//| PANEL DISPLAY CLASS                                               |
//+------------------------------------------------------------------+
class CPanelDisplay
{
private:
   CStateManager*      m_state_manager;
   CLogger*            m_logger;
   CPositionScanner*   m_scanner;
   
   SLabelInfo          m_labels[LBL_COUNT];
   
   string              m_prefix;
   int                 m_base_x;
   int                 m_base_y;
   int                 m_line_height;
   
   color               m_color_header;
   color               m_color_normal;
   color               m_color_profit;
   color               m_color_loss;
   color               m_color_disabled;
   
   bool                m_show_account;
   bool                m_show_positions;
   bool                m_show_cycle;
   bool                m_show_stats;
   bool                m_show_status;
   
   //+------------------------------------------------------------------+
   //| Create Label Object                                              |
   //+------------------------------------------------------------------+
   bool CreateLabel(ENUM_LABEL_ID id, string text, int x, int y, color clr, int size = 9)
   {
      string name = m_prefix + "LBL" + IntegerToString(id);
      
      // Delete if exists
      ObjectDelete(0, name);
      
      // Create label
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
         return false;
      
      // Set properties
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      
      // Store info
      m_labels[id].name = name;
      m_labels[id].x = x;
      m_labels[id].y = y;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Update Label Text                                                |
   //+------------------------------------------------------------------+
   void UpdateLabelText(ENUM_LABEL_ID id, string text, color clr = clrNONE)
   {
      if(m_labels[id].name == "")
         return;
      
      ObjectSetString(0, m_labels[id].name, OBJPROP_TEXT, text);
      
      if(clr != clrNONE)
         ObjectSetInteger(0, m_labels[id].name, OBJPROP_COLOR, clr);
   }
   
   //+------------------------------------------------------------------+
   //| Format Currency                                                  |
   //+------------------------------------------------------------------+
   string FormatCurrency(double value)
   {
      return "$" + DoubleToString(value, 2);
   }
   
   //+------------------------------------------------------------------+
   //| Format Percent                                                   |
   //+------------------------------------------------------------------+
   string FormatPercent(double value)
   {
      return DoubleToString(value, 2) + "%";
   }
   
   //+------------------------------------------------------------------+
   //| Format Duration                                                  |
   //+------------------------------------------------------------------+
   string FormatDuration(int seconds)
   {
      int hours = seconds / 3600;
      int minutes = (seconds % 3600) / 60;
      int secs = seconds % 60;
      
      if(hours > 0)
         return StringFormat("%02d:%02d:%02d", hours, minutes, secs);
      else
         return StringFormat("%02d:%02d", minutes, secs);
   }
   
   //+------------------------------------------------------------------+
   //| Get P/L Color                                                    |
   //+------------------------------------------------------------------+
   color GetPLColor(double pl)
   {
      if(pl > 0) return m_color_profit;
      if(pl < 0) return m_color_loss;
      return m_color_normal;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CPanelDisplay()
   {
      m_state_manager = NULL;
      m_logger = NULL;
      m_scanner = NULL;
      
      m_prefix = "TG_Panel";
      m_base_x = 0;
      m_base_y = 0;
      m_line_height = 20;
      
      m_color_header = clrGold;
      m_color_normal = clrWhite;
      m_color_profit = clrLimeGreen;
      m_color_loss = clrRed;
      m_color_disabled = clrGray;
      
      m_show_account = true;
      m_show_positions = true;
      m_show_cycle = true;
      m_show_stats = true;
      m_show_status = true;
   }
   
   //+------------------------------------------------------------------+
   //| Initialize (Fixed Version - Using DOT not ARROW)                |
   //+------------------------------------------------------------------+
   bool Initialize(CStateManager* state_mgr, 
                   CLogger* logger, 
                   CPositionScanner* scanner,
                   string prefix, 
                   int x, 
                   int y, 
                   int line_height,
                   color color_header,
                   color color_normal, 
                   color color_profit, 
                   color color_loss,
                   bool show_account,
                   bool show_positions,
                   bool show_cycle,
                   bool show_stats,
                   bool show_status)
   {
      // Validate pointers
      if(state_mgr == NULL || logger == NULL || scanner == NULL)
         return false;
      
      // Set pointers
      m_state_manager = state_mgr;
      m_logger = logger;
      m_scanner = scanner;
      
      // Set display settings
      m_prefix = prefix;
      m_base_x = x;
      m_base_y = y;
      m_line_height = line_height;
      
      m_color_header = color_header;
      m_color_normal = color_normal;
      m_color_profit = color_profit;
      m_color_loss = color_loss;
      
      m_show_account = show_account;
      m_show_positions = show_positions;
      m_show_cycle = show_cycle;
      m_show_stats = show_stats;
      m_show_status = show_status;
      
      // Log initialization (USE DOT NOT ARROW!)
      if(m_logger != NULL)
         m_logger.Info("Panel Display initialized");
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Create All Labels                                                |
   //+------------------------------------------------------------------+
   bool CreateAllLabels()
   {
      int y = m_base_y;
      int section_spacing = 10;
      
      // Header
      CreateLabel(LBL_HEADER, "TITAN GRID EA", m_base_x, y, m_color_header, 11);
      y += m_line_height + section_spacing;
      
      // Account section
      if(m_show_account)
      {
         CreateLabel(LBL_ACCOUNT_HEADER, "=== ACCOUNT ===", m_base_x, y, m_color_header);
         y += m_line_height;
         CreateLabel(LBL_BALANCE, "Balance: $0.00", m_base_x, y, m_color_normal);
         y += m_line_height;
         CreateLabel(LBL_EQUITY, "Equity: $0.00", m_base_x, y, m_color_normal);
         y += m_line_height;
         CreateLabel(LBL_MARGIN, "Margin: $0.00", m_base_x, y, m_color_normal);
         y += m_line_height;
         CreateLabel(LBL_MARGIN_LEVEL, "Level: 0%", m_base_x, y, m_color_normal);
         y += m_line_height + section_spacing;
      }
      
      // Cycle section
      if(m_show_cycle)
      {
         CreateLabel(LBL_CYCLE_HEADER, "=== CYCLE ===", m_base_x, y, m_color_header);
         y += m_line_height;
         CreateLabel(LBL_CYCLE_MODE, "Mode: NONE", m_base_x, y, m_color_normal);
         y += m_line_height;
         CreateLabel(LBL_CYCLE_LAYER, "Layer: -", m_base_x, y, m_color_normal);
         y += m_line_height;
         CreateLabel(LBL_CYCLE_DURATION, "Duration: 00:00", m_base_x, y, m_color_normal);
         y += m_line_height + section_spacing;
      }
      
      // Positions section
      if(m_show_positions)
      {
         CreateLabel(LBL_POSITION_HEADER, "=== POSITIONS ===", m_base_x, y, m_color_header);
         y += m_line_height;
         CreateLabel(LBL_MART_BUY, "Mart BUY: 0 (0.00 lot)", m_base_x, y, m_color_normal);
         y += m_line_height;
         CreateLabel(LBL_MART_SELL, "Mart SELL: 0 (0.00 lot)", m_base_x, y, m_color_normal);
         y += m_line_height;
         CreateLabel(LBL_HEDGE, "Hedge: 0 (0.00 lot)", m_base_x, y, m_color_normal);
         y += m_line_height;
         CreateLabel(LBL_TOTAL_POSITIONS, "Total: 0 positions", m_base_x, y, m_color_normal);
         y += m_line_height + section_spacing;
      }
      
      // P&L section (always shown)
      CreateLabel(LBL_PL_HEADER, "=== P&L ===", m_base_x, y, m_color_header);
      y += m_line_height;
      CreateLabel(LBL_FLOATING_PL, "Floating: $0.00", m_base_x, y, m_color_normal);
      y += m_line_height;
      CreateLabel(LBL_DAILY_PL, "Daily: $0.00", m_base_x, y, m_color_normal);
      y += m_line_height + section_spacing;
      
      // Statistics section
      if(m_show_stats)
      {
         CreateLabel(LBL_STATS_HEADER, "=== STATISTICS ===", m_base_x, y, m_color_header);
         y += m_line_height;
         CreateLabel(LBL_TOTAL_CYCLES, "Cycles: 0 (0/0)", m_base_x, y, m_color_normal);
         y += m_line_height;
         CreateLabel(LBL_WIN_RATE, "Win Rate: 0.00%", m_base_x, y, m_color_normal);
         y += m_line_height + section_spacing;
      }
      
      // Status section
      if(m_show_status)
      {
         CreateLabel(LBL_STATUS_HEADER, "=== STATUS ===", m_base_x, y, m_color_header);
         y += m_line_height;
         CreateLabel(LBL_STATUS_MART, "Martingale: OK", m_base_x, y, m_color_profit);
         y += m_line_height;
         CreateLabel(LBL_STATUS_GS, "GridSlicer: OK", m_base_x, y, m_color_profit);
         y += m_line_height;
         CreateLabel(LBL_STATUS_HEDGE, "Hedge: OK", m_base_x, y, m_color_profit);
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Update Display (ALL USING DOT NOT ARROW!)                       |
   //+------------------------------------------------------------------+
   void UpdateDisplay()
   {
      // Update account info
      if(m_show_account)
      {
         double balance = AccountInfoDouble(ACCOUNT_BALANCE);
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         double margin = AccountInfoDouble(ACCOUNT_MARGIN);
         double margin_level = (margin > 0) ? (equity / margin * 100.0) : 0;
         
         UpdateLabelText(LBL_BALANCE, "Balance: " + FormatCurrency(balance));
         UpdateLabelText(LBL_EQUITY, "Equity: " + FormatCurrency(equity), GetPLColor(equity - balance));
         UpdateLabelText(LBL_MARGIN, "Margin: " + FormatCurrency(margin));
         
         color level_color = (margin_level > 150) ? m_color_profit : 
                           (margin_level > 100) ? m_color_normal : m_color_loss;
         UpdateLabelText(LBL_MARGIN_LEVEL, "Level: " + FormatPercent(margin_level), level_color);
      }
      
      // Update cycle info (USE DOT!)
      if(m_show_cycle)
      {
         bool cycle_active = m_state_manager.IsCycleActive();
         
         if(cycle_active)
         {
            ENUM_MARTINGALE_MODE mode = m_state_manager.GetCurrentMode();
            int layer = m_state_manager.GetCurrentLayer();
            datetime start_time = m_state_manager.GetCycleStartTime();
            int duration = (int)(TimeCurrent() - start_time);
            
            string mode_str = (mode == MODE_BUY) ? "BUY" : "SELL";
            color mode_color = (mode == MODE_BUY) ? clrDodgerBlue : clrOrangeRed;
            
            UpdateLabelText(LBL_CYCLE_MODE, "Mode: " + mode_str, mode_color);
            UpdateLabelText(LBL_CYCLE_LAYER, "Layer: L" + IntegerToString(layer));
            UpdateLabelText(LBL_CYCLE_DURATION, "Duration: " + FormatDuration(duration));
         }
         else
         {
            UpdateLabelText(LBL_CYCLE_MODE, "Mode: NONE", m_color_disabled);
            UpdateLabelText(LBL_CYCLE_LAYER, "Layer: -", m_color_disabled);
            UpdateLabelText(LBL_CYCLE_DURATION, "Duration: 00:00", m_color_disabled);
         }
      }
      
      // Update positions info (USE DOT!)
      if(m_show_positions)
      {
         SPositionSummary summary = m_scanner.GetSummary();
         
         UpdateLabelText(LBL_MART_BUY, 
            StringFormat("Mart BUY: %d (%.2f lot)", summary.mart_buy_count, summary.mart_buy_lots),
            (summary.mart_buy_count > 0) ? clrDodgerBlue : m_color_disabled);
         
         UpdateLabelText(LBL_MART_SELL,
            StringFormat("Mart SELL: %d (%.2f lot)", summary.mart_sell_count, summary.mart_sell_lots),
            (summary.mart_sell_count > 0) ? clrOrangeRed : m_color_disabled);
         
         UpdateLabelText(LBL_HEDGE,
            StringFormat("Hedge: %d (%.2f lot)", summary.hedge_count, summary.hedge_lots),
            (summary.hedge_count > 0) ? clrGold : m_color_disabled);
         
         UpdateLabelText(LBL_TOTAL_POSITIONS,
            StringFormat("Total: %d positions", summary.total_positions));
      }
      
      // Update P&L (USE DOT!)
      SPositionSummary pl_summary = m_scanner.GetSummary();
      double floating_pl = pl_summary.GetNetPL();
      
      UpdateLabelText(LBL_FLOATING_PL, "Floating: " + FormatCurrency(floating_pl), GetPLColor(floating_pl));
      UpdateLabelText(LBL_DAILY_PL, "Daily: $0.00", m_color_normal); // TODO: Implement daily P&L tracking
      
      // Update statistics (USE DOT!)
      if(m_show_stats)
      {
         int total_cycles = m_state_manager.GetTotalCycles();
         int successful_cycles = m_state_manager.GetSuccessfulCycles();
         int failed_cycles = m_state_manager.GetFailedCycles();
         double success_rate = m_state_manager.GetSuccessRate();
         
         UpdateLabelText(LBL_TOTAL_CYCLES, 
            StringFormat("Cycles: %d (%d/%d)", total_cycles, successful_cycles, failed_cycles));
         UpdateLabelText(LBL_WIN_RATE, "Win Rate: " + FormatPercent(success_rate));
      }
      
      // Update system status (USE DOT!)
      if(m_show_status)
      {
         bool martingale_ok = !m_state_manager.IsMartingaleStopped();
         bool gridslicer_ok = !m_state_manager.IsGridSlicerStopped();
         bool hedge_ok = !m_state_manager.IsHedgeStopped();
         
         UpdateLabelText(LBL_STATUS_MART, "Martingale: " + (martingale_ok ? "OK" : "OFF"),
            martingale_ok ? m_color_profit : m_color_loss);
         
         UpdateLabelText(LBL_STATUS_GS, "GridSlicer: " + (gridslicer_ok ? "OK" : "OFF"),
            gridslicer_ok ? m_color_profit : m_color_loss);
         
         UpdateLabelText(LBL_STATUS_HEDGE, "Hedge: " + (hedge_ok ? "OK" : "OFF"),
            hedge_ok ? m_color_profit : m_color_loss);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Destroy All Labels                                               |
   //+------------------------------------------------------------------+
   void DestroyAllLabels()
   {
      for(int i = 0; i < LBL_COUNT; i++)
      {
         if(m_labels[i].name != "")
         {
            ObjectDelete(0, m_labels[i].name);
            m_labels[i].Reset();
         }
      }
   }
};

//+------------------------------------------------------------------+
//| End of TG_PanelDisplay.mqh                                       |
//+------------------------------------------------------------------+
#endif
