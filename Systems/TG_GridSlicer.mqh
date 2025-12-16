//+------------------------------------------------------------------+
//|                                          Systems/TG_GridSlicer.mqh |
//|                                              Titan Grid EA v2.08    |
//|        FIXED: Correct Gap Direction Calculation                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "2.08"

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
   
   double m_martingale_layers[30]; 
   int    m_total_martingale_layers;
   SGSLearningData m_learning_data[];
   int m_atr_handle;
   datetime m_last_check_time;
   bool m_debug_mode;

   //+------------------------------------------------------------------+
   //| Deteksi Arah Martingale                                          |
   //+------------------------------------------------------------------+
   ENUM_POSITION_TYPE GetMainDirection()
   {
      if(m_state_manager != NULL && m_state_manager. IsCycleActive())
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
   //| Update Struktur Layer - ULTRA DEBUG VERSION                      |
   //+------------------------------------------------------------------+
   void UpdateLayerStructure(ENUM_POSITION_TYPE direction)
   {
      ArrayInitialize(m_martingale_layers, 0.0);
      m_total_martingale_layers = 0;
      
      if(m_logger != NULL && m_debug_mode) {
         m_logger.Info("==========================================");
         m_logger. Info("UPDATE LAYER STRUCTURE");
         m_logger.Info(StringFormat("Direction: %s", (direction==POSITION_TYPE_BUY)?"BUY":"SELL"));
      }
      
      double prices[];
      ArrayResize(prices, 0);
      
      // Collect prices
      for(int i=PositionsTotal()-1; i>=0; i--) {
         if(PositionSelectByTicket(PositionGetTicket(i))) {
            long magic = PositionGetInteger(POSITION_MAGIC);
            if(m_magic.IsMartingale(magic)) {
               if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == direction) {
                  double price = PositionGetDouble(POSITION_PRICE_OPEN);
                  int s = ArraySize(prices);
                  ArrayResize(prices, s+1);
                  prices[s] = price;
                  
                  if(m_logger != NULL && m_debug_mode) {
                     m_logger. Info(StringFormat("  Found Mart Pos: %. 5f (Magic: %d)", price, magic));
                  }
               }
            }
         }
      }
      
      if(ArraySize(prices) == 0) {
         if(m_logger != NULL) {
            m_logger.Warning("No Martingale positions found!");
         }
         return;
      }
      
      ArraySort(prices);
      
      int total = ArraySize(prices);
      m_total_martingale_layers = total;
      
      if(m_logger != NULL && m_debug_mode) {
         m_logger.Info(StringFormat("Total positions found: %d", total));
         m_logger.Info("Prices after sorting (ascending):");
         for(int i=0; i<total; i++) {
            m_logger.Info(StringFormat("  prices[%d] = %.5f", i, prices[i]));
         }
      }
      
      // ✅ PERBAIKAN: Assign berdasarkan logika natural price
      if(direction == POSITION_TYPE_BUY) {
         // BUY: Layer 1 = terendah (awal martingale), Layer N = tertinggi (paling dalam)
         for(int i=0; i<total; i++) {
            m_martingale_layers[i+1] = prices[i];
         }
      } else {
         // SELL: Layer 1 = tertinggi (awal martingale), Layer N = terendah (paling dalam)
         for(int i=0; i<total; i++) {
            m_martingale_layers[i+1] = prices[total-1-i];
         }
      }
      
      if(m_logger != NULL) {
         m_logger.Info("LAYER STRUCTURE RESULT:");
         for(int i=1; i<=m_total_martingale_layers; i++) {
            m_logger.Info(StringFormat("  L%d = %.5f", i, m_martingale_layers[i]));
         }
         m_logger.Info("==========================================");
      }
   }

   //+------------------------------------------------------------------+
   //| ANTI-STACKING:  Cek Spesifik PO (Unique Magic per Index)          |
   //+------------------------------------------------------------------+
   bool IsSpecificPOFilled(int layer_index, int po_index)
   {
      int unique_id = (layer_index * 100) + po_index;
      long target_magic = m_magic.GetGridSlicerMagic(unique_id);
      
      for(int i=OrdersTotal()-1; i>=0; i--) {
         ulong ticket = OrderGetTicket(i);
         if(OrderSelect(ticket)) {
            if(OrderGetInteger(ORDER_MAGIC) == target_magic) return true;
         }
      }
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
      if(! InpGS_UseAdaptivePercentage) return InpGS_BaseDistancePercent;
      
      double atr_buffer[];
      ArraySetAsSeries(atr_buffer, true);
      if(CopyBuffer(m_atr_handle, 0, 0, 1, atr_buffer) < 1) return InpGS_BaseDistancePercent;
      
      double current_atr = atr_buffer[0] / _Point;
      double normal_atr = 100.0;
      
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
      m_debug_mode = true;
   }
   
   ~CGridSlicerSystem() {
      if(m_atr_handle != INVALID_HANDLE) IndicatorRelease(m_atr_handle);
   }
   
   bool Initialize(CTrade* trade, CMagicNumberManager* magic, CStateManager* state_mgr, CLogger* logger, CErrorHandler* error_handler, CPositionScanner* scanner, CLotCalculator* lot_calc, CPriceHelper* price_helper)
   {
      m_trade = trade; 
      m_magic = magic; 
      m_state_manager = state_mgr;
      m_logger = logger; 
      m_error_handler = error_handler;
      m_scanner = scanner; 
      m_lot_calculator = lot_calc; 
      m_price_helper = price_helper;
      
      m_atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
      
      if(m_logger != NULL) {
         m_logger.Info("GridSlicer System Initialized (v2.08 - Fixed Gap Direction)");
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Main Logic (OnTick) - ULTRA DEBUG                                |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      if(! InpGS_Enable) return;
      if(TimeCurrent() - m_last_check_time < 1) return; 
      m_last_check_time = TimeCurrent();
      
      int total_pos = PositionsTotal();
      if(total_pos < InpGS_StartLayer) return;
      
      ENUM_POSITION_TYPE main_dir = GetMainDirection();
      UpdateLayerStructure(main_dir);
      
      if(m_total_martingale_layers < InpGS_StartLayer) return;
      
      double current_percent = CalculateAdaptivePercent();
      
      double current_price = (main_dir == POSITION_TYPE_BUY) ? 
                             SymbolInfoDouble(_Symbol, SYMBOL_ASK) :
                             SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      if(m_logger != NULL) {
         m_logger.Info("==========================================");
         m_logger. Info("GRIDSLICER ONTICK");
         m_logger. Info(StringFormat("Current Price:  %.5f", current_price));
         m_logger.Info(StringFormat("Percentage: %.1f%%", current_percent));
         m_logger.Info(StringFormat("Total Layers: %d", m_total_martingale_layers));
         m_logger.Info(StringFormat("Start Layer: %d", InpGS_StartLayer));
         m_logger.Info("==========================================");
      }
      
      int total_po_placed = 0;
      
      // --- LOOP GAP ---
      for(int i = m_total_martingale_layers; i >= InpGS_StartLayer; i--)
      {
         if(m_logger != NULL) {
            m_logger.Info("");
            m_logger.Info(StringFormat("########## LOOP ITERATION i=%d ##########", i));
         }
         
         double target_price = m_martingale_layers[i-1];
         double deeper_price = m_martingale_layers[i];
         
         if(m_logger != NULL) {
            m_logger.Info(StringFormat("Array Access: m_martingale_layers[%d] = %.5f (target)", i-1, target_price));
            m_logger.Info(StringFormat("Array Access: m_martingale_layers[%d] = %.5f (deeper)", i, deeper_price));
         }
         
         if(deeper_price <= 0 || target_price <= 0) {
            if(m_logger != NULL) {
               m_logger.Warning(StringFormat("SKIP: Invalid prices (target=%.5f, deeper=%.5f)", target_price, deeper_price));
            }
            continue;
         }
         
         double full_gap = MathAbs(deeper_price - target_price);
         
         if(m_logger != NULL) {
            m_logger.Info(StringFormat("Gap Calculation: |%. 5f - %.5f| = %.5f", deeper_price, target_price, full_gap));
         }
         
         int max_po_count = (int)MathFloor(100.0 / current_percent);
         
         if(max_po_count > InpGS_MaxPOPerGap) max_po_count = InpGS_MaxPOPerGap;
         if(max_po_count < 1) max_po_count = 1;
         
         double spacing_distance = full_gap * (current_percent / 100.0);
         
         if(m_logger != NULL) {
            m_logger. Info(StringFormat("--- GAP L%d -> L%d ---", i-1, i));
            m_logger.Info(StringFormat("Target Layer (L%d): %.5f", i-1, target_price));
            m_logger.Info(StringFormat("Deeper Layer (L%d): %.5f", i, deeper_price));
            m_logger.Info(StringFormat("Gap Size: %.5f points", full_gap));
            m_logger.Info(StringFormat("Spacing per PO: %.5f points", spacing_distance));
            m_logger.Info(StringFormat("Max PO Count: %d", max_po_count));
         }
         
         int po_placed_in_gap = 0;
         
         // ✅ PERBAIKAN UTAMA: Perhitungan Entry Price
         for(int k = 1; k <= max_po_count; k++)
         {
            if(IsSpecificPOFilled(i, k)) {
               if(m_logger != NULL && k <= 2) {
                  m_logger.Info(StringFormat("  PO #%d: Already exists (skipped)", k));
               }
               continue;
            }
            
            double entry_dist = spacing_distance * k;
            double entry_price = 0;
            
            // ✅ LOGIKA BARU: Selalu tambah ke target (gap selalu naik dari target ke deeper)
            if(main_dir == POSITION_TYPE_BUY) {
               // BUY: Gap naik (target < deeper), PO di atas target
               entry_price = target_price + entry_dist;
               
               if(m_logger != NULL && k <= 3) {
                  m_logger.Info(StringFormat("  PO #%d: %. 5f = %.5f + (%.5f * %d)", 
                                            k, entry_price, target_price, spacing_distance, k));
               }
            } else {
               // SELL: Gap turun (target > deeper), tapi sorting bikin target = tertinggi
               // Jadi tetap tambah spacing dari target (menuju deeper yang lebih rendah)
               entry_price = target_price - entry_dist;
               
               if(m_logger != NULL && k <= 3) {
                  m_logger.Info(StringFormat("  PO #%d: %.5f = %.5f - (%.5f * %d)", 
                                            k, entry_price, target_price, spacing_distance, k));
               }
            }
            
            entry_price = NormalizeDouble(entry_price, _Digits);
            
            // ✅ Validasi Gap
            bool in_gap = false;
            if(main_dir == POSITION_TYPE_BUY) {
               in_gap = (entry_price > target_price && entry_price < deeper_price);
            } else {
               in_gap = (entry_price < target_price && entry_price > deeper_price);
            }
            
            if(! in_gap) {
               if(m_logger != NULL && k <= 2) {
                  m_logger.Info(StringFormat("  PO #%d: %. 5f OUTSIDE gap [%.5f - %.5f] - STOP", 
                                            k, entry_price, target_price, deeper_price));
               }
               break;
            }
            
            // ✅ Validasi arah harga (PO harus di luar harga saat ini)
            bool price_direction_ok = false;
            if(main_dir == POSITION_TYPE_BUY) {
               price_direction_ok = (entry_price > current_price);
            } else {
               price_direction_ok = (entry_price < current_price);
            }
            
            if(!price_direction_ok) {
               if(m_logger != NULL && k == 1) {
                  m_logger.Info(StringFormat("  PO #%d: %. 5f wrong side of current %. 5f - SKIP GAP", 
                                            k, entry_price, current_price));
               }
               break;
            }
            
            // ✅ Validasi Broker STOPS_LEVEL
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double stops_level = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
            double safe_dist = stops_level + (10 * _Point);
            
            if(main_dir == POSITION_TYPE_BUY) {
               double min_price = ask + safe_dist;
               if(entry_price < min_price) entry_price = min_price;
            } else {
               double max_price = bid - safe_dist;
               if(entry_price > max_price) entry_price = max_price;
            }
            
            // Recheck setelah adjustment
            if(main_dir == POSITION_TYPE_BUY) {
               in_gap = (entry_price > target_price && entry_price < deeper_price);
            } else {
               in_gap = (entry_price < target_price && entry_price > deeper_price);
            }
            
            if(!in_gap) continue;
            
            // ✅ Place Order
            double lot = CalculateSlicerLot(InpGS_L1LotMultiplier * 0.01, i);
            int unique_id = (i * 100) + k;
            long magic = m_magic.GetGridSlicerMagic(unique_id);
            m_trade. SetExpertMagicNumber(magic);
            
            string comment = StringFormat("GS-L%d-P%d", i, k);
            bool res = false;
            
            if(main_dir == POSITION_TYPE_BUY)
               res = m_trade. BuyStop(lot, entry_price, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
            else
               res = m_trade.SellStop(lot, entry_price, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
               
            if(res) {
               po_placed_in_gap++;
               total_po_placed++;
               if(m_logger != NULL) {
                  m_logger.Info(StringFormat("  SUCCESS PO #%d: %.5f | Lot: %.2f | Magic: %d | %s", 
                                            k, entry_price, lot, magic, comment));
               }
            } else {
               if(m_logger != NULL) {
                  m_logger.Error(StringFormat("  FAILED PO #%d: %.5f | Error: %d", 
                                             k, entry_price, GetLastError()));
               }
            }
         }
         
         if(m_logger != NULL) {
            m_logger.Info(StringFormat("Gap L%d->L%d Summary: %d PO(s) placed", i-1, i, po_placed_in_gap));
         }
      }
      
      if(m_logger != NULL) {
         m_logger.Info("==========================================");
         m_logger.Info(StringFormat("TOTAL:  %d GridSlicer PO(s) placed", total_po_placed));
         m_logger.Info("==========================================");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Cleanup                                                          |
   //+------------------------------------------------------------------+
   void CancelAllOrders()
   {
      int cancelled = 0;
      for(int i=OrdersTotal()-1; i>=0; i--) {
         ulong ticket = OrderGetTicket(i);
         if(OrderSelect(ticket)) {
            long magic = OrderGetInteger(ORDER_MAGIC);
            if(m_magic.IsGridSlicer(magic)) { 
               if(m_trade.OrderDelete(ticket)) cancelled++;
            }
         }
      }
      
      if(m_logger != NULL && cancelled > 0) {
         m_logger.Info(StringFormat("GridSlicer: %d pending order(s) cancelled", cancelled));
      }
   }
};

#endif