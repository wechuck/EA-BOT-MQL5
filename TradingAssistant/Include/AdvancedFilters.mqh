//+------------------------------------------------------------------+
//|                                             AdvancedFilters.mqh |
//|                                  Trading Assistant - Advanced Filters |
//|                      Volume, Multi-TF, Spread, News filtering |
//+------------------------------------------------------------------+
#property copyright "Trading Assistant"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Advanced Filters Class                                           |
//+------------------------------------------------------------------+
class CAdvancedFilters
{
private:
   // Filter settings
   bool     m_use_volume_filter;
   double   m_volume_multiplier;

   bool     m_use_mtf_filter;         // Multi-timeframe confirmation
   ENUM_TIMEFRAMES m_higher_tf;

   bool     m_use_spread_filter;
   double   m_max_spread_pips;

   bool     m_use_news_filter;
   int      m_news_minutes_before;
   int      m_news_minutes_after;

   bool     m_use_session_filter;
   int      m_session_start_hour;
   int      m_session_end_hour;

   // Handles
   int      m_volume_handle;

public:
   CAdvancedFilters();
   ~CAdvancedFilters();

   bool Initialize(string symbol, ENUM_TIMEFRAMES timeframe);

   // Set filters
   void SetVolumeFilter(bool enabled, double volume_multiplier);
   void SetMultiTimeframeFilter(bool enabled, ENUM_TIMEFRAMES higher_tf);
   void SetSpreadFilter(bool enabled, double max_spread_pips);
   void SetNewsFilter(bool enabled, int minutes_before, int minutes_after);
   void SetSessionFilter(bool enabled, int start_hour, int end_hour);

   // Check filters
   bool CheckVolumeCondition();
   bool CheckMultiTimeframeAlignment(string signal_type);
   bool CheckSpreadCondition();
   bool CheckNewsCondition();
   bool CheckSessionCondition();

   // Master filter check
   bool PassesAllFilters(string signal_type);

   // Get filter status
   string GetFilterStatus();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CAdvancedFilters::CAdvancedFilters()
{
   m_use_volume_filter = false;
   m_volume_multiplier = 1.5;

   m_use_mtf_filter = false;
   m_higher_tf = PERIOD_H1;

   m_use_spread_filter = false;
   m_max_spread_pips = 3.0;

   m_use_news_filter = false;
   m_news_minutes_before = 30;
   m_news_minutes_after = 30;

   m_use_session_filter = false;
   m_session_start_hour = 0;
   m_session_end_hour = 24;

   m_volume_handle = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CAdvancedFilters::~CAdvancedFilters()
{
   if(m_volume_handle != INVALID_HANDLE)
      IndicatorRelease(m_volume_handle);
}

//+------------------------------------------------------------------+
//| Initialize                                                        |
//+------------------------------------------------------------------+
bool CAdvancedFilters::Initialize(string symbol, ENUM_TIMEFRAMES timeframe)
{
   // Create volume indicator
   m_volume_handle = iVolumes(symbol, timeframe, VOLUME_TICK);

   if(m_volume_handle == INVALID_HANDLE)
   {
      Print("Failed to create volume indicator");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Set volume filter                                                |
//+------------------------------------------------------------------+
void CAdvancedFilters::SetVolumeFilter(bool enabled, double volume_multiplier)
{
   m_use_volume_filter = enabled;
   m_volume_multiplier = volume_multiplier;
}

//+------------------------------------------------------------------+
//| Set multi-timeframe filter                                       |
//+------------------------------------------------------------------+
void CAdvancedFilters::SetMultiTimeframeFilter(bool enabled, ENUM_TIMEFRAMES higher_tf)
{
   m_use_mtf_filter = enabled;
   m_higher_tf = higher_tf;
}

//+------------------------------------------------------------------+
//| Set spread filter                                                |
//+------------------------------------------------------------------+
void CAdvancedFilters::SetSpreadFilter(bool enabled, double max_spread_pips)
{
   m_use_spread_filter = enabled;
   m_max_spread_pips = max_spread_pips;
}

//+------------------------------------------------------------------+
//| Set news filter                                                  |
//+------------------------------------------------------------------+
void CAdvancedFilters::SetNewsFilter(bool enabled, int minutes_before, int minutes_after)
{
   m_use_news_filter = enabled;
   m_news_minutes_before = minutes_before;
   m_news_minutes_after = minutes_after;
}

//+------------------------------------------------------------------+
//| Set session filter                                               |
//+------------------------------------------------------------------+
void CAdvancedFilters::SetSessionFilter(bool enabled, int start_hour, int end_hour)
{
   m_use_session_filter = enabled;
   m_session_start_hour = start_hour;
   m_session_end_hour = end_hour;
}

//+------------------------------------------------------------------+
//| Check volume condition                                           |
//+------------------------------------------------------------------+
bool CAdvancedFilters::CheckVolumeCondition()
{
   if(!m_use_volume_filter)
      return true;

   if(m_volume_handle == INVALID_HANDLE)
      return true;

   double volumes[];
   ArraySetAsSeries(volumes, true);

   if(CopyBuffer(m_volume_handle, 0, 0, 20, volumes) <= 0)
      return true;

   // Calculate average volume
   double avg_volume = 0;
   for(int i = 1; i < 20; i++)
      avg_volume += volumes[i];
   avg_volume /= 19;

   // Current volume must be higher than average * multiplier
   if(volumes[0] >= avg_volume * m_volume_multiplier)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Check multi-timeframe alignment                                  |
//+------------------------------------------------------------------+
bool CAdvancedFilters::CheckMultiTimeframeAlignment(string signal_type)
{
   if(!m_use_mtf_filter)
      return true;

   // Get higher timeframe trend
   int rsi_handle = iRSI(_Symbol, m_higher_tf, 14, PRICE_CLOSE);
   if(rsi_handle == INVALID_HANDLE)
      return true;

   double rsi[];
   ArraySetAsSeries(rsi, true);

   if(CopyBuffer(rsi_handle, 0, 0, 1, rsi) <= 0)
   {
      IndicatorRelease(rsi_handle);
      return true;
   }

   IndicatorRelease(rsi_handle);

   // BUY signals need higher TF RSI > 50, SELL signals need < 50
   if(signal_type == "BUY" && rsi[0] > 50)
      return true;
   if(signal_type == "SELL" && rsi[0] < 50)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Check spread condition                                           |
//+------------------------------------------------------------------+
bool CAdvancedFilters::CheckSpreadCondition()
{
   if(!m_use_spread_filter)
      return true;

   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * SymbolInfoDouble(_Symbol, SYMBOL_POINT) / 0.0001;

   if(spread <= m_max_spread_pips)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Check news condition (simplified - needs economic calendar)      |
//+------------------------------------------------------------------+
bool CAdvancedFilters::CheckNewsCondition()
{
   if(!m_use_news_filter)
      return true;

   // Simplified implementation
   // In production, you would check economic calendar for high-impact news
   // For now, avoid first 30 minutes of London and NY sessions

   MqlDateTime time_struct;
   TimeToStruct(TimeCurrent(), time_struct);

   // London open: 8:00-8:30 GMT
   // NY open: 13:00-13:30 GMT
   if((time_struct.hour == 8 && time_struct.min < 30) ||
      (time_struct.hour == 13 && time_struct.min < 30))
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Check session condition                                          |
//+------------------------------------------------------------------+
bool CAdvancedFilters::CheckSessionCondition()
{
   if(!m_use_session_filter)
      return true;

   MqlDateTime time_struct;
   TimeToStruct(TimeCurrent(), time_struct);

   int current_hour = time_struct.hour;

   if(m_session_start_hour <= m_session_end_hour)
   {
      // Normal session (e.g., 8-17)
      if(current_hour >= m_session_start_hour && current_hour < m_session_end_hour)
         return true;
   }
   else
   {
      // Overnight session (e.g., 22-6)
      if(current_hour >= m_session_start_hour || current_hour < m_session_end_hour)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Master filter check                                              |
//+------------------------------------------------------------------+
bool CAdvancedFilters::PassesAllFilters(string signal_type)
{
   if(!CheckVolumeCondition())
   {
      Print("Signal rejected: Volume filter");
      return false;
   }

   if(!CheckMultiTimeframeAlignment(signal_type))
   {
      Print("Signal rejected: Multi-timeframe filter");
      return false;
   }

   if(!CheckSpreadCondition())
   {
      Print("Signal rejected: Spread too high");
      return false;
   }

   if(!CheckNewsCondition())
   {
      Print("Signal rejected: News filter");
      return false;
   }

   if(!CheckSessionCondition())
   {
      Print("Signal rejected: Outside trading session");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Get filter status string                                         |
//+------------------------------------------------------------------+
string CAdvancedFilters::GetFilterStatus()
{
   string status = "";

   if(m_use_volume_filter)
      status += "VOL ";
   if(m_use_mtf_filter)
      status += "MTF ";
   if(m_use_spread_filter)
      status += "SPR ";
   if(m_use_news_filter)
      status += "NEWS ";
   if(m_use_session_filter)
      status += "SES ";

   if(status == "")
      return "None";

   return status;
}
//+------------------------------------------------------------------+
