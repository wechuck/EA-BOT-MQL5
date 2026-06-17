//+------------------------------------------------------------------+
//|                                        SCALP_GOLD_HFT_V1.mq5    |
//|                            Gold XAUUSD HFT Scalping EA           |
//|                     Capital Protection + Clean Entries            |
//+------------------------------------------------------------------+
//  Handle: n30dyn4m1c
//  Broker: XM Global Ultra Low Standard
//  Strategy: ADX + RSI + Stochastic + Price Action + HTF + Structure
//  Risk: ~23% per trade, ATR-based dynamic SL/TP, profit lock
//  Goal: $20 start, 30% compounding per level, 30 levels
//+------------------------------------------------------------------+
#property copyright "n30dyn4m1c"
#property version   "2.00"
#property description "Gold HFT Scalping EA v2 — multi-layer entry quality"
#property description "HTF trend + Market Structure + ATR dynamic SL/TP"
#property description "News filter + Spread adaptation + Expectancy guard"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+

input group "=== EA CORE ==="
input int      InpMagic            = 240625;       // Magic Number
input string   InpTradeComment     = "n30dyn4m1c"; // Trade Comment / Handle

input group "=== RISK MANAGEMENT ==="
input double   InpRiskPercent      = 23.0;         // Risk Per Trade (% of balance)
input double   InpMinSLPips        = 150.0;        // Minimum Stop Loss Floor (pips)
input double   InpMaxLossPerTrade  = 0.0;          // Max $ Loss Per Trade (0=use % only)
input bool     InpAddSpreadToSL    = true;         // Add Current Spread to SL Distance (only SL)
input double   InpMinRR            = 1.2;          // Min Reward:Risk Ratio (skip if below)

input group "=== ATR-BASED DYNAMIC SL/TP ==="
input bool     InpUseATR           = true;         // Use ATR for Dynamic SL/TP
input int      InpATRPeriod        = 14;           // ATR Period
input double   InpATRSLMult        = 2.0;          // ATR × Multiplier = SL Distance
input double   InpATRTPMult        = 3.0;          // ATR × Multiplier = TP Distance (must be > SL mult)
input double   InpMaxSLPips        = 500.0;        // Maximum SL Cap (pips)
input double   InpMaxTPPips        = 600.0;        // Maximum TP Cap (pips)

input group "=== TAKE PROFIT & PROFIT LOCK ==="
input double   InpTPPips           = 250.0;        // Take Profit — Fixed Mode (pips, > SL+spread)
input double   InpProfitLockAt     = 100.0;        // Lock Profit When Trade Reaches (pips)
input double   InpProfitLockSL     = 50.0;         // Move SL to Entry + This (pips) on Lock
input bool     InpUseTrailing      = true;         // Enable Trailing Stop After Lock
input double   InpTrailDistPips    = 100.0;        // Trailing Distance Behind Price (pips)
input double   InpTrailStepPips    = 20.0;         // Trailing Step — Min Advance to Move SL (pips)

input group "=== HTF TREND FILTER ==="
input bool     InpUseHTF           = true;         // Enable Higher Timeframe Trend Filter
input ENUM_TIMEFRAMES InpHTF1      = PERIOD_M15;   // HTF 1 (fast trend)
input ENUM_TIMEFRAMES InpHTF2      = PERIOD_H1;    // HTF 2 (macro trend)
input int      InpHTF_MA_Fast      = 20;           // Fast MA Period (on HTF)
input int      InpHTF_MA_Slow      = 50;           // Slow MA Period (on HTF)
input ENUM_MA_METHOD InpHTF_MA_Method = MODE_EMA;  // MA Method

input group "=== MARKET STRUCTURE ==="
input bool     InpUseStructure     = true;         // Enable Market Structure Filter (HH/HL/LH/LL)
input int      InpStructureBars    = 20;           // Lookback Bars for Swing Detection
input int      InpSwingStrength    = 3;            // Bars on Each Side to Confirm Swing Point

input group "=== V3: BREAK OF STRUCTURE (BOS) ==="
input bool     InpUseBOS           = true;         // Require Break of Structure for Entry
input bool     InpBOSConfirmOnly   = false;        // BOS as Confirmation (false=hard gate)

input group "=== V3: VOLUME CONFIRMATION ==="
input bool     InpUseVolume        = true;         // Require Above-Average Tick Volume
input int      InpVolAvgPeriod     = 20;           // Volume Average Lookback (bars)
input double   InpVolMult          = 1.2;          // Current Vol Must Exceed Avg × This

input group "=== V3: BREAK-EVEN STAGE ==="
input bool     InpUseBreakEven     = true;         // Move SL to Break-Even Early
input double   InpBreakEvenAt      = 50.0;         // Profit (pips) to Trigger Break-Even
input double   InpBreakEvenLock    = 5.0;          // SL = Entry + This (pips, covers spread)

input group "=== V3: TRADE TIMEOUT ==="
input bool     InpUseTimeout       = true;         // Close Stale Trades After X Bars
input int      InpMaxBarsInTrade   = 60;           // Max Bars a Trade May Stay Open

input group "=== INDICATOR: ADX (session-adaptive) ==="
input int      InpADXPeriod        = 14;           // ADX Period
input double   InpADXAsian         = 22.0;         // Min ADX — Asian Session
input double   InpADXLondon        = 25.0;         // Min ADX — London Session
input double   InpADXNewYork       = 28.0;         // Min ADX — New York Session
input double   InpADXStrongAsian   = 28.0;         // Strong Trend ADX — Asian
input double   InpADXStrongLondon  = 30.0;         // Strong Trend ADX — London
input double   InpADXStrongNY      = 35.0;         // Strong Trend ADX — New York
input bool     InpADXMustRise      = true;         // ADX Must Be Rising (ADX[1] > ADX[2])
input double   InpMinDISeparation  = 5.0;          // Min |DI+ − DI−| for Standard Entry
input double   InpStrongDISep      = 10.0;         // Min |DI+ − DI−| for Strong Trend

input group "=== SESSION HOURS (broker server time) ==="
input int      InpAsianStart       = 0;            // Asian Session Start Hour
input int      InpAsianEnd         = 7;            // Asian Session End Hour
input int      InpLondonStart      = 7;            // London Session Start Hour
input int      InpLondonEnd        = 15;           // London Session End Hour
input int      InpNYStart          = 15;           // New York Session Start Hour
input int      InpNYEnd            = 22;           // New York Session End Hour

input group "=== INDICATOR: RSI ==="
input int      InpRSIPeriod        = 14;           // RSI Period
input double   InpRSIBuyMin        = 35.0;         // RSI Min for BUY
input double   InpRSIBuyMax        = 65.0;         // RSI Max for BUY
input double   InpRSISellMin       = 35.0;         // RSI Min for SELL
input double   InpRSISellMax       = 65.0;         // RSI Max for SELL

input group "=== INDICATOR: STOCHASTIC ==="
input int      InpStochK           = 14;           // Stochastic %K Period
input int      InpStochD           = 3;            // Stochastic %D Smoothing
input int      InpStochSlowing     = 3;            // Stochastic Slowing
input double   InpStochOBLevel     = 75.0;         // Overbought Level (don't BUY above)
input double   InpStochOSLevel     = 25.0;         // Oversold Level (don't SELL below)

input group "=== POSITION RULES ==="
input int      InpMaxPositions     = 1;            // Max Positions (standard)
input int      InpMaxPosStrong     = 2;            // Max Positions (strong trend)
input double   InpMaxMarginPct     = 80.0;         // Max Free Margin Usage (%)
input int      InpLossCooldownBars = 3;            // Bars to Skip After a SL Hit

input group "=== SPREAD FILTER ==="
input double   InpMaxSpreadPips    = 35.0;         // Max Allowed Spread (pips)
input bool     InpSpreadWidening   = true;         // Reject if Spread Widening vs Avg
input double   InpSpreadAvgMult    = 1.5;          // Reject if Current > Avg × This

input group "=== NEWS FILTER ==="
input bool     InpUseNewsFilter    = true;         // Enable News Filter (MQL5 Calendar)
input int      InpNewsMinutesBefore= 30;           // Minutes Before High-Impact Event
input int      InpNewsMinutesAfter = 30;           // Minutes After High-Impact Event
input string   InpNewsCurrencies   = "USD,XAU";    // Currencies to Filter (comma-sep)

input group "=== DAILY PROTECTION ==="
input double   InpMaxDailyLossPct  = 30.0;         // Max Daily Loss (% of day-start balance)
input bool     InpCloseOnDailyLoss = false;         // Close All Positions on Daily Loss Halt
input bool     InpHaltOnDailyLoss  = true;          // Halt New Entries After Daily Loss

input group "=== LEVEL PROGRESSION ==="
input double   InpStartBalance     = 20.0;         // Level 1 Starting Balance ($)
input double   InpLevelGrowthPct   = 30.0;         // Growth Per Level (%)
input int      InpTotalLevels      = 30;           // Total Levels

input group "=== DASHBOARD ==="
input bool     InpShowDashboard    = true;          // Show On-Chart Dashboard
input color    InpColorProfit      = clrLime;       // Profit Color
input color    InpColorLoss        = clrRed;        // Loss Color
input color    InpColorInfo        = clrWhite;      // Info Text Color
input color    InpColorHeader      = clrGold;       // Header Color
input color    InpColorBG          = C'25,25,35';   // Panel Background Color

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
CTrade         g_trade;

// Indicator handles
int            g_adxHandle;
int            g_rsiHandle;
int            g_stochHandle;
int            g_atrHandle;
int            g_htf1_maFast, g_htf1_maSlow;
int            g_htf2_maFast, g_htf2_maSlow;

// Pip calculation
double         g_pipSize;
double         g_pipValue;

// Daily tracking
double         g_dayStartBalance;
double         g_dailyPL;
bool           g_dailyHalted;
datetime       g_currentDay;

// Bar tracking
datetime       g_lastBarTime;

// Level progression
double         g_levelTargets[];
int            g_currentLevel;

// Loss cooldown — deal history based
int            g_barsSinceLoss;
ulong          g_lastDealTicket;

// Spread averaging
double         g_spreadHistory[];
int            g_spreadIdx;
int            g_spreadCount;
#define        SPREAD_HISTORY_SIZE 60

// Dashboard
string         g_dashPrefix = "SHFT_";

//+------------------------------------------------------------------+
//| INITIALIZATION                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Verify Gold symbol
   string sym = _Symbol;
   StringToUpper(sym);
   if(StringFind(sym, "XAU") < 0 && StringFind(sym, "GOLD") < 0)
   {
      Alert("SCALP GOLD HFT: This EA is for GOLD/XAUUSD only! Symbol: ", _Symbol);
      return(INIT_FAILED);
   }

   //--- Trade object setup
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(30);

   //--- Auto-detect filling mode
   long filling = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      g_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      g_trade.SetTypeFilling(ORDER_FILLING_RETURN);

   //--- Pip size
   if(_Digits == 3 || _Digits == 5)
      g_pipSize = _Point * 10.0;
   else
      g_pipSize = _Point;

   //--- Pip value per lot
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize > 0)
      g_pipValue = tickVal * (g_pipSize / tickSize);
   else
      g_pipValue = 1.0;

   //--- Create indicator handles
   g_adxHandle   = iADX(_Symbol, PERIOD_CURRENT, InpADXPeriod);
   g_rsiHandle   = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   g_stochHandle = iStochastic(_Symbol, PERIOD_CURRENT, InpStochK, InpStochD, InpStochSlowing, MODE_SMA, STO_LOWHIGH);
   g_atrHandle   = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);

   if(g_adxHandle == INVALID_HANDLE || g_rsiHandle == INVALID_HANDLE ||
      g_stochHandle == INVALID_HANDLE || g_atrHandle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicator handles!");
      return(INIT_FAILED);
   }

   //--- HTF MA handles
   if(InpUseHTF)
   {
      g_htf1_maFast = iMA(_Symbol, InpHTF1, InpHTF_MA_Fast, 0, InpHTF_MA_Method, PRICE_CLOSE);
      g_htf1_maSlow = iMA(_Symbol, InpHTF1, InpHTF_MA_Slow, 0, InpHTF_MA_Method, PRICE_CLOSE);
      g_htf2_maFast = iMA(_Symbol, InpHTF2, InpHTF_MA_Fast, 0, InpHTF_MA_Method, PRICE_CLOSE);
      g_htf2_maSlow = iMA(_Symbol, InpHTF2, InpHTF_MA_Slow, 0, InpHTF_MA_Method, PRICE_CLOSE);

      if(g_htf1_maFast == INVALID_HANDLE || g_htf1_maSlow == INVALID_HANDLE ||
         g_htf2_maFast == INVALID_HANDLE || g_htf2_maSlow == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create HTF MA handles!");
         return(INIT_FAILED);
      }
   }

   //--- Level progression table
   CalculateLevelTable();

   //--- Daily state
   g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dailyPL         = 0.0;
   g_dailyHalted     = false;
   g_currentDay      = iTime(_Symbol, PERIOD_D1, 0);
   g_lastBarTime     = 0;

   //--- Loss cooldown
   g_barsSinceLoss = 999;
   g_lastDealTicket = 0;

   //--- Spread history
   ArrayResize(g_spreadHistory, SPREAD_HISTORY_SIZE);
   ArrayFill(g_spreadHistory, 0, SPREAD_HISTORY_SIZE, 0.0);
   g_spreadIdx   = 0;
   g_spreadCount = 0;

   //--- Dashboard
   if(InpShowDashboard) CreateDashboard();

   //--- Log startup
   Print("======================================");
   Print("  SCALP GOLD HFT V2 — INITIALIZED");
   Print("  Handle: ", InpTradeComment);
   Print("  Balance: $", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
   Print("  Level: ", g_currentLevel + 1, " / ", InpTotalLevels);
   Print("  Pip Size: ", DoubleToString(g_pipSize, _Digits));
   Print("  Pip Value/Lot: $", DoubleToString(g_pipValue, 4));
   Print("  Risk: ", DoubleToString(InpRiskPercent, 1), "%");
   Print("  ATR SL/TP: ", InpUseATR ? "ON" : "OFF",
         " | HTF: ", InpUseHTF ? "ON" : "OFF",
         " | Structure: ", InpUseStructure ? "ON" : "OFF",
         " | News: ", InpUseNewsFilter ? "ON" : "OFF");
   Print("  Timeframe: ", EnumToString(Period()));
   Print("======================================");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_adxHandle   != INVALID_HANDLE) IndicatorRelease(g_adxHandle);
   if(g_rsiHandle   != INVALID_HANDLE) IndicatorRelease(g_rsiHandle);
   if(g_stochHandle != INVALID_HANDLE) IndicatorRelease(g_stochHandle);
   if(g_atrHandle   != INVALID_HANDLE) IndicatorRelease(g_atrHandle);

   if(InpUseHTF)
   {
      if(g_htf1_maFast != INVALID_HANDLE) IndicatorRelease(g_htf1_maFast);
      if(g_htf1_maSlow != INVALID_HANDLE) IndicatorRelease(g_htf1_maSlow);
      if(g_htf2_maFast != INVALID_HANDLE) IndicatorRelease(g_htf2_maFast);
      if(g_htf2_maSlow != INVALID_HANDLE) IndicatorRelease(g_htf2_maSlow);
   }

   ObjectsDeleteAll(0, g_dashPrefix);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| MAIN TICK FUNCTION                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- New bar detection
   datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool isNewBar = (barTime != g_lastBarTime);
   if(isNewBar)
   {
      g_lastBarTime = barTime;
      g_barsSinceLoss++;
   }

   //--- Detect SL hit via deal history (accurate, not balance-based)
   DetectSLHitFromDeals();

   //--- Update spread history
   double curSpread = GetSpreadPips();
   g_spreadHistory[g_spreadIdx] = curSpread;
   g_spreadIdx = (g_spreadIdx + 1) % SPREAD_HISTORY_SIZE;
   if(g_spreadCount < SPREAD_HISTORY_SIZE) g_spreadCount++;

   //--- New day reset
   datetime dayTime = iTime(_Symbol, PERIOD_D1, 0);
   if(dayTime != g_currentDay)
   {
      g_currentDay      = dayTime;
      g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_dailyPL         = 0.0;
      g_dailyHalted     = false;
      UpdateCurrentLevel();
      Print("=== NEW DAY | Balance: $", DoubleToString(g_dayStartBalance, 2),
            " | Level: ", g_currentLevel + 1, " ===");
   }

   //--- Update daily P&L
   g_dailyPL = AccountInfoDouble(ACCOUNT_BALANCE) - g_dayStartBalance
             + AccountInfoDouble(ACCOUNT_PROFIT);

   //--- Daily loss check
   if(InpHaltOnDailyLoss && !g_dailyHalted)
   {
      double maxLoss = g_dayStartBalance * InpMaxDailyLossPct / 100.0;
      if(g_dailyPL <= -maxLoss)
      {
         g_dailyHalted = true;
         Print("!!! DAILY LOSS LIMIT HIT: $", DoubleToString(MathAbs(g_dailyPL), 2));
         if(InpCloseOnDailyLoss) CloseAllMyPositions("Daily loss limit");
      }
   }

   //--- ALWAYS manage open positions (SL enforcement, profit lock, trailing)
   ManageOpenPositions();

   //--- Entry logic: only on new bar + not halted
   if(isNewBar && !g_dailyHalted)
   {
      //--- Spread filter
      double spreadPips = GetSpreadPips();
      if(spreadPips > InpMaxSpreadPips)
      {
         if(InpShowDashboard) UpdateDashboard();
         return;
      }

      //--- Spread widening check
      if(InpSpreadWidening && IsSpreadWidening())
      {
         if(InpShowDashboard) UpdateDashboard();
         return;
      }

      //--- Loss cooldown check
      if(g_barsSinceLoss < InpLossCooldownBars)
      {
         if(InpShowDashboard) UpdateDashboard();
         return;
      }

      //--- News filter
      if(InpUseNewsFilter && IsNearHighImpactNews())
      {
         if(InpShowDashboard) UpdateDashboard();
         return;
      }

      //--- Check for entry signal
      int signal = CheckEntrySignal();
      if(signal != 0)
         OpenTrade(signal);
   }

   //--- Dashboard
   if(InpShowDashboard) UpdateDashboard();
}

//+------------------------------------------------------------------+
//| DETECT SL HIT FROM DEAL HISTORY (accurate cooldown)              |
//+------------------------------------------------------------------+
void DetectSLHitFromDeals()
{
   if(!HistorySelect(iTime(_Symbol, PERIOD_D1, 0), TimeCurrent()))
      return;

   int totalDeals = HistoryDealsTotal();
   ulong newestSeen = g_lastDealTicket;

   for(int i = totalDeals - 1; i >= 0; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket <= 0) continue;
      if(dealTicket <= g_lastDealTicket) break;   // already processed

      if(dealTicket > newestSeen) newestSeen = dealTicket;

      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagic) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;

      long reason = HistoryDealGetInteger(dealTicket, DEAL_REASON);
      if(reason == DEAL_REASON_SL)
      {
         g_barsSinceLoss = 0;
         Print("SL HIT detected (deal #", dealTicket, ") — cooldown ", InpLossCooldownBars, " bars");
      }
   }

   //--- Advance watermark to newest processed deal
   g_lastDealTicket = newestSeen;
}

//+------------------------------------------------------------------+
//| HTF TREND DIRECTION                                               |
//|  Returns: 1=bullish, -1=bearish, 0=no clear trend                |
//+------------------------------------------------------------------+
int GetHTFTrend()
{
   if(!InpUseHTF) return 0;

   double fast1[], slow1[], fast2[], slow2[];
   ArraySetAsSeries(fast1, true);
   ArraySetAsSeries(slow1, true);
   ArraySetAsSeries(fast2, true);
   ArraySetAsSeries(slow2, true);

   if(CopyBuffer(g_htf1_maFast, 0, 0, 2, fast1) < 2) return 0;
   if(CopyBuffer(g_htf1_maSlow, 0, 0, 2, slow1) < 2) return 0;
   if(CopyBuffer(g_htf2_maFast, 0, 0, 2, fast2) < 2) return 0;
   if(CopyBuffer(g_htf2_maSlow, 0, 0, 2, slow2) < 2) return 0;

   bool htf1Bull = (fast1[0] > slow1[0]);
   bool htf2Bull = (fast2[0] > slow2[0]);

   if(htf1Bull && htf2Bull) return 1;
   if(!htf1Bull && !htf2Bull) return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| MARKET STRUCTURE: detect HH/HL (bull) or LH/LL (bear)            |
//|  Returns: 1=bullish structure, -1=bearish, 0=unclear              |
//+------------------------------------------------------------------+
int GetMarketStructure()
{
   if(!InpUseStructure) return 0;

   int bars = InpStructureBars;
   int str  = InpSwingStrength;

   double highs[], lows[];
   ArrayResize(highs, bars);
   ArrayResize(lows, bars);

   for(int i = 0; i < bars; i++)
   {
      highs[i] = iHigh(_Symbol, PERIOD_CURRENT, i + 1);
      lows[i]  = iLow(_Symbol, PERIOD_CURRENT, i + 1);
   }

   //--- Find last 2 swing highs and 2 swing lows
   double swingHighs[];
   double swingLows[];
   ArrayResize(swingHighs, 0);
   ArrayResize(swingLows, 0);

   for(int i = str; i < bars - str; i++)
   {
      //--- Swing high: bar[i] higher than str bars on both sides
      bool isSwingHigh = true;
      for(int j = 1; j <= str; j++)
      {
         if(highs[i] <= highs[i - j] || highs[i] <= highs[i + j])
         {
            isSwingHigh = false;
            break;
         }
      }
      if(isSwingHigh)
      {
         int sz = ArraySize(swingHighs);
         ArrayResize(swingHighs, sz + 1);
         swingHighs[sz] = highs[i];
         if(ArraySize(swingHighs) >= 2) break;
      }
   }

   for(int i = str; i < bars - str; i++)
   {
      bool isSwingLow = true;
      for(int j = 1; j <= str; j++)
      {
         if(lows[i] >= lows[i - j] || lows[i] >= lows[i + j])
         {
            isSwingLow = false;
            break;
         }
      }
      if(isSwingLow)
      {
         int sz = ArraySize(swingLows);
         ArrayResize(swingLows, sz + 1);
         swingLows[sz] = lows[i];
         if(ArraySize(swingLows) >= 2) break;
      }
   }

   if(ArraySize(swingHighs) < 2 || ArraySize(swingLows) < 2)
      return 0;

   //--- [0] = most recent, [1] = older
   bool higherHigh = (swingHighs[0] > swingHighs[1]);
   bool higherLow  = (swingLows[0] > swingLows[1]);
   bool lowerHigh  = (swingHighs[0] < swingHighs[1]);
   bool lowerLow   = (swingLows[0] < swingLows[1]);

   if(higherHigh && higherLow)  return 1;    // Bullish structure (HH + HL)
   if(lowerHigh && lowerLow)    return -1;   // Bearish structure (LH + LL)

   return 0;
}

//+------------------------------------------------------------------+
//| FIND NEAREST CONFIRMED SWING HIGH & LOW                          |
//|  Outputs most recent swing high/low values. Returns false if     |
//|  not enough swings found.                                         |
//+------------------------------------------------------------------+
bool FindNearestSwings(double &swingHigh, double &swingLow)
{
   int bars = InpStructureBars;
   int str  = InpSwingStrength;

   double highs[], lows[];
   ArrayResize(highs, bars);
   ArrayResize(lows, bars);
   for(int i = 0; i < bars; i++)
   {
      highs[i] = iHigh(_Symbol, PERIOD_CURRENT, i + 1);
      lows[i]  = iLow(_Symbol, PERIOD_CURRENT, i + 1);
   }

   bool gotHigh = false, gotLow = false;
   swingHigh = 0; swingLow = 0;

   for(int i = str; i < bars - str && !gotHigh; i++)
   {
      bool isSwingHigh = true;
      for(int j = 1; j <= str; j++)
         if(highs[i] <= highs[i - j] || highs[i] <= highs[i + j]) { isSwingHigh = false; break; }
      if(isSwingHigh) { swingHigh = highs[i]; gotHigh = true; }
   }

   for(int i = str; i < bars - str && !gotLow; i++)
   {
      bool isSwingLow = true;
      for(int j = 1; j <= str; j++)
         if(lows[i] >= lows[i - j] || lows[i] >= lows[i + j]) { isSwingLow = false; break; }
      if(isSwingLow) { swingLow = lows[i]; gotLow = true; }
   }

   return (gotHigh && gotLow);
}

//+------------------------------------------------------------------+
//| BREAK OF STRUCTURE (BOS)                                          |
//|  Bull BOS: last closed bar closes ABOVE most recent swing high.  |
//|  Bear BOS: last closed bar closes BELOW most recent swing low.   |
//|  Returns: 1=bull BOS, -1=bear BOS, 0=none                         |
//+------------------------------------------------------------------+
int GetBOS()
{
   double swingHigh, swingLow;
   if(!FindNearestSwings(swingHigh, swingLow)) return 0;

   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);

   if(close1 > swingHigh) return 1;
   if(close1 < swingLow)  return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| VOLUME CONFIRMATION — current tick volume above rolling avg       |
//+------------------------------------------------------------------+
bool VolumeConfirmed()
{
   if(!InpUseVolume) return true;

   long vols[];
   ArraySetAsSeries(vols, true);
   int need = InpVolAvgPeriod + 2;
   if(CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, need, vols) < need)
      return true;   // not enough data — don't block

   //--- Average of bars [2 .. period+1], compare current closed bar [1]
   double sum = 0;
   for(int i = 2; i <= InpVolAvgPeriod + 1; i++)
      sum += (double)vols[i];
   double avg = sum / InpVolAvgPeriod;
   if(avg <= 0) return true;

   return ((double)vols[1] >= avg * InpVolMult);
}

//+------------------------------------------------------------------+
//| NEWS FILTER — check MQL5 economic calendar                       |
//+------------------------------------------------------------------+
bool IsNearHighImpactNews()
{
   datetime now = TimeCurrent();
   datetime from = now - InpNewsMinutesBefore * 60;
   datetime to   = now + InpNewsMinutesAfter * 60;

   MqlCalendarValue values[];
   int count = CalendarValueHistory(values, from, to);
   if(count <= 0) return false;

   for(int i = 0; i < count; i++)
   {
      MqlCalendarEvent event;
      if(!CalendarEventById(values[i].event_id, event))
         continue;

      //--- Only high importance
      if(event.importance != CALENDAR_IMPORTANCE_HIGH)
         continue;

      //--- Check if event currency matches our filter
      MqlCalendarCountry country;
      if(!CalendarCountryById(event.country_id, country))
         continue;

      string evCurrency = country.currency;
      StringToUpper(evCurrency);

      //--- Parse our filter currencies
      string currencies = InpNewsCurrencies;
      StringToUpper(currencies);

      if(StringFind(currencies, evCurrency) >= 0)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| SPREAD WIDENING CHECK                                             |
//+------------------------------------------------------------------+
bool IsSpreadWidening()
{
   if(g_spreadCount < 10) return false;

   double sum = 0;
   int cnt = MathMin(g_spreadCount, SPREAD_HISTORY_SIZE);
   for(int i = 0; i < cnt; i++)
      sum += g_spreadHistory[i];
   double avg = sum / cnt;

   double current = GetSpreadPips();
   return (current > avg * InpSpreadAvgMult);
}

//+------------------------------------------------------------------+
//| GET ATR VALUE IN PIPS                                             |
//+------------------------------------------------------------------+
double GetATRPips()
{
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_atrHandle, 0, 0, 2, atr) < 2) return 0;
   return atr[1] / g_pipSize;
}

//+------------------------------------------------------------------+
//| SIGNAL DETECTION                                                  |
//|  Returns: 0=none, +1=BUY standard, +2=BUY strong,               |
//|           -1=SELL standard, -2=SELL strong                        |
//+------------------------------------------------------------------+
int CheckEntrySignal()
{
   //--- Read ADX buffers
   double adxMain[], diPlus[], diMinus[];
   ArraySetAsSeries(adxMain, true);
   ArraySetAsSeries(diPlus, true);
   ArraySetAsSeries(diMinus, true);
   if(CopyBuffer(g_adxHandle, 0, 0, 3, adxMain)  < 3) return 0;
   if(CopyBuffer(g_adxHandle, 1, 0, 3, diPlus)   < 3) return 0;
   if(CopyBuffer(g_adxHandle, 2, 0, 3, diMinus)  < 3) return 0;

   //--- Read RSI
   double rsi[];
   ArraySetAsSeries(rsi, true);
   if(CopyBuffer(g_rsiHandle, 0, 0, 3, rsi) < 3) return 0;

   //--- Read Stochastic
   double stK[], stD[];
   ArraySetAsSeries(stK, true);
   ArraySetAsSeries(stD, true);
   if(CopyBuffer(g_stochHandle, 0, 0, 3, stK) < 3) return 0;
   if(CopyBuffer(g_stochHandle, 1, 0, 3, stD) < 3) return 0;

   //--- Determine current session and ADX thresholds
   MqlDateTime dt;
   TimeCurrent(dt);
   int hour = dt.hour;

   double adxMin    = InpADXLondon;
   double adxStrong = InpADXStrongLondon;

   if(hour >= InpNYStart && hour < InpNYEnd)
   {
      adxMin   = InpADXNewYork;
      adxStrong = InpADXStrongNY;
   }
   else if(hour >= InpLondonStart && hour < InpLondonEnd)
   {
      adxMin   = InpADXLondon;
      adxStrong = InpADXStrongLondon;
   }
   else if(hour >= InpAsianStart && hour < InpAsianEnd)
   {
      adxMin   = InpADXAsian;
      adxStrong = InpADXStrongAsian;
   }

   //--- GATE 1: ADX absolute floor
   if(adxMain[1] < 20.0) return 0;

   //--- GATE 2: ADX session minimum
   if(adxMain[1] < adxMin) return 0;

   //--- GATE 3: ADX must be RISING
   if(InpADXMustRise && adxMain[1] <= adxMain[2]) return 0;

   //--- GATE 4: DI direction
   double diSpread = diPlus[1] - diMinus[1];
   bool bullishDI  = (diSpread >= InpMinDISeparation);
   bool bearishDI  = (-diSpread >= InpMinDISeparation);
   if(!bullishDI && !bearishDI) return 0;

   int direction = bullishDI ? 1 : -1;

   //--- GATE 5: HTF trend alignment
   if(InpUseHTF)
   {
      int htfTrend = GetHTFTrend();
      if(htfTrend != 0 && htfTrend != direction) return 0;
   }

   //--- GATE 6: Market structure alignment
   if(InpUseStructure)
   {
      int structure = GetMarketStructure();
      if(structure != 0 && structure != direction) return 0;
   }

   //--- GATE 7: Break of Structure (BOS) — hard gate unless confirm-only mode
   int bos = 0;
   if(InpUseBOS)
   {
      bos = GetBOS();
      if(!InpBOSConfirmOnly && bos != direction) return 0;
   }

   //--- GATE 8: Volume confirmation (above-average participation)
   if(!VolumeConfirmed()) return 0;

   //--- Score confirmations (need 2 of 3, +1 if BOS confirm-only)
   int confirms = 0;

   //--- BOS as a confirmation when in confirm-only mode
   if(InpUseBOS && InpBOSConfirmOnly && bos == direction)
      confirms++;

   //--- RSI confirmation
   if(bullishDI && rsi[1] > InpRSIBuyMin && rsi[1] < InpRSIBuyMax)
      confirms++;
   if(bearishDI && rsi[1] > InpRSISellMin && rsi[1] < InpRSISellMax)
      confirms++;

   //--- Stochastic confirmation (zone + fresh cross)
   if(bullishDI)
   {
      bool kAboveD    = (stK[1] > stD[1]);
      bool notOB      = (stK[1] < InpStochOBLevel);
      bool freshCross = (stK[2] <= stD[2]);
      if(kAboveD && notOB && freshCross) confirms++;
   }
   if(bearishDI)
   {
      bool kBelowD    = (stK[1] < stD[1]);
      bool notOS      = (stK[1] > InpStochOSLevel);
      bool freshCross = (stK[2] >= stD[2]);
      if(kBelowD && notOS && freshCross) confirms++;
   }

   //--- Price action confirmation
   double open1  = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double high1  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low1   = iLow(_Symbol, PERIOD_CURRENT, 1);
   double body   = MathAbs(close1 - open1);
   double range  = high1 - low1;

   if(range > 0 && (body / range) >= 0.40)
   {
      if(bullishDI && close1 > open1) confirms++;
      if(bearishDI && close1 < open1) confirms++;
   }

   //--- Need minimum 2 confirmations
   if(confirms < 2) return 0;

   //--- Determine signal strength
   bool strong = (confirms >= 3)
              && (adxMain[1] >= adxStrong)
              && (MathAbs(diSpread) >= InpStrongDISep);

   if(bullishDI) return strong ? 2 : 1;
   if(bearishDI) return strong ? -2 : -1;

   return 0;
}

//+------------------------------------------------------------------+
//| OPEN TRADE                                                        |
//+------------------------------------------------------------------+
bool OpenTrade(int signal)
{
   if(signal == 0) return false;

   int direction = (signal > 0) ? 1 : -1;
   bool isStrong = (MathAbs(signal) == 2);

   //--- Position limits
   int posCount = CountMyPositions();
   int posDir   = GetMyPositionDirection();

   if(posCount >= InpMaxPosStrong)                          return false;
   if(posCount >= InpMaxPositions && !isStrong)             return false;
   if(posCount > 0 && posDir != 0 && posDir != direction)  return false;
   if(posCount > 0 && posDir == direction && !isStrong)     return false;

   //--- Spread check
   double spreadPips = GetSpreadPips();
   if(spreadPips > InpMaxSpreadPips) return false;

   //--- Calculate SL/TP distances
   double slPipsBase, tpPipsBase;

   if(InpUseATR)
   {
      double atrPips = GetATRPips();
      if(atrPips <= 0) return false;

      slPipsBase = atrPips * InpATRSLMult;
      tpPipsBase = atrPips * InpATRTPMult;

      //--- Apply floors and caps
      if(slPipsBase < InpMinSLPips) slPipsBase = InpMinSLPips;
      if(slPipsBase > InpMaxSLPips) slPipsBase = InpMaxSLPips;
      if(tpPipsBase > InpMaxTPPips) tpPipsBase = InpMaxTPPips;
   }
   else
   {
      slPipsBase = InpMinSLPips;
      tpPipsBase = InpTPPips;
   }

   //--- Add spread to SL
   double slPips = slPipsBase;
   if(InpAddSpreadToSL)
      slPips += spreadPips;

   //--- TP: spread is NOT applied to TP — only SL carries the spread buffer.
   //--- ATR TP mult (3.0) > SL mult (2.0) guarantees TP distance > SL distance.
   double tpPips = tpPipsBase;
   if(tpPips < 50.0) tpPips = 50.0;

   //--- EXPECTANCY GUARD: check minimum R:R ratio
   double rr = tpPips / slPips;
   if(rr < InpMinRR)
   {
      Print("R:R SKIP: ", DoubleToString(rr, 2), " < min ", DoubleToString(InpMinRR, 2),
            " (SL:", DoubleToString(slPips, 1), " TP:", DoubleToString(tpPips, 1), ")");
      return false;
   }

   //--- Calculate risk
   double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskDollars = balance * InpRiskPercent / 100.0;

   if(InpMaxLossPerTrade > 0 && riskDollars > InpMaxLossPerTrade)
      riskDollars = InpMaxLossPerTrade;

   //--- Lot size from risk and SL
   double lotSize = riskDollars / (slPipsBase * g_pipValue);
   lotSize = NormalizeLots(lotSize);
   if(lotSize <= 0) return false;

   //--- MARGIN CHECK
   {
      double marginReq = 0;
      double checkPrice = (direction == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                           : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      ENUM_ORDER_TYPE orderType = (direction == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

      if(!OrderCalcMargin(orderType, _Symbol, lotSize, checkPrice, marginReq))
         return false;

      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      double usableMargin = freeMargin * InpMaxMarginPct / 100.0;

      if(marginReq > usableMargin)
      {
         double reducedLots = NormalizeLots(lotSize * usableMargin / marginReq);
         if(reducedLots <= 0)
         {
            double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            double minMargin = 0;
            if(!OrderCalcMargin(orderType, _Symbol, minVol, checkPrice, minMargin))
               minMargin = 0;
            Print("MARGIN SKIP: Need $", DoubleToString(minMargin, 2),
                  " for min lot ", DoubleToString(minVol, 2),
                  " but only $", DoubleToString(freeMargin, 2), " free");
            return false;
         }
         lotSize = reducedLots;
         riskDollars = lotSize * slPipsBase * g_pipValue;
      }
   }

   //--- Price levels
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double slDist = slPips * g_pipSize;
   double tpDist = tpPips * g_pipSize;

   bool result = false;

   if(direction == 1)
   {
      double sl = NormalizeDouble(ask - slDist, _Digits);
      double tp = NormalizeDouble(ask + tpDist, _Digits);
      result = g_trade.Buy(lotSize, _Symbol, ask, sl, tp, InpTradeComment);
      if(result)
         Print(">>> BUY ", DoubleToString(lotSize, 2), " @ ", DoubleToString(ask, _Digits),
               " | SL:", DoubleToString(sl, _Digits), "(", DoubleToString(slPips, 0), "p)",
               " | TP:", DoubleToString(tp, _Digits), "(", DoubleToString(tpPips, 0), "p)",
               " | Risk:$", DoubleToString(riskDollars, 2),
               " | R:R 1:", DoubleToString(rr, 2),
               isStrong ? " [STRONG]" : "");
   }
   else
   {
      double sl = NormalizeDouble(bid + slDist, _Digits);
      double tp = NormalizeDouble(bid - tpDist, _Digits);
      result = g_trade.Sell(lotSize, _Symbol, bid, sl, tp, InpTradeComment);
      if(result)
         Print(">>> SELL ", DoubleToString(lotSize, 2), " @ ", DoubleToString(bid, _Digits),
               " | SL:", DoubleToString(sl, _Digits), "(", DoubleToString(slPips, 0), "p)",
               " | TP:", DoubleToString(tp, _Digits), "(", DoubleToString(tpPips, 0), "p)",
               " | Risk:$", DoubleToString(riskDollars, 2),
               " | R:R 1:", DoubleToString(rr, 2),
               isStrong ? " [STRONG]" : "");
   }

   if(!result)
      Print("!!! Trade failed: ", g_trade.ResultRetcodeDescription());

   return result;
}

//+------------------------------------------------------------------+
//| MANAGE OPEN POSITIONS                                             |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      double openPrice  = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL  = PositionGetDouble(POSITION_SL);
      double currentTP  = PositionGetDouble(POSITION_TP);
      long   posType    = PositionGetInteger(POSITION_TYPE);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

      //--- TRADE TIMEOUT: close stale trades that never resolved
      if(InpUseTimeout && InpMaxBarsInTrade > 0)
      {
         int secsPerBar = PeriodSeconds(PERIOD_CURRENT);
         if(secsPerBar > 0)
         {
            int barsOpen = (int)((TimeCurrent() - openTime) / secsPerBar);
            if(barsOpen >= InpMaxBarsInTrade)
            {
               g_trade.PositionClose(ticket);
               Print("TIMEOUT: ticket ", ticket, " closed after ", barsOpen, " bars");
               continue;
            }
         }
      }

      double currentPrice = (posType == POSITION_TYPE_BUY)
                            ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                            : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      //--- ENFORCE SL: every position MUST have a stop loss
      if(currentSL == 0 || currentSL < 0.001)
      {
         double slDist = InpMinSLPips * g_pipSize;
         double newSL;
         if(posType == POSITION_TYPE_BUY)
            newSL = NormalizeDouble(openPrice - slDist, _Digits);
         else
            newSL = NormalizeDouble(openPrice + slDist, _Digits);
         g_trade.PositionModify(ticket, newSL, currentTP);
         Print("!!! SL ENFORCED on ticket ", ticket);
         continue;
      }

      //--- Calculate profit in pips
      double profitPips;
      if(posType == POSITION_TYPE_BUY)
         profitPips = (currentPrice - openPrice) / g_pipSize;
      else
         profitPips = (openPrice - currentPrice) / g_pipSize;

      //--- BREAK-EVEN STAGE: remove risk early (before full profit lock)
      if(InpUseBreakEven && profitPips >= InpBreakEvenAt && profitPips < InpProfitLockAt)
      {
         double beSL;
         if(posType == POSITION_TYPE_BUY)
         {
            beSL = NormalizeDouble(openPrice + InpBreakEvenLock * g_pipSize, _Digits);
            if(currentSL < beSL)
            {
               g_trade.PositionModify(ticket, beSL, currentTP);
               Print("BREAK-EVEN: ticket ", ticket, " SL -> entry +",
                     DoubleToString(InpBreakEvenLock, 0), " pips");
            }
         }
         else
         {
            beSL = NormalizeDouble(openPrice - InpBreakEvenLock * g_pipSize, _Digits);
            if(currentSL == 0 || currentSL > beSL)
            {
               g_trade.PositionModify(ticket, beSL, currentTP);
               Print("BREAK-EVEN: ticket ", ticket, " SL -> entry +",
                     DoubleToString(InpBreakEvenLock, 0), " pips");
            }
         }
      }

      //--- PROFIT LOCK
      if(profitPips >= InpProfitLockAt)
      {
         double lockSL;
         if(posType == POSITION_TYPE_BUY)
         {
            lockSL = NormalizeDouble(openPrice + InpProfitLockSL * g_pipSize, _Digits);
            if(currentSL < lockSL)
            {
               g_trade.PositionModify(ticket, lockSL, currentTP);
               Print("PROFIT LOCK: ticket ", ticket, " SL -> entry +",
                     DoubleToString(InpProfitLockSL, 0), " pips");
            }
         }
         else
         {
            lockSL = NormalizeDouble(openPrice - InpProfitLockSL * g_pipSize, _Digits);
            if(currentSL > lockSL)
            {
               g_trade.PositionModify(ticket, lockSL, currentTP);
               Print("PROFIT LOCK: ticket ", ticket, " SL -> entry +",
                     DoubleToString(InpProfitLockSL, 0), " pips");
            }
         }
      }

      //--- TRAILING STOP: after profit lock is active
      if(InpUseTrailing && profitPips >= InpProfitLockAt)
      {
         double trailSL;
         if(posType == POSITION_TYPE_BUY)
         {
            trailSL = NormalizeDouble(currentPrice - InpTrailDistPips * g_pipSize, _Digits);
            if(trailSL > currentSL + InpTrailStepPips * g_pipSize)
               g_trade.PositionModify(ticket, trailSL, currentTP);
         }
         else
         {
            trailSL = NormalizeDouble(currentPrice + InpTrailDistPips * g_pipSize, _Digits);
            if(trailSL < currentSL - InpTrailStepPips * g_pipSize)
               g_trade.PositionModify(ticket, trailSL, currentTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| HELPER: get lot size from open position ticket                    |
//+------------------------------------------------------------------+
double lotSizeFromTicket(ulong ticket)
{
   if(PositionSelectByTicket(ticket))
      return PositionGetDouble(POSITION_VOLUME);
   return 0.01;
}

//+------------------------------------------------------------------+
//| COUNT POSITIONS WITH OUR MAGIC                                    |
//+------------------------------------------------------------------+
int CountMyPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == InpMagic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| GET DIRECTION OF FIRST OPEN POSITION                              |
//+------------------------------------------------------------------+
int GetMyPositionDirection()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == InpMagic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         long type = PositionGetInteger(POSITION_TYPE);
         return (type == POSITION_TYPE_BUY) ? 1 : -1;
      }
   }
   return 0;
}

//+------------------------------------------------------------------+
//| CLOSE ALL POSITIONS WITH OUR MAGIC                                |
//+------------------------------------------------------------------+
void CloseAllMyPositions(string reason)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) == InpMagic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         g_trade.PositionClose(ticket);
         Print("Closed ticket ", ticket, " — ", reason);
      }
   }
}

//+------------------------------------------------------------------+
//| PIP & SPREAD UTILITIES                                            |
//+------------------------------------------------------------------+
double GetSpreadPips()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (ask - bid) / g_pipSize;
}

double NormalizeLots(double lots)
{
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(step > 0)
      lots = MathFloor(lots / step) * step;
   lots = MathMax(lots, minVol);
   lots = MathMin(lots, maxVol);
   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//| LEVEL PROGRESSION                                                 |
//+------------------------------------------------------------------+
void CalculateLevelTable()
{
   ArrayResize(g_levelTargets, InpTotalLevels + 1);
   g_levelTargets[0] = InpStartBalance;
   for(int i = 1; i <= InpTotalLevels; i++)
      g_levelTargets[i] = NormalizeDouble(g_levelTargets[i - 1] * (1.0 + InpLevelGrowthPct / 100.0), 2);

   UpdateCurrentLevel();

   Print("--- LEVEL TABLE ---");
   for(int i = 0; i <= InpTotalLevels; i++)
      Print("  Level ", i + 1, ": $", DoubleToString(g_levelTargets[i], 2));
}

void UpdateCurrentLevel()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_currentLevel = 0;
   for(int i = InpTotalLevels; i >= 0; i--)
   {
      if(balance >= g_levelTargets[i])
      {
         g_currentLevel = i;
         break;
      }
   }
}

double GetLevelTarget()
{
   int next = g_currentLevel + 1;
   if(next > InpTotalLevels) return g_levelTargets[InpTotalLevels];
   return g_levelTargets[next];
}

double GetLevelProgress()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double current = g_levelTargets[g_currentLevel];
   double target  = GetLevelTarget();
   if(target <= current) return 100.0;
   return MathMin(100.0, (balance - current) / (target - current) * 100.0);
}

//+------------------------------------------------------------------+
//| DASHBOARD                                                         |
//+------------------------------------------------------------------+
void CreateDashboard()
{
   int panelW = 300;
   int panelH = 340;
   int panelX = 15;
   int panelY = 30;

   string bgName = g_dashPrefix + "BG";
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, panelX);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, panelY);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, panelW);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, panelH);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, InpColorBG);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, clrGold);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);

   int x = panelX + 12;
   int y = panelY + 8;
   int lineH = 18;

   DashLabel("Title",     x, y, "SCALP GOLD HFT V3", InpColorHeader, 10, true);   y += lineH + 4;
   DashLabel("Handle",    x, y, "Handle: n30dyn4m1c", InpColorInfo, 8, false);     y += lineH;
   DashLabel("Sep1",      x, y, "────────────────────────────", clrDimGray, 7, false); y += lineH - 4;
   DashLabel("Balance",   x, y, "Balance: ---", InpColorInfo, 9, false);            y += lineH;
   DashLabel("Level",     x, y, "Level: ---", InpColorInfo, 9, false);              y += lineH;
   DashLabel("Target",    x, y, "Target: ---", InpColorInfo, 9, false);             y += lineH;
   DashLabel("Progress",  x, y, "Progress: ---", InpColorInfo, 9, false);           y += lineH;
   DashLabel("DailyPL",   x, y, "Daily P&L: ---", InpColorInfo, 9, false);          y += lineH;
   DashLabel("Positions", x, y, "Positions: ---", InpColorInfo, 9, false);           y += lineH;
   DashLabel("Spread",    x, y, "Spread: ---", InpColorInfo, 9, false);              y += lineH;
   DashLabel("ATR",       x, y, "ATR: ---", InpColorInfo, 9, false);                y += lineH;
   DashLabel("HTF",       x, y, "HTF: ---", InpColorInfo, 9, false);                y += lineH;
   DashLabel("Structure", x, y, "Structure: ---", InpColorInfo, 9, false);           y += lineH;
   DashLabel("BOS",       x, y, "BOS: ---", InpColorInfo, 9, false);                 y += lineH;
   DashLabel("Volume",    x, y, "Volume: ---", InpColorInfo, 9, false);              y += lineH;
   DashLabel("Status",    x, y, "Status: ---", InpColorInfo, 9, true);               y += lineH;

   ChartRedraw();
}

void UpdateDashboard()
{
   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   double spread   = GetSpreadPips();
   int    posCount = CountMyPositions();

   DashUpdate("Balance", "Balance: $" + DoubleToString(balance, 2)
              + " (Eq: $" + DoubleToString(equity, 2) + ")",
              (equity >= balance) ? InpColorProfit : InpColorLoss);

   DashUpdate("Level", "Level: " + IntegerToString(g_currentLevel + 1) + " / " + IntegerToString(InpTotalLevels),
              InpColorInfo);

   DashUpdate("Target", "Target: $" + DoubleToString(GetLevelTarget(), 2), InpColorHeader);

   double prog = GetLevelProgress();
   DashUpdate("Progress", "Progress: " + DoubleToString(prog, 1) + "%",
              (prog >= 50) ? InpColorProfit : InpColorInfo);

   DashUpdate("DailyPL", "Daily P&L: $" + DoubleToString(g_dailyPL, 2),
              (g_dailyPL >= 0) ? InpColorProfit : InpColorLoss);

   DashUpdate("Positions", "Positions: " + IntegerToString(posCount)
              + " / " + IntegerToString(g_dailyHalted ? 0 : InpMaxPositions),
              InpColorInfo);

   string spreadStatus = (spread <= InpMaxSpreadPips) ? " OK" : " HIGH";
   DashUpdate("Spread", "Spread: " + DoubleToString(spread, 1) + " pips" + spreadStatus,
              (spread <= InpMaxSpreadPips) ? InpColorProfit : InpColorLoss);

   //--- ATR
   double atrPips = GetATRPips();
   DashUpdate("ATR", "ATR: " + DoubleToString(atrPips, 1) + " pips"
              + (InpUseATR ? " (dynamic SL/TP)" : " (fixed)"), InpColorInfo);

   //--- HTF trend
   string htfText = "HTF: ";
   if(InpUseHTF)
   {
      int htf = GetHTFTrend();
      htfText += (htf == 1) ? "BULLISH" : (htf == -1) ? "BEARISH" : "MIXED";
      DashUpdate("HTF", htfText, (htf == 1) ? InpColorProfit : (htf == -1) ? InpColorLoss : InpColorInfo);
   }
   else
      DashUpdate("HTF", "HTF: OFF", clrDimGray);

   //--- Market structure
   string strText = "Structure: ";
   if(InpUseStructure)
   {
      int str = GetMarketStructure();
      strText += (str == 1) ? "HH/HL (bull)" : (str == -1) ? "LH/LL (bear)" : "unclear";
      DashUpdate("Structure", strText, (str == 1) ? InpColorProfit : (str == -1) ? InpColorLoss : InpColorInfo);
   }
   else
      DashUpdate("Structure", "Structure: OFF", clrDimGray);

   //--- BOS (Break of Structure)
   if(InpUseBOS)
   {
      int bos = GetBOS();
      string bosText = "BOS: " + ((bos == 1) ? "BULL break" : (bos == -1) ? "BEAR break" : "none");
      DashUpdate("BOS", bosText, (bos == 1) ? InpColorProfit : (bos == -1) ? InpColorLoss : InpColorInfo);
   }
   else
      DashUpdate("BOS", "BOS: OFF", clrDimGray);

   //--- Volume confirmation
   if(InpUseVolume)
   {
      bool volOK = VolumeConfirmed();
      DashUpdate("Volume", "Volume: " + (volOK ? "above avg" : "below avg"),
                 volOK ? InpColorProfit : InpColorLoss);
   }
   else
      DashUpdate("Volume", "Volume: OFF", clrDimGray);

   //--- Status
   string status;
   color  statusClr;
   if(g_dailyHalted)
   {
      status    = "Status: HALTED (daily loss)";
      statusClr = InpColorLoss;
   }
   else if(posCount > 0)
   {
      status    = "Status: IN TRADE";
      statusClr = InpColorHeader;
   }
   else
   {
      status    = "Status: SCANNING";
      statusClr = InpColorProfit;
   }
   DashUpdate("Status", status, statusClr);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| DASHBOARD HELPERS                                                 |
//+------------------------------------------------------------------+
void DashLabel(string name, int x, int y, string text, color clr, int fontSize, bool bold)
{
   string objName = g_dashPrefix + name;
   ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetString(0, objName, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
}

void DashUpdate(string name, string text, color clr)
{
   string objName = g_dashPrefix + name;
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
}
//+------------------------------------------------------------------+
//| END OF EA                                                         |
//+------------------------------------------------------------------+
