//+------------------------------------------------------------------+
//|                                              HFT Gold EA Bot.mq5 |
//|                                    High-Frequency Trading Bot    |
//|                                         For Gold Trading Only    |
//+------------------------------------------------------------------+
#property copyright "HFT Gold EA"
#property link      ""
#property version   "1.00"
#property description "HFT EA Bot designed to grow $5 account to $10k+ over 100 days"
#property description "Breakout strategy with dynamic profit targets"

#include <Trade\Trade.mqh>

// Input Parameters
input group "=== Account & Risk Settings ==="
input double   InitialBalance = 5.0;              // Initial Account Balance ($)
input double   MaxStopLossPips = 150.0;           // Maximum Stop Loss (pips)
input double   RiskPercent = 30.0;                // Risk per trade (%)
input double   InitialLotSize = 0.01;             // Starting Lot Size

input group "=== Daily Profit Targets ==="
input double   DailyProfitTarget_Stage1 = 2.0;    // Stage 1: Daily Target ($2-4)
input double   DailyProfitTarget_Stage2 = 6.0;    // Stage 2: Daily Target ($6)
input double   DailyProfitTarget_Stage3 = 10.0;   // Stage 3: Daily Target ($10+)
input double   BalanceThreshold_Stage2 = 20.0;    // Balance for Stage 2 ($)
input double   BalanceThreshold_Stage3 = 50.0;    // Balance for Stage 3 ($)

input group "=== Breakout Strategy Settings ==="
input int      BreakoutPeriod = 20;               // Breakout Period (bars)
input double   BreakoutBuffer = 5.0;              // Breakout Buffer (pips)
input int      MinBreakoutStrength = 10;          // Min Breakout Strength (pips)
input bool     UseVolatilityFilter = true;        // Use Volatility Filter
input double   MinATR = 15.0;                     // Minimum ATR (pips)

input group "=== Take Profit Settings ==="
input double   TakeProfitMultiplier = 2.0;        // TP Multiplier (x SL)
input bool     UseTrailingStop = true;            // Use Trailing Stop
input double   TrailingStopPips = 30.0;           // Trailing Stop (pips)
input double   TrailingStepPips = 5.0;            // Trailing Step (pips)

input group "=== Time Filter ==="
input bool     UseTimeFilter = true;              // Use Time Filter
input int      StartHour = 2;                     // Start Hour (Server Time)
input int      EndHour = 22;                      // End Hour (Server Time)
input bool     AvoidNews = true;                  // Avoid News Times

input group "=== HFT Settings ==="
input int      MaxTradesPerDay = 10;              // Max Trades Per Day
input int      MinBarsBetweenTrades = 3;          // Min Bars Between Trades
input bool     ScaleProfits = true;               // Scale TP with Balance Growth

input group "=== Display Settings ==="
input bool     ShowDashboard = true;              // Show Dashboard
input color    PanelColor = clrDarkSlateGray;     // Panel Color
input color    TextColor = clrWhite;              // Text Color
input int      FontSize = 9;                      // Font Size

// Global Variables
CTrade trade;
datetime lastTradeTime = 0;
int tradesToday = 0;
datetime currentDay = 0;
double dailyProfit = 0.0;
double sessionStartBalance = 0.0;
double highestBalance = 0.0;

// Dashboard coordinates
int panelX = 20;
int panelY = 30;
int lineHeight = 18;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   // Verify we're trading GOLD
   if(_Symbol != "XAUUSD" && _Symbol != "GOLD" && _Symbol != "XAUUSD.m")
   {
      Alert("This EA is designed for GOLD trading only! Current symbol: ", _Symbol);
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(888777);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);

   sessionStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   highestBalance = sessionStartBalance;

   Print("HFT Gold EA Bot initialized successfully");
   Print("Initial Balance: $", InitialBalance);
   Print("Max SL: ", MaxStopLossPips, " pips (~$", (MaxStopLossPips * InitialLotSize * 0.01), ")");
   Print("Risk per trade: ", RiskPercent, "%");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up dashboard
   ObjectsDeleteAll(0, "HFT_");
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Update daily statistics
   UpdateDailyStats();

   // Check if daily profit target reached
   if(CheckDailyProfitTarget())
   {
      if(ShowDashboard) UpdateDashboard();
      return; // Stop trading for today
   }

   // Check max trades per day
   if(tradesToday >= MaxTradesPerDay)
   {
      if(ShowDashboard) UpdateDashboard();
      return;
   }

   // Time filter
   if(!CheckTimeFilter())
   {
      if(ShowDashboard) UpdateDashboard();
      return;
   }

   // Manage existing positions
   ManagePositions();

   // Check for new trade opportunities
   if(CanOpenNewTrade())
   {
      int signal = GetBreakoutSignal();

      if(signal == 1) // Buy signal
      {
         OpenTrade(ORDER_TYPE_BUY);
      }
      else if(signal == -1) // Sell signal
      {
         OpenTrade(ORDER_TYPE_SELL);
      }
   }

   // Update dashboard
   if(ShowDashboard) UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Update daily statistics                                          |
//+------------------------------------------------------------------+
void UpdateDailyStats()
{
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));

   if(today != currentDay)
   {
      // New day started
      currentDay = today;
      tradesToday = 0;
      sessionStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      dailyProfit = 0.0;
   }
   else
   {
      dailyProfit = AccountInfoDouble(ACCOUNT_BALANCE) - sessionStartBalance;
   }

   // Track highest balance
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(currentBalance > highestBalance)
      highestBalance = currentBalance;
}

//+------------------------------------------------------------------+
//| Check if daily profit target is reached                          |
//+------------------------------------------------------------------+
bool CheckDailyProfitTarget()
{
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double targetProfit = DailyProfitTarget_Stage1;

   // Determine current stage based on balance
   if(currentBalance >= BalanceThreshold_Stage3)
      targetProfit = DailyProfitTarget_Stage3;
   else if(currentBalance >= BalanceThreshold_Stage2)
      targetProfit = DailyProfitTarget_Stage2;

   return (dailyProfit >= targetProfit);
}

//+------------------------------------------------------------------+
//| Check time filter                                                |
//+------------------------------------------------------------------+
bool CheckTimeFilter()
{
   if(!UseTimeFilter) return true;

   MqlDateTime timeStruct;
   TimeCurrent(timeStruct);
   int currentHour = timeStruct.hour;

   if(currentHour < StartHour || currentHour >= EndHour)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Check if we can open a new trade                                 |
//+------------------------------------------------------------------+
bool CanOpenNewTrade()
{
   // Check if we have open positions
   if(PositionsTotal() > 0)
      return false;

   // Check minimum bars between trades
   if(lastTradeTime > 0)
   {
      int barsSinceLastTrade = Bars(_Symbol, PERIOD_CURRENT, lastTradeTime, TimeCurrent());
      if(barsSinceLastTrade < MinBarsBetweenTrades)
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Get breakout signal                                              |
//+------------------------------------------------------------------+
int GetBreakoutSignal()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   // Get highest high and lowest low
   double highestHigh = 0;
   double lowestLow = DBL_MAX;

   for(int i = 1; i <= BreakoutPeriod; i++)
   {
      double high = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low = iLow(_Symbol, PERIOD_CURRENT, i);

      if(high > highestHigh) highestHigh = high;
      if(low < lowestLow) lowestLow = low;
   }

   // Current price
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Calculate breakout levels with buffer
   double bufferPoints = BreakoutBuffer * 10 * point; // Convert pips to points
   double buyLevel = highestHigh + bufferPoints;
   double sellLevel = lowestLow - bufferPoints;

   // Check volatility filter
   if(UseVolatilityFilter)
   {
      double atr = GetATR(14);
      double atrPips = atr / (10 * point);

      if(atrPips < MinATR)
         return 0; // Not enough volatility
   }

   // Check breakout strength
   double breakoutStrength = 0;
   if(ask > buyLevel)
   {
      breakoutStrength = (ask - highestHigh) / (10 * point);
      if(breakoutStrength >= MinBreakoutStrength)
         return 1; // Buy signal
   }
   else if(bid < sellLevel)
   {
      breakoutStrength = (lowestLow - bid) / (10 * point);
      if(breakoutStrength >= MinBreakoutStrength)
         return -1; // Sell signal
   }

   return 0; // No signal
}

//+------------------------------------------------------------------+
//| Get ATR value                                                     |
//+------------------------------------------------------------------+
double GetATR(int period)
{
   double atrArray[];
   ArraySetAsSeries(atrArray, true);

   int atrHandle = iATR(_Symbol, PERIOD_CURRENT, period);
   if(atrHandle == INVALID_HANDLE) return 0;

   if(CopyBuffer(atrHandle, 0, 0, 1, atrArray) <= 0) return 0;

   IndicatorRelease(atrHandle);
   return atrArray[0];
}

//+------------------------------------------------------------------+
//| Open a trade                                                      |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE orderType)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double lotSize = CalculateLotSize();

   // Calculate SL and TP
   double sl = 0, tp = 0;
   double slPips = MaxStopLossPips;
   double tpPips = slPips * TakeProfitMultiplier;

   // Scale TP with balance growth if enabled
   if(ScaleProfits)
   {
      double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(currentBalance > InitialBalance)
      {
         double growthFactor = currentBalance / InitialBalance;
         tpPips *= MathMin(growthFactor, 3.0); // Cap at 3x
      }
   }

   if(orderType == ORDER_TYPE_BUY)
   {
      sl = ask - (slPips * 10 * point);
      tp = ask + (tpPips * 10 * point);

      if(trade.Buy(lotSize, _Symbol, ask, sl, tp, "HFT Gold Breakout Buy"))
      {
         lastTradeTime = TimeCurrent();
         tradesToday++;
         Print("BUY order opened: Lot=", lotSize, " SL=", slPips, " pips, TP=", tpPips, " pips");
      }
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      sl = bid + (slPips * 10 * point);
      tp = bid - (tpPips * 10 * point);

      if(trade.Sell(lotSize, _Symbol, bid, sl, tp, "HFT Gold Breakout Sell"))
      {
         lastTradeTime = TimeCurrent();
         tradesToday++;
         Print("SELL order opened: Lot=", lotSize, " SL=", slPips, " pips, TP=", tpPips, " pips");
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate dynamic lot size                                       |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double balanceGrowth = currentBalance / InitialBalance;

   // Scale lot size with account growth (but start conservative)
   double lotSize = InitialLotSize;

   if(balanceGrowth > 2.0) // Double the balance
      lotSize = InitialLotSize * 1.5;
   else if(balanceGrowth > 5.0) // 5x the balance
      lotSize = InitialLotSize * 2.0;
   else if(balanceGrowth > 10.0) // 10x the balance
      lotSize = InitialLotSize * 3.0;

   // Ensure lot size meets broker requirements
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lotSize = MathMax(lotSize, minLot);
   lotSize = MathMin(lotSize, maxLot);
   lotSize = MathFloor(lotSize / lotStep) * lotStep;

   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManagePositions()
{
   if(!UseTrailingStop) return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != 888777) continue;

      double posOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double posSL = PositionGetDouble(POSITION_SL);
      double posTP = PositionGetDouble(POSITION_TP);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      double currentPrice = (posType == POSITION_TYPE_BUY) ?
                           SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                           SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      double trailPoints = TrailingStopPips * 10 * point;
      double stepPoints = TrailingStepPips * 10 * point;

      if(posType == POSITION_TYPE_BUY)
      {
         double newSL = currentPrice - trailPoints;
         if(newSL > posSL + stepPoints && newSL < currentPrice)
         {
            trade.PositionModify(ticket, newSL, posTP);
         }
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         double newSL = currentPrice + trailPoints;
         if(newSL < posSL - stepPoints && newSL > currentPrice)
         {
            trade.PositionModify(ticket, newSL, posTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update dashboard display                                         |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double currentProfit = dailyProfit;

   // Determine current stage
   string stage = "Stage 1";
   double targetProfit = DailyProfitTarget_Stage1;

   if(currentBalance >= BalanceThreshold_Stage3)
   {
      stage = "Stage 3";
      targetProfit = DailyProfitTarget_Stage3;
   }
   else if(currentBalance >= BalanceThreshold_Stage2)
   {
      stage = "Stage 2";
      targetProfit = DailyProfitTarget_Stage2;
   }

   double progressPercent = (targetProfit > 0) ? (currentProfit / targetProfit) * 100 : 0;

   // Calculate days to goal (rough estimate)
   int daysToGoal = 0;
   if(currentProfit > 0)
   {
      double remainingProfit = 10000 - currentBalance;
      daysToGoal = (int)(remainingProfit / currentProfit);
   }

   // Create panel
   CreateLabel("HFT_Panel_BG", panelX, panelY, "█████████████████████████████████", PanelColor, 11);

   int y = panelY;

   CreateLabel("HFT_Title", panelX + 5, y, "⚡ HFT GOLD EA BOT ⚡", clrGold, FontSize + 2);
   y += lineHeight + 5;

   CreateLabel("HFT_Line1", panelX + 5, y, "━━━━━━━━━━━━━━━━━━━━━━━━━━━", TextColor, FontSize);
   y += lineHeight;

   CreateLabel("HFT_Balance", panelX + 5, y,
               "Balance: $" + DoubleToString(currentBalance, 2) + " | Equity: $" + DoubleToString(equity, 2),
               TextColor, FontSize);
   y += lineHeight;

   CreateLabel("HFT_Growth", panelX + 5, y,
               "Growth: " + DoubleToString((currentBalance / InitialBalance - 1) * 100, 1) + "% | Peak: $" + DoubleToString(highestBalance, 2),
               clrLimeGreen, FontSize);
   y += lineHeight;

   CreateLabel("HFT_Line2", panelX + 5, y, "━━━━━━━━━━━━━━━━━━━━━━━━━━━", TextColor, FontSize);
   y += lineHeight;

   color profitColor = (currentProfit >= 0) ? clrLimeGreen : clrRed;
   CreateLabel("HFT_DailyProfit", panelX + 5, y,
               "Today's P/L: $" + DoubleToString(currentProfit, 2) + " (" + stage + ")",
               profitColor, FontSize);
   y += lineHeight;

   CreateLabel("HFT_Target", panelX + 5, y,
               "Target: $" + DoubleToString(targetProfit, 2) + " | Progress: " + DoubleToString(progressPercent, 1) + "%",
               TextColor, FontSize);
   y += lineHeight;

   CreateLabel("HFT_Line3", panelX + 5, y, "━━━━━━━━━━━━━━━━━━━━━━━━━━━", TextColor, FontSize);
   y += lineHeight;

   CreateLabel("HFT_Trades", panelX + 5, y,
               "Trades Today: " + IntegerToString(tradesToday) + "/" + IntegerToString(MaxTradesPerDay),
               TextColor, FontSize);
   y += lineHeight;

   CreateLabel("HFT_Positions", panelX + 5, y,
               "Open Positions: " + IntegerToString(PositionsTotal()),
               TextColor, FontSize);
   y += lineHeight;

   CreateLabel("HFT_Line4", panelX + 5, y, "━━━━━━━━━━━━━━━━━━━━━━━━━━━", TextColor, FontSize);
   y += lineHeight;

   string status = "🟢 ACTIVE";
   color statusColor = clrLimeGreen;

   if(CheckDailyProfitTarget())
   {
      status = "✓ TARGET REACHED";
      statusColor = clrGold;
   }
   else if(tradesToday >= MaxTradesPerDay)
   {
      status = "⏸ MAX TRADES";
      statusColor = clrOrange;
   }
   else if(!CheckTimeFilter())
   {
      status = "⏰ OUTSIDE HOURS";
      statusColor = clrGray;
   }

   CreateLabel("HFT_Status", panelX + 5, y, "Status: " + status, statusColor, FontSize);
   y += lineHeight;

   if(daysToGoal > 0 && daysToGoal < 500)
   {
      CreateLabel("HFT_Projection", panelX + 5, y,
                  "Est. to $10k: ~" + IntegerToString(daysToGoal) + " days",
                  clrCyan, FontSize - 1);
   }
   else
   {
      CreateLabel("HFT_Projection", panelX + 5, y,
                  "Goal: $10k in ~100 days",
                  clrCyan, FontSize - 1);
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Create label helper function                                     |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int size)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
