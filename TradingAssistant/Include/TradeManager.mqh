//+------------------------------------------------------------------+
//|                                          TradeManager.mqh        |
//|                          Automatic SL/TP and Trailing Management |
//|                                    After Manual Entry Only       |
//+------------------------------------------------------------------+
#property copyright "Trading Assistant 2026"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Trade Manager Class                                              |
//+------------------------------------------------------------------+
class CTradeManager
{
private:
   ulong    m_position_ticket;
   bool     m_is_managing;
   double   m_initial_sl;
   double   m_initial_tp;
   double   m_trailing_distance;
   double   m_trailing_step;
   bool     m_trailing_active;
   double   m_breakeven_distance;
   bool     m_breakeven_set;

   // Risk/Reward settings
   double   m_rr_ratio;           // Risk:Reward ratio (default 1:3)
   double   m_atr_multiplier_sl;  // ATR multiplier for SL
   double   m_atr_multiplier_tp;  // ATR multiplier for TP

   int      m_atr_handle;
   int      m_atr_period;

public:
   CTradeManager();
   ~CTradeManager();

   // Initialization
   bool Init(string symbol, ENUM_TIMEFRAMES timeframe);
   void Deinit();

   // Configuration
   void SetRiskReward(double rr_ratio);
   void SetATRMultipliers(double sl_mult, double tp_mult);
   void SetTrailingParams(double distance_points, double step_points);

   // Trade detection and management
   bool CheckForNewPosition();
   bool ManagePosition();
   bool HasActivePosition();
   void Reset();

   // Position info
   double GetCurrentProfit();
   double GetStopLoss();
   double GetTakeProfit();
   bool IsTrailingActive();

private:
   bool SetInitialSLTP(ulong ticket);
   bool ActivateTrailingStop();
   bool UpdateTrailingStop();
   bool MoveToBreakeven();
   double CalculateSL(ENUM_POSITION_TYPE type, double entry_price);
   double CalculateTP(ENUM_POSITION_TYPE type, double entry_price, double sl_distance);
   double GetATRValue();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CTradeManager::CTradeManager()
{
   m_position_ticket = 0;
   m_is_managing = false;
   m_initial_sl = 0;
   m_initial_tp = 0;
   m_trailing_active = false;
   m_breakeven_set = false;

   m_rr_ratio = 3.0;  // 1:3 risk reward
   m_atr_multiplier_sl = 1.5;
   m_atr_multiplier_tp = 4.5;  // 3x the SL distance

   m_trailing_distance = 200;  // points
   m_trailing_step = 50;       // points
   m_breakeven_distance = 100; // points

   m_atr_handle = INVALID_HANDLE;
   m_atr_period = 14;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CTradeManager::~CTradeManager()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Initialize                                                        |
//+------------------------------------------------------------------+
bool CTradeManager::Init(string symbol, ENUM_TIMEFRAMES timeframe)
{
   m_atr_handle = iATR(symbol, timeframe, m_atr_period);
   if(m_atr_handle == INVALID_HANDLE)
   {
      Print("Error creating ATR indicator for TradeManager: ", GetLastError());
      return false;
   }

   Print("Trade Manager initialized successfully");
   return true;
}

//+------------------------------------------------------------------+
//| Cleanup                                                           |
//+------------------------------------------------------------------+
void CTradeManager::Deinit()
{
   if(m_atr_handle != INVALID_HANDLE)
      IndicatorRelease(m_atr_handle);
}

//+------------------------------------------------------------------+
//| Set risk/reward ratio                                            |
//+------------------------------------------------------------------+
void CTradeManager::SetRiskReward(double rr_ratio)
{
   m_rr_ratio = rr_ratio;
   m_atr_multiplier_tp = m_atr_multiplier_sl * rr_ratio;
}

//+------------------------------------------------------------------+
//| Set ATR multipliers                                              |
//+------------------------------------------------------------------+
void CTradeManager::SetATRMultipliers(double sl_mult, double tp_mult)
{
   m_atr_multiplier_sl = sl_mult;
   m_atr_multiplier_tp = tp_mult;
}

//+------------------------------------------------------------------+
//| Set trailing stop parameters                                     |
//+------------------------------------------------------------------+
void CTradeManager::SetTrailingParams(double distance_points, double step_points)
{
   m_trailing_distance = distance_points;
   m_trailing_step = step_points;
}

//+------------------------------------------------------------------+
//| Check for new manually opened position                           |
//+------------------------------------------------------------------+
bool CTradeManager::CheckForNewPosition()
{
   // If already managing a position, skip
   if(m_is_managing && PositionSelectByTicket(m_position_ticket))
      return false;

   // Check if there's a position for current symbol
   if(!PositionSelect(_Symbol))
   {
      Reset();
      return false;
   }

   // Get position ticket
   ulong ticket = PositionGetInteger(POSITION_TICKET);

   // Check if this is a new position we haven't managed yet
   if(ticket != m_position_ticket)
   {
      Print("New position detected: ", ticket);
      m_position_ticket = ticket;
      m_is_managing = true;
      m_trailing_active = false;
      m_breakeven_set = false;

      // Set initial SL and TP
      if(!SetInitialSLTP(ticket))
      {
         Print("Warning: Could not set initial SL/TP");
      }

      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Manage active position                                           |
//+------------------------------------------------------------------+
bool CTradeManager::ManagePosition()
{
   if(!m_is_managing || m_position_ticket == 0)
      return false;

   // Check if position still exists
   if(!PositionSelectByTicket(m_position_ticket))
   {
      Print("Position closed: ", m_position_ticket);
      Reset();
      return false;
   }

   double current_profit = PositionGetDouble(POSITION_PROFIT);
   double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
   ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double current_price = pos_type == POSITION_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double distance_points = 0;

   // Calculate distance in points
   if(pos_type == POSITION_TYPE_BUY)
      distance_points = (current_price - entry_price) / point;
   else
      distance_points = (entry_price - current_price) / point;

   // Move to breakeven if profit is enough
   if(!m_breakeven_set && distance_points >= m_breakeven_distance)
   {
      if(MoveToBreakeven())
      {
         m_breakeven_set = true;
         Print("Position moved to breakeven");
      }
   }

   // Activate trailing stop if profit is enough
   if(!m_trailing_active && distance_points >= m_trailing_distance)
   {
      if(ActivateTrailingStop())
      {
         m_trailing_active = true;
         Print("Trailing stop activated");
      }
   }

   // Update trailing stop if active
   if(m_trailing_active)
   {
      UpdateTrailingStop();
   }

   return true;
}

//+------------------------------------------------------------------+
//| Set initial SL and TP                                            |
//+------------------------------------------------------------------+
bool CTradeManager::SetInitialSLTP(ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
      return false;

   double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
   ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double current_sl = PositionGetDouble(POSITION_SL);
   double current_tp = PositionGetDouble(POSITION_TP);

   // Calculate SL and TP
   double new_sl = CalculateSL(pos_type, entry_price);
   double sl_distance = MathAbs(entry_price - new_sl);
   double new_tp = CalculateTP(pos_type, entry_price, sl_distance);

   // Only set if not already set by trader
   bool need_modification = false;
   if(current_sl == 0 || MathAbs(current_sl - new_sl) > SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10)
   {
      need_modification = true;
   }
   if(current_tp == 0 || MathAbs(current_tp - new_tp) > SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10)
   {
      need_modification = true;
   }

   if(need_modification)
   {
      MqlTradeRequest request = {};
      MqlTradeResult result = {};

      request.action = TRADE_ACTION_SLTP;
      request.position = ticket;
      request.symbol = _Symbol;
      request.sl = new_sl;
      request.tp = new_tp;

      if(OrderSend(request, result))
      {
         m_initial_sl = new_sl;
         m_initial_tp = new_tp;
         Print("SL/TP set successfully - SL: ", new_sl, " TP: ", new_tp);
         return true;
      }
      else
      {
         Print("Failed to set SL/TP: ", result.retcode, " - ", result.comment);
         return false;
      }
   }

   m_initial_sl = current_sl;
   m_initial_tp = current_tp;
   return true;
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss                                              |
//+------------------------------------------------------------------+
double CTradeManager::CalculateSL(ENUM_POSITION_TYPE type, double entry_price)
{
   double atr = GetATRValue();
   double sl_distance = atr * m_atr_multiplier_sl;

   double sl = 0;
   if(type == POSITION_TYPE_BUY)
      sl = entry_price - sl_distance;
   else
      sl = entry_price + sl_distance;

   // Normalize price
   return NormalizeDouble(sl, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

//+------------------------------------------------------------------+
//| Calculate Take Profit                                            |
//+------------------------------------------------------------------+
double CTradeManager::CalculateTP(ENUM_POSITION_TYPE type, double entry_price, double sl_distance)
{
   double tp_distance = sl_distance * m_rr_ratio;

   double tp = 0;
   if(type == POSITION_TYPE_BUY)
      tp = entry_price + tp_distance;
   else
      tp = entry_price - tp_distance;

   // Normalize price
   return NormalizeDouble(tp, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

//+------------------------------------------------------------------+
//| Get ATR value                                                     |
//+------------------------------------------------------------------+
double CTradeManager::GetATRValue()
{
   double atr[];
   ArraySetAsSeries(atr, true);

   if(CopyBuffer(m_atr_handle, 0, 0, 1, atr) < 1)
      return 0;

   return atr[0];
}

//+------------------------------------------------------------------+
//| Activate trailing stop                                           |
//+------------------------------------------------------------------+
bool CTradeManager::ActivateTrailingStop()
{
   // Trailing stop logic will be applied in UpdateTrailingStop
   return true;
}

//+------------------------------------------------------------------+
//| Update trailing stop                                             |
//+------------------------------------------------------------------+
bool CTradeManager::UpdateTrailingStop()
{
   if(!PositionSelectByTicket(m_position_ticket))
      return false;

   ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double current_sl = PositionGetDouble(POSITION_SL);
   double current_price = pos_type == POSITION_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   double new_sl = 0;
   bool should_update = false;

   if(pos_type == POSITION_TYPE_BUY)
   {
      new_sl = current_price - (m_trailing_distance * point);
      if(new_sl > current_sl + (m_trailing_step * point))
         should_update = true;
   }
   else
   {
      new_sl = current_price + (m_trailing_distance * point);
      if(new_sl < current_sl - (m_trailing_step * point) || current_sl == 0)
         should_update = true;
   }

   if(should_update)
   {
      MqlTradeRequest request = {};
      MqlTradeResult result = {};

      request.action = TRADE_ACTION_SLTP;
      request.position = m_position_ticket;
      request.symbol = _Symbol;
      request.sl = NormalizeDouble(new_sl, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
      request.tp = PositionGetDouble(POSITION_TP);

      if(OrderSend(request, result))
      {
         Print("Trailing stop updated to: ", new_sl);
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Move stop loss to breakeven                                      |
//+------------------------------------------------------------------+
bool CTradeManager::MoveToBreakeven()
{
   if(!PositionSelectByTicket(m_position_ticket))
      return false;

   double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);

   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   request.action = TRADE_ACTION_SLTP;
   request.position = m_position_ticket;
   request.symbol = _Symbol;
   request.sl = NormalizeDouble(entry_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
   request.tp = PositionGetDouble(POSITION_TP);

   return OrderSend(request, result);
}

//+------------------------------------------------------------------+
//| Check if managing active position                                |
//+------------------------------------------------------------------+
bool CTradeManager::HasActivePosition()
{
   return m_is_managing && PositionSelectByTicket(m_position_ticket);
}

//+------------------------------------------------------------------+
//| Get current profit                                                |
//+------------------------------------------------------------------+
double CTradeManager::GetCurrentProfit()
{
   if(!HasActivePosition())
      return 0;

   return PositionGetDouble(POSITION_PROFIT);
}

//+------------------------------------------------------------------+
//| Get Stop Loss                                                     |
//+------------------------------------------------------------------+
double CTradeManager::GetStopLoss()
{
   if(!HasActivePosition())
      return 0;

   return PositionGetDouble(POSITION_SL);
}

//+------------------------------------------------------------------+
//| Get Take Profit                                                   |
//+------------------------------------------------------------------+
double CTradeManager::GetTakeProfit()
{
   if(!HasActivePosition())
      return 0;

   return PositionGetDouble(POSITION_TP);
}

//+------------------------------------------------------------------+
//| Is trailing active                                                |
//+------------------------------------------------------------------+
bool CTradeManager::IsTrailingActive()
{
   return m_trailing_active;
}

//+------------------------------------------------------------------+
//| Reset trade manager                                              |
//+------------------------------------------------------------------+
void CTradeManager::Reset()
{
   m_position_ticket = 0;
   m_is_managing = false;
   m_trailing_active = false;
   m_breakeven_set = false;
   m_initial_sl = 0;
   m_initial_tp = 0;
}
//+------------------------------------------------------------------+
