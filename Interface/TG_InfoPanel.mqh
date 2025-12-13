//+------------------------------------------------------------------+
//|                           Interface/TG_InfoPanel.mqh             |
//|                                          Titan Grid EA v1.0      |
//|                   Compact Info Display (Top Right)               |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.00"

#ifndef TG_INFO_PANEL_MQH
#define TG_INFO_PANEL_MQH

#include "../Core/TG_Definitions.mqh"
#include "../Core/TG_StateManager.mqh"
#include "../Core/TG_Logger.mqh"
#include "../Utilities/TG_PositionScanner.mqh"

//+------------------------------------------------------------------+
//| INFO LABEL IDs                                                    |
//+------------------------------------------------------------------+
enum ENUM_INFO_LABEL_ID
{
   INFO_LBL_HEADER,
   INFO_LBL_CYCLE,
   INFO_LBL_PL,
   INFO_LBL_STATUS,
   INFO_LBL_COUNT
};

//+------------------------------------------------------------------+
//| COMPACT INFO PANEL CLASS                                          |
//+------------------------------------------------------------------+
class CInfoPanel
{
private:
   CStateManager*      m_state_manager;
   CLogger*            m_logger;
   CPositionScanner*   m_scanner;
   
   string              m_prefix;
   int                 m_panel_x;
   int                 m_panel_y;
   int                 m_panel_width;
   int                 m_panel_height;
   
   string              m_background_name;
   string              m_labels[INFO_LBL_COUNT];
   
   color               m_bg_color;
   color               m_text_color;
   color               m_header_color;
   color               m_profit_color;
   color               m_loss_color;
   
   bool                m_visible;
   
   //+------------------------------------------------------------------+
   //| Create Background                                                |
   //+------------------------------------------------------------------+
   bool CreateBackground()
   {
      m_background_name = m_prefix + "_InfoBG";
      ObjectDelete(0, m_background_name);
      
      if(!ObjectCreate(0, m_background_name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
         return false;
      
      ObjectSetInteger(0, m_background_name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, m_background_name, OBJPROP_XDISTANCE, m_panel_x);
      ObjectSetInteger(0, m_background_name, OBJPROP_YDISTANCE, m_panel_y);
      ObjectSetInteger(0, m_background_name, OBJPROP_XSIZE, m_panel_width);
      ObjectSetInteger(0, m_background_name, OBJPROP_YSIZE, m_panel_height);
      ObjectSetInteger(0, m_background_name, OBJPROP_BGCOLOR, m_bg_color);
      ObjectSetInteger(0, m_background_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, m_background_name, OBJPROP_COLOR, clrDimGray);
      ObjectSetInteger(0, m_background_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, m_background_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, m_background_name, OBJPROP_BACK, true);
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Create Label                                                     |
   //+------------------------------------------------------------------+
   bool CreateLabel(ENUM_INFO_LABEL_ID id, string text, int y_offset, int font_size, color clr)
   {
      string name = m_prefix + "_InfoLbl_" + IntegerToString(id);
      ObjectDelete(0, name);
      
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
         return false;
      
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, m_panel_x + m_panel_width - 5);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, m_panel_y + y_offset);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      
      m_labels[id] = name;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Update Label                                                     |
   //+------------------------------------------------------------------+
   void UpdateLabel(ENUM_INFO_LABEL_ID id, string text, color clr = clrNONE)
   {
      if(m_labels[id] == "")
         return;
      
      ObjectSetString(0, m_labels[id], OBJPROP_TEXT, text);
      
      if(clr != clrNONE)
         ObjectSetInteger(0, m_labels[id], OBJPROP_COLOR, clr);
   }
   
   //+------------------------------------------------------------------+
   //| Format Duration                                                  |
   //+------------------------------------------------------------------+
   string FormatDuration(int seconds)
   {
      int hours = seconds / 3600;
      int minutes = (seconds % 3600) / 60;
      int secs = seconds % 60;
      
      return StringFormat("%02d:%02d:%02d", hours, minutes, secs);
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CInfoPanel()
   {
      m_state_manager = NULL;
      m_logger = NULL;
      m_scanner = NULL;
      
      m_prefix = "TG_Info";
      m_panel_x = 10;
      m_panel_y = 30;
      m_panel_width = 280;
      m_panel_height = 80;
      
      m_bg_color = C'40,40,45';        // Dark gray
      m_text_color = clrWhiteSmoke;
      m_header_color = clrGold;
      m_profit_color = clrLimeGreen;
      m_loss_color = clrTomato;
      
      m_visible = false;
   }
   
   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   bool Initialize(CStateManager* state_mgr,
                   CLogger* logger,
                   CPositionScanner* scanner,
                   int x,
                   int y,
                   int width,
                   int height,
                   color bg_color,
                   color text_color)
   {
      if(state_mgr == NULL || logger == NULL || scanner == NULL)
         return false;
      
      m_state_manager = state_mgr;
      m_logger = logger;
      m_scanner = scanner;
      
      m_panel_x = x;
      m_panel_y = y;
      m_panel_width = width;
      m_panel_height = height;
      m_bg_color = bg_color;
      m_text_color = text_color;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Create Panel                                                     |
   //+------------------------------------------------------------------+
   bool Create()
   {
      // Create background
      if(!CreateBackground())
         return false;
      
      // Create labels
      CreateLabel(INFO_LBL_HEADER, "TITAN GRID EA v1.0", 5, 9, m_header_color);
      CreateLabel(INFO_LBL_CYCLE, "Cycle: NONE | 00:00:00", 25, 8, m_text_color);
      CreateLabel(INFO_LBL_PL, "P&L: $0.00 | Pos: 0 (0.00)", 40, 8, m_text_color);
      CreateLabel(INFO_LBL_STATUS, "● Mart  ● GS  ● Hedge  ● Recovery", 60, 7, m_text_color);
      
      m_visible = true;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Update Display                                                   |
   //+------------------------------------------------------------------+
   void Update()
   {
      if(!m_visible)
         return;
      
      // Update cycle info
      string cycle_text = "Cycle: ";
      if(m_state_manager.IsCycleActive())
      {
         ENUM_MARTINGALE_MODE mode = m_state_manager.GetCurrentMode();
         int layer = m_state_manager.GetCurrentLayer();
         datetime start = m_state_manager.GetCycleStartTime();
         int duration = (int)(TimeCurrent() - start);
         
         string mode_str = (mode == MODE_BUY) ? "BUY" : "SELL";
         cycle_text += mode_str + " L" + IntegerToString(layer) + " | " + FormatDuration(duration);
         
         color cycle_color = (mode == MODE_BUY) ? clrDodgerBlue : clrOrangeRed;
         UpdateLabel(INFO_LBL_CYCLE, cycle_text, cycle_color);
      }
      else
      {
         cycle_text += "NONE | 00:00:00";
         UpdateLabel(INFO_LBL_CYCLE, cycle_text, clrGray);
      }
      
      // Update P&L and positions
      SPositionSummary summary = m_scanner.GetSummary();
      double pl = summary.GetNetPL();
      int total_pos = summary.total_positions;
      double total_lots = summary.mart_buy_lots + summary.mart_sell_lots + summary.hedge_lots;
      
      string pl_text = StringFormat("P&L: $%.2f | Pos: %d (%.2f)", pl, total_pos, total_lots);
      color pl_color = (pl > 0) ? m_profit_color : (pl < 0) ? m_loss_color : m_text_color;
      UpdateLabel(INFO_LBL_PL, pl_text, pl_color);
      
      // Update status lights
      string status_text = "";
      status_text += m_state_manager.IsMartingaleStopped() ? "○" : "●";
      status_text += " Mart  ";
      status_text += m_state_manager.IsGridSlicerStopped() ? "○" : "●";
      status_text += " GS  ";
      status_text += m_state_manager.IsHedgeStopped() ? "○" : "●";
      status_text += " Hedge  ";
      status_text += m_state_manager.IsRecoveryStopped() ? "○" : "●";
      status_text += " Recovery";
      
      UpdateLabel(INFO_LBL_STATUS, status_text, m_text_color);
   }
   
   //+------------------------------------------------------------------+
   //| Destroy Panel                                                    |
   //+------------------------------------------------------------------+
   void Destroy()
   {
      ObjectDelete(0, m_background_name);
      
      for(int i = 0; i < INFO_LBL_COUNT; i++)
      {
         if(m_labels[i] != "")
         {
            ObjectDelete(0, m_labels[i]);
            m_labels[i] = "";
         }
      }
      
      m_visible = false;
   }
   
   //+------------------------------------------------------------------+
   //| Getters                                                          |
   //+------------------------------------------------------------------+
   bool IsVisible() const { return m_visible; }
   int GetWidth() const { return m_panel_width; }
   int GetHeight() const { return m_panel_height; }
};

//+------------------------------------------------------------------+
//| End of TG_InfoPanel.mqh                                          |
//+------------------------------------------------------------------+
#endif
