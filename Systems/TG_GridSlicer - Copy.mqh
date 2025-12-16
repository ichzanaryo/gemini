//+------------------------------------------------------------------+
//|                                          Systems/TG_GridSlicer.mqh |
//|                                              Titan Grid EA v1.0      |
//|               GridSlicer v1.06: Smart Gap & Distance Fix             |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.06"

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
   
   // Struktur Harga Layer (Index 1 = Awal, Index N = Terakhir/Floating)
   double m_martingale_layers[30]; 
   int    m_total_martingale_layers;
   
   // Throttle
   datetime m_last_check_time;

   //+------------------------------------------------------------------+
   //| Deteksi Arah Martingale Utama                                    |
   //+------------------------------------------------------------------+
   ENUM_POSITION_TYPE GetMainDirection()
   {
      if(m_state_manager != NULL && m_state_manager.IsCycleActive())
      {
         return (m_state_manager.GetCurrentMode() == MODE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      }
      
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
   //| Update Struktur Layer (Sorting Harga)                            |
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
      
      // Mapping ke Index 1-based
      if(direction == POSITION_TYPE_BUY) {
         // BUY: Index 1 = Tertinggi (L1), Index N = Terendah (Last)
         for(int i=0; i<total; i++) m_martingale_layers[i+1] = prices[total-1-i]; 
      } 
      else {
         // SELL: Index 1 = Terendah (L1), Index N = Tertinggi (Last)
         for(int i=0; i<total; i++) m_martingale_layers[i+1] = prices[i];
      }
   }

   //+------------------------------------------------------------------+
   //| Cek Apakah Slot PO Ini Sudah Terisi?                             |
   //+------------------------------------------------------------------+
   bool IsSpecificPOFilled(int layer_index, int po_index)
   {
      // ID Unik: (Layer * 100) + Index. Contoh: L3 PO1 = 301
      int unique_id = (layer_index * 100) + po_index;
      long target_magic = m_magic.GetGridSlicerMagic(unique_id);
      
      // 1. Cek Pending Order Aktif
      for(int i=OrdersTotal()-1; i>=0; i--) {
         ulong ticket = OrderGetTicket(i);
         if(OrderSelect(ticket)) {
            if(OrderGetInteger(ORDER_MAGIC) == target_magic) return true;
         }
      }
      
      // 2. Cek Posisi Aktif (Order sudah kena)
      for(int i=PositionsTotal()-1; i>=0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket)) {
            if(PositionGetInteger(POSITION_MAGIC) == target_magic) return true;
         }
      }
      
      return false;
   }

   //+------------------------------------------------------------------+
   //| Hitung Lot                                                       |
   //+------------------------------------------------------------------+
   double CalculateSlicerLot(double base_lot, int layer_index)
   {
      double multiplier = 1.0 + ((layer_index - InpGS_StartLayer) * 0.1); 
      double total_layer_lot = base_lot * multiplier;
      double lot_per_po = total_layer_lot; 
      
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      
      if(step > 0) lot_per_po = MathRound(lot_per_po / step) * step;
      if(lot_per_po < min) lot_per_po = min;
      if(lot_per_po > max) lot_per_po = max;
      
      return lot_per_po;
   }

public:
   CGridSlicerSystem() {
      m_trade = NULL; m_magic = NULL;
      ArrayInitialize(m_martingale_layers, 0.0);
      m_last_check_time = 0;
   }
   
   bool Initialize(CTrade* trade, CMagicNumberManager* magic, CStateManager* state_mgr, 
                   CLogger* logger, CErrorHandler* error_handler, CPositionScanner* scanner, 
                   CLotCalculator* lot_calc, CPriceHelper* price_helper)
   {
      m_trade = trade; m_magic = magic; m_state_manager = state_mgr;
      m_logger = logger; m_error_handler = error_handler;
      m_scanner = scanner; m_lot_calculator = lot_calc; m_price_helper = price_helper;
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Logic Utama (OnTick)                                             |
   //+------------------------------------------------------------------+
   void OnTick()
   {
      if(!InpGS_Enable) return;
      if(TimeCurrent() - m_last_check_time < 1) return; // Throttle 1s
      m_last_check_time = TimeCurrent();
      
      // Update Data Layer
      ENUM_POSITION_TYPE main_dir = GetMainDirection();
      UpdateLayerStructure(main_dir);
      
      // Jika layer belum cukup dalam, skip
      if(m_total_martingale_layers < InpGS_StartLayer) return;
      
      // Ambil data market
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double stop_lvl = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
      // Tambahkan buffer aman agar order tidak ditolak (spread + 20 point)
      double safe_dist = stop_lvl + (20 * _Point); 

      // --- LOOP DARI LAYER TERDALAM KE ATAS ---
      // i = Layer Bawah (Deep), i-1 = Layer Atas (Target)
      for(int i = m_total_martingale_layers; i >= InpGS_StartLayer; i--)
      {
         double deep_price = m_martingale_layers[i];     
         double target_price = m_martingale_layers[i-1]; 
         
         if(deep_price <= 0 || target_price <= 0) continue;
         
         // Hitung Gap
         double full_gap = MathAbs(deep_price - target_price);
         
         // Tentukan jumlah PO (jika gap sempit, cuma 1)
         int po_count = InpGS_MaxPOPerGap;
         if(full_gap < InpGS_MinGapForMultiPO) po_count = 1;
         
         // Area Efektif untuk di-slice (misal 30% dari gap)
         double effective_gap = full_gap * (InpGS_BaseDistancePercent / 100.0);
         double slice_step = effective_gap / po_count;
         
         // Loop PO dalam gap
         for(int k = 1; k <= po_count; k++)
         {
            // Cek apakah slot ini sudah terisi?
            if(IsSpecificPOFilled(i, k)) continue;
            
            // Hitung Harga Entry
            double entry_dist = slice_step * k; 
            double entry_price = 0;
            
            if(main_dir == POSITION_TYPE_BUY) {
               // BUY STOP: Di atas Deep Price
               entry_price = deep_price + entry_dist;
               
               // [FIX] Validasi Jarak Aman:
               // Jika entry_price terlalu dekat dengan Ask, geser ke atas minimal safe_dist
               if(entry_price <= ask + safe_dist) {
                  entry_price = ask + safe_dist;
                  // Tapi jangan sampai melebihi target price (layer atasnya)
                  if(entry_price >= target_price) continue; // Gap sudah tertutup, skip
               }
            } 
            else {
               // SELL STOP: Di bawah Deep Price
               entry_price = deep_price - entry_dist;
               
               // [FIX] Validasi Jarak Aman:
               // Jika entry_price terlalu dekat dengan Bid, geser ke bawah minimal safe_dist
               if(entry_price >= bid - safe_dist) {
                  entry_price = bid - safe_dist;
                  if(entry_price <= target_price) continue; // Gap tertutup
               }
            }
            
            entry_price = NormalizeDouble(entry_price, _Digits);
            
            // Hitung Lot
            double lot = CalculateSlicerLot(0.01, i); 
            
            // Set Magic Unik
            int unique_id = (i * 100) + k;
            long magic = m_magic.GetGridSlicerMagic(unique_id);
            m_trade.SetExpertMagicNumber(magic);
            
            string comment = StringFormat("GS-L%d-P%d", i, k);
            bool res = false;
            
            // Eksekusi Order
            if(main_dir == POSITION_TYPE_BUY) {
               res = m_trade.BuyStop(lot, entry_price, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
            } else {
               res = m_trade.SellStop(lot, entry_price, _Symbol, 0, 0, ORDER_TIME_GTC, 0, comment);
            }
            
            // Logging
            if(res && m_logger != NULL) {
               m_logger.Info(StringFormat("✅ GS PO Placed: Gap L%d (#%d) @ %.5f", i, k, entry_price));
            } else if(!res && m_logger != NULL) {
               // Log error jika gagal, untuk debugging user
               m_logger.Debug(StringFormat("⚠️ GS PO Fail L%d: Err %d", i, GetLastError()));
            }
         }
      }
   }
   
   void CancelAllOrders()
   {
      for(int i=OrdersTotal()-1; i>=0; i--) {
         ulong ticket = OrderGetTicket(i);
         if(OrderSelect(ticket)) {
            long magic = OrderGetInteger(ORDER_MAGIC);
            if(m_magic.IsGridSlicer(magic)) { 
                m_trade.OrderDelete(ticket);
            }
         }
      }
   }
};

#endif