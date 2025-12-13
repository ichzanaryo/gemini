//+------------------------------------------------------------------+
//|                              Utilities/TG_PositionScanner.mqh    |
//|                                          Titan Grid EA v1.0      |
//|                          Position Scanner & Analyzer             |
//+------------------------------------------------------------------+
//| Location: C:\Users\ichza\AppData\Roaming\MetaQuotes\Terminal\   |
//|           D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\         |
//|           TitanGridEA\Utilities\TG_PositionScanner.mqh           |
//|                                                                  |
//| Purpose:  Scan and analyze all EA positions                     |
//|           Calculate totals, averages, profits                   |
//|           Separate martingale, hedge, gridslicer positions      |
//|           Dependencies: TG_Definitions.mqh, TG_MagicNumbers.mqh |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.00"

//+------------------------------------------------------------------+
//| CHANGE LOG                                                        |
//+------------------------------------------------------------------+
// Version 1.00 - 2025-01-20
// [INITIAL] Position scanner created
// [ADD] Scan all positions with magic filter
// [ADD] Separate by system type (mart/hedge/gs/recovery)
// [ADD] Calculate totals, averages, profits
// [ADD] Get position details by ticket
// [ADD] Find highest/lowest layers
//+------------------------------------------------------------------+

#ifndef TG_POSITION_SCANNER_MQH
#define TG_POSITION_SCANNER_MQH

#include "../Core/TG_Definitions.mqh"
#include "../Core/TG_MagicNumbers.mqh"

//+------------------------------------------------------------------+
//| POSITION SCANNER CLASS                                            |
//+------------------------------------------------------------------+
class CPositionScanner
{
private:
   CMagicNumberManager* m_magic_manager;      // Pointer to magic manager
   
   // Cached data (updated on Scan())
   SPositionInfo       m_positions[];          // All positions
   SPositionSummary    m_summary;              // Summary data
   datetime            m_last_scan_time;       // Last scan timestamp
   
   //+------------------------------------------------------------------+
   //| Calculate Average Price                                          |
   //+------------------------------------------------------------------+
   double CalculateAveragePrice(SPositionInfo &positions[], int count)
   {
      if(count == 0)
         return 0;
      
      double total_weighted = 0;
      double total_lots = 0;
      
      for(int i = 0; i < count; i++)
      {
         total_weighted += positions[i].open_price * positions[i].lots;
         total_lots += positions[i].lots;
      }
      
      return (total_lots > 0) ? (total_weighted / total_lots) : 0;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate Total Profit                                           |
   //+------------------------------------------------------------------+
   double CalculateTotalProfit(SPositionInfo &positions[], int count)
   {
      double total = 0;
      
      for(int i = 0; i < count; i++)
      {
         total += positions[i].profit + positions[i].swap + positions[i].commission;
      }
      
      return total;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CPositionScanner()
   {
      m_magic_manager = NULL;
      m_last_scan_time = 0;
      ArrayResize(m_positions, 0);
   }
   
   //+------------------------------------------------------------------+
   //| Initialize Scanner                                               |
   //+------------------------------------------------------------------+
   bool Initialize(CMagicNumberManager* magic_manager)
   {
      if(magic_manager == NULL)
      {
         Print("❌ Position Scanner: Magic manager is NULL");
         return false;
      }
      
      m_magic_manager = magic_manager;
      
      Print("✅ Position Scanner initialized");
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Scan All Positions                                               |
   //+------------------------------------------------------------------+
   bool Scan()
   {
      // Clear previous data
      ArrayResize(m_positions, 0);
      m_summary.Reset();
      
      int total_positions = PositionsTotal();
      
      if(total_positions == 0)
      {
         m_last_scan_time = TimeCurrent();
         return true; // No positions, but not an error
      }
      
      // Temporary arrays for categorization
      SPositionInfo mart_buy_positions[];
      SPositionInfo mart_sell_positions[];
      SPositionInfo hedge_positions[];
      SPositionInfo gridslicer_positions[];
      SPositionInfo recovery_buy_positions[];
      SPositionInfo recovery_sell_positions[];
      
      ArrayResize(mart_buy_positions, 0);
      ArrayResize(mart_sell_positions, 0);
      ArrayResize(hedge_positions, 0);
      ArrayResize(gridslicer_positions, 0);
      ArrayResize(recovery_buy_positions, 0);
      ArrayResize(recovery_sell_positions, 0);
      
      // Scan all positions
      for(int i = 0; i < total_positions; i++)
      {
         ulong ticket = PositionGetTicket(i);
         
         if(ticket <= 0)
            continue;
         
         // Get position info
         long magic = PositionGetInteger(POSITION_MAGIC);
         
         // Check if this position belongs to our EA
         if(!m_magic_manager.IsMagicOurs(magic))
            continue;
         
         // Create position info structure
         SPositionInfo pos;
         pos.ticket = ticket;
         pos.type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         pos.open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         pos.lots = PositionGetDouble(POSITION_VOLUME);
         pos.profit = PositionGetDouble(POSITION_PROFIT);
         pos.swap = PositionGetDouble(POSITION_SWAP);
         pos.commission = 0; // Commission not available in MT5 position, only in deals
         pos.open_time = (datetime)PositionGetInteger(POSITION_TIME);
         pos.comment = PositionGetString(POSITION_COMMENT);
         pos.magic = magic;
         pos.layer = m_magic_manager.GetLayerIndex(magic);
         
         // Add to main array
         int size = ArraySize(m_positions);
         ArrayResize(m_positions, size + 1);
         m_positions[size] = pos;
         
         // Categorize by system type
         if(m_magic_manager.IsMartingale(magic))
         {
            if(m_magic_manager.IsBuy(magic))
            {
               // Martingale BUY
               int mart_buy_size = ArraySize(mart_buy_positions);
               ArrayResize(mart_buy_positions, mart_buy_size + 1);
               mart_buy_positions[mart_buy_size] = pos;
               
               m_summary.mart_buy_count++;
               m_summary.mart_buy_lots += pos.lots;
            }
            else if(m_magic_manager.IsSell(magic))
            {
               // Martingale SELL
               int mart_sell_size = ArraySize(mart_sell_positions);
               ArrayResize(mart_sell_positions, mart_sell_size + 1);
               mart_sell_positions[mart_sell_size] = pos;
               
               m_summary.mart_sell_count++;
               m_summary.mart_sell_lots += pos.lots;
            }
         }
         else if(m_magic_manager.IsHedge(magic))
         {
            // Hedge
            int hedge_size = ArraySize(hedge_positions);
            ArrayResize(hedge_positions, hedge_size + 1);
            hedge_positions[hedge_size] = pos;
            
            m_summary.hedge_count++;
            m_summary.hedge_lots += pos.lots;
         }
         else if(m_magic_manager.IsGridSlicer(magic))
         {
            // GridSlicer
            int gs_size = ArraySize(gridslicer_positions);
            ArrayResize(gridslicer_positions, gs_size + 1);
            gridslicer_positions[gs_size] = pos;
            
            m_summary.gridslicer_count++;
            m_summary.gridslicer_lots += pos.lots;
         }
         else if(m_magic_manager.IsRecovery(magic))
         {
            // Recovery - separate by direction
            if(pos.type == POSITION_TYPE_BUY)
            {
               int rec_buy_size = ArraySize(recovery_buy_positions);
               ArrayResize(recovery_buy_positions, rec_buy_size + 1);
               recovery_buy_positions[rec_buy_size] = pos;
               
               m_summary.recovery_buy_count++;
               m_summary.recovery_buy_lots += pos.lots;
            }
            else
            {
               int rec_sell_size = ArraySize(recovery_sell_positions);
               ArrayResize(recovery_sell_positions, rec_sell_size + 1);
               recovery_sell_positions[rec_sell_size] = pos;
               
               m_summary.recovery_sell_count++;
               m_summary.recovery_sell_lots += pos.lots;
            }
         }
      }
      
      // Calculate averages and profits
      m_summary.mart_buy_avg_price = CalculateAveragePrice(mart_buy_positions, m_summary.mart_buy_count);
      m_summary.mart_sell_avg_price = CalculateAveragePrice(mart_sell_positions, m_summary.mart_sell_count);
      
      m_summary.mart_buy_profit = CalculateTotalProfit(mart_buy_positions, m_summary.mart_buy_count);
      m_summary.mart_sell_profit = CalculateTotalProfit(mart_sell_positions, m_summary.mart_sell_count);
      m_summary.hedge_profit = CalculateTotalProfit(hedge_positions, m_summary.hedge_count);
      m_summary.gridslicer_profit = CalculateTotalProfit(gridslicer_positions, m_summary.gridslicer_count);
      m_summary.recovery_buy_profit = CalculateTotalProfit(recovery_buy_positions, m_summary.recovery_buy_count);
      m_summary.recovery_sell_profit = CalculateTotalProfit(recovery_sell_positions, m_summary.recovery_sell_count);
      
      // Calculate totals
      m_summary.total_positions = ArraySize(m_positions);
      m_summary.total_lots = m_summary.mart_buy_lots + m_summary.mart_sell_lots + 
                             m_summary.hedge_lots + m_summary.gridslicer_lots + 
                             m_summary.recovery_buy_lots + m_summary.recovery_sell_lots;
      m_summary.total_profit = m_summary.GetNetPL();
      
      m_last_scan_time = TimeCurrent();
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get Summary                                                       |
   //+------------------------------------------------------------------+
   SPositionSummary GetSummary()
   {
      return m_summary;
   }
   
   //+------------------------------------------------------------------+
   //| Get All Positions                                                |
   //+------------------------------------------------------------------+
   int GetAllPositions(SPositionInfo &positions[])
   {
      int count = ArraySize(m_positions);
      ArrayResize(positions, count);
      
      for(int i = 0; i < count; i++)
      {
         positions[i] = m_positions[i];
      }
      
      return count;
   }
   
   //+------------------------------------------------------------------+
   //| Get Positions by Type                                            |
   //+------------------------------------------------------------------+
   int GetPositionsByType(SPositionInfo &positions[], ENUM_POSITION_TYPE type)
   {
      ArrayResize(positions, 0);
      int count = 0;
      
      for(int i = 0; i < ArraySize(m_positions); i++)
      {
         if(m_positions[i].type == type)
         {
            ArrayResize(positions, count + 1);
            positions[count] = m_positions[i];
            count++;
         }
      }
      
      return count;
   }
   
   //+------------------------------------------------------------------+
   //| Get Martingale BUY Positions                                     |
   //+------------------------------------------------------------------+
   int GetMartingaleBuyPositions(SPositionInfo &positions[])
   {
      ArrayResize(positions, 0);
      int count = 0;
      
      for(int i = 0; i < ArraySize(m_positions); i++)
      {
         if(m_magic_manager.IsMartingale(m_positions[i].magic) &&
            m_magic_manager.IsBuy(m_positions[i].magic))
         {
            ArrayResize(positions, count + 1);
            positions[count] = m_positions[i];
            
            // 🔥 EXTRACT LAYER from magic number!
            positions[count].layer = m_magic_manager.GetLayerIndex(m_positions[i].magic);
            
            count++;
         }
      }
      
      return count;
   }
   
   //+------------------------------------------------------------------+
   //| Get Martingale SELL Positions                                    |
   //+------------------------------------------------------------------+
   int GetMartingaleSellPositions(SPositionInfo &positions[])
   {
      ArrayResize(positions, 0);
      int count = 0;
      
      for(int i = 0; i < ArraySize(m_positions); i++)
      {
         if(m_magic_manager.IsMartingale(m_positions[i].magic) &&
            m_magic_manager.IsSell(m_positions[i].magic))
         {
            ArrayResize(positions, count + 1);
            positions[count] = m_positions[i];
            
            // 🔥 EXTRACT LAYER from magic number!
            positions[count].layer = m_magic_manager.GetLayerIndex(m_positions[i].magic);
            
            count++;
         }
      }
      
      return count;
   }
   
   //+------------------------------------------------------------------+
   //| Get Hedge Positions                                              |
   //+------------------------------------------------------------------+
   int GetHedgePositions(SPositionInfo &positions[])
   {
      ArrayResize(positions, 0);
      int count = 0;
      
      for(int i = 0; i < ArraySize(m_positions); i++)
      {
         if(m_magic_manager.IsHedge(m_positions[i].magic))
         {
            ArrayResize(positions, count + 1);
            positions[count] = m_positions[i];
            count++;
         }
      }
      
      return count;
   }
   
   //+------------------------------------------------------------------+
   //| Get GridSlicer Positions                                         |
   //+------------------------------------------------------------------+
   int GetGridSlicerPositions(SPositionInfo &positions[])
   {
      ArrayResize(positions, 0);
      int count = 0;
      
      for(int i = 0; i < ArraySize(m_positions); i++)
      {
         if(m_magic_manager.IsGridSlicer(m_positions[i].magic))
         {
            ArrayResize(positions, count + 1);
            positions[count] = m_positions[i];
            count++;
         }
      }
      
      return count;
   }
   
   //+------------------------------------------------------------------+
   //| Get Position by Ticket                                           |
   //+------------------------------------------------------------------+
   bool GetPositionByTicket(ulong ticket, SPositionInfo &position)
   {
      for(int i = 0; i < ArraySize(m_positions); i++)
      {
         if(m_positions[i].ticket == ticket)
         {
            position = m_positions[i];
            return true;
         }
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if Position Exists                                         |
   //+------------------------------------------------------------------+
   bool PositionExists(ulong ticket)
   {
      for(int i = 0; i < ArraySize(m_positions); i++)
      {
         if(m_positions[i].ticket == ticket)
            return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Get Highest Martingale Layer                                     |
   //+------------------------------------------------------------------+
   int GetHighestMartingaleLayer()
   {
      int highest = 0;
      
      for(int i = 0; i < ArraySize(m_positions); i++)
      {
         if(m_magic_manager.IsMartingale(m_positions[i].magic))
         {
            if(m_positions[i].layer > highest)
               highest = m_positions[i].layer;
         }
      }
      
      return highest;
   }
   
   //+------------------------------------------------------------------+
   //| Get Highest Hedge Layer                                          |
   //+------------------------------------------------------------------+
   int GetHighestHedgeLayer()
   {
      int highest = 0;
      
      for(int i = 0; i < ArraySize(m_positions); i++)
      {
         if(m_magic_manager.IsHedge(m_positions[i].magic))
         {
            if(m_positions[i].layer > highest)
               highest = m_positions[i].layer;
         }
      }
      
      return highest;
   }
   
   //+------------------------------------------------------------------+
   //| Count Positions by Layer                                         |
   //+------------------------------------------------------------------+
   int CountPositionsByLayer(int layer)
   {
      int count = 0;
      
      for(int i = 0; i < ArraySize(m_positions); i++)
      {
         if(m_positions[i].layer == layer)
            count++;
      }
      
      return count;
   }
   
   //+------------------------------------------------------------------+
   //| Get Total Floating P/L                                           |
   //+------------------------------------------------------------------+
   double GetTotalFloatingPL()
   {
      return m_summary.GetNetPL();
   }
   
   //+------------------------------------------------------------------+
   //| Get Martingale Net P/L                                           |
   //+------------------------------------------------------------------+
   double GetMartingaleNetPL()
   {
      return m_summary.GetMartingaleNetPL();
   }
   
   //+------------------------------------------------------------------+
   //| Print Summary                                                     |
   //+------------------------------------------------------------------+
   void PrintSummary()
   {
      Print("╔═══════════════════════════════════════════════════════════╗");
      Print("║              POSITION SCANNER SUMMARY                     ║");
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ Last Scan: ", TimeToString(m_last_scan_time, TIME_DATE|TIME_SECONDS));
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ MARTINGALE BUY:                                           ║");
      Print("║   Count:       ", m_summary.mart_buy_count);
      Print("║   Lots:        ", DoubleToString(m_summary.mart_buy_lots, 2));
      Print("║   Avg Price:   ", DoubleToString(m_summary.mart_buy_avg_price, _Digits));
      Print("║   Profit:      $", DoubleToString(m_summary.mart_buy_profit, 2));
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ MARTINGALE SELL:                                          ║");
      Print("║   Count:       ", m_summary.mart_sell_count);
      Print("║   Lots:        ", DoubleToString(m_summary.mart_sell_lots, 2));
      Print("║   Avg Price:   ", DoubleToString(m_summary.mart_sell_avg_price, _Digits));
      Print("║   Profit:      $", DoubleToString(m_summary.mart_sell_profit, 2));
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ HEDGE:                                                    ║");
      Print("║   Count:       ", m_summary.hedge_count);
      Print("║   Lots:        ", DoubleToString(m_summary.hedge_lots, 2));
      Print("║   Profit:      $", DoubleToString(m_summary.hedge_profit, 2));
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ GRIDSLICER:                                               ║");
      Print("║   Count:       ", m_summary.gridslicer_count);
      Print("║   Lots:        ", DoubleToString(m_summary.gridslicer_lots, 2));
      Print("║   Profit:      $", DoubleToString(m_summary.gridslicer_profit, 2));
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ RECOVERY:                                                 ║");
      Print("║   BUY Count:   ", m_summary.recovery_buy_count);
      Print("║   BUY Lots:    ", DoubleToString(m_summary.recovery_buy_lots, 2));
      Print("║   BUY Profit:  $", DoubleToString(m_summary.recovery_buy_profit, 2));
      Print("║   SELL Count:  ", m_summary.recovery_sell_count);
      Print("║   SELL Lots:   ", DoubleToString(m_summary.recovery_sell_lots, 2));
      Print("║   SELL Profit: $", DoubleToString(m_summary.recovery_sell_profit, 2));
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ TOTALS:                                                   ║");
      Print("║   Total Count: ", m_summary.total_positions);
      Print("║   Total Lots:  ", DoubleToString(m_summary.total_lots, 2));
      Print("║   Net P/L:     $", DoubleToString(m_summary.total_profit, 2));
      Print("╚═══════════════════════════════════════════════════════════╝");
   }
   
   //+------------------------------------------------------------------+
   //| Get Last Scan Time                                               |
   //+------------------------------------------------------------------+
   datetime GetLastScanTime() { return m_last_scan_time; }
   
   //+------------------------------------------------------------------+
   //| Get Total Position Count                                         |
   //+------------------------------------------------------------------+
   int GetTotalCount() { return m_summary.total_positions; }
};

//+------------------------------------------------------------------+
//| End of TG_PositionScanner.mqh                                    |
//+------------------------------------------------------------------+
#endif // TG_POSITION_SCANNER_MQH
