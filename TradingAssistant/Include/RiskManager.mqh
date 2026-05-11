//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|                                  Trading Assistant - Risk Manager |
//|                      Daily limits, profit targets, drawdown control |
//+------------------------------------------------------------------+
#property copyright "Trading Assistant"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Risk Manager Class                                               |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   // Daily limits
   bool     m_use_daily_loss_limit;
   double   m_daily_loss_limit_pct;
   double   m_daily_starting_balance;
   double   m_daily_loss_amount;

   bool     m_use_daily_profit_target;
   double   m_daily_profit_target_pct;
   double   m_daily_profit_amount;

   bool     m_use_max_trades_limit;
   int      m_max_trades_per_day;
   int      m_trades_today;

   // Weekly limits
   bool     m_use_weekly_loss_limit;
   double   m_weekly_loss_limit_pct;
   double   m_weekly_starting_balance;

   // Drawdown control
   bool     m_use_drawdown_limit;
   double   m_max_drawdown_pct;
   double   m_peak_balance;

   // Trade quality
   bool     m_use_consecutive_loss_limit;
   int      m_max_consecutive_losses;
   int      m_current_consecutive_losses;

   // Reset tracking
   datetime m_last_reset_day;
   datetime m_last_reset_week;

   // Status
   bool     m_trading_allowed;
   string   m_block_reason;

public:
   CRiskManager();
   ~CRiskManager();

   // Settings
   void SetDailyLossLimit(bool enabled, double loss_pct);
   void SetDailyProfitTarget(bool enabled, double profit_pct);
   void SetMaxTradesPerDay(bool enabled, int max_trades);
   void SetWeeklyLossLimit(bool enabled, double loss_pct);
   void SetDrawdownLimit(bool enabled, double max_drawdown_pct);
   void SetConsecutiveLossLimit(bool enabled, int max_losses);

   // Update
   void Update();
   void OnTradeClose(bool was_profitable, double profit);
   void OnNewTrade();

   // Status
   bool IsTradingAllowed() { return m_trading_allowed; }
   string GetBlockReason() { return m_block_reason; }

   // Statistics
   double GetDailyPnL();
   double GetWeeklyPnL();
   double GetCurrentDrawdown();
   int GetTradesTo day() { return m_trades_today; }
   int GetConsecutiveLosses() { return m_current_consecutive_losses; }

   // Reset
   void ResetDaily();
   void ResetWeekly();
   void ForceReset();

private:
   void CheckDailyReset();
   void CheckWeeklyReset();
   void UpdateTradingStatus();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager()
{
   m_use_daily_loss_limit = false;
   m_daily_loss_limit_pct = 2.0;
   m_daily_starting_balance = 0;
   m_daily_loss_amount = 0;

   m_use_daily_profit_target = false;
   m_daily_profit_target_pct = 5.0;
   m_daily_profit_amount = 0;

   m_use_max_trades_limit = false;
   m_max_trades_per_day = 10;
   m_trades_today = 0;

   m_use_weekly_loss_limit = false;
   m_weekly_loss_limit_pct = 5.0;
   m_weekly_starting_balance = 0;

   m_use_drawdown_limit = false;
   m_max_drawdown_pct = 10.0;
   m_peak_balance = AccountInfoDouble(ACCOUNT_BALANCE);

   m_use_consecutive_loss_limit = false;
   m_max_consecutive_losses = 3;
   m_current_consecutive_losses = 0;

   m_last_reset_day = 0;
   m_last_reset_week = 0;

   m_trading_allowed = true;
   m_block_reason = "";

   ResetDaily();
   ResetWeekly();
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager()
{
}

//+------------------------------------------------------------------+
//| Set daily loss limit                                             |
//+------------------------------------------------------------------+
void CRiskManager::SetDailyLossLimit(bool enabled, double loss_pct)
{
   m_use_daily_loss_limit = enabled;
   m_daily_loss_limit_pct = loss_pct;
}

//+------------------------------------------------------------------+
//| Set daily profit target                                          |
//+------------------------------------------------------------------+
void CRiskManager::SetDailyProfitTarget(bool enabled, double profit_pct)
{
   m_use_daily_profit_target = enabled;
   m_daily_profit_target_pct = profit_pct;
}

//+------------------------------------------------------------------+
//| Set max trades per day                                           |
//+------------------------------------------------------------------+
void CRiskManager::SetMaxTradesPerDay(bool enabled, int max_trades)
{
   m_use_max_trades_limit = enabled;
   m_max_trades_per_day = max_trades;
}

//+------------------------------------------------------------------+
//| Set weekly loss limit                                            |
//+------------------------------------------------------------------+
void CRiskManager::SetWeeklyLossLimit(bool enabled, double loss_pct)
{
   m_use_weekly_loss_limit = enabled;
   m_weekly_loss_limit_pct = loss_pct;
}

//+------------------------------------------------------------------+
//| Set drawdown limit                                               |
//+------------------------------------------------------------------+
void CRiskManager::SetDrawdownLimit(bool enabled, double max_drawdown_pct)
{
   m_use_drawdown_limit = enabled;
   m_max_drawdown_pct = max_drawdown_pct;
}

//+------------------------------------------------------------------+
//| Set consecutive loss limit                                       |
//+------------------------------------------------------------------+
void CRiskManager::SetConsecutiveLossLimit(bool enabled, int max_losses)
{
   m_use_consecutive_loss_limit = enabled;
   m_max_consecutive_losses = max_losses;
}

//+------------------------------------------------------------------+
//| Update risk manager                                              |
//+------------------------------------------------------------------+
void CRiskManager::Update()
{
   CheckDailyReset();
   CheckWeeklyReset();
   UpdateTradingStatus();
}

//+------------------------------------------------------------------+
//| On trade close                                                    |
//+------------------------------------------------------------------+
void CRiskManager::OnTradeClose(bool was_profitable, double profit)
{
   m_daily_profit_amount += profit;

   if(was_profitable)
      m_current_consecutive_losses = 0;
   else
   {
      m_current_consecutive_losses++;
      m_daily_loss_amount += MathAbs(profit);
   }

   // Update peak balance
   double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(current_balance > m_peak_balance)
      m_peak_balance = current_balance;

   UpdateTradingStatus();
}

//+------------------------------------------------------------------+
//| On new trade opened                                              |
//+------------------------------------------------------------------+
void CRiskManager::OnNewTrade()
{
   m_trades_today++;
   UpdateTradingStatus();
}

//+------------------------------------------------------------------+
//| Get daily P&L                                                     |
//+------------------------------------------------------------------+
double CRiskManager::GetDailyPnL()
{
   double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   return current_balance - m_daily_starting_balance;
}

//+------------------------------------------------------------------+
//| Get weekly P&L                                                    |
//+------------------------------------------------------------------+
double CRiskManager::GetWeeklyPnL()
{
   double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   return current_balance - m_weekly_starting_balance;
}

//+------------------------------------------------------------------+
//| Get current drawdown                                             |
//+------------------------------------------------------------------+
double CRiskManager::GetCurrentDrawdown()
{
   double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double drawdown = m_peak_balance - current_balance;
   return (drawdown / m_peak_balance) * 100.0;
}

//+------------------------------------------------------------------+
//| Reset daily statistics                                           |
//+------------------------------------------------------------------+
void CRiskManager::ResetDaily()
{
   m_daily_starting_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   m_daily_loss_amount = 0;
   m_daily_profit_amount = 0;
   m_trades_today = 0;
   m_last_reset_day = TimeCurrent();

   m_trading_allowed = true;
   m_block_reason = "";

   Print("Daily risk limits reset. Starting balance: ", m_daily_starting_balance);
}

//+------------------------------------------------------------------+
//| Reset weekly statistics                                          |
//+------------------------------------------------------------------+
void CRiskManager::ResetWeekly()
{
   m_weekly_starting_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   m_last_reset_week = TimeCurrent();

   Print("Weekly risk limits reset. Starting balance: ", m_weekly_starting_balance);
}

//+------------------------------------------------------------------+
//| Force reset all limits                                           |
//+------------------------------------------------------------------+
void CRiskManager::ForceReset()
{
   ResetDaily();
   ResetWeekly();
   m_current_consecutive_losses = 0;
   m_peak_balance = AccountInfoDouble(ACCOUNT_BALANCE);
}

//+------------------------------------------------------------------+
//| Check if daily reset is needed                                   |
//+------------------------------------------------------------------+
void CRiskManager::CheckDailyReset()
{
   MqlDateTime current_time, last_reset;
   TimeToStruct(TimeCurrent(), current_time);
   TimeToStruct(m_last_reset_day, last_reset);

   if(current_time.day != last_reset.day)
      ResetDaily();
}

//+------------------------------------------------------------------+
//| Check if weekly reset is needed                                  |
//+------------------------------------------------------------------+
void CRiskManager::CheckWeeklyReset()
{
   MqlDateTime current_time, last_reset;
   TimeToStruct(TimeCurrent(), current_time);
   TimeToStruct(m_last_reset_week, last_reset);

   // Reset on Monday
   if(current_time.day_of_week == 1 && last_reset.day_of_week != 1)
      ResetWeekly();
}

//+------------------------------------------------------------------+
//| Update trading status                                            |
//+------------------------------------------------------------------+
void CRiskManager::UpdateTradingStatus()
{
   m_trading_allowed = true;
   m_block_reason = "";

   // Check daily loss limit
   if(m_use_daily_loss_limit)
   {
      double daily_pnl = GetDailyPnL();
      double loss_limit = m_daily_starting_balance * (m_daily_loss_limit_pct / 100.0);

      if(daily_pnl <= -loss_limit)
      {
         m_trading_allowed = false;
         m_block_reason = "Daily loss limit reached (" + DoubleToString(m_daily_loss_limit_pct, 1) + "%)";
         return;
      }
   }

   // Check daily profit target
   if(m_use_daily_profit_target)
   {
      double daily_pnl = GetDailyPnL();
      double profit_target = m_daily_starting_balance * (m_daily_profit_target_pct / 100.0);

      if(daily_pnl >= profit_target)
      {
         m_trading_allowed = false;
         m_block_reason = "Daily profit target reached (" + DoubleToString(m_daily_profit_target_pct, 1) + "%)";
         return;
      }
   }

   // Check max trades per day
   if(m_use_max_trades_limit && m_trades_today >= m_max_trades_per_day)
   {
      m_trading_allowed = false;
      m_block_reason = "Max trades per day reached (" + IntegerToString(m_max_trades_per_day) + ")";
      return;
   }

   // Check weekly loss limit
   if(m_use_weekly_loss_limit)
   {
      double weekly_pnl = GetWeeklyPnL();
      double loss_limit = m_weekly_starting_balance * (m_weekly_loss_limit_pct / 100.0);

      if(weekly_pnl <= -loss_limit)
      {
         m_trading_allowed = false;
         m_block_reason = "Weekly loss limit reached (" + DoubleToString(m_weekly_loss_limit_pct, 1) + "%)";
         return;
      }
   }

   // Check drawdown limit
   if(m_use_drawdown_limit)
   {
      double current_dd = GetCurrentDrawdown();
      if(current_dd >= m_max_drawdown_pct)
      {
         m_trading_allowed = false;
         m_block_reason = "Max drawdown reached (" + DoubleToString(m_max_drawdown_pct, 1) + "%)";
         return;
      }
   }

   // Check consecutive losses
   if(m_use_consecutive_loss_limit && m_current_consecutive_losses >= m_max_consecutive_losses)
   {
      m_trading_allowed = false;
      m_block_reason = "Max consecutive losses reached (" + IntegerToString(m_max_consecutive_losses) + ")";
      return;
   }
}
//+------------------------------------------------------------------+
