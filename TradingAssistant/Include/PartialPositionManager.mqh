//+------------------------------------------------------------------+
//|                                        PartialPositionManager.mqh |
//|                      Trading Assistant - Partial Position Management |
//|                              Scale out, multiple TP levels |
//+------------------------------------------------------------------+
#property copyright "Trading Assistant"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Partial Position Manager Class                                   |
//+------------------------------------------------------------------+
class CPartialPositionManager
{
private:
   CTrade   m_trade;

   // Settings
   bool     m_use_partial_close;
   double   m_tp1_rr_ratio;           // First TP at 1:2 RR
   double   m_tp1_close_percent;     // Close 50% at TP1
   double   m_tp2_rr_ratio;           // Second TP at 1:3 RR
   double   m_tp2_close_percent;     // Close 30% at TP2
   // Remaining 20% goes to final TP at 1:5 RR

   // Tracking
   ulong    m_current_ticket;
   bool     m_tp1_hit;
   bool     m_tp2_hit;
   double   m_original_lot_size;

public:
   CPartialPositionManager();
   ~CPartialPositionManager();

   // Settings
   void SetPartialClose(bool enabled, double tp1_rr, double tp1_percent, double tp2_rr, double tp2_percent);

   // Monitor position
   void CheckPartialClose(ulong ticket);

   // Reset
   void Reset();

private:
   bool ClosePartial(ulong ticket, double percent);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CPartialPositionManager::CPartialPositionManager()
{
   m_use_partial_close = false;
   m_tp1_rr_ratio = 2.0;
   m_tp1_close_percent = 50.0;
   m_tp2_rr_ratio = 3.0;
   m_tp2_close_percent = 30.0;

   m_current_ticket = 0;
   m_tp1_hit = false;
   m_tp2_hit = false;
   m_original_lot_size = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CPartialPositionManager::~CPartialPositionManager()
{
}

//+------------------------------------------------------------------+
//| Set partial close settings                                       |
//+------------------------------------------------------------------+
void CPartialPositionManager::SetPartialClose(bool enabled, double tp1_rr, double tp1_percent, double tp2_rr, double tp2_percent)
{
   m_use_partial_close = enabled;
   m_tp1_rr_ratio = tp1_rr;
   m_tp1_close_percent = tp1_percent;
   m_tp2_rr_ratio = tp2_rr;
   m_tp2_close_percent = tp2_percent;
}

//+------------------------------------------------------------------+
//| Check for partial close opportunities                            |
//+------------------------------------------------------------------+
void CPartialPositionManager::CheckPartialClose(ulong ticket)
{
   if(!m_use_partial_close)
      return;

   if(ticket == 0)
      return;

   // Track new position
   if(ticket != m_current_ticket)
   {
      m_current_ticket = ticket;
      m_tp1_hit = false;
      m_tp2_hit = false;

      if(PositionSelectByTicket(ticket))
         m_original_lot_size = PositionGetDouble(POSITION_VOLUME);
   }

   if(!PositionSelectByTicket(ticket))
      return;

   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
   double sl = PositionGetDouble(POSITION_SL);
   ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   // Calculate risk distance
   double risk = MathAbs(open_price - sl);
   if(risk == 0)
      return;

   // Calculate current profit in RR terms
   double profit_distance = (pos_type == POSITION_TYPE_BUY) ?
                            (current_price - open_price) :
                            (open_price - current_price);

   double current_rr = profit_distance / risk;

   // Check TP1
   if(!m_tp1_hit && current_rr >= m_tp1_rr_ratio)
   {
      Print("TP1 hit at ", DoubleToString(current_rr, 2), " RR. Closing ", m_tp1_close_percent, "%");
      if(ClosePartial(ticket, m_tp1_close_percent))
         m_tp1_hit = true;
   }

   // Check TP2
   if(m_tp1_hit && !m_tp2_hit && current_rr >= m_tp2_rr_ratio)
   {
      Print("TP2 hit at ", DoubleToString(current_rr, 2), " RR. Closing ", m_tp2_close_percent, "%");
      if(ClosePartial(ticket, m_tp2_close_percent))
         m_tp2_hit = true;
   }
}

//+------------------------------------------------------------------+
//| Close partial position                                           |
//+------------------------------------------------------------------+
bool CPartialPositionManager::ClosePartial(ulong ticket, double percent)
{
   if(!PositionSelectByTicket(ticket))
      return false;

   double current_volume = PositionGetDouble(POSITION_VOLUME);
   double close_volume = NormalizeDouble(m_original_lot_size * (percent / 100.0), 2);

   // Ensure we don't try to close more than available
   if(close_volume > current_volume)
      close_volume = current_volume;

   // Ensure minimum lot size
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(close_volume < min_lot)
      return false;

   return m_trade.PositionClosePartial(ticket, close_volume);
}

//+------------------------------------------------------------------+
//| Reset tracking                                                    |
//+------------------------------------------------------------------+
void CPartialPositionManager::Reset()
{
   m_current_ticket = 0;
   m_tp1_hit = false;
   m_tp2_hit = false;
   m_original_lot_size = 0;
}
//+------------------------------------------------------------------+
