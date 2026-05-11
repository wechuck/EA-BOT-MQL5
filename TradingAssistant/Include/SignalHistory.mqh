//+------------------------------------------------------------------+
//|                                                SignalHistory.mqh |
//|                                  Trading Assistant - Signal History |
//|                                         Tracks past signals & results |
//+------------------------------------------------------------------+
#property copyright "Trading Assistant"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Signal history entry structure                                   |
//+------------------------------------------------------------------+
struct SSignalHistory
{
   datetime    time;              // When signal occurred
   string      type;              // BUY or SELL
   int         strength;          // Signal strength 0-100
   double      entry_price;       // Price when signal appeared
   double      result_pips;       // Result if followed (0 if not tracked)
   bool        was_profitable;    // True if profitable
   bool        is_tracked;        // True if we're tracking this signal
};

//+------------------------------------------------------------------+
//| Signal History Manager Class                                     |
//+------------------------------------------------------------------+
class CSignalHistory
{
private:
   SSignalHistory  m_history[100];  // Store last 100 signals
   int            m_count;          // Number of signals stored
   int            m_head;           // Circular buffer head

   // Statistics
   int            m_total_signals;
   int            m_winning_signals;
   int            m_losing_signals;
   double         m_total_pips;

public:
   CSignalHistory();
   ~CSignalHistory();

   // Add new signal
   void AddSignal(string type, int strength, double entry_price);

   // Update signal result (when trade closes)
   void UpdateSignalResult(int index, double exit_price, bool profitable);

   // Get history
   int GetSignalCount() { return m_count; }
   bool GetSignal(int index, SSignalHistory &signal);

   // Get recent signals (last N)
   int GetRecentSignals(SSignalHistory &signals[], int count);

   // Statistics
   double GetWinRate();
   double GetTotalPips() { return m_total_pips; }
   int GetTotalSignals() { return m_total_signals; }
   int GetWinningSignals() { return m_winning_signals; }
   int GetLosingSignals() { return m_losing_signals; }

   // Reset statistics
   void ResetStats();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CSignalHistory::CSignalHistory()
{
   m_count = 0;
   m_head = 0;
   m_total_signals = 0;
   m_winning_signals = 0;
   m_losing_signals = 0;
   m_total_pips = 0;

   // Initialize struct array manually
   for(int i = 0; i < 100; i++)
   {
      m_history[i].time = 0;
      m_history[i].type = "";
      m_history[i].strength = 0;
      m_history[i].entry_price = 0;
      m_history[i].result_pips = 0;
      m_history[i].was_profitable = false;
      m_history[i].is_tracked = false;
   }
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CSignalHistory::~CSignalHistory()
{
}

//+------------------------------------------------------------------+
//| Add new signal to history                                        |
//+------------------------------------------------------------------+
void CSignalHistory::AddSignal(string type, int strength, double entry_price)
{
   SSignalHistory signal;
   signal.time = TimeCurrent();
   signal.type = type;
   signal.strength = strength;
   signal.entry_price = entry_price;
   signal.result_pips = 0;
   signal.was_profitable = false;
   signal.is_tracked = false;

   // Add to circular buffer
   m_history[m_head] = signal;
   m_head = (m_head + 1) % 100;

   if(m_count < 100)
      m_count++;

   m_total_signals++;
}

//+------------------------------------------------------------------+
//| Update signal result                                             |
//+------------------------------------------------------------------+
void CSignalHistory::UpdateSignalResult(int index, double exit_price, bool profitable)
{
   if(index < 0 || index >= m_count)
      return;

   m_history[index].is_tracked = true;
   m_history[index].was_profitable = profitable;

   // Calculate pips
   double pips = (exit_price - m_history[index].entry_price) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(m_history[index].type == "SELL")
      pips = -pips;

   m_history[index].result_pips = pips;
   m_total_pips += pips;

   if(profitable)
      m_winning_signals++;
   else
      m_losing_signals++;
}

//+------------------------------------------------------------------+
//| Get signal by index                                              |
//+------------------------------------------------------------------+
bool CSignalHistory::GetSignal(int index, SSignalHistory &signal)
{
   if(index < 0 || index >= m_count)
      return false;

   signal = m_history[index];
   return true;
}

//+------------------------------------------------------------------+
//| Get recent signals                                               |
//+------------------------------------------------------------------+
int CSignalHistory::GetRecentSignals(SSignalHistory &signals[], int count)
{
   if(count > m_count)
      count = m_count;

   ArrayResize(signals, count);

   // Get last N signals
   int start = (m_head - count + 100) % 100;
   for(int i = 0; i < count; i++)
   {
      int idx = (start + i) % 100;
      signals[i] = m_history[idx];
   }

   return count;
}

//+------------------------------------------------------------------+
//| Get win rate percentage                                          |
//+------------------------------------------------------------------+
double CSignalHistory::GetWinRate()
{
   int total_tracked = m_winning_signals + m_losing_signals;
   if(total_tracked == 0)
      return 0;

   return (double)m_winning_signals / total_tracked * 100.0;
}

//+------------------------------------------------------------------+
//| Reset all statistics                                             |
//+------------------------------------------------------------------+
void CSignalHistory::ResetStats()
{
   m_total_signals = 0;
   m_winning_signals = 0;
   m_losing_signals = 0;
   m_total_pips = 0;
   m_count = 0;
   m_head = 0;
}
//+------------------------------------------------------------------+
