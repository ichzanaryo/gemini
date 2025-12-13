//+------------------------------------------------------------------+
//|                                      Core/TG_MagicNumbers.mqh    |
//|                                          Titan Grid EA v1.05     |
//|                              Magic Number Management (UNLOCKED)  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ichzanaryo"
#property link      "https://t.me/fatichid"
#property version   "1.05"

#ifndef TG_MAGIC_NUMBERS_MQH
#define TG_MAGIC_NUMBERS_MQH

#include "TG_Definitions.mqh"

//+------------------------------------------------------------------+
//| SYSTEM TYPE CODES                                                |
//+------------------------------------------------------------------+
#define MAGIC_SYSTEM_MARTINGALE     10    // Martingale positions
#define MAGIC_SYSTEM_GRIDSLICER     20    // GridSlicer pending orders
#define MAGIC_SYSTEM_HEDGE          30    // Hedge positions
#define MAGIC_SYSTEM_RECOVERY       40    // Recovery positions
#define MAGIC_SYSTEM_MANUAL         50    // Manual entries
#define MAGIC_SYSTEM_TEST           90    // Test/Debug

//+------------------------------------------------------------------+
//| DIRECTION CODES                                                  |
//+------------------------------------------------------------------+
#define MAGIC_DIRECTION_BUY         10    // BUY positions
#define MAGIC_DIRECTION_SELL        20    // SELL positions
#define MAGIC_DIRECTION_BOTH        0     // Direction-neutral

//+------------------------------------------------------------------+
//| MAGIC NUMBER GENERATOR CLASS                                     |
//+------------------------------------------------------------------+
class CMagicNumberManager
{
private:
   int m_base_magic;

   bool ValidateBaseMagic(int magic)
   {
      if(magic < 100000 || magic > 999999)
      {
         Print("❌ ERROR: Base magic must be between 100000 and 999999");
         return false;
      }
      return true;
   }
   
public:
   CMagicNumberManager() { m_base_magic = 123456; }
   
   bool Initialize(int base_magic)
   {
      if(!ValidateBaseMagic(base_magic)) return false;
      m_base_magic = base_magic;
      Print("✅ Magic Number Manager Initialized. Base: ", m_base_magic);
      return true;
   }
   
   // --- MARTINGALE ---
   long GetMartingaleBuyMagic(int layer)
   {
      // Format: BASESSDDLL (Base + 10 + 10 + Layer)
      return (long)m_base_magic * 1000000 + MAGIC_SYSTEM_MARTINGALE * 10000 + MAGIC_DIRECTION_BUY * 100 + layer;
   }
   
   long GetMartingaleSellMagic(int layer)
   {
      return (long)m_base_magic * 1000000 + MAGIC_SYSTEM_MARTINGALE * 10000 + MAGIC_DIRECTION_SELL * 100 + layer;
   }
   
   // --- GRIDSLICER (FIXED) ---
   long GetGridSlicerMagic(int index)
   {
      // [FIX] REMOVED LIMITATION check (index < 0 || index > 20)
      // GridSlicer now uses ID format: (Layer * 100) + PO_Index
      // Example: Layer 15, PO 2 => ID 1502. 
      // Valid range now supports up to 9999 (fits in last 4 digits)
      
      // Format: BASESSIIII (Base + 20 + Index)
      // Note: We allocate 4 digits for index to support the Layer+PO format
      // Formula modified to allow larger numbers in the suffix
      
      // Original Format was: Base(6) + Sys(2) + Dir(2) + Id(2)
      // Since GridSlicer needs more space for ID (e.g. 1502), we treat the last 4 digits as flexible.
      
      // Example: 123456 20 1502 (Base + Sys + Index)
      long magic = (long)m_base_magic * 1000000 + 
                   MAGIC_SYSTEM_GRIDSLICER * 10000 + 
                   index; // Index can now be up to 9999
      
      return magic;
   }
   
   // --- HEDGE ---
   long GetHedgeBuyMagic()
   {
      return (long)m_base_magic * 1000000 + MAGIC_SYSTEM_HEDGE * 10000 + MAGIC_DIRECTION_BUY * 100;
   }
   
   long GetHedgeSellMagic()
   {
      return (long)m_base_magic * 1000000 + MAGIC_SYSTEM_HEDGE * 10000 + MAGIC_DIRECTION_SELL * 100;
   }
   
   // --- RECOVERY ---
   long GetRecoveryBuyMagic(int index = 0)
   {
      return (long)m_base_magic * 1000000 + MAGIC_SYSTEM_RECOVERY * 10000 + MAGIC_DIRECTION_BUY * 100 + index;
   }
   
   long GetRecoverySellMagic(int index = 0)
   {
      return (long)m_base_magic * 1000000 + MAGIC_SYSTEM_RECOVERY * 10000 + MAGIC_DIRECTION_SELL * 100 + index;
   }
   
   // --- MANUAL ---
   long GetManualBuyMagic()
   {
      return (long)m_base_magic * 1000000 + MAGIC_SYSTEM_MANUAL * 10000 + MAGIC_DIRECTION_BUY * 100;
   }
   
   long GetManualSellMagic()
   {
      return (long)m_base_magic * 1000000 + MAGIC_SYSTEM_MANUAL * 10000 + MAGIC_DIRECTION_SELL * 100;
   }
   
   // --- HELPERS ---
   bool IsMagicOurs(long magic)
   {
      long base = magic / 1000000;
      return (base == m_base_magic);
   }
   
   int GetSystemType(long magic)
   {
      if(!IsMagicOurs(magic)) return -1;
      return (int)((magic / 10000) % 100);
   }
   
   int GetLayerIndex(long magic)
   {
      if(!IsMagicOurs(magic)) return -1;
      return (int)(magic % 100); // Only takes last 2 digits
   }
   
   // Type Checkers
   bool IsMartingale(long magic) { return GetSystemType(magic) == MAGIC_SYSTEM_MARTINGALE; }
   bool IsGridSlicer(long magic) { return GetSystemType(magic) == MAGIC_SYSTEM_GRIDSLICER; }
   bool IsHedge(long magic)      { return GetSystemType(magic) == MAGIC_SYSTEM_HEDGE; }
   bool IsRecovery(long magic)   { return GetSystemType(magic) == MAGIC_SYSTEM_RECOVERY; }
   
   // Direction Checkers (Not applicable for GridSlicer advanced IDs)
   bool IsBuy(long magic) 
   { 
      int dir = (int)((magic / 100) % 100);
      return (dir == MAGIC_DIRECTION_BUY); 
   }
   
   bool IsSell(long magic) 
   { 
      int dir = (int)((magic / 100) % 100);
      return (dir == MAGIC_DIRECTION_SELL); 
   }
   
   int GetBaseMagic() const { return m_base_magic; }
};

#endif