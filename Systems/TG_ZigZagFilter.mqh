//+------------------------------------------------------------------+
//|                                      Systems/TG_ZigZagFilter.mqh |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.16"

#ifndef TG_ZIGZAG_FILTER_MQH
#define TG_ZIGZAG_FILTER_MQH

// PERBAIKAN: Arahkan ke Main Inputs
#include "../Config/TG_Inputs_Main.mqh" 

class CZigZagFilter
{
private:
   int      m_handle;
   double   m_buffer[];
   double   m_last_high;
   double   m_last_low;
   int      m_last_high_bar;
   int      m_last_low_bar;

public:
   CZigZagFilter() { m_handle = INVALID_HANDLE; m_last_high = 0; m_last_low = 0; }
   ~CZigZagFilter() { if(m_handle != INVALID_HANDLE) IndicatorRelease(m_handle); }

   bool Initialize()
   {
      m_handle = iCustom(_Symbol, _Period, "Examples\\ZigZag", InpZZ_Depth, InpZZ_Deviation, InpZZ_Backstep);
      if(m_handle == INVALID_HANDLE) {
         Print("❌ Failed to create ZigZag handle!");
         return false;
      }
      return true;
   }

   void Refresh()
   {
      if(m_handle == INVALID_HANDLE) return;
      ArraySetAsSeries(m_buffer, true);
      if(CopyBuffer(m_handle, 0, 0, 100, m_buffer) < 100) return;
      
      m_last_high = 0; m_last_low = 0;
      m_last_high_bar = -1; m_last_low_bar = -1;
      
      for(int i = 0; i < 100; i++) {
         double val = m_buffer[i];
         if(val == 0 || val == EMPTY_VALUE) continue;
         
         double high = iHigh(_Symbol, _Period, i);
         double low  = iLow(_Symbol, _Period, i);
         
         if(MathAbs(val - high) < _Point && m_last_high == 0) {
            m_last_high = val; m_last_high_bar = i;
         }
         if(MathAbs(val - low) < _Point && m_last_low == 0) {
            m_last_low = val; m_last_low_bar = i;
         }
         if(m_last_high > 0 && m_last_low > 0) break;
      }
   }

   double GetLastSwingHigh() { return m_last_high; }
   double GetLastSwingLow()  { return m_last_low; }
   bool IsSignalFresh(int max_bars = 50) { return (m_last_high_bar <= max_bars && m_last_low_bar <= max_bars); }
};
#endif