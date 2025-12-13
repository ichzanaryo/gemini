//+------------------------------------------------------------------+
//|                          Interface/TG_ButtonPanel.mqh            |
//|                                          Titan Grid EA v1.0      |
//|                Button Controls (Bottom Left)                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.00"

#ifndef TG_BUTTON_PANEL_MQH
#define TG_BUTTON_PANEL_MQH

#include "../Core/TG_Definitions.mqh"
#include "../Core/TG_StateManager.mqh"
#include "../Core/TG_Logger.mqh"
#include "../Systems/TG_EntryManager.mqh"
#include "../Systems/TG_Martingale.mqh"

//+------------------------------------------------------------------+
//| BUTTON IDs (Simplified)                                          |
//+------------------------------------------------------------------+
enum ENUM_BTN_ID
{
   BTN_BUY,
   BTN_SELL,
   BTN_CLOSE_CYCLE,
   BTN_CLOSE_ALL,
   BTN_STOP_MART,
   BTN_STOP_ALL,
   BTN_COUNT
};

//+------------------------------------------------------------------+
//| BUTTON CONTROL PANEL CLASS                                       |
//+------------------------------------------------------------------+
class CButtonPanel
{
private:
   CStateManager*      m_state_manager;
   CLogger*            m_logger;
   CEntryManager*      m_entry_manager;
   CMartingaleSystem*  m_martingale;
   
   string              m_prefix;
   int                 m_panel_x;
   int                 m_panel_y;
   int                 m_panel_width;
   int                 m_button_height;
   int                 m_button_spacing;
   
   string              m_background_name;
   string              m_buttons[BTN_COUNT];
   
   color               m_bg_color;
   color               m_color_buy;
   color               m_color_sell;
   color               m_color_close;
   color               m_color_stop;
   color               m_color_resume;
   
   bool                m_visible;
   
   //+------------------------------------------------------------------+
   //| Create Background                                                |
   //+------------------------------------------------------------------+
   bool CreateBackground(int height)
   {
      m_background_name = m_prefix + "_BtnBG";
      ObjectDelete(0, m_background_name);
      
      if(!ObjectCreate(0, m_background_name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
         return false;
      
      ObjectSetInteger(0, m_background_name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, m_background_name, OBJPROP_XDISTANCE, m_panel_x);
      ObjectSetInteger(0, m_background_name, OBJPROP_YDISTANCE, m_panel_y);
      ObjectSetInteger(0, m_background_name, OBJPROP_XSIZE, m_panel_width);
      ObjectSetInteger(0, m_background_name, OBJPROP_YSIZE, height);
      ObjectSetInteger(0, m_background_name, OBJPROP_BGCOLOR, m_bg_color);
      ObjectSetInteger(0, m_background_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, m_background_name, OBJPROP_COLOR, clrDimGray);
      ObjectSetInteger(0, m_background_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, m_background_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, m_background_name, OBJPROP_BACK, true);
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Create Button                                                    |
   //+------------------------------------------------------------------+
   bool CreateButton(ENUM_BTN_ID id, string text, int y_offset, int width, color bg_color)
   {
      string name = m_prefix + "_Btn_" + IntegerToString(id);
      ObjectDelete(0, name);
      
      if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0))
         return false;
      
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, m_panel_x + 10);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, m_panel_y + y_offset);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, m_button_height);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrGray);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_STATE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      
      m_buttons[id] = name;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get Context-Aware Label                                         |
   //+------------------------------------------------------------------+
   string GetBuyLabel()
   {
      if(m_state_manager == NULL || !m_state_manager.IsCycleActive())
         return "🟢 BUY";
      
      ENUM_MARTINGALE_MODE mode = m_state_manager.GetCurrentMode();
      int layer = m_state_manager.GetCurrentLayer();
      
      if(mode == MODE_BUY)
         return "🟢 ADD L" + IntegerToString(layer + 1);
      else
         return "🟢 HEDGE";
   }
   
   //+------------------------------------------------------------------+
   //| Get Context-Aware Label                                         |
   //+------------------------------------------------------------------+
   string GetSellLabel()
   {
      if(m_state_manager == NULL || !m_state_manager.IsCycleActive())
         return "🔴 SELL";
      
      ENUM_MARTINGALE_MODE mode = m_state_manager.GetCurrentMode();
      int layer = m_state_manager.GetCurrentLayer();
      
      if(mode == MODE_SELL)
         return "🔴 ADD L" + IntegerToString(layer + 1);
      else
         return "🔴 HEDGE";
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CButtonPanel()
   {
      m_state_manager = NULL;
      m_logger = NULL;
      m_entry_manager = NULL;
      m_martingale = NULL;
      
      m_prefix = "TG_Btn";
      m_panel_x = 10;
      m_panel_y = 30;
      m_panel_width = 200;
      m_button_height = 40;
      m_button_spacing = 5;
      
      m_bg_color = C'40,40,45';
      m_color_buy = C'0,150,0';         // Dark green
      m_color_sell = C'200,50,50';      // Dark red
      m_color_close = C'150,0,0';       // Crimson
      m_color_stop = C'100,50,50';      // Dark red
      m_color_resume = C'50,150,50';    // Forest green
      
      m_visible = false;
   }
   
   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   bool Initialize(CStateManager* state_mgr,
                   CLogger* logger,
                   CEntryManager* entry_mgr,
                   CMartingaleSystem* martingale,
                   int x,
                   int y,
                   int width,
                   int button_height,
                   int button_spacing)
   {
      if(state_mgr == NULL || logger == NULL)
         return false;
      
      m_state_manager = state_mgr;
      m_logger = logger;
      m_entry_manager = entry_mgr;
      m_martingale = martingale;
      
      m_panel_x = x;
      m_panel_y = y;
      m_panel_width = width;
      m_button_height = button_height;
      m_button_spacing = button_spacing;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Create Panel                                                     |
   //+------------------------------------------------------------------+
   bool Create()
   {
      int current_y = m_panel_y;
      int half_width = (m_panel_width - 20 - m_button_spacing) / 2;
      
      // Row 1: BUY + SELL (side by side)
      CreateButton(BTN_BUY, "🟢 BUY", current_y, half_width, m_color_buy);
      
      // Create SELL button with offset
      string sell_name = m_prefix + "_Btn_" + IntegerToString(BTN_SELL);
      ObjectDelete(0, sell_name);
      
      if(ObjectCreate(0, sell_name, OBJ_BUTTON, 0, 0, 0))
      {
         ObjectSetInteger(0, sell_name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
         ObjectSetInteger(0, sell_name, OBJPROP_XDISTANCE, m_panel_x + 10 + half_width + m_button_spacing);
         ObjectSetInteger(0, sell_name, OBJPROP_YDISTANCE, current_y);
         ObjectSetInteger(0, sell_name, OBJPROP_XSIZE, half_width);
         ObjectSetInteger(0, sell_name, OBJPROP_YSIZE, m_button_height);
         ObjectSetInteger(0, sell_name, OBJPROP_BGCOLOR, m_color_sell);
         ObjectSetInteger(0, sell_name, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, sell_name, OBJPROP_FONTSIZE, 10);
         ObjectSetString(0, sell_name, OBJPROP_FONT, "Arial Bold");
         ObjectSetString(0, sell_name, OBJPROP_TEXT, "🔴 SELL");
         ObjectSetInteger(0, sell_name, OBJPROP_STATE, false);
         ObjectSetInteger(0, sell_name, OBJPROP_SELECTABLE, false);
         m_buttons[BTN_SELL] = sell_name;
      }
      
      current_y += m_button_height + m_button_spacing;
      
      // Row 2: CLOSE CYCLE
      CreateButton(BTN_CLOSE_CYCLE, "⏹ CLOSE CYCLE", current_y, m_panel_width - 20, m_color_close);
      current_y += m_button_height + m_button_spacing;
      
      // Row 3: CLOSE ALL
      CreateButton(BTN_CLOSE_ALL, "⛔ CLOSE ALL", current_y, m_panel_width - 20, m_color_close);
      current_y += m_button_height + m_button_spacing * 2;
      
      // Row 4: STOP MART
      CreateButton(BTN_STOP_MART, "⏸ STOP MART", current_y, m_panel_width - 20, m_color_stop);
      current_y += m_button_height + m_button_spacing;
      
      // Row 5: STOP ALL
      CreateButton(BTN_STOP_ALL, "⏸ STOP ALL", current_y, m_panel_width - 20, m_color_stop);
      current_y += m_button_height + 10;
      
      // Create background with calculated height
      int total_height = current_y - m_panel_y;
      CreateBackground(total_height);
      
      m_visible = true;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Update Button States                                             |
   //+------------------------------------------------------------------+
   void Update()
   {
      if(!m_visible || m_state_manager == NULL)
         return;
      
      // Update BUY/SELL labels
      ObjectSetString(0, m_buttons[BTN_BUY], OBJPROP_TEXT, GetBuyLabel());
      ObjectSetString(0, m_buttons[BTN_SELL], OBJPROP_TEXT, GetSellLabel());
      
      // Update CLOSE CYCLE (enabled only when cycle active)
      bool cycle_active = m_state_manager.IsCycleActive();
      ObjectSetInteger(0, m_buttons[BTN_CLOSE_CYCLE], OBJPROP_BGCOLOR, 
                      cycle_active ? m_color_close : clrDarkGray);
      
      // Update STOP MART button
      bool mart_stopped = m_state_manager.IsMartingaleStopped();
      ObjectSetString(0, m_buttons[BTN_STOP_MART], OBJPROP_TEXT,
                     mart_stopped ? "▶ RESUME MART" : "⏸ STOP MART");
      ObjectSetInteger(0, m_buttons[BTN_STOP_MART], OBJPROP_BGCOLOR,
                      mart_stopped ? m_color_resume : m_color_stop);
      
      // Update STOP ALL button
      bool all_stopped = (m_state_manager.IsMartingaleStopped() &&
                         m_state_manager.IsGridSlicerStopped() &&
                         m_state_manager.IsHedgeStopped() &&
                         m_state_manager.IsRecoveryStopped());
      ObjectSetString(0, m_buttons[BTN_STOP_ALL], OBJPROP_TEXT,
                     all_stopped ? "▶ RESUME ALL" : "⏸ STOP ALL");
      ObjectSetInteger(0, m_buttons[BTN_STOP_ALL], OBJPROP_BGCOLOR,
                      all_stopped ? m_color_resume : m_color_stop);
   }
   
   //+------------------------------------------------------------------+
   //| Handle Button Click                                              |
   //+------------------------------------------------------------------+
   bool OnButtonClick(string clicked_name)
   {
      // Find button
      ENUM_BTN_ID btn_id = BTN_COUNT;
      for(int i = 0; i < BTN_COUNT; i++)
      {
         if(m_buttons[i] == clicked_name)
         {
            btn_id = (ENUM_BTN_ID)i;
            break;
         }
      }
      
      if(btn_id == BTN_COUNT)
         return false;
      
      // Reset button state
      ObjectSetInteger(0, clicked_name, OBJPROP_STATE, false);
      
      // Handle click
      switch(btn_id)
      {
         case BTN_BUY:
            return HandleBuyClick();
         
         case BTN_SELL:
            return HandleSellClick();
         
         case BTN_CLOSE_CYCLE:
            return HandleCloseCycleClick();
         
         case BTN_CLOSE_ALL:
            return HandleCloseAllClick();
         
         case BTN_STOP_MART:
            return HandleStopMartClick();
         
         case BTN_STOP_ALL:
            return HandleStopAllClick();
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Button Handlers                                                  |
   //+------------------------------------------------------------------+
   bool HandleBuyClick()
   {
      if(m_logger != NULL)
         m_logger.Info("BUY button clicked");
      
      if(m_entry_manager == NULL || m_state_manager == NULL)
         return false;
      
      if(!m_state_manager.IsCycleActive())
         return m_entry_manager.ManualEntryBuy();
      
      ENUM_MARTINGALE_MODE mode = m_state_manager.GetCurrentMode();
      if(mode == MODE_BUY && m_martingale != NULL)
         return m_martingale.AddLayer();
      
      return false;
   }
   
   bool HandleSellClick()
   {
      if(m_logger != NULL)
         m_logger.Info("SELL button clicked");
      
      if(m_entry_manager == NULL || m_state_manager == NULL)
         return false;
      
      if(!m_state_manager.IsCycleActive())
         return m_entry_manager.ManualEntrySell();
      
      ENUM_MARTINGALE_MODE mode = m_state_manager.GetCurrentMode();
      if(mode == MODE_SELL && m_martingale != NULL)
         return m_martingale.AddLayer();
      
      return false;
   }
   
   bool HandleCloseCycleClick()
   {
      if(m_martingale != NULL && m_state_manager.IsCycleActive())
         return m_martingale.CloseCycle(false);
      return false;
   }
   
   bool HandleCloseAllClick()
   {
      if(m_logger != NULL)
         m_logger.Warning("Close All - not yet implemented");
      return false;
   }
   
   bool HandleStopMartClick()
   {
      if(m_state_manager.IsMartingaleStopped())
         m_state_manager.ResumeMartingale();
      else
         m_state_manager.StopMartingale();
      return true;
   }
   
   bool HandleStopAllClick()
   {
      bool all_stopped = (m_state_manager.IsMartingaleStopped() &&
                         m_state_manager.IsGridSlicerStopped() &&
                         m_state_manager.IsHedgeStopped() &&
                         m_state_manager.IsRecoveryStopped());
      
      if(all_stopped)
         m_state_manager.ResumeAll();
      else
      {
         m_state_manager.StopMartingale();
         m_state_manager.StopGridSlicer();
         m_state_manager.StopHedge();
         m_state_manager.StopRecovery();
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Destroy Panel                                                    |
   //+------------------------------------------------------------------+
   void Destroy()
   {
      ObjectDelete(0, m_background_name);
      
      for(int i = 0; i < BTN_COUNT; i++)
      {
         if(m_buttons[i] != "")
         {
            ObjectDelete(0, m_buttons[i]);
            m_buttons[i] = "";
         }
      }
      
      m_visible = false;
   }
   
   //+------------------------------------------------------------------+
   //| Getters                                                          |
   //+------------------------------------------------------------------+
   bool IsVisible() const { return m_visible; }
};

//+------------------------------------------------------------------+
//| End of TG_ButtonPanel.mqh                                        |
//+------------------------------------------------------------------+
#endif
