//+------------------------------------------------------------------+
//|                                           SignalDetector.mqh     |
//|                             RSI, Stochastic, ADX Signal Detection|
//|                                    High-Quality Setup Identifier |
//+------------------------------------------------------------------+
#property copyright "Trading Assistant 2026"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Signal Detection Class                                           |
//+------------------------------------------------------------------+
class CSignalDetector
{
private:
   // Indicator handles
   int      m_rsi_handle;
   int      m_stoch_handle;
   int      m_adx_handle;
   int      m_atr_handle;

   // Indicator parameters
   int      m_rsi_period;
   int      m_stoch_k;
   int      m_stoch_d;
   int      m_stoch_slowing;
   int      m_adx_period;
   int      m_atr_period;

   // Threshold parameters
   double   m_rsi_oversold;
   double   m_rsi_overbought;
   double   m_stoch_oversold;
   double   m_stoch_overbought;
   double   m_adx_minimum;

   // Signal cooldown
   datetime m_last_signal_time;
   int      m_cooldown_minutes;

   // Signal frequency control
   int      m_signals_today;
   int      m_signals_this_week;
   datetime m_last_day_reset;
   datetime m_last_week_reset;
   int      m_max_signals_per_day;

   // Signal quality tracking
   int      m_current_signal_strength;
   string   m_current_signal_type;
   bool     m_signal_active;

public:
   CSignalDetector();
   ~CSignalDetector();

   // Initialization
   bool Init(string symbol, ENUM_TIMEFRAMES timeframe);
   void Deinit();

   // Configuration
   void SetRSIParams(int period, double oversold, double overbought);
   void SetStochParams(int k, int d, int slowing, double oversold, double overbought);
   void SetADXParams(int period, double minimum);
   void SetFrequencyControl(int max_signals_day, int cooldown_minutes);

   // Signal detection
   bool ScanForSignal();
   int  GetSignalStrength();
   string GetSignalType();
   bool IsSignalActive();
   string GetNextSignalTime();

   // Signal statistics
   int  GetSignalsToday() { return m_signals_today; }
   int  GetSignalsThisWeek() { return m_signals_this_week; }

private:
   // Analysis methods
   bool CheckRSICondition(double &rsi_value);
   bool CheckStochasticCondition(double &stoch_main, double &stoch_signal);
   bool CheckADXCondition(double &adx_value);
   bool CheckMarketStructure();
   int  CalculateSignalStrength(double rsi, double stoch, double adx, bool structure_ok);

   // Helper methods
   bool IsInCooldown();
   void UpdateDailyReset();
   void UpdateWeeklyReset();
   bool CanGenerateSignal();
   void RegisterSignal();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CSignalDetector::CSignalDetector()
{
   m_rsi_handle = INVALID_HANDLE;
   m_stoch_handle = INVALID_HANDLE;
   m_adx_handle = INVALID_HANDLE;
   m_atr_handle = INVALID_HANDLE;

   // Default parameters
   m_rsi_period = 14;
   m_rsi_oversold = 30.0;
   m_rsi_overbought = 70.0;

   m_stoch_k = 5;
   m_stoch_d = 3;
   m_stoch_slowing = 3;
   m_stoch_oversold = 20.0;
   m_stoch_overbought = 80.0;

   m_adx_period = 14;
   m_adx_minimum = 20.0;

   m_atr_period = 14;

   m_last_signal_time = 0;
   m_cooldown_minutes = 240; // 4 hours cooldown

   m_signals_today = 0;
   m_signals_this_week = 0;
   m_max_signals_per_day = 1; // Maximum 1 signal per day = 4-7 per week
   m_last_day_reset = TimeCurrent();
   m_last_week_reset = TimeCurrent();

   m_current_signal_strength = 0;
   m_current_signal_type = "NONE";
   m_signal_active = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CSignalDetector::~CSignalDetector()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Initialize indicators                                            |
//+------------------------------------------------------------------+
bool CSignalDetector::Init(string symbol, ENUM_TIMEFRAMES timeframe)
{
   // Create RSI indicator
   m_rsi_handle = iRSI(symbol, timeframe, m_rsi_period, PRICE_CLOSE);
   if(m_rsi_handle == INVALID_HANDLE)
   {
      Print("Error creating RSI indicator: ", GetLastError());
      return false;
   }

   // Create Stochastic indicator
   m_stoch_handle = iStochastic(symbol, timeframe, m_stoch_k, m_stoch_d, m_stoch_slowing, MODE_SMA, STO_LOWHIGH);
   if(m_stoch_handle == INVALID_HANDLE)
   {
      Print("Error creating Stochastic indicator: ", GetLastError());
      return false;
   }

   // Create ADX indicator
   m_adx_handle = iADX(symbol, timeframe, m_adx_period);
   if(m_adx_handle == INVALID_HANDLE)
   {
      Print("Error creating ADX indicator: ", GetLastError());
      return false;
   }

   // Create ATR indicator for volatility measurement
   m_atr_handle = iATR(symbol, timeframe, m_atr_period);
   if(m_atr_handle == INVALID_HANDLE)
   {
      Print("Error creating ATR indicator: ", GetLastError());
      return false;
   }

   Print("Signal Detector initialized successfully");
   return true;
}

//+------------------------------------------------------------------+
//| Cleanup                                                           |
//+------------------------------------------------------------------+
void CSignalDetector::Deinit()
{
   if(m_rsi_handle != INVALID_HANDLE)
      IndicatorRelease(m_rsi_handle);
   if(m_stoch_handle != INVALID_HANDLE)
      IndicatorRelease(m_stoch_handle);
   if(m_adx_handle != INVALID_HANDLE)
      IndicatorRelease(m_adx_handle);
   if(m_atr_handle != INVALID_HANDLE)
      IndicatorRelease(m_atr_handle);
}

//+------------------------------------------------------------------+
//| Set RSI parameters                                               |
//+------------------------------------------------------------------+
void CSignalDetector::SetRSIParams(int period, double oversold, double overbought)
{
   m_rsi_period = period;
   m_rsi_oversold = oversold;
   m_rsi_overbought = overbought;
}

//+------------------------------------------------------------------+
//| Set Stochastic parameters                                        |
//+------------------------------------------------------------------+
void CSignalDetector::SetStochParams(int k, int d, int slowing, double oversold, double overbought)
{
   m_stoch_k = k;
   m_stoch_d = d;
   m_stoch_slowing = slowing;
   m_stoch_oversold = oversold;
   m_stoch_overbought = overbought;
}

//+------------------------------------------------------------------+
//| Set ADX parameters                                               |
//+------------------------------------------------------------------+
void CSignalDetector::SetADXParams(int period, double minimum)
{
   m_adx_period = period;
   m_adx_minimum = minimum;
}

//+------------------------------------------------------------------+
//| Set frequency control                                            |
//+------------------------------------------------------------------+
void CSignalDetector::SetFrequencyControl(int max_signals_day, int cooldown_minutes)
{
   m_max_signals_per_day = max_signals_day;
   m_cooldown_minutes = cooldown_minutes;
}

//+------------------------------------------------------------------+
//| Scan for trading signal                                          |
//+------------------------------------------------------------------+
bool CSignalDetector::ScanForSignal()
{
   UpdateDailyReset();
   UpdateWeeklyReset();

   // Always get indicator values and calculate strength (for dashboard display)
   double rsi_value = 0;
   double stoch_main = 0, stoch_signal = 0;
   double adx_value = 0;

   // Check each condition
   bool rsi_ok = CheckRSICondition(rsi_value);
   bool stoch_ok = CheckStochasticCondition(stoch_main, stoch_signal);
   bool adx_ok = CheckADXCondition(adx_value);
   bool structure_ok = CheckMarketStructure();

   // Always calculate signal strength (even if in cooldown)
   m_current_signal_strength = CalculateSignalStrength(rsi_value, stoch_main, adx_value, structure_ok);

   // Check if we can actually generate a signal alert
   if(!CanGenerateSignal())
   {
      m_signal_active = false;
      // Keep strength displayed but don't trigger signal
      return false;
   }

   // A valid signal requires ALL conditions to be met
   if(rsi_ok && stoch_ok && adx_ok && structure_ok && m_current_signal_strength >= 70)
   {
      m_signal_active = true;

      // Determine signal type
      if(rsi_value < m_rsi_oversold)
         m_current_signal_type = "BUY - Reversal Dip";
      else if(rsi_value > m_rsi_overbought)
         m_current_signal_type = "SELL - Reversal Peak";
      else if(rsi_value < 50)
         m_current_signal_type = "BUY - Continuation Dip";
      else
         m_current_signal_type = "SELL - Continuation Peak";

      RegisterSignal();
      return true;
   }

   m_signal_active = false;
   return false;
}

//+------------------------------------------------------------------+
//| Check RSI condition                                              |
//+------------------------------------------------------------------+
bool CSignalDetector::CheckRSICondition(double &rsi_value)
{
   double rsi[];
   ArraySetAsSeries(rsi, true);

   if(CopyBuffer(m_rsi_handle, 0, 0, 3, rsi) < 3)
      return false;

   rsi_value = rsi[0];

   // RSI in extreme zone (oversold for buys, overbought for sells)
   // OR RSI showing pullback in strong trend (30-50 or 50-70 range)
   bool in_extreme = (rsi_value < m_rsi_oversold) || (rsi_value > m_rsi_overbought);
   bool in_pullback_zone = (rsi_value > 30 && rsi_value < 70);

   return (in_extreme || in_pullback_zone);
}

//+------------------------------------------------------------------+
//| Check Stochastic condition                                       |
//+------------------------------------------------------------------+
bool CSignalDetector::CheckStochasticCondition(double &stoch_main, double &stoch_signal)
{
   double main_line[], signal_line[];
   ArraySetAsSeries(main_line, true);
   ArraySetAsSeries(signal_line, true);

   if(CopyBuffer(m_stoch_handle, 0, 0, 3, main_line) < 3)
      return false;
   if(CopyBuffer(m_stoch_handle, 1, 0, 3, signal_line) < 3)
      return false;

   stoch_main = main_line[0];
   stoch_signal = signal_line[0];

   // Stochastic confirming timing (oversold for buys, overbought for sells, or crossover)
   bool in_oversold = (stoch_main < m_stoch_oversold);
   bool in_overbought = (stoch_main > m_stoch_overbought);
   bool bullish_cross = (main_line[1] < signal_line[1]) && (main_line[0] > signal_line[0]);
   bool bearish_cross = (main_line[1] > signal_line[1]) && (main_line[0] < signal_line[0]);

   return (in_oversold || in_overbought || bullish_cross || bearish_cross);
}

//+------------------------------------------------------------------+
//| Check ADX condition                                              |
//+------------------------------------------------------------------+
bool CSignalDetector::CheckADXCondition(double &adx_value)
{
   double adx[];
   ArraySetAsSeries(adx, true);

   if(CopyBuffer(m_adx_handle, 0, 0, 3, adx) < 3)
      return false;

   adx_value = adx[0];

   // ADX must be above minimum threshold (momentum building)
   // OR ADX is rising (trend strengthening)
   bool above_threshold = (adx_value > m_adx_minimum);
   bool rising = (adx[0] > adx[1]);

   return (above_threshold || (adx_value > m_adx_minimum * 0.8 && rising));
}

//+------------------------------------------------------------------+
//| Check market structure                                           |
//+------------------------------------------------------------------+
bool CSignalDetector::CheckMarketStructure()
{
   // Simplified market structure check
   // Looking for support/resistance zones using recent highs/lows

   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, 50, high) < 50)
      return false;
   if(CopyLow(_Symbol, PERIOD_CURRENT, 0, 50, low) < 50)
      return false;
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 50, close) < 50)
      return false;

   // Find recent swing high and low
   double swing_high = high[ArrayMaximum(high, 1, 20)];
   double swing_low = low[ArrayMinimum(low, 1, 20)];
   double current_price = close[0];

   // Check if price is near support (for buys) or resistance (for sells)
   double range = swing_high - swing_low;
   double support_zone = swing_low + range * 0.2;
   double resistance_zone = swing_high - range * 0.2;

   bool near_support = (current_price <= support_zone);
   bool near_resistance = (current_price >= resistance_zone);

   // Structure is valid if we're near key levels
   return (near_support || near_resistance || range > 0);
}

//+------------------------------------------------------------------+
//| Calculate signal strength (0-100)                                |
//+------------------------------------------------------------------+
int CSignalDetector::CalculateSignalStrength(double rsi, double stoch, double adx, bool structure_ok)
{
   int strength = 0;

   // RSI contribution (0-30 points)
   if(rsi < m_rsi_oversold || rsi > m_rsi_overbought)
      strength += 30; // Extreme zone
   else if(rsi < 50)
      strength += 15; // Pullback zone
   else
      strength += 10;

   // Stochastic contribution (0-25 points)
   if(stoch < m_stoch_oversold || stoch > m_stoch_overbought)
      strength += 25;
   else
      strength += 10;

   // ADX contribution (0-30 points)
   if(adx > m_adx_minimum * 1.5)
      strength += 30; // Strong momentum
   else if(adx > m_adx_minimum)
      strength += 20; // Adequate momentum
   else
      strength += 5;

   // Structure contribution (0-15 points)
   if(structure_ok)
      strength += 15;

   return MathMin(strength, 100);
}

//+------------------------------------------------------------------+
//| Check if in cooldown period                                      |
//+------------------------------------------------------------------+
bool CSignalDetector::IsInCooldown()
{
   if(m_last_signal_time == 0)
      return false;

   int elapsed_minutes = (int)((TimeCurrent() - m_last_signal_time) / 60);
   return (elapsed_minutes < m_cooldown_minutes);
}

//+------------------------------------------------------------------+
//| Update daily reset                                               |
//+------------------------------------------------------------------+
void CSignalDetector::UpdateDailyReset()
{
   MqlDateTime current_time, last_reset;
   TimeToStruct(TimeCurrent(), current_time);
   TimeToStruct(m_last_day_reset, last_reset);

   // Check if it's a new day
   if(current_time.day != last_reset.day)
   {
      m_signals_today = 0;
      m_last_day_reset = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Update weekly reset                                              |
//+------------------------------------------------------------------+
void CSignalDetector::UpdateWeeklyReset()
{
   MqlDateTime current_time, last_reset;
   TimeToStruct(TimeCurrent(), current_time);
   TimeToStruct(m_last_week_reset, last_reset);

   // Check if it's a new week (Monday reset)
   if(current_time.day_of_week == 1 && last_reset.day_of_week != 1)
   {
      m_signals_this_week = 0;
      m_last_week_reset = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Check if signal can be generated                                 |
//+------------------------------------------------------------------+
bool CSignalDetector::CanGenerateSignal()
{
   // Check cooldown
   if(IsInCooldown())
      return false;

   // Check daily limit
   if(m_signals_today >= m_max_signals_per_day)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Register a new signal                                            |
//+------------------------------------------------------------------+
void CSignalDetector::RegisterSignal()
{
   m_last_signal_time = TimeCurrent();
   m_signals_today++;
   m_signals_this_week++;
}

//+------------------------------------------------------------------+
//| Get current signal strength                                      |
//+------------------------------------------------------------------+
int CSignalDetector::GetSignalStrength()
{
   return m_current_signal_strength;
}

//+------------------------------------------------------------------+
//| Get signal type                                                   |
//+------------------------------------------------------------------+
string CSignalDetector::GetSignalType()
{
   return m_current_signal_type;
}

//+------------------------------------------------------------------+
//| Check if signal is active                                        |
//+------------------------------------------------------------------+
bool CSignalDetector::IsSignalActive()
{
   return m_signal_active;
}

//+------------------------------------------------------------------+
//| Get next signal time estimate                                    |
//+------------------------------------------------------------------+
string CSignalDetector::GetNextSignalTime()
{
   if(m_signals_today >= m_max_signals_per_day)
      return "Tomorrow";

   if(IsInCooldown())
   {
      int remaining = m_cooldown_minutes - (int)((TimeCurrent() - m_last_signal_time) / 60);
      return IntegerToString(remaining) + " min";
   }

   return "Scanning...";
}
//+------------------------------------------------------------------+
