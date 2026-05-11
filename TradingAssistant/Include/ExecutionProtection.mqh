//+------------------------------------------------------------------+
//|                                     ExecutionProtection.mqh      |
//|                          Spread and Slippage Protection System   |
//|                                         Execution Quality Monitor|
//+------------------------------------------------------------------+
#property copyright "Trading Assistant 2026"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Execution Protection Class                                       |
//+------------------------------------------------------------------+
class CExecutionProtection
{
private:
   double   m_max_spread_points;
   double   m_warning_spread_points;
   double   m_max_slippage_points;

   double   m_current_spread;
   int      m_spread_status;  // 0 = bad, 1 = warning, 2 = good
   string   m_exec_quality_message;

   // Spread monitoring
   datetime m_last_spread_warning;
   int      m_warning_cooldown_seconds;

   // Statistics
   double   m_avg_spread;
   int      m_spread_samples;

public:
   CExecutionProtection();
   ~CExecutionProtection();

   // Configuration
   void SetSpreadLimits(double max_spread, double warning_spread);
   void SetSlippageLimits(double max_slippage);

   // Monitoring
   void Update();
   bool IsSafeToTrade();
   bool IsSafeToModify();

   // Status getters
   double GetCurrentSpread() { return m_current_spread; }
   int GetSpreadStatus() { return m_spread_status; }
   string GetExecutionQuality() { return m_exec_quality_message; }
   double GetAverageSpread() { return m_avg_spread; }

   // Alerts
   void CheckAndAlert();

private:
   void UpdateSpreadStatus();
   void UpdateExecutionQuality();
   double CalculateSpread();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CExecutionProtection::CExecutionProtection()
{
   m_max_spread_points = 30.0;      // Maximum acceptable spread
   m_warning_spread_points = 20.0;  // Warning threshold
   m_max_slippage_points = 10.0;    // Maximum acceptable slippage

   m_current_spread = 0;
   m_spread_status = 2;  // Good by default
   m_exec_quality_message = "Monitoring...";

   m_last_spread_warning = 0;
   m_warning_cooldown_seconds = 300;  // 5 minutes

   m_avg_spread = 0;
   m_spread_samples = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CExecutionProtection::~CExecutionProtection()
{
}

//+------------------------------------------------------------------+
//| Set spread limits                                                |
//+------------------------------------------------------------------+
void CExecutionProtection::SetSpreadLimits(double max_spread, double warning_spread)
{
   m_max_spread_points = max_spread;
   m_warning_spread_points = warning_spread;
}

//+------------------------------------------------------------------+
//| Set slippage limits                                              |
//+------------------------------------------------------------------+
void CExecutionProtection::SetSlippageLimits(double max_slippage)
{
   m_max_slippage_points = max_slippage;
}

//+------------------------------------------------------------------+
//| Update execution protection status                               |
//+------------------------------------------------------------------+
void CExecutionProtection::Update()
{
   m_current_spread = CalculateSpread();

   // Update running average
   m_spread_samples++;
   m_avg_spread = ((m_avg_spread * (m_spread_samples - 1)) + m_current_spread) / m_spread_samples;

   // Limit samples to prevent overflow
   if(m_spread_samples > 1000)
   {
      m_spread_samples = 100;
      m_avg_spread = m_current_spread;
   }

   UpdateSpreadStatus();
   UpdateExecutionQuality();
   CheckAndAlert();
}

//+------------------------------------------------------------------+
//| Calculate current spread in points                               |
//+------------------------------------------------------------------+
double CExecutionProtection::CalculateSpread()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(point == 0)
      return 0;

   return (ask - bid) / point;
}

//+------------------------------------------------------------------+
//| Update spread status                                             |
//+------------------------------------------------------------------+
void CExecutionProtection::UpdateSpreadStatus()
{
   if(m_current_spread <= m_warning_spread_points)
      m_spread_status = 2;  // Good
   else if(m_current_spread <= m_max_spread_points)
      m_spread_status = 1;  // Warning
   else
      m_spread_status = 0;  // Bad - too high
}

//+------------------------------------------------------------------+
//| Update execution quality message                                 |
//+------------------------------------------------------------------+
void CExecutionProtection::UpdateExecutionQuality()
{
   if(m_spread_status == 2)
   {
      m_exec_quality_message = "✓ Excellent execution conditions";
   }
   else if(m_spread_status == 1)
   {
      m_exec_quality_message = "⚠ Caution: Spread elevated";
   }
   else
   {
      m_exec_quality_message = "✗ Warning: Spread too high - avoid trading";
   }
}

//+------------------------------------------------------------------+
//| Check if safe to open new trades                                 |
//+------------------------------------------------------------------+
bool CExecutionProtection::IsSafeToTrade()
{
   return (m_spread_status >= 1);  // Allow trading if not in bad status
}

//+------------------------------------------------------------------+
//| Check if safe to modify positions                                |
//+------------------------------------------------------------------+
bool CExecutionProtection::IsSafeToModify()
{
   return (m_spread_status >= 1);  // Allow modifications if not in bad status
}

//+------------------------------------------------------------------+
//| Check and send alerts                                            |
//+------------------------------------------------------------------+
void CExecutionProtection::CheckAndAlert()
{
   // Alert on high spread (with cooldown to avoid spam)
   if(m_spread_status == 0)
   {
      if(TimeCurrent() - m_last_spread_warning > m_warning_cooldown_seconds)
      {
         string alert_msg = StringFormat("HIGH SPREAD WARNING: Current spread %.1f pts exceeds maximum %.1f pts",
                                        m_current_spread, m_max_spread_points);
         Print(alert_msg);
         // Alert function would go here for push notifications
         m_last_spread_warning = TimeCurrent();
      }
   }
}
//+------------------------------------------------------------------+
