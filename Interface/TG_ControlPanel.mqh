//+------------------------------------------------------------------+
//|                           Interface/TG_ControlPanel.mqh          |
//|                                          Titan Grid EA v1.0      |
//|                      Main Control Panel System                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.00"

#ifndef TG_CONTROL_PANEL_MQH
#define TG_CONTROL_PANEL_MQH

#include "../Core/TG_Definitions.mqh"
#include "../Core/TG_StateManager.mqh"
#include "../Core/TG_Logger.mqh"
#include "../Utilities/TG_PositionScanner.mqh"
#include "TG_PanelButtons.mqh"
#include "TG_PanelDisplay.mqh"

//+------------------------------------------------------------------+
//| CONTROL PANEL CLASS                                               |
//+------------------------------------------------------------------+
class CControlPanel
{
private:
   CPanelButtons*      m_buttons;
   CPanelDisplay*      m_display;
   
   CStateManager*      m_state_manager;
   CLogger*            m_logger;
   CPositionScanner*   m_scanner;
   CEntryManager*      m_entry_manager;
   CMartingaleManagerV2*  m_martingale;
   
   string              m_prefix;
   bool                m_initialized;
   bool                m_visible;
   
   int                 m_panel_x;
   int                 m_panel_y;
   int                 m_panel_width;
   int                 m_panel_height;
   
   datetime            m_last_update;
   int                 m_update_interval_ms;
   
   string              m_background_name;
   
   bool CreateBackground()
   {
      m_background_name = m_prefix + "_BG";
      ObjectDelete(0, m_background_name);
      
      if(!ObjectCreate(0, m_background_name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
         return false;
      
      ObjectSetInteger(0, m_background_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, m_background_name, OBJPROP_XDISTANCE, m_panel_x);
      ObjectSetInteger(0, m_background_name, OBJPROP_YDISTANCE, m_panel_y);
      ObjectSetInteger(0, m_background_name, OBJPROP_XSIZE, m_panel_width);
      ObjectSetInteger(0, m_background_name, OBJPROP_YSIZE, m_panel_height);
      ObjectSetInteger(0, m_background_name, OBJPROP_BGCOLOR, clrDarkSlateGray);
      ObjectSetInteger(0, m_background_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, m_background_name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, m_background_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, m_background_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, m_background_name, OBJPROP_BACK, true);
      
      return true;
   }

public:
   CControlPanel()
   {
      m_buttons = NULL;
      m_display = NULL;
      m_state_manager = NULL;
      m_logger = NULL;
      m_scanner = NULL;
      m_entry_manager = NULL;
      m_martingale = NULL;
      
      m_prefix = "TG_Panel";
      m_initialized = false;
      m_visible = false;
      
      m_panel_x = 10;
      m_panel_y = 50;
      m_panel_width = 350;
      m_panel_height = 600;
      
      m_last_update = 0;
      m_update_interval_ms = 500;
   }
   
   ~CControlPanel()
   {
      Destroy();
      
      if(m_buttons != NULL)
         delete m_buttons;
      
      if(m_display != NULL)
         delete m_display;
   }
   
   bool Initialize(CStateManager* state_mgr,
                   CLogger* logger,
                   CPositionScanner* scanner,
                   CEntryManager* entry_mgr,
                   CMartingaleManagerV2* martingale,
                   int pos_x,
                   int pos_y,
                   int width,
                   int height,
                   int update_interval_ms,
                   bool show_manual_buttons,
                   bool show_stop_resume,
                   bool show_close_cycle,
                   bool show_close_all,
                   bool show_account,
                   bool show_positions,
                   bool show_cycle,
                   bool show_stats,
                   bool show_status)
   {
      if(state_mgr == NULL || logger == NULL || scanner == NULL || 
         entry_mgr == NULL || martingale == NULL)
      {
         Print("Control Panel: NULL pointer in Initialize");
         return false;
      }
      
      m_state_manager = state_mgr;
      m_logger = logger;
      m_scanner = scanner;
      m_entry_manager = entry_mgr;
      m_martingale = martingale;
      
      m_panel_x = pos_x;
      m_panel_y = pos_y;
      m_panel_width = width;
      m_panel_height = height;
      m_update_interval_ms = update_interval_ms;
      
      m_buttons = new CPanelButtons();
      m_display = new CPanelDisplay();
      
      if(m_buttons == NULL || m_display == NULL)
      {
         m_logger->Error("Failed to create panel components");
         return false;
      }
      
      int display_x = m_panel_x + 10;
      int display_y = m_panel_y + 10;
      int button_y = m_panel_y + 400;
      
      if(!m_display.Initialize(
         m_state_manager, m_logger, m_scanner,
         m_prefix, display_x, display_y, 20,
         clrGold, clrWhite, clrLimeGreen, clrRed,
         show_account, show_positions, show_cycle, show_stats, show_status, false))
      {
         m_logger->Error("Failed to initialize panel display");
         return false;
      }
      
      if(!m_buttons.Initialize(
         m_state_manager, m_logger, m_entry_manager, m_martingale,
         m_prefix, m_panel_x + 10, button_y, m_panel_width - 20, 30, 5,
         clrDodgerBlue, clrOrangeRed, clrCrimson, clrDarkRed, clrForestGreen))
      {
         m_logger->Error("Failed to initialize panel buttons");
         return false;
      }
      
      m_initialized = true;
      m_logger->Info("Control Panel initialized successfully");
      
      return true;
   }
   
   bool Create()
   {
      if(!m_initialized)
      {
         m_logger->Error("Cannot create panel - not initialized");
         return false;
      }
      
      if(!CreateBackground())
      {
         m_logger->Error("Failed to create panel background");
         return false;
      }
      
      if(!m_display.CreateAllLabels())
      {
         m_logger->Error("Failed to create display labels");
         return false;
      }
      
      if(!m_buttons.CreateAllButtons(true, true, true, true))
      {
         m_logger->Error("Failed to create buttons");
         return false;
      }
      
      m_visible = true;
      m_logger->Info("Control Panel created and visible");
      
      ChartRedraw();
      
      return true;
   }
   
   void Update()
   {
      if(!m_visible)
         return;
      
      int elapsed_ms = (int)((TimeCurrent() - m_last_update) * 1000);
      
      if(elapsed_ms < m_update_interval_ms)
         return;
      
      m_display.UpdateDisplay();
      m_buttons.UpdateButtonStates();
      
      m_last_update = TimeCurrent();
   }
   
   void OnChartEvent(int id, long lparam, double dparam, string sparam)
   {
      if(id == CHARTEVENT_OBJECT_CLICK)
      {
         m_buttons.OnButtonClick(sparam);
      }
   }
   
   void Show()
   {
      if(!m_initialized)
         return;
      
      if(!m_visible)
         Create();
      
      m_visible = true;
   }
   
   void Hide()
   {
      ObjectSetInteger(0, m_background_name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      
      m_display.DestroyAllLabels();
      m_buttons.DestroyAllButtons();
      
      m_visible = false;
   }
   
   void Destroy()
   {
      if(m_visible)
         Hide();
      
      ObjectDelete(0, m_background_name);
   }
   
   bool IsVisible() { return m_visible; }
   bool IsInitialized() { return m_initialized; }
};

#endif
