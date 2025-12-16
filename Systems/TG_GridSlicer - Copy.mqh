//+------------------------------------------------------------------+
//|                                          Systems/TG_GridSlicer.mqh |
//|                                              Titan Grid EA v1.0      |
//|        GridSlicer ULTIMATE: v2 Features + Anti-Stacking Fix          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "2.01"

#ifndef TG_GRIDSLICER_MQH
#define TG_GRIDSLICER_MQH

#include <Trade/Trade.mqh>
#include "../Core/TG_Definitions.mqh"
#include "../Core/TG_MagicNumbers.mqh"
#include "../Core/TG_StateManager.mqh"
#include "../Core/TG_Logger.mqh"
#include "../Core/TG_ErrorHandler.mqh"
#include "../Utilities/TG_PositionScanner.mqh"
#include "../Utilities/TG_LotCalculation.mqh"
#include "../Utilities/TG_PriceHelpers.mqh"
#include "../Config/TG_Inputs_GridSlicer.mqh"

// Struct untuk Learning Data
struct SGSLearningData
{
   double distance_percent; 
   int    success_count;    
   int    total_count;      
   double success_rate;     
};

class CGridSlicerSystem
{
private:
   CTrade* m_trade;
   CMagicNumberManager* m_magic;
   CStateManager* m_state_manager;
   CLogger* m_logger;
   CErrorHandler* m_error_handler;
   CPositionScanner* m_scanner;
   CLotCalculator* m_lot_calculator;
   CPriceHelper* m_price_helper;
   
   // Tracking Harga Layer
   double m_martingale_layers[30]; 
   int    m_total_martingale_layers;
   
   // Learning System
   SGSLearningData m_learning_data[];
   
   // ATR Handle
   int m_atr_handle;
   
   // Throttle
   datetime m_last_check_time;

   //+------------------------------------------------------------------+
   //| Deteksi Arah Martingale                                          |
   //+------------------------------------------------------------------+
   ENUM_POSITION_TYPE GetMainDirection()
   {
      if(m_state_manager != NULL && m_state_manager.IsCycleActive())
         return (m_state_manager.GetCurrentMode() == MODE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      
      int buy=0, sell=0;
      for(int i=PositionsTotal()-1; i>=0; i--) {
         if(PositionSelectByTicket(PositionGetTicket(i))) {
            long magic = PositionGetInteger(POSITION_MAGIC);
            if(m_magic.IsMartingale(magic)) {
               if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) buy++; else sell++;
            }
         }
      }
      return (buy >= sell) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   }

   //+------------------------------------------------------------------+
   //| Update Struktur Layer                                            |
   //+------------------------------------------------------------------+
   void UpdateLayerStructure(ENUM_POSITION_TYPE direction)
   {
      ArrayInitialize(m_martingale_layers, 0.0);
      m_total_martingale_layers = 0;
      
      double prices[];
      ArrayResize(prices, 0);
      
      for(int i=PositionsTotal()-1; i>=0; i--) {
         if(PositionSelectByTicket(PositionGetTicket(i))) {
            long magic = PositionGetInteger(POSITION_MAGIC);
            if(m_magic.IsMartingale(magic)) {
               if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == direction) {
                  int s = ArraySize(prices);
                  ArrayResize(prices, s+1);
                  prices[s] = PositionGetDouble(POSITION_PRICE_OPEN);
               }
            }
         }
      }
      
      if(ArraySize(prices) == 0) return;
      ArraySort(prices); 
      
      int total = ArraySize(prices);
      m_total_martingale_layers = total;
      
      if(direction == POSITION_TYPE_BUY) {
         for(int i=0; i<total; i++) m_martingale_layers[i+1] = prices[total-1-i]; 
      } else {
         for(int i=0; i<total; i++) m_martingale_layers[i+1] = prices[i];
      }
   }

   //+------------------------------------------------------------------+
   //| ANTI-STACKING: Cek Spesifik PO (Unique Magic per Index)          |
   //+------------------------------------------------------------------+
   bool IsSpecificPOFilled(int layer_index, int po_index)
   {
      // ID Unik: (Layer * 100) + Index
      int unique_id = (layer_index * 100) + po_index;
      long target_magic = m_magic.GetGridSlicerMagic(unique_id);
      
      // Cek Pending Orders
      for(int i=OrdersTotal()-1; i>=0; i--) {
         ulong ticket = OrderGetTicket(i);
         if(OrderSelect(ticket)) {
            if(OrderGetInteger(ORDER_MAGIC) == target_magic) return true;
         }
      }
      // Cek Active Positions
      for(int i=PositionsTotal()-1; i>=0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket)) {
            if(PositionGetInteger(POSITION_MAGIC) == target_magic) return true;
         }
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| V2 FEATURE: Adaptive Distance Calculation (ATR)                  |
   //+------------------------------------------------------------------+
   double CalculateAdaptivePercent()
   {
      if(!InpGS_UseAdaptivePercentage) return InpGS_BaseDistancePercent;
      
      double atr_buffer[];
      ArraySetAsSeries(atr_buffer, true);
      if(CopyBuffer(m_atr_handle, 0, 0, 1, atr_buffer) < 1) return InpGS_BaseDistancePercent;
      
      double current_atr = atr_buffer[0] / _Point;
      double normal_atr = 100.0; // Baseline ATR (bisa dijadikan input jika mau)
      
      double ratio = current_atr / normal_atr;
      double adapted = InpGS_BaseDistancePercent * ratio * InpGS_VolatilityMultiplier;
      
      if(adapted < InpGS_MinPercent) adapted = InpGS_MinPercent;
      if(adapted > InpGS_MaxPercent) adapted = InpGS_MaxPercent;
      
      return adapted;
   }

   //+------------------------------------------------------------------+
   //| Hitung Lot Slicer                                                |
   //+------------------------------------------------------------------+
   double CalculateSlicerLot(double base_lot, int layer_index)
   {
      double multiplier = 1.0 + ((layer_index - InpGS_StartLayer) * 0.1); 
      double lot = base_lot * multiplier;
      
      // Normalize
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      
      if(step > 0) lot = MathRound(lot / step) * step;
      if(lot < min) lot = min;
      if(lot > max) lot = max;
      
      return lot;
   }

public:
   CGridSlicerSystem() {
      m_trade = NULL; m_magic = NULL;
      ArrayInitialize(m_martingale_layers, 0.0);
      m_last_check_time = 0;
      m_atr_handle = INVALID_HANDLE;
   }
   
   ~CGridSlicerSystem() {
      if(m_atr_handle != INVALID_HANDLE) IndicatorRelease(m_atr_handle);
   }
   
   bool Initialize(CTrade* trade, CMagicNumberManager* magic, CStateManager* state_mgr, 
                   CLogger* logger, CErrorHandler* error_handler, CPositionScanner* scanner, 
                   CLotCalculator* lot_calc, CPriceHelper* price_helper)
   {
      m_trade = trade; m_magic = magic; m_state_manager = state_mgr;
      m_logger = logger; m_error_handler = error_handler;
      m_scanner = scanner; m_lot_calculator = lot_calc; m_price_helper = price_helper;
      
      // Init ATR untuk fitur Adaptive
      m_atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Main Logic (OnTick)                                              |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      if(!InpGS_Enable) return;
      if(TimeCurrent() - m_last_check_time < 1) return; 
      m_last_check_time = TimeCurrent();
      
      int total_pos = PositionsTotal();
      if(total_pos < InpGS_StartLayer) return;
      
      ENUM_POSITION_TYPE main_dir = GetMainDirection();
      UpdateLayerStructure(main_dir);
      
      if(m_total_martingale_layers < InpGS_StartLayer) return;
      
      // Hitung Jarak Adaptif (Fitur V2)
      double current_percent = CalculateAdaptivePercent();
      
      // --- LOOP GAP ---
      for(int i = m_total_martingale_layers; i >= InpGS_StartLayer; i--)
      {
         double deep_price = m_martingale_layers[i];     
         double target_price = m_martingale_layers[i-1]; 
         
         if(deep_price <= 0 || target_price <= 0) continue;
         
         // Validasi Gap
         double full_gap = MathAbs(deep_price - target_price);
         int po_count = InpGS_MaxPOPerGap;
         if(full_gap < InpGS_MinGapForMultiPO) po_count = 1;
         
         double effective_gap = full_gap * (current_percent / 100.0);
         double slice_step = effective_gap / po_count;
         
         // --- LOOP PO ---
         for(int k = 1; k <= po_count; k++)
         {
            // Validasi Magic Number (Fitur Anti-Stacking)
            if(IsSpecificPOFilled(i, k)) continue;
            
            // Kalkulasi Harga
            double entry_dist = slice_step * k; 
            double entry_price = 0;
            
            if(main_dir == POSITION_TYPE_BUY) {
               entry_price = deep_price + entry_dist;
            } else {
               entry_price = deep_price - entry_dist;
            }
            
            entry_price = NormalizeDouble(entry_price, _Digits);
            
            // Validasi Broker Distance
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double safe_dist = ((double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point) + (20*_Point);
            
            bool price_valid = false;
            if(main_dir == POSITION_TYPE_BUY) {
               // Buy Stop: Price > Ask
               if(entry_price <= ask + safe_dist) {
                   entry_price = ask + safe_dist; // Auto adjust
                   if(entry_price >= target_price) continue; // Gap tertutup
               }
               price_valid = true;
            } else {
               // Sell Stop: Price < Bid
               if(entry_price >= bid - safe_dist) {
                   entry_price = bid - safe_dist; // Auto adjust
                   if(entry_price <= target_price) continue; // Gap tertutup
               }
               price_valid = true;
            }
            
            if(!price_valid) continue;
            
            // Eksekusi
            double lot = CalculateSlicerLot(0.01, i);
            int unique_id = (i * 100) + k;
            long magic = m_magic.GetGridSlicerMagic(unique_id); // Gunakan Magic Unik!
            m_trade.SetExpertMagicNumber(magic);
            
            string comment = StringFormat("GS-L%d-P%d", i, k);
            bool res = false;
            
            if(main_dir == POSITION_TYPE_BUY)
               res = m_trade.BuyStop(lot, entry_price, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
            else
               res = m_trade.SellStop(lot, entry_price, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
               
            if(res && m_logger != NULL)
               m_logger.Info(StringFormat("✅ GS PO Placed (Adaptive %.1f%%): L%d #%d @ %.5f", current_percent, i, k, entry_price));
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Cleanup                                                          |
   //+------------------------------------------------------------------+
   void CancelAllOrders()
   {
      for(int i=OrdersTotal()-1; i>=0; i--) {
         ulong ticket = OrderGetTicket(i);
         if(OrderSelect(ticket)) {
            long magic = OrderGetInteger(ORDER_MAGIC);
            // Cek apakah Magic Number masuk range GridSlicer
            // Base Range: 200000 - 209999 (asumsi base magic standar)
            // Gunakan helper dari Magic Manager
            if(m_magic.IsGridSlicer(magic)) { 
                m_trade.OrderDelete(ticket);
            }
         }
      }
   }
};

#endif