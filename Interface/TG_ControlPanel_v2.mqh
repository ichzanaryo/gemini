//+------------------------------------------------------------------+
//|                      Interface/TG_ControlPanel_v2.mqh            |
//|                                          Titan Grid EA v1.0      |
//|              Dual Panel Manager (Info + Buttons)                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "2.00"

#ifndef TG_CONTROL_PANEL_V2_MQH
#define TG_CONTROL_PANEL_V2_MQH

#include "../Core/TG_Definitions.mqh"
#include "../Core/TG_StateManager.mqh"
#include "../Core/TG_Logger.mqh"
#include "../Utilities/TG_PositionScanner.mqh"
#include "TG_InfoPanel.mqh"
#include "TG_ButtonPanel.mqh"

// Forward declarations
class CEntryManager;
class CMartingaleSystem;

//+------------------------------------------------------------------+
//| DUAL PANEL CONTROL MANAGER                                       |
//+------------------------------------------------------------------+
class CControlPanel
{
private:
   CInfoPanel*         m_info_panel;
   CButtonPanel*       m_button_panel;
   
   CStateManager*      m_state_manager;
   CLogger*            m_logger;
   CPositionScanner*   m_scanner;
   CEntryManager*      m_entry_manager;
   CMartingaleSystem*  m_martingale;
   
   bool                m_initialized;
   datetime            m_last_update;
   int                 m_update_interval_ms;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CControlPanel()
   {
      m_info_panel = NULL;
      m_button_panel = NULL;
      m_state_manager = NULL;
      m_logger = NULL;
      m_scanner = NULL;
      m_entry_manager = NULL;
      m_martingale = NULL;
      
      m_initialized = false;
      m_last_update = 0;
      m_update_interval_ms = 500;
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~CControlPanel()
   {
      Destroy();
      
      if(m_info_panel != NULL)
      {
         delete m_info_panel;
         m_info_panel = NULL;
      }
      
      if(m_button_panel != NULL)
      {
         delete m_button_panel;
         m_button_panel = NULL;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Initialize (Simplified - 2 Panel System)                        |
   //+------------------------------------------------------------------+
   bool Initialize(CStateManager* state_mgr,
                   CLogger* logger,
                   CPositionScanner* scanner)
   {
      if(state_mgr == NULL || logger == NULL || scanner == NULL)
      {
         Print("Control Panel: NULL pointer in Initialize");
         return false;
      }
      
      m_state_manager = state_mgr;
      m_logger = logger;
      m_scanner = scanner;
      
      // Create info panel (top right)
      m_info_panel = new CInfoPanel();
      if(m_info_panel == NULL)
      {
         Print("Failed to create Info Panel");
         return false;
      }
      
      if(!m_info_panel.Initialize(m_state_manager, m_logger, m_scanner,
                                   10,   // x offset from right
                                   30,   // y offset from top
                                   280,  // width
                                   80,   // height
                                   C'40,40,45',  // bg color
                                   clrWhiteSmoke)) // text color
      {
         Print("Failed to initialize Info Panel");
         return false;
      }
      
      // Create button panel (bottom left)
      m_button_panel = new CButtonPanel();
      if(m_button_panel == NULL)
      {
         Print("Failed to create Button Panel");
         return false;
      }
      
      // Note: entry_manager and martingale will be set later via SetDependencies
      if(!m_button_panel.Initialize(m_state_manager, m_logger, NULL, NULL,
                                     10,   // x offset from left
                                     30,   // y offset from bottom
                                     200,  // width
                                     40,   // button height
                                     5))   // button spacing
      {
         Print("Failed to initialize Button Panel");
         return false;
      }
      
      m_initialized = true;
      Print("Control Panel (v2) initialized - 2 panel system");
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Set Additional Dependencies                                      |
   //+------------------------------------------------------------------+
   void SetDependencies(CEntryManager* entry_mgr, CMartingaleSystem* martingale)
   {
      m_entry_manager = entry_mgr;
      m_martingale = martingale;
      
      // Update button panel with trading system dependencies
      if(m_button_panel != NULL)
      {
         m_button_panel.Initialize(m_state_manager, m_logger, 
                                   m_entry_manager, m_martingale,
                                   10, 30, 200, 40, 5);
         Print("Button Panel dependencies set");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Create Both Panels                                               |
   //+------------------------------------------------------------------+
   bool Create()
   {
      if(!m_initialized)
      {
         Print("Cannot create panels - not initialized");
         return false;
      }
      
      bool success = true;
      
      // Create info panel
      if(m_info_panel != NULL)
      {
         if(!m_info_panel.Create())
         {
            Print("Failed to create Info Panel UI");
            success = false;
         }
         else
         {
            Print("Info Panel created (top right)");
         }
      }
      
      // Create button panel
      if(m_button_panel != NULL)
      {
         if(!m_button_panel.Create())
         {
            Print("Failed to create Button Panel UI");
            success = false;
         }
         else
         {
            Print("Button Panel created (bottom left)");
         }
      }
      
      ChartRedraw();
      
      return success;
   }
   
   //+------------------------------------------------------------------+
   //| Update Both Panels                                               |
   //+------------------------------------------------------------------+
   void Update()
   {
      datetime current_time = TimeCurrent();
      int elapsed_ms = (int)((current_time - m_last_update) * 1000);
      
      if(elapsed_ms < m_update_interval_ms)
         return;
      
      // Update info panel
      if(m_info_panel != NULL && m_info_panel.IsVisible())
      {
         m_info_panel.Update();
      }
      
      // Update button panel
      if(m_button_panel != NULL && m_button_panel.IsVisible())
      {
         m_button_panel.Update();
      }
      
      m_last_update = current_time;
   }
   
   //+------------------------------------------------------------------+
   //| Handle Chart Events                                              |
   //+------------------------------------------------------------------+
   void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
   {
      if(id == CHARTEVENT_OBJECT_CLICK)
      {
         // Handle button clicks
         if(m_button_panel != NULL)
         {
            m_button_panel.OnButtonClick(sparam);
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Destroy Both Panels                                              |
   //+------------------------------------------------------------------+
   void Destroy()
   {
      if(m_info_panel != NULL)
      {
         m_info_panel.Destroy();
      }
      
      if(m_button_panel != NULL)
      {
         m_button_panel.Destroy();
      }
   }
   
   //+------------------------------------------------------------------+
   //| Getters                                                          |
   //+------------------------------------------------------------------+
   bool IsInitialized() const { return m_initialized; }
   
   bool IsVisible() const 
   { 
      if(m_info_panel != NULL && m_info_panel.IsVisible())
         return true;
      if(m_button_panel != NULL && m_button_panel.IsVisible())
         return true;
      return false;
   }
};

//+------------------------------------------------------------------+
//| End of TG_ControlPanel_v2.mqh                                    |
//+------------------------------------------------------------------+
#endif
