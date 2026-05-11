//+------------------------------------------------------------------+
//|                                        PositionSizing.mqh        |
//|                          XAUUSD Scaling Calculator System        |
//|                                    From $17 to $40,000 Journey   |
//+------------------------------------------------------------------+
#property copyright "Trading Assistant 2026"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Position Sizing Class                                            |
//+------------------------------------------------------------------+
class CPositionSizing
{
private:
   double   m_current_balance;
   double   m_base_risk_percent;      // Normal risk (5-10%)
   double   m_aggressive_risk_percent; // Aggressive risk (30%)
   double   m_base_reward_percent;    // Normal reward (15-30%)
   double   m_aggressive_reward_percent; // Aggressive reward (70%+)

   double   m_contract_size;          // XAUUSD = 100
   double   m_recommended_lot;
   double   m_current_risk_pct;
   double   m_current_reward_pct;
   double   m_rr_ratio;

   bool     m_aggressive_mode;

   // Account milestones
   double   m_target_balance;         // $40,000
   double   m_starting_balance;       // $17

public:
   CPositionSizing();
   ~CPositionSizing();

   // Configuration
   void SetBalance(double balance);
   void SetRiskParameters(double base_risk, double aggressive_risk);
   void SetRewardParameters(double base_reward, double aggressive_reward);
   void SetContractSize(double contract_size);
   void SetAggressiveMode(bool aggressive);

   // Calculation
   void CalculateLotSize(double sl_distance_points);
   double GetRecommendedLot() { return m_recommended_lot; }
   double GetCurrentRiskPercent() { return m_current_risk_pct; }
   double GetCurrentRewardPercent() { return m_current_reward_pct; }
   double GetRRRatio() { return m_rr_ratio; }

   // Scaling information
   string GetScalingStatus();
   double GetProgressToTarget();
   int GetEstimatedTradesRemaining();

private:
   double CalculateRiskAmount();
   double DetermineOptimalLot(double risk_amount, double sl_distance);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CPositionSizing::CPositionSizing()
{
   m_current_balance = 17.0;
   m_base_risk_percent = 5.0;
   m_aggressive_risk_percent = 30.0;
   m_base_reward_percent = 15.0;       // 1:3 ratio
   m_aggressive_reward_percent = 70.0;  // Aggressive target

   m_contract_size = 100.0;  // XAUUSD
   m_recommended_lot = 0.01;
   m_current_risk_pct = m_base_risk_percent;
   m_current_reward_pct = m_base_reward_percent;
   m_rr_ratio = 3.0;

   m_aggressive_mode = false;

   m_target_balance = 40000.0;
   m_starting_balance = 17.0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CPositionSizing::~CPositionSizing()
{
}

//+------------------------------------------------------------------+
//| Set current balance                                              |
//+------------------------------------------------------------------+
void CPositionSizing::SetBalance(double balance)
{
   m_current_balance = balance;
}

//+------------------------------------------------------------------+
//| Set risk parameters                                              |
//+------------------------------------------------------------------+
void CPositionSizing::SetRiskParameters(double base_risk, double aggressive_risk)
{
   m_base_risk_percent = base_risk;
   m_aggressive_risk_percent = aggressive_risk;
}

//+------------------------------------------------------------------+
//| Set reward parameters                                            |
//+------------------------------------------------------------------+
void CPositionSizing::SetRewardParameters(double base_reward, double aggressive_reward)
{
   m_base_reward_percent = base_reward;
   m_aggressive_reward_percent = aggressive_reward;
}

//+------------------------------------------------------------------+
//| Set contract size                                                |
//+------------------------------------------------------------------+
void CPositionSizing::SetContractSize(double contract_size)
{
   m_contract_size = contract_size;
}

//+------------------------------------------------------------------+
//| Set aggressive mode                                              |
//+------------------------------------------------------------------+
void CPositionSizing::SetAggressiveMode(bool aggressive)
{
   m_aggressive_mode = aggressive;

   if(aggressive)
   {
      m_current_risk_pct = m_aggressive_risk_percent;
      m_current_reward_pct = m_aggressive_reward_percent;
      m_rr_ratio = m_aggressive_reward_percent / m_aggressive_risk_percent;
   }
   else
   {
      m_current_risk_pct = m_base_risk_percent;
      m_current_reward_pct = m_base_reward_percent;
      m_rr_ratio = m_base_reward_percent / m_base_risk_percent;
   }
}

//+------------------------------------------------------------------+
//| Calculate recommended lot size                                   |
//+------------------------------------------------------------------+
void CPositionSizing::CalculateLotSize(double sl_distance_points)
{
   double risk_amount = CalculateRiskAmount();
   m_recommended_lot = DetermineOptimalLot(risk_amount, sl_distance_points);
}

//+------------------------------------------------------------------+
//| Calculate risk amount in dollars                                 |
//+------------------------------------------------------------------+
double CPositionSizing::CalculateRiskAmount()
{
   return m_current_balance * (m_current_risk_pct / 100.0);
}

//+------------------------------------------------------------------+
//| Determine optimal lot size                                       |
//+------------------------------------------------------------------+
double CPositionSizing::DetermineOptimalLot(double risk_amount, double sl_distance)
{
   if(sl_distance <= 0)
      return 0.01;  // Minimum lot

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   // For XAUUSD: 1 lot = 100 oz, 1 pip = $1 per 0.01 lot typically
   // Formula: Lot Size = Risk Amount / (SL in points × Point Value per Lot)

   double point_value = tick_value;  // Value of 1 point for 1 lot
   double sl_value_per_lot = sl_distance * point * point_value / point;

   double calculated_lot = risk_amount / sl_value_per_lot;

   // Normalize lot size
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   calculated_lot = MathMax(calculated_lot, min_lot);
   calculated_lot = MathMin(calculated_lot, max_lot);
   calculated_lot = MathFloor(calculated_lot / lot_step) * lot_step;

   return calculated_lot;
}

//+------------------------------------------------------------------+
//| Get scaling status message                                       |
//+------------------------------------------------------------------+
string CPositionSizing::GetScalingStatus()
{
   double progress = GetProgressToTarget();

   if(m_current_balance < 50)
      return "Micro Stage - Building Foundation";
   else if(m_current_balance < 200)
      return "Mini Stage - Growing Capital";
   else if(m_current_balance < 1000)
      return "Standard Entry - Accelerating";
   else if(m_current_balance < 10000)
      return "Advanced Stage - Scaling Up";
   else if(m_current_balance < m_target_balance)
      return "Professional Stage - Near Target";
   else
      return "TARGET REACHED!";
}

//+------------------------------------------------------------------+
//| Get progress to target                                           |
//+------------------------------------------------------------------+
double CPositionSizing::GetProgressToTarget()
{
   if(m_target_balance <= m_starting_balance)
      return 100.0;

   double progress = ((m_current_balance - m_starting_balance) / (m_target_balance - m_starting_balance)) * 100.0;
   return MathMin(progress, 100.0);
}

//+------------------------------------------------------------------+
//| Estimate trades remaining to target                              |
//+------------------------------------------------------------------+
int CPositionSizing::GetEstimatedTradesRemaining()
{
   if(m_current_balance >= m_target_balance)
      return 0;

   // Estimate based on average growth per trade
   // Assuming 1:3 R:R and 5% risk = 15% gain per winning trade
   // With 50% win rate = ~7.5% average growth per trade
   double avg_growth_per_trade = m_current_risk_pct * m_rr_ratio * 0.5;  // 50% win rate assumption

   if(avg_growth_per_trade <= 0)
      return 999;

   double remaining_growth = ((m_target_balance / m_current_balance) - 1) * 100;
   int estimated_trades = (int)MathCeil(remaining_growth / avg_growth_per_trade);

   return estimated_trades;
}
//+------------------------------------------------------------------+
