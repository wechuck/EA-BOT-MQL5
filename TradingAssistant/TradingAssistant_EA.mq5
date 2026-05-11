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

//+------------------------------------------------------------------+
//| Global Objects                                                    |
//+------------------------------------------------------------------+
CModernDashboard      *Dashboard;
CSignalDetector       *SignalDetector;
CTradeManager         *TradeManager;
CExecutionProtection  *ExecProtection;
CPositionSizing       *PositionSizing;
CAlertSystem          *AlertSystem;

//--- Global variables
datetime g_last_bar_time = 0;
bool g_initialized = false;

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

   Print("Trading Assistant stopped. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_initialized)
      return;

   // Update execution protection on every tick
   ExecProtection.Update();

   // Update position sizing with current balance
   PositionSizing.SetBalance(AccountInfoDouble(ACCOUNT_BALANCE));

   // Check for new manually opened positions
   TradeManager.CheckForNewPosition();

   // Manage existing positions (SL/TP/Trailing)
   if(TradeManager.HasActivePosition())
   {
      if(ExecProtection.IsSafeToModify())
         TradeManager.ManagePosition();
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
   // Scan for trading signals
   bool signal_found = SignalDetector.ScanForSignal();

   if(signal_found)
   {
      string signal_type = SignalDetector.GetSignalType();
      int signal_strength = SignalDetector.GetSignalStrength();

      Print("========================================");
      Print("HIGH-QUALITY SIGNAL DETECTED!");
      Print("Type: ", signal_type);
      Print("Strength: ", signal_strength, "%");
      Print("========================================");
      Print("Review the chart and decide if you want to enter manually.");
      Print("EA will manage the trade after you open it.");

      // Send alert to trader
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

      Print("Recommended Lot Size: ", DoubleToString(PositionSizing.GetRecommendedLot(), 2));
      Print("Risk: ", DoubleToString(PositionSizing.GetCurrentRiskPercent(), 1), "%");
      Print("Target: ", DoubleToString(PositionSizing.GetCurrentRewardPercent(), 1), "%");
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
   Dashboard.UpdateSignalPanel(signal_status, signal_strength, next_signal);

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
   double win_rate = 0.0;  // Would need to track trade history
   double total_profit = AccountInfoDouble(ACCOUNT_BALANCE) - AccountInfoDouble(ACCOUNT_EQUITY);
   Dashboard.UpdateStatsPanel(signals_today, signals_week, win_rate, total_profit);

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
