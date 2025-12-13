//+------------------------------------------------------------------+
//|                                        Core/TG_MagicNumbers.mqh  |
//|                                          Titan Grid EA v1.0      |
//|                                  Magic Number Management System  |
//+------------------------------------------------------------------+
//| Location: C:\Users\ichza\AppData\Roaming\MetaQuotes\Terminal\   |
//|           D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\         |
//|           TitanGridEA\Core\TG_MagicNumbers.mqh                   |
//|                                                                  |
//| Purpose:  Centralized magic number generation and management    |
//|           Ensures unique identification for all position types  |
//|           Dependencies: TG_Definitions.mqh                       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.00"

//+------------------------------------------------------------------+
//| CHANGE LOG                                                        |
//+------------------------------------------------------------------+
// Version 1.00 - 2025-01-20
// [INITIAL] Magic number system created
// [ADD] Base magic number configuration
// [ADD] Magic number generators for all systems
// [ADD] Magic number validators
// [ADD] System identification functions
//+------------------------------------------------------------------+

#ifndef TG_MAGIC_NUMBERS_MQH
#define TG_MAGIC_NUMBERS_MQH

#include "TG_Definitions.mqh"

//+------------------------------------------------------------------+
//| MAGIC NUMBER STRUCTURE                                            |
//|------------------------------------------------------------------|
//| Format: AABBCCDD                                                  |
//|   AA = Base magic (user input, 10-99)                            |
//|   BB = System type (10-90)                                       |
//|   CC = Direction (10=BUY, 20=SELL, 00=Both)                      |
//|   DD = Layer/Index (00-99)                                       |
//|                                                                  |
//| Example: 12345678                                                 |
//|   12 = Base magic                                                |
//|   34 = Martingale system                                         |
//|   56 = BUY direction                                             |
//|   78 = Layer 78                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| BASE MAGIC NUMBER (User Configurable)                            |
//+------------------------------------------------------------------+
// This will be set from EA input parameter
// Range: 100000 - 999999 (6 digits for safety)
// Each user should use unique base magic to avoid conflicts

//+------------------------------------------------------------------+
//| SYSTEM TYPE CODES (Second pair of digits)                        |
//+------------------------------------------------------------------+
#define MAGIC_SYSTEM_MARTINGALE     10    // Martingale positions
#define MAGIC_SYSTEM_GRIDSLICER     20    // GridSlicer pending orders & positions
#define MAGIC_SYSTEM_HEDGE          30    // Hedge positions
#define MAGIC_SYSTEM_RECOVERY       40    // Recovery positions
#define MAGIC_SYSTEM_MANUAL         50    // Manual entries from panel
#define MAGIC_SYSTEM_TEST           90    // Test/Debug positions

//+------------------------------------------------------------------+
//| DIRECTION CODES (Third pair of digits)                           |
//+------------------------------------------------------------------+
#define MAGIC_DIRECTION_BUY         10    // BUY positions
#define MAGIC_DIRECTION_SELL        20    // SELL positions
#define MAGIC_DIRECTION_BOTH        0     // Direction-neutral (for PO)

//+------------------------------------------------------------------+
//| MAGIC NUMBER GENERATOR CLASS                                      |
//+------------------------------------------------------------------+
class CMagicNumberManager
{
private:
   int m_base_magic;                          // Base magic number
   
   // Validation
   bool ValidateBaseMagic(int magic)
   {
      if(magic < 100000 || magic > 999999)
      {
         Print("❌ ERROR: Base magic must be between 100000 and 999999");
         Print("   Current value: ", magic);
         return false;
      }
      return true;
   }
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CMagicNumberManager()
   {
      m_base_magic = 123456; // Default
   }
   
   //+------------------------------------------------------------------+
   //| Initialize with base magic                                        |
   //+------------------------------------------------------------------+
   bool Initialize(int base_magic)
   {
      if(!ValidateBaseMagic(base_magic))
         return false;
      
      m_base_magic = base_magic;
      
      Print("╔═══════════════════════════════════════════════════════════╗");
      Print("║         MAGIC NUMBER MANAGER INITIALIZED                 ║");
      Print("╠═══════════════════════════════════════════════════════════╣");
      Print("║ Base Magic: ", m_base_magic);
      Print("║ Format: ", m_base_magic, "SSDDLL");
      Print("║   SS = System Type (10-90)");
      Print("║   DD = Direction (10=BUY, 20=SELL, 00=Both)");
      Print("║   LL = Layer/Index (00-99)");
      Print("╚═══════════════════════════════════════════════════════════╝");
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| MARTINGALE MAGIC NUMBERS                                          |
   //+------------------------------------------------------------------+
   
   // Generate magic for Martingale BUY position at specific layer
   long GetMartingaleBuyMagic(int layer)
   {
      if(layer < 1 || layer > MAX_LAYERS)
      {
         Print("⚠️ WARNING: Invalid layer ", layer, ". Using layer 1.");
         layer = 1;
      }
      
      // Format: BASE + SYSTEM(10) + DIRECTION(10) + LAYER
      // Example: 123456 + 10 + 10 + 01 = 12345611001
      long magic = (long)m_base_magic * 10000 + 
                   MAGIC_SYSTEM_MARTINGALE * 100 + 
                   MAGIC_DIRECTION_BUY * 10 + 
                   layer;
      
      return magic;
   }
   
   // Generate magic for Martingale SELL position at specific layer
   long GetMartingaleSellMagic(int layer)
   {
      if(layer < 1 || layer > MAX_LAYERS)
      {
         Print("⚠️ WARNING: Invalid layer ", layer, ". Using layer 1.");
         layer = 1;
      }
      
      // Format: BASE + SYSTEM(10) + DIRECTION(20) + LAYER
      // Example: 123456 + 10 + 20 + 01 = 12345612001
      long magic = (long)m_base_magic * 10000 + 
                   MAGIC_SYSTEM_MARTINGALE * 100 + 
                   MAGIC_DIRECTION_SELL * 10 + 
                   layer;
      
      return magic;
   }
   
   //+------------------------------------------------------------------+
   //| GRIDSLICER MAGIC NUMBERS                                          |
   //+------------------------------------------------------------------+
   
   // Generate magic for GridSlicer pending order
   long GetGridSlicerMagic(int index)
   {
      if(index < 0 || index > MAX_GRIDSLICER_POS)
      {
         Print("⚠️ WARNING: Invalid GridSlicer index ", index);
         index = 0;
      }
      
      // Format: BASE + SYSTEM(20) + DIRECTION(00) + INDEX
      // Example: 123456 + 20 + 00 + 05 = 12345620005
      long magic = (long)m_base_magic * 10000 + 
                   MAGIC_SYSTEM_GRIDSLICER * 100 + 
                   index;
      
      return magic;
   }
   
   //+------------------------------------------------------------------+
   //| HEDGE MAGIC NUMBERS                                               |
   //+------------------------------------------------------------------+
   
   // Generate magic for Hedge BUY position
   long GetHedgeBuyMagic()
   {
      // Format: BASE + SYSTEM(30) + DIRECTION(10) + 00
      // Example: 123456 + 30 + 10 + 00 = 12345631000
      long magic = (long)m_base_magic * 10000 + 
                   MAGIC_SYSTEM_HEDGE * 100 + 
                   MAGIC_DIRECTION_BUY * 10;
      
      return magic;
   }
   
   // Generate magic for Hedge SELL position
   long GetHedgeSellMagic()
   {
      // Format: BASE + SYSTEM(30) + DIRECTION(20) + 00
      // Example: 123456 + 30 + 20 + 00 = 12345632000
      long magic = (long)m_base_magic * 10000 + 
                   MAGIC_SYSTEM_HEDGE * 100 + 
                   MAGIC_DIRECTION_SELL * 10;
      
      return magic;
   }
   
   //+------------------------------------------------------------------+
   //| RECOVERY MAGIC NUMBERS                                            |
   //+------------------------------------------------------------------+
   
   // Generate magic for Recovery BUY position
   long GetRecoveryBuyMagic(int index = 0)
   {
      // Format: BASE + SYSTEM(40) + DIRECTION(10) + INDEX
      // Example: 123456 + 40 + 10 + 01 = 12345641001
      long magic = (long)m_base_magic * 10000 + 
                   MAGIC_SYSTEM_RECOVERY * 100 + 
                   MAGIC_DIRECTION_BUY * 10 + 
                   index;
      
      return magic;
   }
   
   // Generate magic for Recovery SELL position
   long GetRecoverySellMagic(int index = 0)
   {
      // Format: BASE + SYSTEM(40) + DIRECTION(20) + INDEX
      // Example: 123456 + 40 + 20 + 01 = 12345642001
      long magic = (long)m_base_magic * 10000 + 
                   MAGIC_SYSTEM_RECOVERY * 100 + 
                   MAGIC_DIRECTION_SELL * 10 + 
                   index;
      
      return magic;
   }
   
   //+------------------------------------------------------------------+
   //| MANUAL ENTRY MAGIC NUMBERS                                        |
   //+------------------------------------------------------------------+
   
   // Generate magic for Manual BUY entry
   long GetManualBuyMagic()
   {
      // Format: BASE + SYSTEM(50) + DIRECTION(10) + 00
      // Example: 123456 + 50 + 10 + 00 = 12345651000
      long magic = (long)m_base_magic * 10000 + 
                   MAGIC_SYSTEM_MANUAL * 100 + 
                   MAGIC_DIRECTION_BUY * 10;
      
      return magic;
   }
   
   // Generate magic for Manual SELL entry
   long GetManualSellMagic()
   {
      // Format: BASE + SYSTEM(50) + DIRECTION(20) + 00
      // Example: 123456 + 50 + 20 + 00 = 12345652000
      long magic = (long)m_base_magic * 10000 + 
                   MAGIC_SYSTEM_MANUAL * 100 + 
                   MAGIC_DIRECTION_SELL * 10;
      
      return magic;
   }
   
   //+------------------------------------------------------------------+
   //| MAGIC NUMBER VALIDATORS & PARSERS                                |
   //+------------------------------------------------------------------+
   
   // Check if magic number belongs to this EA
   bool IsMagicOurs(long magic)
   {
      // Extract base magic (first 6 digits)
      long base = magic / 10000;
      
      return (base == m_base_magic);
   }
   
   // Get system type from magic number
   int GetSystemType(long magic)
   {
      if(!IsMagicOurs(magic))
         return -1;
      
      // Extract system code (digits 7-8)
      int system = (int)((magic / 100) % 100);
      
      return system;
   }
   
   // Get direction from magic number
   int GetDirection(long magic)
   {
      if(!IsMagicOurs(magic))
         return -1;
      
      // Extract direction code (digits 9-10)
      int direction = (int)((magic / 10) % 10);
      
      return direction;
   }
   
   // Get layer/index from magic number
   int GetLayerIndex(long magic)
   {
      if(!IsMagicOurs(magic))
         return -1;
      
      // Extract layer/index (last 2 digits)
      int layer = (int)(magic % 100);
      
      return layer;
   }
   
   // Check if magic is Martingale
   bool IsMartingale(long magic)
   {
      return (GetSystemType(magic) == MAGIC_SYSTEM_MARTINGALE);
   }
   
   // Check if magic is GridSlicer
   bool IsGridSlicer(long magic)
   {
      return (GetSystemType(magic) == MAGIC_SYSTEM_GRIDSLICER);
   }
   
   // Check if magic is Hedge
   bool IsHedge(long magic)
   {
      return (GetSystemType(magic) == MAGIC_SYSTEM_HEDGE);
   }
   
   // Check if magic is Recovery
   bool IsRecovery(long magic)
   {
      return (GetSystemType(magic) == MAGIC_SYSTEM_RECOVERY);
   }
   
   // Check if magic is Manual entry
   bool IsManual(long magic)
   {
      return (GetSystemType(magic) == MAGIC_SYSTEM_MANUAL);
   }
   
   // Check if magic is BUY direction
   bool IsBuy(long magic)
   {
      return (GetDirection(magic) == MAGIC_DIRECTION_BUY);
   }
   
   // Check if magic is SELL direction
   bool IsSell(long magic)
   {
      return (GetDirection(magic) == MAGIC_DIRECTION_SELL);
   }
   
   //+------------------------------------------------------------------+
   //| MAGIC NUMBER TO STRING (For Logging & Display)                   |
   //+------------------------------------------------------------------+
   string MagicToString(long magic)
   {
      if(!IsMagicOurs(magic))
         return "NOT OURS: " + IntegerToString(magic);
      
      string result = "";
      
      // System type
      int system = GetSystemType(magic);
      switch(system)
      {
         case MAGIC_SYSTEM_MARTINGALE:
            result += "MART-";
            break;
         case MAGIC_SYSTEM_GRIDSLICER:
            result += "GS-";
            break;
         case MAGIC_SYSTEM_HEDGE:
            result += "HEDGE-";
            break;
         case MAGIC_SYSTEM_RECOVERY:
            result += "RECOV-";
            break;
         case MAGIC_SYSTEM_MANUAL:
            result += "MANUAL-";
            break;
         default:
            result += "UNKNOWN-";
            break;
      }
      
      // Direction
      int direction = GetDirection(magic);
      if(direction == MAGIC_DIRECTION_BUY)
         result += "BUY";
      else if(direction == MAGIC_DIRECTION_SELL)
         result += "SELL";
      else
         result += "BOTH";
      
      // Layer/Index
      int layer = GetLayerIndex(magic);
      if(layer > 0)
         result += "-L" + IntegerToString(layer);
      
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| GET ALL MAGICS FOR A SYSTEM (For Position Scanning)              |
   //+------------------------------------------------------------------+
   
   // Get all Martingale BUY magics (array of all layers)
   void GetAllMartingaleBuyMagics(long &magics[])
   {
      ArrayResize(magics, MAX_LAYERS);
      
      for(int i = 0; i < MAX_LAYERS; i++)
      {
         magics[i] = GetMartingaleBuyMagic(i + 1);
      }
   }
   
   // Get all Martingale SELL magics (array of all layers)
   void GetAllMartingaleSellMagics(long &magics[])
   {
      ArrayResize(magics, MAX_LAYERS);
      
      for(int i = 0; i < MAX_LAYERS; i++)
      {
         magics[i] = GetMartingaleSellMagic(i + 1);
      }
   }
   
   // Get all GridSlicer magics
   void GetAllGridSlicerMagics(long &magics[])
   {
      ArrayResize(magics, MAX_GRIDSLICER_POS);
      
      for(int i = 0; i < MAX_GRIDSLICER_POS; i++)
      {
         magics[i] = GetGridSlicerMagic(i);
      }
   }
   
   //+------------------------------------------------------------------+
   //| DEBUG: PRINT ALL MAGICS                                          |
   //+------------------------------------------------------------------+
   void PrintAllMagics()
   {
      Print("╔═══════════════════════════════════════════════════════════╗");
      Print("║              ALL MAGIC NUMBERS FOR BASE: ", m_base_magic, "        ║");
      Print("╠═══════════════════════════════════════════════════════════╣");
      
      Print("║ MARTINGALE BUY:                                           ║");
      for(int i = 1; i <= 5; i++)
      {
         long magic = GetMartingaleBuyMagic(i);
         Print("║   Layer ", i, ": ", magic, " (", MagicToString(magic), ")");
      }
      Print("║   ... (layers 6-", MAX_LAYERS, ")");
      
      Print("║ MARTINGALE SELL:                                          ║");
      for(int i = 1; i <= 5; i++)
      {
         long magic = GetMartingaleSellMagic(i);
         Print("║   Layer ", i, ": ", magic, " (", MagicToString(magic), ")");
      }
      Print("║   ... (layers 6-", MAX_LAYERS, ")");
      
      Print("║ GRIDSLICER:                                               ║");
      for(int i = 0; i < 3; i++)
      {
         long magic = GetGridSlicerMagic(i);
         Print("║   Index ", i, ": ", magic, " (", MagicToString(magic), ")");
      }
      Print("║   ... (indices 3-", MAX_GRIDSLICER_POS, ")");
      
      Print("║ HEDGE:                                                    ║");
      Print("║   BUY:  ", GetHedgeBuyMagic(), " (", MagicToString(GetHedgeBuyMagic()), ")");
      Print("║   SELL: ", GetHedgeSellMagic(), " (", MagicToString(GetHedgeSellMagic()), ")");
      
      Print("║ RECOVERY:                                                 ║");
      Print("║   BUY:  ", GetRecoveryBuyMagic(), " (", MagicToString(GetRecoveryBuyMagic()), ")");
      Print("║   SELL: ", GetRecoverySellMagic(), " (", MagicToString(GetRecoverySellMagic()), ")");
      
      Print("║ MANUAL:                                                   ║");
      Print("║   BUY:  ", GetManualBuyMagic(), " (", MagicToString(GetManualBuyMagic()), ")");
      Print("║   SELL: ", GetManualSellMagic(), " (", MagicToString(GetManualSellMagic()), ")");
      
      Print("╚═══════════════════════════════════════════════════════════╝");
   }
   
   //+------------------------------------------------------------------+
   //| GETTERS                                                           |
   //+------------------------------------------------------------------+
   int GetBaseMagic() const { return m_base_magic; }
};

//+------------------------------------------------------------------+
//| GLOBAL INSTANCE (Will be initialized in main EA)                 |
//+------------------------------------------------------------------+
// This will be instantiated in TitanGrid_v1.0.mq5
// CMagicNumberManager g_magic_manager;

//+------------------------------------------------------------------+
//| End of TG_MagicNumbers.mqh                                       |
//+------------------------------------------------------------------+
#endif // TG_MAGIC_NUMBERS_MQH
