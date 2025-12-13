//+------------------------------------------------------------------+
//|                          Config/TG_Inputs_ControlPanel.mqh       |
//|                                          Titan Grid EA v1.0      |
//|                      Control Panel Input Parameters              |
//+------------------------------------------------------------------+
//| Location: C:\Users\ichza\AppData\Roaming\MetaQuotes\Terminal\   |
//|           D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\         |
//|           TitanGridEA\Config\TG_Inputs_ControlPanel.mqh          |
//|                                                                  |
//| Purpose:  Control Panel UI configuration parameters             |
//|           Position, size, theme, update intervals               |
//|           Dependencies: TG_Definitions.mqh                       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.00"

//+------------------------------------------------------------------+
//| CHANGE LOG                                                        |
//+------------------------------------------------------------------+
// Version 1.00 - 2025-01-20
// [INITIAL] Control Panel input parameters created
// [ADD] Position and size settings
// [ADD] Theme and color settings
// [ADD] Display options
// [ADD] Button configurations
//+------------------------------------------------------------------+

#ifndef TG_INPUTS_CONTROL_PANEL_MQH
#define TG_INPUTS_CONTROL_PANEL_MQH

#include "../Core/TG_Definitions.mqh"

//+------------------------------------------------------------------+
//| CONTROL PANEL - POSITION & SIZE                                  |
//+------------------------------------------------------------------+
input group "═══════════ CONTROL PANEL POSITION ═══════════"

input ENUM_PANEL_POSITION InpPanel_Position = PANEL_POS_TOP_RIGHT;  // Panel Position
input int InpPanel_OffsetX = 10;                                     // X Offset from Edge (px)
input int InpPanel_OffsetY = 50;                                     // Y Offset from Edge (px)

// Custom position (if PANEL_POS_CUSTOM selected)
input int InpPanel_CustomX = 100;                                    // Custom X Position (px)
input int InpPanel_CustomY = 100;                                    // Custom Y Position (px)

//+------------------------------------------------------------------+
//| CONTROL PANEL - SIZE & LAYOUT                                    |
//+------------------------------------------------------------------+
input group "═══════════ PANEL SIZE & LAYOUT ═══════════"

input ENUM_PANEL_SIZE InpPanel_Size = PANEL_SIZE_NORMAL;            // Panel Size Mode
input int InpPanel_Width = 350;                                      // Panel Width (px)
input int InpPanel_MinHeight = 400;                                  // Min Panel Height (px)

input int InpPanel_Padding = 10;                                     // Internal Padding (px)
input int InpPanel_LineHeight = 20;                                  // Line Height (px)
input int InpPanel_ButtonHeight = 30;                                // Button Height (px)
input int InpPanel_ButtonSpacing = 5;                                // Button Spacing (px)

//+------------------------------------------------------------------+
//| CONTROL PANEL - THEME & COLORS                                   |
//+------------------------------------------------------------------+
input group "═══════════ PANEL THEME & COLORS ═══════════"

input ENUM_PANEL_THEME InpPanel_Theme = PANEL_THEME_DARK;            // Panel Theme

// Background colors
input color InpPanel_ColorBG = clrDarkSlateGray;                     // Panel Background
input color InpPanel_ColorHeader = clrBlack;                         // Header Background
input color InpPanel_ColorBorder = clrWhite;                         // Border Color

// Text colors
input color InpPanel_ColorTextNormal = clrWhite;                     // Normal Text
input color InpPanel_ColorTextProfit = clrLimeGreen;                 // Profit Text
input color InpPanel_ColorTextLoss = clrRed;                         // Loss Text
input color InpPanel_ColorTextDisabled = clrGray;                    // Disabled Text

// Button colors
input color InpPanel_ColorButtonNormal = clrDimGray;                 // Normal Button
input color InpPanel_ColorButtonBuy = clrDodgerBlue;                 // BUY Button
input color InpPanel_ColorButtonSell = clrOrangeRed;                 // SELL Button
input color InpPanel_ColorButtonClose = clrCrimson;                  // Close Button
input color InpPanel_ColorButtonStop = clrDarkRed;                   // Stop Button
input color InpPanel_ColorButtonResume = clrForestGreen;             // Resume Button

//+------------------------------------------------------------------+
//| CONTROL PANEL - DISPLAY OPTIONS                                  |
//+------------------------------------------------------------------+
input group "═══════════ DISPLAY OPTIONS ═══════════"

input bool InpPanel_ShowAccountInfo = true;                          // Show Account Info
input bool InpPanel_ShowPositionSummary = true;                      // Show Position Summary
input bool InpPanel_ShowCycleInfo = true;                            // Show Cycle Info
input bool InpPanel_ShowStatistics = true;                           // Show Statistics
input bool InpPanel_ShowSystemStatus = true;                         // Show System Status

input bool InpPanel_ShowProfitInPercent = false;                     // Show Profit in %
input bool InpPanel_ShowLayerDetails = true;                         // Show Layer Details
input bool InpPanel_CompactMode = false;                             // Compact Display Mode

//+------------------------------------------------------------------+
//| CONTROL PANEL - UPDATE SETTINGS                                  |
//+------------------------------------------------------------------+
input group "═══════════ UPDATE SETTINGS ═══════════"

input int InpPanel_UpdateIntervalMS = 500;                           // Update Interval (ms)
input bool InpPanel_UpdateOnTick = true;                             // Update Every Tick
input bool InpPanel_FlashOnChange = true;                            // Flash on P/L Change

//+------------------------------------------------------------------+
//| CONTROL PANEL - BUTTON SETTINGS                                  |
//+------------------------------------------------------------------+
input group "═══════════ BUTTON SETTINGS ═══════════"

input bool InpPanel_ShowManualButtons = true;                        // Show Manual BUY/SELL
input bool InpPanel_ShowStopResumeButtons = true;                    // Show Stop/Resume Buttons
input bool InpPanel_ShowCloseCycleButton = true;                     // Show Close Cycle Button
input bool InpPanel_ShowCloseAllButton = true;                       // Show Close All Button
input bool InpPanel_ShowMinimizeButton = true;                       // Show Minimize Button

input bool InpPanel_ConfirmCloseAll = true;                          // Confirm Close All
input bool InpPanel_ConfirmStopSystem = false;                       // Confirm Stop System

//+------------------------------------------------------------------+
//| CONTROL PANEL - ADVANCED                                         |
//+------------------------------------------------------------------+
input group "═══════════ ADVANCED OPTIONS ═══════════"

input bool InpPanel_Draggable = true;                                // Allow Drag & Drop
input bool InpPanel_Minimizable = true;                              // Allow Minimize
input bool InpPanel_ShowTooltips = true;                             // Show Button Tooltips

input string InpPanel_FontName = "Arial";                            // Font Name
input int InpPanel_FontSize = 9;                                     // Font Size
input bool InpPanel_FontBold = false;                                // Bold Font

input int InpPanel_CornerRadius = 5;                                 // Corner Radius (px)
input int InpPanel_BorderWidth = 1;                                  // Border Width (px)

//+------------------------------------------------------------------+
//| VALIDATION FUNCTION                                               |
//+------------------------------------------------------------------+
bool ValidateControlPanelInputs(string &error_msg)
{
   // Validate size parameters
   if(InpPanel_Width < 200 || InpPanel_Width > 800)
   {
      error_msg = "Panel width must be between 200 and 800 pixels";
      return false;
   }
   
   if(InpPanel_MinHeight < 300 || InpPanel_MinHeight > 1000)
   {
      error_msg = "Panel height must be between 300 and 1000 pixels";
      return false;
   }
   
   if(InpPanel_Padding < 0 || InpPanel_Padding > 50)
   {
      error_msg = "Panel padding must be between 0 and 50 pixels";
      return false;
   }
   
   if(InpPanel_LineHeight < 15 || InpPanel_LineHeight > 40)
   {
      error_msg = "Line height must be between 15 and 40 pixels";
      return false;
   }
   
   if(InpPanel_ButtonHeight < 20 || InpPanel_ButtonHeight > 60)
   {
      error_msg = "Button height must be between 20 and 60 pixels";
      return false;
   }
   
   // Validate update interval
   if(InpPanel_UpdateIntervalMS < 100 || InpPanel_UpdateIntervalMS > 5000)
   {
      error_msg = "Update interval must be between 100 and 5000 ms";
      return false;
   }
   
   // Validate font size
   if(InpPanel_FontSize < 6 || InpPanel_FontSize > 20)
   {
      error_msg = "Font size must be between 6 and 20";
      return false;
   }
   
   // Validate offsets
   if(InpPanel_OffsetX < 0 || InpPanel_OffsetX > 500)
   {
      error_msg = "X offset must be between 0 and 500 pixels";
      return false;
   }
   
   if(InpPanel_OffsetY < 0 || InpPanel_OffsetY > 500)
   {
      error_msg = "Y offset must be between 0 and 500 pixels";
      return false;
   }
   
   error_msg = "Control Panel inputs validated successfully";
   return true;
}

//+------------------------------------------------------------------+
//| PRINT CONTROL PANEL INPUT SUMMARY                                |
//+------------------------------------------------------------------+
void PrintControlPanelInputs()
{
   Print("╔═══════════════════════════════════════════════════════════╗");
   Print("║       CONTROL PANEL - INPUT PARAMETERS                   ║");
   Print("╠═══════════════════════════════════════════════════════════╣");
   Print("║ POSITION:                                                 ║");
   Print("║   Position:        ", EnumToString(InpPanel_Position));
   Print("║   Offset:          (", InpPanel_OffsetX, ", ", InpPanel_OffsetY, ")");
   Print("╠═══════════════════════════════════════════════════════════╣");
   Print("║ SIZE & LAYOUT:                                            ║");
   Print("║   Size Mode:       ", EnumToString(InpPanel_Size));
   Print("║   Width:           ", InpPanel_Width, " px");
   Print("║   Min Height:      ", InpPanel_MinHeight, " px");
   Print("║   Button Height:   ", InpPanel_ButtonHeight, " px");
   Print("╠═══════════════════════════════════════════════════════════╣");
   Print("║ THEME:                                                    ║");
   Print("║   Theme:           ", EnumToString(InpPanel_Theme));
   Print("║   Font:            ", InpPanel_FontName, " ", InpPanel_FontSize, "pt");
   Print("╠═══════════════════════════════════════════════════════════╣");
   Print("║ DISPLAY:                                                  ║");
   Print("║   Account Info:    ", (InpPanel_ShowAccountInfo ? "Yes" : "No"));
   Print("║   Positions:       ", (InpPanel_ShowPositionSummary ? "Yes" : "No"));
   Print("║   Cycle Info:      ", (InpPanel_ShowCycleInfo ? "Yes" : "No"));
   Print("║   Statistics:      ", (InpPanel_ShowStatistics ? "Yes" : "No"));
   Print("║   Compact Mode:    ", (InpPanel_CompactMode ? "Yes" : "No"));
   Print("╠═══════════════════════════════════════════════════════════╣");
   Print("║ BUTTONS:                                                  ║");
   Print("║   Manual Buttons:  ", (InpPanel_ShowManualButtons ? "Yes" : "No"));
   Print("║   Stop/Resume:     ", (InpPanel_ShowStopResumeButtons ? "Yes" : "No"));
   Print("║   Close Cycle:     ", (InpPanel_ShowCloseCycleButton ? "Yes" : "No"));
   Print("║   Close All:       ", (InpPanel_ShowCloseAllButton ? "Yes" : "No"));
   Print("╠═══════════════════════════════════════════════════════════╣");
   Print("║ UPDATE:                                                   ║");
   Print("║   Interval:        ", InpPanel_UpdateIntervalMS, " ms");
   Print("║   On Every Tick:   ", (InpPanel_UpdateOnTick ? "Yes" : "No"));
   Print("║   Flash Changes:   ", (InpPanel_FlashOnChange ? "Yes" : "No"));
   Print("╚═══════════════════════════════════════════════════════════╝");
}

//+------------------------------------------------------------------+
//| End of TG_Inputs_ControlPanel.mqh                                |
//+------------------------------------------------------------------+
#endif // TG_INPUTS_CONTROL_PANEL_MQH
