//+------------------------------------------------------------------+
//|                                    TradingAssistant_EA.mq5      |
//|                                   Trading Support System 2026    |
//|                      Signal Detection + Trade Management System  |
//|                                      NEVER AUTO-TRADES           |
//+------------------------------------------------------------------+
#property copyright "Trading Assistant 2026"
#property link      "https://github.com/wechuck/EA-BOT-MQL5"
#property version   "1.00"
#property description "Signal-only trading assistant with trade management"
#property description "NO AUTO-TRADING - Manual execution required"
#property description "RSI + Stochastic + ADX + Structure confirmation"
#property strict

// Include all modules
#include "Include/ModernDashboard.mqh"
#include "Include/SignalDetector.mqh"
#include "Include/TradeManager.mqh"
#include "Include/ExecutionProtection.mqh"
#include "Include/PositionSizing.mqh"
#include "Include/AlertSystem.mqh"

// NEW ENHANCED MODULES
#include "Include/SignalHistory.mqh"
#include "Include/AdvancedFilters.mqh"
#include "Include/RiskManager.mqh"
#include "Include/PerformanceTracker.mqh"
#include "Include/PartialPositionManager.mqh"
#include "Include/MarketAnalysis.mqh"
#include "Include/EnhancedAlertSystem.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+

//--- Signal Detection Settings
input group "=== Signal Detection ==="
input int                InpRSIPeriod = 14;                    // RSI Period
input double             InpRSIOversold = 30.0;                // RSI Oversold Level
input double             InpRSIOverbought = 70.0;              // RSI Overbought Level
input int                InpStochK = 5;                        // Stochastic %K Period
input int                InpStochD = 3;                        // Stochastic %D Period
input int                InpStochSlowing = 3;                  // Stochastic Slowing
input double             InpStochOversold = 20.0;              // Stochastic Oversold
input double             InpStochOverbought = 80.0;            // Stochastic Overbought
input int                InpADXPeriod = 14;                    // ADX Period
input double             InpADXMinimum = 20.0;                 // ADX Minimum Threshold
input int                InpMaxSignalsPerDay = 1;              // Max Signals Per Day (1 = 4-7/week)
input int                InpSignalCooldownMinutes = 240;       // Signal Cooldown (minutes)

//--- Trade Management Settings
input group "=== Trade Management ==="
input double             InpRiskRewardRatio = 4.5;             // Risk:Reward Ratio (1:X) - 1:4 to 1:5
input bool               InpUseFixedDistance = true;           // Use Fixed SL/TP Distance
input double             InpFixedSLDistance = 200;             // Fixed SL Distance (points)
input double             InpFixedTPDistance = 900;             // Fixed TP Distance (points) - 800-1000
input double             InpATRMultiplierSL = 1.5;             // ATR Multiplier for SL (if not fixed)
input double             InpTrailingDistance = 400;            // Trailing Stop Distance (points)
input double             InpTrailingStep = 100;                // Trailing Stop Step (points)
input double             InpBreakevenDistance = 200;           // Breakeven Distance (points)

//--- Risk & Position Sizing
input group "=== Position Sizing ==="
input double             InpBaseRiskPercent = 5.0;             // Base Risk Per Trade (%)
input double             InpAggressiveRiskPercent = 30.0;      // Aggressive Risk (%)
input double             InpBaseRewardPercent = 15.0;          // Base Reward Target (%)
input double             InpAggressiveRewardPercent = 70.0;    // Aggressive Reward Target (%)
input bool               InpAggressiveMode = false;            // Use Aggressive Mode
input double             InpContractSize = 100.0;              // Contract Size (XAUUSD=100)

//--- Execution Protection
input group "=== Execution Protection ==="
input double             InpMaxSpread = 30.0;                  // Maximum Spread (points)
input double             InpWarningSpread = 20.0;              // Warning Spread (points)
input double             InpMaxSlippage = 10.0;                // Maximum Slippage (points)

//--- Alert Settings
input group "=== Alert Settings ==="
input bool               InpEnableAlerts = true;               // Enable Alerts
input bool               InpEnablePushNotifications = true;    // Enable Push Notifications
input bool               InpEnableSound = true;                // Enable Sound Alerts
input bool               InpEnablePopup = false;               // Enable Popup Alerts

//--- Dashboard Settings
input group "=== Dashboard Settings ==="
input bool               InpShowDashboard = true;              // Show Dashboard
input int                InpDashboardX = 20;                   // Dashboard X Position
input int                InpDashboardY = 30;                   // Dashboard Y Position
input ENUM_TIMEFRAMES    InpTimeframe = PERIOD_M15;            // Analysis Timeframe (M15 recommended)
input bool               InpShowEntryPopup = true;             // Show Entry Popup Alert
input bool               InpBlockFridayLate = true;            // Block Trading Friday after 22:00

//--- Advanced Filters
input group "=== Advanced Filters ==="
input bool               InpUseVolumeFilter = false;           // Use Volume Filter
input double             InpVolumeMultiplier = 1.5;            // Volume Multiplier
input bool               InpUseMultiTFFilter = false;          // Use Multi-Timeframe Confirmation
input ENUM_TIMEFRAMES    InpHigherTimeframe = PERIOD_H1;       // Higher Timeframe for Confirmation
input bool               InpUseSpreadFilter = true;            // Use Spread Filter (Recommended)
input double             InpMaxSpreadPips = 3.0;               // Max Spread (Pips)
input bool               InpUseSessionFilter = false;          // Use Trading Session Filter
input int                InpSessionStartHour = 8;              // Session Start Hour (GMT)
input int                InpSessionEndHour = 17;               // Session End Hour (GMT)

//--- Risk Management
input group "=== Risk Management Limits ==="
input bool               InpUseDailyLossLimit = true;          // Use Daily Loss Limit
input double             InpDailyLossLimitPct = 2.0;           // Daily Loss Limit (%)
input bool               InpUseDailyProfitTarget = false;      // Use Daily Profit Target
input double             InpDailyProfitTargetPct = 5.0;        // Daily Profit Target (%)
input bool               InpUseMaxTradesLimit = true;          // Use Max Trades Per Day Limit
input int                InpMaxTradesPerDay = 5;               // Max Trades Per Day
input bool               InpUseDrawdownLimit = true;           // Use Drawdown Limit
input double             InpMaxDrawdownPct = 10.0;             // Max Drawdown (%)
input bool               InpUseConsecLossLimit = true;         // Use Consecutive Loss Limit
input int                InpMaxConsecutiveLosses = 3;          // Max Consecutive Losses

//--- Partial Position Management
input group "=== Partial Position Management ==="
input bool               InpUsePartialClose = false;           // Use Partial Position Close
input double             InpTP1_RR = 2.0;                      // TP1 Risk:Reward Ratio
input double             InpTP1_ClosePct = 50.0;               // TP1 Close Percent
input double             InpTP2_RR = 3.0;                      // TP2 Risk:Reward Ratio
input double             InpTP2_ClosePct = 30.0;               // TP2 Close Percent (20% remains for final TP)

//--- Enhanced Alerts
input group "=== Enhanced Alert System ==="
input bool               InpUseTelegram = false;               // Use Telegram Alerts
input string             InpTelegramToken = "";                // Telegram Bot Token
input string             InpTelegramChatID = "";               // Telegram Chat ID
input bool               InpUseEmailAlerts = false;            // Use Email Alerts
input string             InpEmailSubjectPrefix = "[TradingAssistant]"; // Email Subject Prefix
input bool               InpUseCustomSounds = true;            // Use Custom Sound Files
input int                InpAlertCooldownSeconds = 60;         // Alert Cooldown (seconds)

//+------------------------------------------------------------------+
//| Global Objects                                                    |
//+------------------------------------------------------------------+
CModernDashboard       *Dashboard;
CSignalDetector        *SignalDetector;
CTradeManager          *TradeManager;
CExecutionProtection   *ExecProtection;
CPositionSizing        *PositionSizing;
CAlertSystem           *AlertSystem;

// NEW ENHANCED MODULES
CSignalHistory         *SignalHistory;
CAdvancedFilters       *AdvancedFilters;
CRiskManager           *RiskManager;
CPerformanceTracker    *PerformanceTracker;
CPartialPositionManager *PartialPositionMgr;
CMarketAnalysis        *MarketAnalysis;
CEnhancedAlertSystem   *EnhancedAlerts;

//--- Global variables
datetime g_last_bar_time = 0;
bool g_initialized = false;
double g_recommended_lot = 0; // Store recommended lot for dashboard

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("========================================");
   Print("Trading Assistant EA - Initializing");
   Print("========================================");
   Print("IMPORTANT: This EA does NOT auto-trade!");
   Print("It only provides signals and manages manually opened positions.");
   Print("========================================");

   // Create objects
   Dashboard = new CModernDashboard();
   SignalDetector = new CSignalDetector();
   TradeManager = new CTradeManager();
   ExecProtection = new CExecutionProtection();
   PositionSizing = new CPositionSizing();
   AlertSystem = new CAlertSystem();

   // Initialize Dashboard
   if(InpShowDashboard)
   {
      if(!Dashboard.Init("TradingAssist", InpDashboardX, InpDashboardY, 450, 650))
      {
         Print("Error: Failed to initialize dashboard");
         return INIT_FAILED;
      }
   }

   // Initialize Signal Detector
   if(!SignalDetector.Init(_Symbol, InpTimeframe))
   {
      Print("Error: Failed to initialize signal detector");
      return INIT_FAILED;
   }
   SignalDetector.SetRSIParams(InpRSIPeriod, InpRSIOversold, InpRSIOverbought);
   SignalDetector.SetStochParams(InpStochK, InpStochD, InpStochSlowing, InpStochOversold, InpStochOverbought);
   SignalDetector.SetADXParams(InpADXPeriod, InpADXMinimum);
   SignalDetector.SetFrequencyControl(InpMaxSignalsPerDay, InpSignalCooldownMinutes);

   // Initialize Trade Manager
   if(!TradeManager.Init(_Symbol, InpTimeframe))
   {
      Print("Error: Failed to initialize trade manager");
      return INIT_FAILED;
   }
   TradeManager.SetRiskReward(InpRiskRewardRatio);
   TradeManager.SetATRMultipliers(InpATRMultiplierSL, InpATRMultiplierSL * InpRiskRewardRatio);
   TradeManager.SetTrailingParams(InpTrailingDistance, InpTrailingStep);
   TradeManager.SetFixedDistance(InpUseFixedDistance, InpFixedSLDistance, InpFixedTPDistance);
   TradeManager.SetBreakevenDistance(InpBreakevenDistance);

   // Initialize Execution Protection
   ExecProtection.SetSpreadLimits(InpMaxSpread, InpWarningSpread);
   ExecProtection.SetSlippageLimits(InpMaxSlippage);

   // Initialize Position Sizing
   PositionSizing.SetBalance(AccountInfoDouble(ACCOUNT_BALANCE));
   PositionSizing.SetRiskParameters(InpBaseRiskPercent, InpAggressiveRiskPercent);
   PositionSizing.SetRewardParameters(InpBaseRewardPercent, InpAggressiveRewardPercent);
   PositionSizing.SetContractSize(InpContractSize);
   PositionSizing.SetAggressiveMode(InpAggressiveMode);

   // Initialize Alert System
   AlertSystem.EnableAlerts(InpEnableAlerts);
   AlertSystem.EnablePush(InpEnablePushNotifications);
   AlertSystem.EnableSound(InpEnableSound);
   AlertSystem.EnablePopup(InpEnablePopup);

   // Initialize NEW ENHANCED MODULES

   // Signal History
   SignalHistory = new CSignalHistory();

   // Advanced Filters
   AdvancedFilters = new CAdvancedFilters();
   if(!AdvancedFilters.Initialize(_Symbol, InpTimeframe))
   {
      Print("Warning: Failed to initialize advanced filters");
   }
   AdvancedFilters.SetVolumeFilter(InpUseVolumeFilter, InpVolumeMultiplier);
   AdvancedFilters.SetMultiTimeframeFilter(InpUseMultiTFFilter, InpHigherTimeframe);
   AdvancedFilters.SetSpreadFilter(InpUseSpreadFilter, InpMaxSpreadPips);
   AdvancedFilters.SetSessionFilter(InpUseSessionFilter, InpSessionStartHour, InpSessionEndHour);

   // Risk Manager
   RiskManager = new CRiskManager();
   RiskManager.SetDailyLossLimit(InpUseDailyLossLimit, InpDailyLossLimitPct);
   RiskManager.SetDailyProfitTarget(InpUseDailyProfitTarget, InpDailyProfitTargetPct);
   RiskManager.SetMaxTradesPerDay(InpUseMaxTradesLimit, InpMaxTradesPerDay);
   RiskManager.SetDrawdownLimit(InpUseDrawdownLimit, InpMaxDrawdownPct);
   RiskManager.SetConsecutiveLossLimit(InpUseConsecLossLimit, InpMaxConsecutiveLosses);

   // Performance Tracker
   PerformanceTracker = new CPerformanceTracker();
   PerformanceTracker.Initialize();

   // Partial Position Manager
   PartialPositionMgr = new CPartialPositionManager();
   PartialPositionMgr.SetPartialClose(InpUsePartialClose, InpTP1_RR, InpTP1_ClosePct, InpTP2_RR, InpTP2_ClosePct);

   // Market Analysis
   MarketAnalysis = new CMarketAnalysis();
   if(!MarketAnalysis.Initialize(_Symbol, InpTimeframe))
   {
      Print("Warning: Failed to initialize market analysis");
   }

   // Enhanced Alert System
   EnhancedAlerts = new CEnhancedAlertSystem();
   EnhancedAlerts.SetPushNotifications(InpEnablePushNotifications);
   EnhancedAlerts.SetTerminalAlert(InpEnableAlerts);
   EnhancedAlerts.SetSoundAlert(InpUseCustomSounds, "alert2.wav", "ok.wav", "timeout.wav");
   EnhancedAlerts.SetEmailAlert(InpUseEmailAlerts, InpEmailSubjectPrefix);
   EnhancedAlerts.SetTelegram(InpUseTelegram, InpTelegramToken, InpTelegramChatID);
   EnhancedAlerts.SetAlertCooldown(InpAlertCooldownSeconds);

   g_initialized = true;
   Print("Trading Assistant initialized successfully");
   Print("Monitoring ", _Symbol, " on ", EnumToString(InpTimeframe));
   Print("Waiting for high-quality setups...");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Trading Assistant EA - Shutting down...");

   // Cleanup
   if(Dashboard != NULL)
   {
      Dashboard.Deinit();
      delete Dashboard;
   }
   if(SignalDetector != NULL)
   {
      SignalDetector.Deinit();
      delete SignalDetector;
   }
   if(TradeManager != NULL)
   {
      TradeManager.Deinit();
      delete TradeManager;
   }
   if(ExecProtection != NULL)
      delete ExecProtection;
   if(PositionSizing != NULL)
      delete PositionSizing;
   if(AlertSystem != NULL)
      delete AlertSystem;

   // Cleanup NEW ENHANCED MODULES
   if(SignalHistory != NULL)
      delete SignalHistory;
   if(AdvancedFilters != NULL)
      delete AdvancedFilters;
   if(RiskManager != NULL)
      delete RiskManager;
   if(PerformanceTracker != NULL)
   {
      PerformanceTracker.ExportDailyReport(); // Export final report on shutdown
      delete PerformanceTracker;
   }
   if(PartialPositionMgr != NULL)
      delete PartialPositionMgr;
   if(MarketAnalysis != NULL)
      delete MarketAnalysis;
   if(EnhancedAlerts != NULL)
      delete EnhancedAlerts;

   Print("Trading Assistant stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_initialized)
      return;

   // Update NEW ENHANCED MODULES
   RiskManager.Update();  // Check risk limits
   MarketAnalysis.Update(); // Update market analysis

   // Update execution protection on every tick
   ExecProtection.Update();

   // Update position sizing with current balance
   PositionSizing.SetBalance(AccountInfoDouble(ACCOUNT_BALANCE));

   // Check for new manually opened positions
   TradeManager.CheckForNewPosition();

   // Manage existing positions (SL/TP/Trailing + Partial Close)
   if(TradeManager.HasActivePosition())
   {
      if(ExecProtection.IsSafeToModify())
         TradeManager.ManagePosition();

      // Check for partial position close opportunities
      if(InpUsePartialClose)
      {
         ulong ticket = PositionGetTicket(0);
         if(ticket > 0)
            PartialPositionMgr.CheckPartialClose(ticket);
      }
   }

   // Continuously scan for signals (updates strength meter even without new bar)
   // This makes the dashboard responsive and shows real-time signal strength
   SignalDetector.ScanForSignal();

   // Check for new bar (for signal alerting)
   datetime current_bar_time = iTime(_Symbol, InpTimeframe, 0);
   if(current_bar_time != g_last_bar_time)
   {
      g_last_bar_time = current_bar_time;
      OnNewBar();
   }

   // Update dashboard on every tick for live updates
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| New bar event handler                                            |
//+------------------------------------------------------------------+
void OnNewBar()
{
   // Check risk management limits first
   if(!RiskManager.IsTradingAllowed())
   {
      Print("Trading blocked by Risk Manager: ", RiskManager.GetBlockReason());
      return;
   }

   // Check if trading is allowed at this time
   if(!IsTradingTimeAllowed())
   {
      Print("Trading blocked: Friday after 22:00 (high risk period)");
      return;
   }

   // Scan for trading signals
   bool signal_found = SignalDetector.ScanForSignal();

   if(signal_found)
   {
      string signal_type = SignalDetector.GetSignalType();
      int signal_strength = SignalDetector.GetSignalStrength();

      // Apply advanced filters
      if(!AdvancedFilters.PassesAllFilters(signal_type))
      {
         Print("Signal rejected by advanced filters");
         return;
      }

      // Clear previous chart lines before drawing new ones
      if(Dashboard != NULL)
      {
         Dashboard.ClearChartLines();
      }

      Print("========================================");
      Print("HIGH-QUALITY SIGNAL DETECTED!");
      Print("Type: ", signal_type);
      Print("Strength: ", signal_strength, "%");
      Print("========================================");
      Print("Review the chart and decide if you want to enter manually.");
      Print("EA will manage the trade after you open it.");

      // Send alerts
      AlertSystem.SendSignalAlert(signal_type, signal_strength);

      // Calculate recommended position size
      int atr_handle = iATR(_Symbol, InpTimeframe, 14);
      double atr_value = 0;
      if(atr_handle != INVALID_HANDLE)
      {
         double atr_buffer[];
         ArraySetAsSeries(atr_buffer, true);
         if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0)
            atr_value = atr_buffer[0];
         IndicatorRelease(atr_handle);
      }
      double sl_distance = atr_value * InpATRMultiplierSL / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      PositionSizing.CalculateLotSize(sl_distance);

      g_recommended_lot = PositionSizing.GetRecommendedLot();

      Print("Recommended Lot Size: ", DoubleToString(g_recommended_lot, 2));
      Print("Risk: ", DoubleToString(PositionSizing.GetCurrentRiskPercent(), 1), "%");
      Print("Target: ", DoubleToString(PositionSizing.GetCurrentRewardPercent(), 1), "%");

      // Add to signal history
      double current_price = SymbolInfoDouble(_Symbol, (signal_type == "BUY") ? SYMBOL_ASK : SYMBOL_BID);
      SignalHistory.AddSignal(signal_type, signal_strength, current_price);

      // Send enhanced alert with more details
      EnhancedAlerts.SendSignalAlert(signal_type, signal_strength, current_price, g_recommended_lot);

      // Notify risk manager of new trade intent
      RiskManager.OnNewTrade();

      // Show on-screen entry popup
      if(InpShowEntryPopup && Dashboard != NULL)
      {
         Dashboard.ShowEntryPopup(signal_type, g_recommended_lot);
      }

      // Draw SL/TP lines and signal arrow on chart
      if(Dashboard != NULL)
      {
         // Calculate entry, SL, and TP prices for visual display
         bool is_buy = (signal_type == "BUY");
         double current_price = SymbolInfoDouble(_Symbol, is_buy ? SYMBOL_ASK : SYMBOL_BID);
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

         // Using fixed distances (200 for SL, 900 for TP as per user request)
         double sl_price = is_buy ?
            current_price - (InpFixedSLDistance * point) :
            current_price + (InpFixedSLDistance * point);

         double tp_price = is_buy ?
            current_price + (InpFixedTPDistance * point) :
            current_price - (InpFixedTPDistance * point);

         // Draw visual lines on chart (Entry, SL, TP)
         Dashboard.DrawSLTPLines(signal_type, current_price, sl_price, tp_price);

         // Draw signal arrow and direction text
         Dashboard.DrawSignalArrow(signal_type, current_price);
      }
   }
}

//+------------------------------------------------------------------+
//| Update dashboard display                                         |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!InpShowDashboard || Dashboard == NULL)
      return;

   // Signal Panel - show dynamic status
   string signal_status = "WATCHING";
   int signal_strength = SignalDetector.GetSignalStrength();

   // Determine status based on signal strength and active state
   if(SignalDetector.IsSignalActive())
   {
      signal_status = "ACTIVE";
   }
   else if(signal_strength >= 70)
   {
      signal_status = "ACTIVE"; // High strength should also show ACTIVE
   }
   else if(signal_strength >= 50)
   {
      signal_status = "SCANNING"; // Intermediate state showing analysis
   }
   else if(signal_strength > 0)
   {
      signal_status = "WATCHING";
   }
   else
   {
      signal_status = "IDLE";
   }

   string next_signal = SignalDetector.GetNextSignalTime();

   // Get current signal direction (BUY/SELL) to display on dashboard
   string signal_direction = "NONE";
   if(SignalDetector.IsSignalActive() || signal_strength >= 70)
   {
      signal_direction = SignalDetector.GetSignalType();
   }

   // Use overloaded version with lot size and signal direction
   Dashboard.UpdateSignalPanel(signal_status, signal_strength, next_signal, g_recommended_lot, signal_direction);

   // Trade Management Panel
   bool has_position = TradeManager.HasActivePosition();
   double sl = TradeManager.GetStopLoss();
   double tp = TradeManager.GetTakeProfit();
   double profit = TradeManager.GetCurrentProfit();
   bool trailing = TradeManager.IsTrailingActive();
   Dashboard.UpdateTradePanel(has_position, sl, tp, profit, trailing);

   // Risk & Position Sizing Panel
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double lot_size = PositionSizing.GetRecommendedLot();
   double risk_pct = PositionSizing.GetCurrentRiskPercent();
   double reward_pct = PositionSizing.GetCurrentRewardPercent();
   Dashboard.UpdateRiskPanel(balance, lot_size, risk_pct, reward_pct);

   // Execution Quality Panel
   double spread = ExecProtection.GetCurrentSpread();
   int spread_status = ExecProtection.GetSpreadStatus();
   string exec_quality = ExecProtection.GetExecutionQuality();
   Dashboard.UpdateExecutionPanel(spread, spread_status, exec_quality);

   // Statistics Panel
   int signals_today = SignalDetector.GetSignalsToday();
   int signals_week = SignalDetector.GetSignalsThisWeek();
   double win_rate = PerformanceTracker.GetWinRate();
   double total_profit = PerformanceTracker.GetNetProfit();
   Dashboard.UpdateStatsPanel(signals_today, signals_week, win_rate, total_profit);

   // NEW ENHANCED PANELS

   // Market Analysis Panel
   Dashboard.UpdateMarketAnalysisPanel(
      MarketAnalysis.GetTrend(),
      MarketAnalysis.GetVolatility(),
      MarketAnalysis.GetSupport(),
      MarketAnalysis.GetResistance(),
      MarketAnalysis.GetATR()
   );

   // Performance Panel
   Dashboard.UpdatePerformancePanel(
      PerformanceTracker.GetNetProfit(),
      PerformanceTracker.GetWinRate(),
      PerformanceTracker.GetProfitFactor(),
      PerformanceTracker.GetTotalTrades()
   );

   // Filter Status Panel
   Dashboard.UpdateFilterStatusPanel(
      AdvancedFilters.GetFilterStatus(),
      RiskManager.IsTradingAllowed(),
      RiskManager.GetBlockReason()
   );

   // Risk Limits Panel
   Dashboard.UpdateRiskLimitsPanel(
      RiskManager.GetDailyPnL(),
      RiskManager.GetWeeklyPnL(),
      RiskManager.GetTradesToday(),
      RiskManager.GetConsecutiveLosses()
   );

   // Signal History Panel (if we have history)
   string recent_signals[];
   // TODO: Format last 5 signals from SignalHistory

   Dashboard.Update();
}

//+------------------------------------------------------------------+
//| Timer function (called every second)                             |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Periodic updates can go here if needed
}

//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Handle chart events if needed
}

//+------------------------------------------------------------------+
//| Check if trading is allowed at current time                     |
//+------------------------------------------------------------------+
bool IsTradingTimeAllowed()
{
   if(!InpBlockFridayLate)
      return true;  // No time restrictions if disabled

   MqlDateTime time_struct;
   TimeToStruct(TimeCurrent(), time_struct);

   // Block trading on Friday (day 5) after 22:00
   if(time_struct.day_of_week == 5 && time_struct.hour >= 22)
   {
      return false;  // High risk period - market closing for weekend
   }

   return true;  // Trading allowed
}
//+------------------------------------------------------------------+
