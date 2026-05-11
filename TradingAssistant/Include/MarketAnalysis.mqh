//+------------------------------------------------------------------+
//|                                              MarketAnalysis.mqh |
//|                          Trading Assistant - Market Analysis |
//|                    Trend detection, volatility, SR levels |
//+------------------------------------------------------------------+
#property copyright "Trading Assistant"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Market Analysis Class                                            |
//+------------------------------------------------------------------+
class CMarketAnalysis
{
private:
   // Indicator handles
   int      m_ema_fast_handle;
   int      m_ema_slow_handle;
   int      m_atr_handle;

   // Current analysis
   string   m_current_trend;          // BULLISH, BEARISH, SIDEWAYS
   string   m_volatility_level;       // LOW, MEDIUM, HIGH
   double   m_support_level;
   double   m_resistance_level;
   double   m_current_atr;

   // Settings
   int      m_ema_fast_period;
   int      m_ema_slow_period;
   int      m_atr_period;

public:
   CMarketAnalysis();
   ~CMarketAnalysis();

   bool Initialize(string symbol, ENUM_TIMEFRAMES timeframe);
   void Update();

   // Getters
   string GetTrend() { return m_current_trend; }
   string GetVolatility() { return m_volatility_level; }
   double GetSupport() { return m_support_level; }
   double GetResistance() { return m_resistance_level; }
   double GetATR() { return m_current_atr; }

private:
   void AnalyzeTrend();
   void AnalyzeVolatility();
   void FindSupportResistance();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CMarketAnalysis::CMarketAnalysis()
{
   m_ema_fast_handle = INVALID_HANDLE;
   m_ema_slow_handle = INVALID_HANDLE;
   m_atr_handle = INVALID_HANDLE;

   m_current_trend = "SIDEWAYS";
   m_volatility_level = "MEDIUM";
   m_support_level = 0;
   m_resistance_level = 0;
   m_current_atr = 0;

   m_ema_fast_period = 20;
   m_ema_slow_period = 50;
   m_atr_period = 14;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CMarketAnalysis::~CMarketAnalysis()
{
   if(m_ema_fast_handle != INVALID_HANDLE)
      IndicatorRelease(m_ema_fast_handle);
   if(m_ema_slow_handle != INVALID_HANDLE)
      IndicatorRelease(m_ema_slow_handle);
   if(m_atr_handle != INVALID_HANDLE)
      IndicatorRelease(m_atr_handle);
}

//+------------------------------------------------------------------+
//| Initialize                                                        |
//+------------------------------------------------------------------+
bool CMarketAnalysis::Initialize(string symbol, ENUM_TIMEFRAMES timeframe)
{
   m_ema_fast_handle = iMA(symbol, timeframe, m_ema_fast_period, 0, MODE_EMA, PRICE_CLOSE);
   m_ema_slow_handle = iMA(symbol, timeframe, m_ema_slow_period, 0, MODE_EMA, PRICE_CLOSE);
   m_atr_handle = iATR(symbol, timeframe, m_atr_period);

   if(m_ema_fast_handle == INVALID_HANDLE ||
      m_ema_slow_handle == INVALID_HANDLE ||
      m_atr_handle == INVALID_HANDLE)
   {
      Print("Failed to create market analysis indicators");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Update analysis                                                   |
//+------------------------------------------------------------------+
void CMarketAnalysis::Update()
{
   AnalyzeTrend();
   AnalyzeVolatility();
   FindSupportResistance();
}

//+------------------------------------------------------------------+
//| Analyze trend direction                                          |
//+------------------------------------------------------------------+
void CMarketAnalysis::AnalyzeTrend()
{
   double ema_fast[], ema_slow[];
   ArraySetAsSeries(ema_fast, true);
   ArraySetAsSeries(ema_slow, true);

   if(CopyBuffer(m_ema_fast_handle, 0, 0, 3, ema_fast) <= 0 ||
      CopyBuffer(m_ema_slow_handle, 0, 0, 3, ema_slow) <= 0)
   {
      m_current_trend = "UNKNOWN";
      return;
   }

   // Check EMA alignment
   if(ema_fast[0] > ema_slow[0] && ema_fast[1] > ema_slow[1])
   {
      m_current_trend = "BULLISH";
   }
   else if(ema_fast[0] < ema_slow[0] && ema_fast[1] < ema_slow[1])
   {
      m_current_trend = "BEARISH";
   }
   else
   {
      m_current_trend = "SIDEWAYS";
   }
}

//+------------------------------------------------------------------+
//| Analyze volatility level                                         |
//+------------------------------------------------------------------+
void CMarketAnalysis::AnalyzeVolatility()
{
   double atr[];
   ArraySetAsSeries(atr, true);

   if(CopyBuffer(m_atr_handle, 0, 0, 20, atr) <= 0)
   {
      m_volatility_level = "UNKNOWN";
      return;
   }

   m_current_atr = atr[0];

   // Calculate average ATR
   double avg_atr = 0;
   for(int i = 0; i < 20; i++)
      avg_atr += atr[i];
   avg_atr /= 20;

   // Classify volatility
   if(m_current_atr > avg_atr * 1.5)
      m_volatility_level = "HIGH";
   else if(m_current_atr < avg_atr * 0.7)
      m_volatility_level = "LOW";
   else
      m_volatility_level = "MEDIUM";
}

//+------------------------------------------------------------------+
//| Find support and resistance levels                               |
//+------------------------------------------------------------------+
void CMarketAnalysis::FindSupportResistance()
{
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);

   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, 50, highs) <= 0 ||
      CopyLow(_Symbol, PERIOD_CURRENT, 0, 50, lows) <= 0)
      return;

   // Find recent swing high (resistance)
   m_resistance_level = highs[ArrayMaximum(highs, 0, 20)];

   // Find recent swing low (support)
   m_support_level = lows[ArrayMinimum(lows, 0, 20)];
}
//+------------------------------------------------------------------+
