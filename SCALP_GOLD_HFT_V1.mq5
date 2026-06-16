//+------------------------------------------------------------------+
//|                                        SCALP_GOLD_HFT_V1.mq5    |
//|                            Gold XAUUSD HFT Scalping EA           |
//|                     Capital Protection + Clean Entries            |
//+------------------------------------------------------------------+
//  Handle: n30dyn4m1c
//  Broker: XM Global Ultra Low Standard
//  Strategy: ADX + RSI + Stochastic + Price Action confluence
//  Risk: ~23% per trade, SL min 150 pips + spread, profit lock at +200
//  Goal: $20 start, 30% compounding per level, 30 levels
//+------------------------------------------------------------------+
#property copyright "n30dyn4m1c"
#property version   "1.00"
#property description "Gold HFT Scalping EA with capital protection"
#property description "ADX + RSI + Stochastic + Price Action confluence"
#property description "Level progression: $20 start, 30% per level"
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
input double   InpMinSLPips        = 150.0;        // Minimum Stop Loss (pips)
input double   InpMaxLossPerTrade  = 0.0;          // Max $ Loss Per Trade (0=use % only)
input bool     InpAddSpreadToSL    = true;         // Add Current Spread to SL Distance

input group "=== TAKE PROFIT & PROFIT LOCK ==="
input double   InpTPPips           = 200.0;        // Take Profit (pips)
input double   InpProfitLockAt     = 200.0;        // Lock Profit When Trade Reaches (pips)
input double   InpProfitLockSL     = 50.0;         // Move SL to Entry + This (pips) on Lock
input bool     InpUseTrailing      = true;         // Enable Trailing Stop After Lock
input double   InpTrailDistPips    = 100.0;        // Trailing Distance Behind Price (pips)
input double   InpTrailStepPips    = 20.0;         // Trailing Step — Min Advance to Move SL (pips)

input group "=== INDICATOR: ADX ==="
input int      InpADXPeriod        = 14;           // ADX Period
input double   InpADXMinLevel      = 20.0;         // Min ADX for Entry (trend exists)
input double   InpADXStrongLevel   = 30.0;         // ADX Level for Strong Trend (2nd trade)
input double   InpMinDISeparation  = 5.0;          // Min |DI+ − DI−| for Standard Entry
input double   InpStrongDISep      = 10.0;         // Min |DI+ − DI−| for Strong Trend

input group "=== INDICATOR: RSI ==="
input int      InpRSIPeriod        = 14;           // RSI Period
input double   InpRSIBuyMin        = 35.0;         // RSI Min for BUY (avoid oversold trap)
input double   InpRSIBuyMax        = 75.0;         // RSI Max for BUY (avoid overbought)
input double   InpRSISellMin       = 25.0;         // RSI Min for SELL (avoid oversold)
input double   InpRSISellMax       = 65.0;         // RSI Max for SELL (avoid overbought trap)

input group "=== INDICATOR: STOCHASTIC ==="
input int      InpStochK           = 14;           // Stochastic %K Period
input int      InpStochD           = 3;            // Stochastic %D Smoothing
input int      InpStochSlowing     = 3;            // Stochastic Slowing

input group "=== POSITION RULES ==="
input int      InpMaxPositions     = 1;            // Max Positions (standard)
input int      InpMaxPosStrong     = 2;            // Max Positions (strong trend)
input double   InpMaxMarginPct     = 80.0;         // Max Free Margin Usage for 2nd Trade (%)

input group "=== SPREAD FILTER ==="
input double   InpMaxSpreadPips    = 35.0;         // Max Allowed Spread (pips) — always active

input group "=== DAILY PROTECTION ==="
input double   InpMaxDailyLossPct  = 30.0;         // Max Daily Loss (% of day-start balance)
input bool     InpCloseOnDailyLoss = false;         // Close All Positions on Daily Loss Halt
input bool     InpHaltOnDailyLoss  = true;          // Halt New Entries After Daily Loss

input group "=== LEVEL PROGRESSION ==="
input double   InpStartBalance     = 20.0;         // Level 1 Starting Balance ($)
input double   InpLevelGrowthPct   = 30.0;         // Growth Per Level (%)
input int      InpTotalLevels      = 30;           // Total Levels

input group "=== SESSION FILTER (optional) ==="
input bool     InpUseSessionFilter = false;         // Enable Session Filter (OFF = trade all hours)
input int      InpSessionStart     = 2;            // Session Start Hour (server time)
input int      InpSessionEnd       = 22;           // Session End Hour (server time)

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

// Pip calculation
double         g_pipSize;
double         g_pipValue;    // per standard lot

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

// Dashboard object prefix
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

   //--- Pip size: Gold 2-digit = 0.01, Gold 3-digit = 0.001 (1 pip = 0.01 always)
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

   if(g_adxHandle == INVALID_HANDLE || g_rsiHandle == INVALID_HANDLE || g_stochHandle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicator handles!");
      return(INIT_FAILED);
   }

   //--- Level progression table
   CalculateLevelTable();

   //--- Daily state
   g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dailyPL         = 0.0;
   g_dailyHalted     = false;
   g_currentDay      = iTime(_Symbol, PERIOD_D1, 0);
   g_lastBarTime     = 0;

   //--- Dashboard
   if(InpShowDashboard) CreateDashboard();

   //--- Log startup
   Print("======================================");
   Print("  SCALP GOLD HFT V1 — INITIALIZED");
   Print("  Handle: ", InpTradeComment);
   Print("  Balance: $", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
   Print("  Level: ", g_currentLevel + 1, " / ", InpTotalLevels);
   Print("  Next Target: $", DoubleToString(GetLevelTarget(), 2));
   Print("  Pip Size: ", DoubleToString(g_pipSize, _Digits));
   Print("  Pip Value/Lot: $", DoubleToString(g_pipValue, 4));
   Print("  Risk: ", DoubleToString(InpRiskPercent, 1), "% | Min SL: ", DoubleToString(InpMinSLPips, 0), " pips");
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
   if(isNewBar) g_lastBarTime = barTime;

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
         Print("!!! DAILY LOSS LIMIT HIT: $", DoubleToString(MathAbs(g_dailyPL), 2),
               " | Halting new entries for today");
         if(InpCloseOnDailyLoss) CloseAllMyPositions("Daily loss limit");
      }
   }

   //--- ALWAYS manage open positions (SL enforcement, profit lock, trailing)
   ManageOpenPositions();

   //--- Entry logic: only on new bar + not halted
   if(isNewBar && !g_dailyHalted)
   {
      //--- Session filter
      if(InpUseSessionFilter)
      {
         MqlDateTime dt;
         TimeCurrent(dt);
         if(dt.hour < InpSessionStart || dt.hour >= InpSessionEnd)
         {
            if(InpShowDashboard) UpdateDashboard();
            return;
         }
      }

      //--- Spread filter
      double spreadPips = GetSpreadPips();
      if(spreadPips > InpMaxSpreadPips)
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
//| SIGNAL DETECTION                                                  |
//|  Returns: 0=none, +1=BUY standard, +2=BUY strong,               |
//|           -1=SELL standard, -2=SELL strong                        |
//+------------------------------------------------------------------+
int CheckEntrySignal()
{
   //--- Read ADX buffers (bar 1 = last completed bar)
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

   //--- GATE 1: ADX must show trend (mandatory)
   if(adxMain[1] < InpADXMinLevel) return 0;

   //--- GATE 2: DI direction (mandatory)
   double diSpread = diPlus[1] - diMinus[1];
   bool bullishDI  = (diSpread >= InpMinDISeparation);
   bool bearishDI  = (-diSpread >= InpMinDISeparation);
   if(!bullishDI && !bearishDI) return 0;

   //--- Score confirmations (need 2 of 3)
   int confirms = 0;

   //--- RSI confirmation
   if(bullishDI && rsi[1] > InpRSIBuyMin && rsi[1] < InpRSIBuyMax)
      confirms++;
   if(bearishDI && rsi[1] > InpRSISellMin && rsi[1] < InpRSISellMax)
      confirms++;

   //--- Stochastic confirmation
   if(bullishDI && stK[1] > stD[1])   confirms++;   // Bullish momentum
   if(bearishDI && stK[1] < stD[1])   confirms++;   // Bearish momentum

   //--- Price action confirmation
   double open1  = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double high1  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low1   = iLow(_Symbol, PERIOD_CURRENT, 1);
   double body   = MathAbs(close1 - open1);
   double range  = high1 - low1;

   if(range > 0 && (body / range) >= 0.40)
   {
      if(bullishDI && close1 > open1) confirms++;   // Bullish candle
      if(bearishDI && close1 < open1) confirms++;   // Bearish candle
   }

   //--- Need minimum 2 confirmations beyond ADX+DI
   if(confirms < 2) return 0;

   //--- Determine signal strength
   bool strong = (confirms >= 3)
              && (adxMain[1] >= InpADXStrongLevel)
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

   int direction = (signal > 0) ? 1 : -1;     // 1=BUY, -1=SELL
   bool isStrong = (MathAbs(signal) == 2);

   //--- Position limits
   int posCount = CountMyPositions();
   int posDir   = GetMyPositionDirection();

   if(posCount >= InpMaxPosStrong)                          return false;
   if(posCount >= InpMaxPositions && !isStrong)             return false;
   if(posCount > 0 && posDir != 0 && posDir != direction)  return false;
   if(posCount > 0 && posDir == direction && !isStrong)     return false;

   //--- Spread check (double-check)
   double spreadPips = GetSpreadPips();
   if(spreadPips > InpMaxSpreadPips) return false;

   //--- Calculate risk
   double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskDollars = balance * InpRiskPercent / 100.0;

   if(InpMaxLossPerTrade > 0 && riskDollars > InpMaxLossPerTrade)
      riskDollars = InpMaxLossPerTrade;

   //--- Lot size from risk and SL
   double baseSLPips = InpMinSLPips;
   double lotSize    = riskDollars / (baseSLPips * g_pipValue);
   lotSize = NormalizeLots(lotSize);
   if(lotSize <= 0) return false;

   //--- Recalculate actual SL after lot normalization (lot rounding changes effective SL)
   double actualSLPips = riskDollars / (lotSize * g_pipValue);
   if(actualSLPips < InpMinSLPips)
      actualSLPips = InpMinSLPips;

   //--- Add spread buffer
   double slPips = actualSLPips;
   if(InpAddSpreadToSL)
      slPips += spreadPips;

   //--- Margin check for 2nd position
   if(posCount > 0)
   {
      double marginReq = 0;
      double checkPrice = (direction == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                           : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      ENUM_ORDER_TYPE orderType = (direction == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(!OrderCalcMargin(orderType, _Symbol, lotSize, checkPrice, marginReq))
         return false;
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(marginReq > freeMargin * InpMaxMarginPct / 100.0)
      {
         double reducedLots = NormalizeLots(lotSize * (freeMargin * InpMaxMarginPct / 100.0) / marginReq);
         if(reducedLots <= 0) return false;
         lotSize = reducedLots;
      }
   }

   //--- Price levels
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double slDist = slPips * g_pipSize;
   double tpDist = InpTPPips * g_pipSize;

   bool result = false;

   if(direction == 1)
   {
      double sl = NormalizeDouble(ask - slDist, _Digits);
      double tp = NormalizeDouble(ask + tpDist, _Digits);
      result = g_trade.Buy(lotSize, _Symbol, ask, sl, tp, InpTradeComment);
      if(result)
         Print(">>> BUY opened: ", DoubleToString(lotSize, 2), " lots @ ",
               DoubleToString(ask, _Digits), " | SL: ", DoubleToString(sl, _Digits),
               " (", DoubleToString(slPips, 1), " pips) | TP: ", DoubleToString(tp, _Digits),
               " | Risk: $", DoubleToString(riskDollars, 2),
               isStrong ? " [STRONG TREND]" : "");
   }
   else
   {
      double sl = NormalizeDouble(bid + slDist, _Digits);
      double tp = NormalizeDouble(bid - tpDist, _Digits);
      result = g_trade.Sell(lotSize, _Symbol, bid, sl, tp, InpTradeComment);
      if(result)
         Print(">>> SELL opened: ", DoubleToString(lotSize, 2), " lots @ ",
               DoubleToString(bid, _Digits), " | SL: ", DoubleToString(sl, _Digits),
               " (", DoubleToString(slPips, 1), " pips) | TP: ", DoubleToString(tp, _Digits),
               " | Risk: $", DoubleToString(riskDollars, 2),
               isStrong ? " [STRONG TREND]" : "");
   }

   if(!result)
      Print("!!! Trade failed: ", g_trade.ResultRetcodeDescription());

   return result;
}

//+------------------------------------------------------------------+
//| MANAGE OPEN POSITIONS                                             |
//|  — Enforce SL, profit lock, trailing stop                        |
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
         Print("!!! SL ENFORCED on ticket ", ticket, " — SL was missing!");
         continue;
      }

      //--- Calculate profit in pips
      double profitPips;
      if(posType == POSITION_TYPE_BUY)
         profitPips = (currentPrice - openPrice) / g_pipSize;
      else
         profitPips = (openPrice - currentPrice) / g_pipSize;

      //--- PROFIT LOCK: at +200 pips, move SL to entry + 50 pips
      if(profitPips >= InpProfitLockAt)
      {
         double lockSL;
         if(posType == POSITION_TYPE_BUY)
         {
            lockSL = NormalizeDouble(openPrice + InpProfitLockSL * g_pipSize, _Digits);
            if(currentSL < lockSL)
            {
               g_trade.PositionModify(ticket, lockSL, currentTP);
               Print("PROFIT LOCK: ticket ", ticket, " SL moved to +",
                     DoubleToString(InpProfitLockSL, 0), " pips (locked ",
                     DoubleToString(InpProfitLockSL * lotSizeFromTicket(ticket) * g_pipValue, 2),
                     " profit)");
            }
         }
         else
         {
            lockSL = NormalizeDouble(openPrice - InpProfitLockSL * g_pipSize, _Digits);
            if(currentSL > lockSL)
            {
               g_trade.PositionModify(ticket, lockSL, currentTP);
               Print("PROFIT LOCK: ticket ", ticket, " SL moved to +",
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
//| GET DIRECTION OF FIRST OPEN POSITION (1=BUY, -1=SELL, 0=none)   |
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
         Print("Closed ticket ", ticket, " — Reason: ", reason);
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

   //--- Log level table
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
   int panelW = 280;
   int panelH = 260;
   int panelX = 15;
   int panelY = 30;

   //--- Background
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

   //--- Labels
   int x = panelX + 12;
   int y = panelY + 8;
   int lineH = 20;

   DashLabel("Title",    x, y,            "SCALP GOLD HFT V1", InpColorHeader, 10, true);  y += lineH + 4;
   DashLabel("Handle",   x, y,            "Handle: n30dyn4m1c", InpColorInfo, 8, false);    y += lineH;
   DashLabel("Sep1",     x, y,            "──────────────────────────", clrDimGray, 7, false); y += lineH - 4;
   DashLabel("Balance",  x, y,            "Balance: ---", InpColorInfo, 9, false);           y += lineH;
   DashLabel("Level",    x, y,            "Level: ---", InpColorInfo, 9, false);             y += lineH;
   DashLabel("Target",   x, y,            "Target: ---", InpColorInfo, 9, false);            y += lineH;
   DashLabel("Progress", x, y,            "Progress: ---", InpColorInfo, 9, false);          y += lineH;
   DashLabel("DailyPL",  x, y,            "Daily P&L: ---", InpColorInfo, 9, false);         y += lineH;
   DashLabel("Positions",x, y,            "Positions: ---", InpColorInfo, 9, false);          y += lineH;
   DashLabel("Spread",   x, y,            "Spread: ---", InpColorInfo, 9, false);             y += lineH;
   DashLabel("Status",   x, y,            "Status: ---", InpColorInfo, 9, true);              y += lineH;

   ChartRedraw();
}

void UpdateDashboard()
{
   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   double spread   = GetSpreadPips();
   int    posCount = CountMyPositions();

   //--- Balance
   DashUpdate("Balance", "Balance: $" + DoubleToString(balance, 2)
              + " (Eq: $" + DoubleToString(equity, 2) + ")",
              (equity >= balance) ? InpColorProfit : InpColorLoss);

   //--- Level
   DashUpdate("Level", "Level: " + IntegerToString(g_currentLevel + 1) + " / " + IntegerToString(InpTotalLevels),
              InpColorInfo);

   //--- Target
   DashUpdate("Target", "Target: $" + DoubleToString(GetLevelTarget(), 2), InpColorHeader);

   //--- Progress
   double prog = GetLevelProgress();
   DashUpdate("Progress", "Progress: " + DoubleToString(prog, 1) + "%",
              (prog >= 50) ? InpColorProfit : InpColorInfo);

   //--- Daily P&L
   DashUpdate("DailyPL", "Daily P&L: $" + DoubleToString(g_dailyPL, 2),
              (g_dailyPL >= 0) ? InpColorProfit : InpColorLoss);

   //--- Positions
   DashUpdate("Positions", "Positions: " + IntegerToString(posCount)
              + " / " + IntegerToString(g_dailyHalted ? 0 : (posCount > 0 ? InpMaxPosStrong : InpMaxPositions)),
              InpColorInfo);

   //--- Spread
   string spreadStatus = (spread <= InpMaxSpreadPips) ? " OK" : " HIGH";
   DashUpdate("Spread", "Spread: " + DoubleToString(spread, 1) + " pips" + spreadStatus,
              (spread <= InpMaxSpreadPips) ? InpColorProfit : InpColorLoss);

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
