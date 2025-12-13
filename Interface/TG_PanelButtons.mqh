//+------------------------------------------------------------------+
//|                            Interface/TG_PanelButtons.mqh         |
//|                                          Titan Grid EA v1.0      |
//|                          Panel Button Management                 |
//+------------------------------------------------------------------+
//| Location: C:\Users\ichza\AppData\Roaming\MetaQuotes\Terminal\   |
//|           D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\         |
//|           TitanGridEA\Interface\TG_PanelButtons.mqh              |
//|                                                                  |
//| Purpose:  Manage all control panel buttons                      |
//|           Create, update, handle clicks                         |
//|           Context-aware button labels                           |
//|           Dependencies: Core systems, Entry manager              |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.00"

//+------------------------------------------------------------------+
//| CHANGE LOG                                                        |
//+------------------------------------------------------------------+
// Version 1.00 - 2025-01-20
// [INITIAL] Panel button system created
// [ADD] Button creation and destruction
// [ADD] Context-aware button labels
// [ADD] Click handling with enhanced manual logic
// [ADD] Button state management (enabled/disabled)
//+------------------------------------------------------------------+

#ifndef TG_PANEL_BUTTONS_MQH
#define TG_PANEL_BUTTONS_MQH

#include "../Core/TG_Definitions.mqh"
#include "../Core/TG_StateManager.mqh"
#include "../Core/TG_Logger.mqh"
#include "../Systems/TG_EntryManager.mqh"
#include "../Systems/TG_Martingale.mqh"

//+------------------------------------------------------------------+
//| BUTTON ID ENUMERATION                                             |
//+------------------------------------------------------------------+
enum ENUM_BUTTON_ID
{
   BTN_MANUAL_BUY,           // Manual BUY button
   BTN_MANUAL_SELL,          // Manual SELL button
   BTN_CLOSE_CYCLE,          // Close current cycle
   BTN_CLOSE_ALL,            // Close all positions
   BTN_STOP_MARTINGALE,      // Stop/Resume martingale
   BTN_STOP_GRIDSLICER,      // Stop/Resume GridSlicer
   BTN_STOP_HEDGE,           // Stop/Resume hedge
   BTN_STOP_RECOVERY,        // Stop/Resume recovery
   BTN_STOP_ALL,             // Stop/Resume all systems
   BTN_MINIMIZE,             // Minimize panel
   BTN_COUNT                 // Total button count
};

//+------------------------------------------------------------------+
//| BUTTON INFO STRUCTURE                                             |
//+------------------------------------------------------------------+
struct SButtonInfo
{
   string   name;            // Object name
   string   label;           // Button text
   int      x;               // X position
   int      y;               // Y position
   int      width;           // Width
   int      height;          // Height
   color    bg_color;        // Background color
   color    text_color;      // Text color
   bool     enabled;         // Is enabled
   bool     visible;         // Is visible
   
   void Reset()
   {
      name = "";
      label = "";
      x = 0;
      y = 0;
      width = 0;
      height = 0;
      bg_color = clrDimGray;
      text_color = clrWhite;
      enabled = true;
      visible = true;
   }
};

//+------------------------------------------------------------------+
//| PANEL BUTTONS CLASS                                               |
//+------------------------------------------------------------------+
class CPanelButtons
{
private:
   // Dependencies
   CStateManager*     m_state_manager;
   CLogger*           m_logger;
   CEntryManager*     m_entry_manager;
   CMartingaleManagerV2* m_martingale;
   
   // Button storage
   SButtonInfo        m_buttons[BTN_COUNT];
   
   // Settings
   string             m_prefix;           // Object name prefix
   int                m_base_x;           // Base X position
   int                m_base_y;           // Base Y position
   int                m_button_width;     // Default button width
   int                m_button_height;    // Default button height
   int                m_button_spacing;   // Spacing between buttons
   
   // Colors
   color              m_color_buy;
   color              m_color_sell;
   color              m_color_close;
   color              m_color_stop;
   color              m_color_resume;
   color              m_color_normal;
   
   //+------------------------------------------------------------------+
   //| Create Button Object                                             |
   //+------------------------------------------------------------------+
   bool CreateButton(ENUM_BUTTON_ID id, string label, int x, int y, int width, int height, color bg_color)
   {
      string name = m_prefix + "_BTN_" + EnumToString(id);
      
      // Delete if exists
      ObjectDelete(0, name);
      
      // Create button
      if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0))
      {
         m_logger.Error("Failed to create button: " + name);
         return false;
      }
      
      // Set properties
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrGray);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
      ObjectSetString(0, name, OBJPROP_TEXT, label);
      ObjectSetInteger(0, name, OBJPROP_STATE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      
      // Store info
      m_buttons[id].name = name;
      m_buttons[id].label = label;
      m_buttons[id].x = x;
      m_buttons[id].y = y;
      m_buttons[id].width = width;
      m_buttons[id].height = height;
      m_buttons[id].bg_color = bg_color;
      m_buttons[id].enabled = true;
      m_buttons[id].visible = true;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Update Button Label (Context-Aware)                             |
   //+------------------------------------------------------------------+
   string GetManualBuyLabel()
   {
      if(!m_state_manager.IsCycleActive())
         return "🟢 START BUY";
      
      ENUM_MARTINGALE_MODE mode = m_state_manager.GetCurrentMode();
      int layer = m_state_manager.GetCurrentLayer();
      
      if(mode == MODE_BUY)
      {
         // Same direction - add layer
         return "🟢 ADD BUY L" + IntegerToString(layer + 1);
      }
      else if(mode == MODE_SELL)
      {
         // Opposite direction - start hedge
         // TODO: Check if hedge already active (Phase 6)
         return "🟢 HEDGE H1";
      }
      
      return "🟢 BUY";
   }
   
   //+------------------------------------------------------------------+
   //| Update Button Label (Context-Aware)                             |
   //+------------------------------------------------------------------+
   string GetManualSellLabel()
   {
      if(!m_state_manager.IsCycleActive())
         return "🔴 START SELL";
      
      ENUM_MARTINGALE_MODE mode = m_state_manager.GetCurrentMode();
      int layer = m_state_manager.GetCurrentLayer();
      
      if(mode == MODE_SELL)
      {
         // Same direction - add layer
         return "🔴 ADD SELL L" + IntegerToString(layer + 1);
      }
      else if(mode == MODE_BUY)
      {
         // Opposite direction - start hedge
         // TODO: Check if hedge already active (Phase 6)
         return "🔴 HEDGE H1";
      }
      
      return "🔴 SELL";
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CPanelButtons()
   {
      m_state_manager = NULL;
      m_logger = NULL;
      m_entry_manager = NULL;
      m_martingale = NULL;
      
      m_prefix = "TG_Panel";
      m_base_x = 0;
      m_base_y = 0;
      m_button_width = 100;
      m_button_height = 30;
      m_button_spacing = 5;
      
      m_color_buy = clrDodgerBlue;
      m_color_sell = clrOrangeRed;
      m_color_close = clrCrimson;
      m_color_stop = clrDarkRed;
      m_color_resume = clrForestGreen;
      m_color_normal = clrDimGray;
   }
   
   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   bool Initialize(CStateManager* state_manager,
                   CLogger* logger,
                   CEntryManager* entry_manager,
                   CMartingaleManagerV2* martingale,
                   string prefix,
                   int base_x,
                   int base_y,
                   int button_width,
                   int button_height,
                   int button_spacing,
                   color color_buy,
                   color color_sell,
                   color color_close,
                   color color_stop,
                   color color_resume)
   {
      if(state_manager == NULL || logger == NULL || entry_manager == NULL || martingale == NULL)
      {
         Print("❌ PanelButtons: NULL pointer in Initialize");
         return false;
      }
      
      m_state_manager = state_manager;
      m_logger = logger;
      m_entry_manager = entry_manager;
      m_martingale = martingale;
      
      m_prefix = prefix;
      m_base_x = base_x;
      m_base_y = base_y;
      m_button_width = button_width;
      m_button_height = button_height;
      m_button_spacing = button_spacing;
      
      m_color_buy = color_buy;
      m_color_sell = color_sell;
      m_color_close = color_close;
      m_color_stop = color_stop;
      m_color_resume = color_resume;
      
      m_logger.Info("✅ Panel Buttons initialized");
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Create All Buttons                                               |
   //+------------------------------------------------------------------+
   bool CreateAllButtons(bool show_manual,
                        bool show_stop_resume,
                        bool show_close_cycle,
                        bool show_close_all)
   {
      int current_y = m_base_y;
      
      // Manual BUY/SELL buttons (side by side)
      if(show_manual)
      {
         int half_width = (m_button_width - m_button_spacing) / 2;
         
         CreateButton(BTN_MANUAL_BUY, "🟢 BUY", m_base_x, current_y, 
                     half_width, m_button_height, m_color_buy);
         
         CreateButton(BTN_MANUAL_SELL, "🔴 SELL", m_base_x + half_width + m_button_spacing, current_y,
                     half_width, m_button_height, m_color_sell);
         
         current_y += m_button_height + m_button_spacing;
      }
      
      // Close Cycle button
      if(show_close_cycle)
      {
         CreateButton(BTN_CLOSE_CYCLE, "⏹ CLOSE CYCLE", m_base_x, current_y,
                     m_button_width, m_button_height, m_color_close);
         
         current_y += m_button_height + m_button_spacing;
      }
      
      // Close All button
      if(show_close_all)
      {
         CreateButton(BTN_CLOSE_ALL, "⛔ CLOSE ALL", m_base_x, current_y,
                     m_button_width, m_button_height, m_color_close);
         
         current_y += m_button_height + m_button_spacing;
      }
      
      // Stop/Resume buttons
      if(show_stop_resume)
      {
         CreateButton(BTN_STOP_MARTINGALE, "⏸ STOP MART", m_base_x, current_y,
                     m_button_width, m_button_height, m_color_stop);
         
         current_y += m_button_height + m_button_spacing;
         
         CreateButton(BTN_STOP_ALL, "⏸ STOP ALL", m_base_x, current_y,
                     m_button_width, m_button_height, m_color_stop);
         
         current_y += m_button_height + m_button_spacing;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Update Button States                                             |
   //+------------------------------------------------------------------+
   void UpdateButtonStates()
   {
      // Update Manual BUY button
      string buy_label = GetManualBuyLabel();
      ObjectSetString(0, m_buttons[BTN_MANUAL_BUY].name, OBJPROP_TEXT, buy_label);
      
      // Update Manual SELL button
      string sell_label = GetManualSellLabel();
      ObjectSetString(0, m_buttons[BTN_MANUAL_SELL].name, OBJPROP_TEXT, sell_label);
      
      // Update Close Cycle button (only enabled when cycle active)
      bool cycle_active = m_state_manager.IsCycleActive();
      SetButtonEnabled(BTN_CLOSE_CYCLE, cycle_active);
      
      // Update Stop/Resume buttons
      bool mart_stopped = m_state_manager.IsMartingaleStopped();
      ObjectSetString(0, m_buttons[BTN_STOP_MARTINGALE].name, OBJPROP_TEXT, 
                     mart_stopped ? "▶ RESUME MART" : "⏸ STOP MART");
      ObjectSetInteger(0, m_buttons[BTN_STOP_MARTINGALE].name, OBJPROP_BGCOLOR,
                      mart_stopped ? m_color_resume : m_color_stop);
      
      // Update Stop All button
      bool all_stopped = (m_state_manager.IsMartingaleStopped() && 
                         m_state_manager.IsGridSlicerStopped() &&
                         m_state_manager.IsHedgeStopped() &&
                         m_state_manager.IsRecoveryStopped());
      
      ObjectSetString(0, m_buttons[BTN_STOP_ALL].name, OBJPROP_TEXT,
                     all_stopped ? "▶ RESUME ALL" : "⏸ STOP ALL");
      ObjectSetInteger(0, m_buttons[BTN_STOP_ALL].name, OBJPROP_BGCOLOR,
                      all_stopped ? m_color_resume : m_color_stop);
   }
   
   //+------------------------------------------------------------------+
   //| Set Button Enabled/Disabled                                      |
   //+------------------------------------------------------------------+
   void SetButtonEnabled(ENUM_BUTTON_ID id, bool enabled)
   {
      m_buttons[id].enabled = enabled;
      
      // Visual feedback
      if(enabled)
      {
         ObjectSetInteger(0, m_buttons[id].name, OBJPROP_BGCOLOR, m_buttons[id].bg_color);
         ObjectSetInteger(0, m_buttons[id].name, OBJPROP_COLOR, clrWhite);
      }
      else
      {
         ObjectSetInteger(0, m_buttons[id].name, OBJPROP_BGCOLOR, clrDarkGray);
         ObjectSetInteger(0, m_buttons[id].name, OBJPROP_COLOR, clrGray);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Handle Button Click                                              |
   //+------------------------------------------------------------------+
   bool OnButtonClick(string clicked_object)
   {
      // Find which button was clicked
      ENUM_BUTTON_ID clicked_id = BTN_COUNT;
      
      for(int i = 0; i < BTN_COUNT; i++)
      {
         if(m_buttons[i].name == clicked_object)
         {
            clicked_id = (ENUM_BUTTON_ID)i;
            break;
         }
      }
      
      if(clicked_id == BTN_COUNT)
         return false; // Not our button
      
      // Check if button is enabled
      if(!m_buttons[clicked_id].enabled)
      {
         m_logger.Warning("Button clicked but disabled: " + clicked_object);
         return true; // Handled but ignored
      }
      
      // Reset button state
      ObjectSetInteger(0, clicked_object, OBJPROP_STATE, false);
      
      // Handle button action
      switch(clicked_id)
      {
         case BTN_MANUAL_BUY:
            return HandleManualBuyClick();
         
         case BTN_MANUAL_SELL:
            return HandleManualSellClick();
         
         case BTN_CLOSE_CYCLE:
            return HandleCloseCycleClick();
         
         case BTN_CLOSE_ALL:
            return HandleCloseAllClick();
         
         case BTN_STOP_MARTINGALE:
            return HandleStopMartingaleClick();
         
         case BTN_STOP_ALL:
            return HandleStopAllClick();
         
         default:
            return false;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Handle Manual BUY Click (Enhanced Logic)                        |
   //+------------------------------------------------------------------+
   bool HandleManualBuyClick()
   {
      m_logger.Info("🔘 Manual BUY button clicked");
      
      if(!m_state_manager.IsCycleActive())
      {
         // Start new BUY cycle
         return m_entry_manager.ManualEntryBuy();
      }
      
      ENUM_MARTINGALE_MODE mode = m_state_manager.GetCurrentMode();
      
      if(mode == MODE_BUY)
      {
         // Add BUY layer
         m_logger.Info("Adding BUY layer (same direction)");
         return m_martingale.AddLayer();
      }
      else if(mode == MODE_SELL)
      {
         // Start hedge (will be implemented in Phase 6)
         m_logger.Info("Starting HEDGE (opposite direction)");
         m_logger.Warning("Hedge system not yet implemented - Phase 6");
         return false;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Handle Manual SELL Click (Enhanced Logic)                       |
   //+------------------------------------------------------------------+
   bool HandleManualSellClick()
   {
      m_logger.Info("🔘 Manual SELL button clicked");
      
      if(!m_state_manager.IsCycleActive())
      {
         // Start new SELL cycle
         return m_entry_manager.ManualEntrySell();
      }
      
      ENUM_MARTINGALE_MODE mode = m_state_manager.GetCurrentMode();
      
      if(mode == MODE_SELL)
      {
         // Add SELL layer
         m_logger.Info("Adding SELL layer (same direction)");
         return m_martingale.AddLayer();
      }
      else if(mode == MODE_BUY)
      {
         // Start hedge (will be implemented in Phase 6)
         m_logger.Info("Starting HEDGE (opposite direction)");
         m_logger.Warning("Hedge system not yet implemented - Phase 6");
         return false;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Handle Close Cycle Click                                         |
   //+------------------------------------------------------------------+
   bool HandleCloseCycleClick()
   {
      m_logger.Info("🔘 Close Cycle button clicked");
      
      if(!m_state_manager.IsCycleActive())
      {
         m_logger.Warning("No active cycle to close");
         return false;
      }
      
      return m_martingale.CloseCycle(false); // false = manual close, not TP
   }
   
   //+------------------------------------------------------------------+
   //| Handle Close All Click                                           |
   //+------------------------------------------------------------------+
   bool HandleCloseAllClick()
   {
      m_logger.Info("🔘 Close All button clicked");
      
      // This will close ALL positions regardless of system
      // Implementation will require position scanner
      m_logger.Warning("Close All - to be implemented with position scanner");
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Handle Stop Martingale Click                                     |
   //+------------------------------------------------------------------+
   bool HandleStopMartingaleClick()
   {
      m_logger.Info("🔘 Stop/Resume Martingale clicked");
      
      if(m_state_manager.IsMartingaleStopped())
      {
         m_state_manager.ResumeMartingale();
         m_logger.Info("✅ Martingale resumed");
      }
      else
      {
         m_state_manager.StopMartingale();
         m_logger.Info("⏸ Martingale stopped");
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Handle Stop All Click                                            |
   //+------------------------------------------------------------------+
   bool HandleStopAllClick()
   {
      m_logger.Info("🔘 Stop/Resume All clicked");
      
      bool all_stopped = (m_state_manager.IsMartingaleStopped() && 
                         m_state_manager.IsGridSlicerStopped() &&
                         m_state_manager.IsHedgeStopped() &&
                         m_state_manager.IsRecoveryStopped());
      
      if(all_stopped)
      {
         m_state_manager.ResumeAll();
         m_logger.Info("✅ All systems resumed");
      }
      else
      {
         m_state_manager.StopMartingale();
         m_state_manager.StopGridSlicer();
         m_state_manager.StopHedge();
         m_state_manager.StopRecovery();
         m_logger.Info("⏸ All systems stopped");
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Destroy All Buttons                                              |
   //+------------------------------------------------------------------+
   void DestroyAllButtons()
   {
      for(int i = 0; i < BTN_COUNT; i++)
      {
         if(m_buttons[i].name != "")
         {
            ObjectDelete(0, m_buttons[i].name);
            m_buttons[i].Reset();
         }
      }
   }
};

//+------------------------------------------------------------------+
//| End of TG_PanelButtons.mqh                                       |
//+------------------------------------------------------------------+
#endif // TG_PANEL_BUTTONS_MQH
