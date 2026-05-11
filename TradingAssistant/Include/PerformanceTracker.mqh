//+------------------------------------------------------------------+
//|                                           PerformanceTracker.mqh |
//|                            Trading Assistant - Performance Tracking |
//|                          Real-time P&L, statistics, export to CSV |
//+------------------------------------------------------------------+
#property copyright "Trading Assistant"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Trade record structure                                           |
//+------------------------------------------------------------------+
struct STradeRecord
{
   datetime    open_time;
   datetime    close_time;
   string      type;
   double      lot_size;
   double      open_price;
   double      close_price;
   double      sl;
   double      tp;
   double      profit;
   double      pips;
   bool        hit_tp;
   string      comment;
};

//+------------------------------------------------------------------+
//| Performance Tracker Class                                        |
//+------------------------------------------------------------------+
class CPerformanceTracker
{
private:
   STradeRecord   m_trades[1000];     // Store last 1000 trades
   int            m_trade_count;

   // Performance metrics
   double         m_total_profit;
   double         m_total_loss;
   double         m_gross_profit;
   double         m_gross_loss;
   int            m_winning_trades;
   int            m_losing_trades;
   double         m_largest_win;
   double         m_largest_loss;
   double         m_total_pips;

   // Current session
   datetime       m_session_start;
   double         m_session_starting_balance;

   // Best/worst
   int            m_best_day_trades;
   double         m_best_day_profit;
   int            m_worst_day_trades;
   double         m_worst_day_loss;

   // Export
   string         m_export_folder;

public:
   CPerformanceTracker();
   ~CPerformanceTracker();

   void Initialize();

   // Add trade
   void AddTrade(datetime open_time, datetime close_time, string type, double lot,
                 double open_price, double close_price, double sl, double tp,
                 double profit, string comment);

   // Statistics
   double GetTotalProfit() { return m_total_profit; }
   double GetTotalLoss() { return m_total_loss; }
   double GetNetProfit() { return m_total_profit + m_total_loss; }
   double GetProfitFactor();
   double GetWinRate();
   double GetAverageWin();
   double GetAverageLoss();
   double GetRiskRewardRatio();
   int GetTotalTrades() { return m_trade_count; }
   int GetWinningTrades() { return m_winning_trades; }
   int GetLosingTrades() { return m_losing_trades; }
   double GetLargestWin() { return m_largest_win; }
   double GetLargestLoss() { return m_largest_loss; }
   double GetTotalPips() { return m_total_pips; }

   // Session stats
   double GetSessionProfit();
   int GetSessionTrades();

   // Export
   bool ExportToCSV(string filename);
   bool ExportDailyReport();

   // Reset
   void ResetSession();
   void ResetAll();

private:
   double CalculatePips(string type, double open_price, double close_price);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CPerformanceTracker::CPerformanceTracker()
{
   m_trade_count = 0;
   m_total_profit = 0;
   m_total_loss = 0;
   m_gross_profit = 0;
   m_gross_loss = 0;
   m_winning_trades = 0;
   m_losing_trades = 0;
   m_largest_win = 0;
   m_largest_loss = 0;
   m_total_pips = 0;

   m_session_start = TimeCurrent();
   m_session_starting_balance = AccountInfoDouble(ACCOUNT_BALANCE);

   m_best_day_trades = 0;
   m_best_day_profit = 0;
   m_worst_day_trades = 0;
   m_worst_day_loss = 0;

   m_export_folder = "TradingAssistant_Reports";
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CPerformanceTracker::~CPerformanceTracker()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                        |
//+------------------------------------------------------------------+
void CPerformanceTracker::Initialize()
{
   // Create export folder if it doesn't exist
   string folder_path = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + m_export_folder;
   FolderCreate(m_export_folder, FILE_COMMON);

   Print("Performance Tracker initialized. Export folder: ", m_export_folder);
}

//+------------------------------------------------------------------+
//| Add trade record                                                 |
//+------------------------------------------------------------------+
void CPerformanceTracker::AddTrade(datetime open_time, datetime close_time, string type, double lot,
                                   double open_price, double close_price, double sl, double tp,
                                   double profit, string comment)
{
   if(m_trade_count >= 1000)
   {
      // Shift array to make room
      for(int i = 0; i < 999; i++)
         m_trades[i] = m_trades[i + 1];
      m_trade_count = 999;
   }

   STradeRecord trade;
   trade.open_time = open_time;
   trade.close_time = close_time;
   trade.type = type;
   trade.lot_size = lot;
   trade.open_price = open_price;
   trade.close_price = close_price;
   trade.sl = sl;
   trade.tp = tp;
   trade.profit = profit;
   trade.pips = CalculatePips(type, open_price, close_price);
   trade.hit_tp = (MathAbs(close_price - tp) < MathAbs(close_price - sl));
   trade.comment = comment;

   m_trades[m_trade_count] = trade;
   m_trade_count++;

   // Update statistics
   if(profit > 0)
   {
      m_winning_trades++;
      m_total_profit += profit;
      m_gross_profit += profit;
      if(profit > m_largest_win)
         m_largest_win = profit;
   }
   else
   {
      m_losing_trades++;
      m_total_loss += profit;
      m_gross_loss += MathAbs(profit);
      if(profit < m_largest_loss)
         m_largest_loss = profit;
   }

   m_total_pips += trade.pips;
}

//+------------------------------------------------------------------+
//| Calculate profit factor                                          |
//+------------------------------------------------------------------+
double CPerformanceTracker::GetProfitFactor()
{
   if(m_gross_loss == 0)
      return m_gross_profit > 0 ? 999.9 : 0;

   return m_gross_profit / m_gross_loss;
}

//+------------------------------------------------------------------+
//| Calculate win rate                                               |
//+------------------------------------------------------------------+
double CPerformanceTracker::GetWinRate()
{
   int total = m_winning_trades + m_losing_trades;
   if(total == 0)
      return 0;

   return (double)m_winning_trades / total * 100.0;
}

//+------------------------------------------------------------------+
//| Get average win                                                   |
//+------------------------------------------------------------------+
double CPerformanceTracker::GetAverageWin()
{
   if(m_winning_trades == 0)
      return 0;

   return m_total_profit / m_winning_trades;
}

//+------------------------------------------------------------------+
//| Get average loss                                                  |
//+------------------------------------------------------------------+
double CPerformanceTracker::GetAverageLoss()
{
   if(m_losing_trades == 0)
      return 0;

   return m_total_loss / m_losing_trades;
}

//+------------------------------------------------------------------+
//| Get risk/reward ratio                                            |
//+------------------------------------------------------------------+
double CPerformanceTracker::GetRiskRewardRatio()
{
   double avg_loss = GetAverageLoss();
   if(avg_loss == 0)
      return 0;

   return MathAbs(GetAverageWin() / avg_loss);
}

//+------------------------------------------------------------------+
//| Get session profit                                                |
//+------------------------------------------------------------------+
double CPerformanceTracker::GetSessionProfit()
{
   return AccountInfoDouble(ACCOUNT_BALANCE) - m_session_starting_balance;
}

//+------------------------------------------------------------------+
//| Get session trades                                                |
//+------------------------------------------------------------------+
int CPerformanceTracker::GetSessionTrades()
{
   int session_trades = 0;
   for(int i = 0; i < m_trade_count; i++)
   {
      if(m_trades[i].open_time >= m_session_start)
         session_trades++;
   }
   return session_trades;
}

//+------------------------------------------------------------------+
//| Export to CSV                                                     |
//+------------------------------------------------------------------+
bool CPerformanceTracker::ExportToCSV(string filename)
{
   int file_handle = FileOpen(m_export_folder + "\\" + filename, FILE_WRITE | FILE_CSV | FILE_COMMON);

   if(file_handle == INVALID_HANDLE)
   {
      Print("Failed to create CSV file: ", filename);
      return false;
   }

   // Write header
   FileWrite(file_handle, "Open Time", "Close Time", "Type", "Lot Size", "Open Price",
             "Close Price", "SL", "TP", "Profit", "Pips", "Hit TP", "Comment");

   // Write trades
   for(int i = 0; i < m_trade_count; i++)
   {
      FileWrite(file_handle,
                TimeToString(m_trades[i].open_time),
                TimeToString(m_trades[i].close_time),
                m_trades[i].type,
                DoubleToString(m_trades[i].lot_size, 2),
                DoubleToString(m_trades[i].open_price, _Digits),
                DoubleToString(m_trades[i].close_price, _Digits),
                DoubleToString(m_trades[i].sl, _Digits),
                DoubleToString(m_trades[i].tp, _Digits),
                DoubleToString(m_trades[i].profit, 2),
                DoubleToString(m_trades[i].pips, 1),
                m_trades[i].hit_tp ? "Yes" : "No",
                m_trades[i].comment);
   }

   FileClose(file_handle);
   Print("Exported ", m_trade_count, " trades to: ", filename);
   return true;
}

//+------------------------------------------------------------------+
//| Export daily report                                              |
//+------------------------------------------------------------------+
bool CPerformanceTracker::ExportDailyReport()
{
   MqlDateTime time_struct;
   TimeToStruct(TimeCurrent(), time_struct);

   string filename = StringFormat("DailyReport_%04d-%02d-%02d.csv",
                                  time_struct.year, time_struct.mon, time_struct.day);

   return ExportToCSV(filename);
}

//+------------------------------------------------------------------+
//| Reset session                                                     |
//+------------------------------------------------------------------+
void CPerformanceTracker::ResetSession()
{
   m_session_start = TimeCurrent();
   m_session_starting_balance = AccountInfoDouble(ACCOUNT_BALANCE);
}

//+------------------------------------------------------------------+
//| Reset all statistics                                             |
//+------------------------------------------------------------------+
void CPerformanceTracker::ResetAll()
{
   m_trade_count = 0;
   m_total_profit = 0;
   m_total_loss = 0;
   m_gross_profit = 0;
   m_gross_loss = 0;
   m_winning_trades = 0;
   m_losing_trades = 0;
   m_largest_win = 0;
   m_largest_loss = 0;
   m_total_pips = 0;

   ResetSession();
}

//+------------------------------------------------------------------+
//| Calculate pips from price difference                             |
//+------------------------------------------------------------------+
double CPerformanceTracker::CalculatePips(string type, double open_price, double close_price)
{
   double pips = (close_price - open_price) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(type == "SELL")
      pips = -pips;

   return pips;
}
//+------------------------------------------------------------------+
