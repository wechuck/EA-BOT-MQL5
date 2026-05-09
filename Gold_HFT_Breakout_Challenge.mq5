//+------------------------------------------------------------------+
//|                                 Gold_HFT_Breakout_Challenge.mq5 |
//|                                          $5 to $10K Challenge    |
//|                      Gold HFT Breakout EA with Profit Protection |
//+------------------------------------------------------------------+
#property copyright "Gold HFT Challenge EA"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//--- Input Parameters
input group "=== Challenge Settings ==="
input double   StartingBalance = 5.0;           // Starting Account Balance ($)
input double   DailyProfitTarget = 10.0;        // Daily Profit Target ($)
input int      MaxDailyTrades = 25;             // Maximum Trades Per Day
input bool     LockProfitsDaily = true;         // Lock Profits at Daily Target

input group "=== Trading Parameters ==="
input bool     UseDynamicLotSize = true;        // Use Dynamic Lot Sizing
input double   FixedLotSize = 0.01;             // Fixed Lot Size (if not dynamic)
input double   RiskPercentPerTrade = 5.0;       // Risk Per Trade (% of balance) - AGGRESSIVE
input double   MaxLotSize = 100.0;              // Maximum Lot Size
input double   MarginUsagePercent = 80.0;       // Max Margin Usage (%)
input int      StopLossPips = 150;              // Stop Loss (pips)
input int      TakeProfitPips = 500;            // Take Profit (pips)
input int      BreakevenPips = 50;              // Move to Breakeven at (pips)
input int      TrailingStartPips = 100;         // Start Trailing at (pips)
input int      TrailingStepPips = 20;           // Trailing Step (pips)

input group "=== Breakout Strategy ==="
input int      BreakoutPeriod = 20;             // Breakout Period (bars)
input int      BreakoutBuffer = 8;              // Breakout Buffer (pips) - BALANCED
input int      MinVolatilityPips = 40;          // Minimum Volatility (pips) - BALANCED
input bool     UseMultiTimeframe = true;        // Use Multi-Timeframe Confirmation
input bool     UseRSIFilter = true;             // Use RSI Filter
input int      RSIPeriod = 14;                  // RSI Period
input int      RSIUpperLevel = 70;              // RSI Overbought Level - BALANCED
input int      RSILowerLevel = 30;              // RSI Oversold Level - BALANCED
input bool     UseATRFilter = true;             // Use ATR Volatility Filter
input int      ATRPeriod = 14;                  // ATR Period
input double   ATRMultiplier = 1.5;             // ATR Multiplier - BALANCED
input bool     UseMomentumFilter = true;        // Use Momentum Confirmation
input int      MomentumPeriod = 10;             // Momentum Period
input bool     UseADXFilter = true;             // Use ADX Trend Filter
input int      ADXPeriod = 14;                  // ADX Period
input double   ADXMinLevel = 25.0;              // Minimum ADX Level - BALANCED (moderate trend)
input bool     UseTrendAlignment = false;       // Multi-Timeframe Trend Alignment (OPTIONAL - very strict)
input bool     UseVolumeConfirmation = false;   // Volume Spike Confirmation (OPTIONAL - very strict)

input group "=== Risk Management ==="
input int      MaxSpreadPips = 40;              // Maximum Allowed Spread (pips)
input int      MaxSlippagePips = 40;            // Maximum Allowed Slippage (pips)
input double   MaxDailyDrawdownPercent = 30.0;  // Max Daily Drawdown (%)
input int      MaxConcurrentPositions = 2;      // Max Concurrent Positions
input bool     UseTimeBasedExit = true;         // Use Time-Based Exit for Losing Trades
input int      MaxTradeMinutes = 60;            // Max Minutes in Losing Trade
input double   PartialProfitPercent = 50.0;     // Close % at First Profit Target
input int      PartialProfitPips = 250;         // First Profit Target (pips)
input bool     StopAfterDailyLoss = true;       // Stop Trading After Daily Loss
input double   MaxDailyLossDollars = 1.0;       // Max Daily Loss in Dollars
input bool     ResumeOnGoodSignal = true;       // Resume Trading on Strong Signal

input group "=== Session Filters ==="
input bool     TradeLondonSession = true;       // Trade London Session
input bool     TradeNYSession = true;           // Trade NY Session
input bool     TradeAsianSession = false;       // Trade Asian Session
input int      StartHour = 0;                   // Start Hour (0 = no limit)
input int      EndHour = 24;                    // End Hour (24 = no limit)

input group "=== UI Settings ==="
input color    ColorProfit = clrLime;           // Profit Color
input color    ColorLoss = clrRed;              // Loss Color
input color    ColorInfo = clrWhite;            // Info Color
input int      UIRefreshSeconds = 1;            // UI Refresh Rate (seconds)
input bool     EnableDebugLog = false;          // Enable Debug Logging for Entry Signals

//--- Global Variables
CTrade trade;
datetime lastBarTime = 0;
datetime dailyResetTime = 0;
int dailyTradeCount = 0;
double dailyProfit = 0.0;
double dailyStartBalance = 0.0;
bool dailyTargetReached = false;
double pointValue = 0.0;

// Indicator handles
int rsiHandle = INVALID_HANDLE;
int atrHandle = INVALID_HANDLE;
int maHandle = INVALID_HANDLE;
int adxHandle = INVALID_HANDLE;

// Daily loss tracking
bool dailyLossLimitReached = false;
double dailyLoss = 0.0;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Initialize trade object
    trade.SetExpertMagicNumber(123456);
    trade.SetDeviationInPoints(MaxSlippagePips * 10);
    trade.SetTypeFilling(ORDER_FILLING_FOK);
    trade.SetAsyncMode(false);

    //--- Calculate point value
    pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    //--- Initialize indicators
    if(UseRSIFilter)
    {
        rsiHandle = iRSI(_Symbol, PERIOD_M5, RSIPeriod, PRICE_CLOSE);
        if(rsiHandle == INVALID_HANDLE)
        {
            Print("Error creating RSI indicator");
            return(INIT_FAILED);
        }
    }

    if(UseATRFilter)
    {
        atrHandle = iATR(_Symbol, PERIOD_M5, ATRPeriod);
        if(atrHandle == INVALID_HANDLE)
        {
            Print("Error creating ATR indicator");
            return(INIT_FAILED);
        }
    }

    if(UseMultiTimeframe)
    {
        maHandle = iMA(_Symbol, PERIOD_M15, 20, 0, MODE_SMA, PRICE_CLOSE);
        if(maHandle == INVALID_HANDLE)
        {
            Print("Error creating MA indicator");
            return(INIT_FAILED);
        }
    }

    if(UseADXFilter)
    {
        adxHandle = iADX(_Symbol, PERIOD_M5, ADXPeriod);
        if(adxHandle == INVALID_HANDLE)
        {
            Print("Error creating ADX indicator");
            return(INIT_FAILED);
        }
    }

    //--- Initialize daily tracking
    ResetDailyCounters();

    //--- Create UI
    CreateDashboard();

    Print("Gold HFT Breakout Challenge EA Initialized");
    Print("Starting Balance: $", StartingBalance);
    Print("Daily Target: $", DailyProfitTarget);

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Release indicator handles
    if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
    if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
    if(maHandle != INVALID_HANDLE) IndicatorRelease(maHandle);
    if(adxHandle != INVALID_HANDLE) IndicatorRelease(adxHandle);

    //--- Remove all UI objects
    ObjectsDeleteAll(0, "HFT_");
    Comment("");
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- Check for new bar
    datetime currentBarTime = iTime(_Symbol, PERIOD_M1, 0);
    bool isNewBar = (currentBarTime != lastBarTime);
    if(isNewBar) lastBarTime = currentBarTime;

    //--- Reset daily counters if new day
    if(IsNewDay())
    {
        ResetDailyCounters();
    }

    //--- Update daily profit
    UpdateDailyProfit();

    //--- Check daily target
    if(LockProfitsDaily && dailyProfit >= DailyProfitTarget)
    {
        if(!dailyTargetReached)
        {
            dailyTargetReached = true;
            Print("🎯 DAILY TARGET REACHED! Profit: $", DoubleToString(dailyProfit, 2));
            CloseAllPositions("Daily target reached");
        }
    }

    //--- Manage existing positions
    ManagePositions();

    //--- Update UI
    static datetime lastUIUpdate = 0;
    if(TimeCurrent() - lastUIUpdate >= UIRefreshSeconds)
    {
        UpdateDashboard();
        lastUIUpdate = TimeCurrent();
    }

    //--- Check if we should trade
    if(!ShouldTrade()) return;

    //--- Look for trading opportunities on new bar
    if(isNewBar)
    {
        CheckForBreakout();
    }
}

//+------------------------------------------------------------------+
//| Check if we should trade                                          |
//+------------------------------------------------------------------+
bool ShouldTrade()
{
    //--- Check daily target lock
    if(dailyTargetReached) return false;

    //--- Check daily loss limit
    if(StopAfterDailyLoss && dailyLossLimitReached)
    {
        // Allow resuming only on very strong signals
        if(ResumeOnGoodSignal && CheckStrongSignal())
        {
            Print("💪 Strong signal detected - resuming trading after daily loss");
        }
        else
        {
            return false;
        }
    }

    //--- Check max daily trades
    if(dailyTradeCount >= MaxDailyTrades)
    {
        return false;
    }

    //--- Check max drawdown
    double drawdown = dailyStartBalance - AccountInfoDouble(ACCOUNT_EQUITY);
    double drawdownPercent = (drawdown / dailyStartBalance) * 100.0;
    if(drawdownPercent >= MaxDailyDrawdownPercent)
    {
        Print("⚠️ Max daily drawdown reached: ", DoubleToString(drawdownPercent, 2), "%");
        return false;
    }

    //--- Check spread
    double spread = GetSpreadInPips();
    if(spread > MaxSpreadPips)
    {
        return false;
    }

    //--- Check concurrent positions
    if(CountOpenPositions() >= MaxConcurrentPositions)
    {
        return false;
    }

    //--- Check trading session
    if(!IsValidTradingSession())
    {
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Check for breakout opportunities                                  |
//+------------------------------------------------------------------+
void CheckForBreakout()
{
    //--- Get current price
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    //--- Calculate breakout levels
    double highLevel = iHigh(_Symbol, PERIOD_M5, iHighest(_Symbol, PERIOD_M5, MODE_HIGH, BreakoutPeriod, 1));
    double lowLevel = iLow(_Symbol, PERIOD_M5, iLowest(_Symbol, PERIOD_M5, MODE_LOW, BreakoutPeriod, 1));

    //--- Check volatility
    double volatility = (highLevel - lowLevel) / pointValue / 10.0;
    if(volatility < MinVolatilityPips)
    {
        if(EnableDebugLog)
            Print("❌ Volatility too low: ", DoubleToString(volatility, 1), " pips (need ", MinVolatilityPips, ")");
        return; // Not enough volatility
    }

    //--- ATR Filter - ensure market is active enough
    if(UseATRFilter && !CheckATRFilter())
    {
        if(EnableDebugLog)
            Print("❌ ATR filter failed");
        return;
    }

    //--- Add buffer
    double bufferPoints = BreakoutBuffer * 10 * pointValue;
    double buyLevel = highLevel + bufferPoints;
    double sellLevel = lowLevel - bufferPoints;

    //--- Check for bullish breakout
    if(ask > buyLevel)
    {
        if(EnableDebugLog)
            Print("🔍 Bullish breakout detected at ", DoubleToString(ask, _Digits));

        // RSI Filter - avoid overbought (STRICT)
        if(UseRSIFilter && !CheckRSI(true))
        {
            if(EnableDebugLog) Print("❌ RSI filter failed for BUY");
            return;
        }

        // Trend confirmation - MUST align
        if(UseMultiTimeframe && !ConfirmTrend(true))
        {
            if(EnableDebugLog) Print("❌ Trend confirmation failed for BUY");
            return;
        }

        // Momentum confirmation - MUST be positive
        if(UseMomentumFilter && !CheckMomentum(true))
        {
            if(EnableDebugLog) Print("❌ Momentum filter failed for BUY");
            return;
        }

        // ADX Filter - MUST show strong trend
        if(UseADXFilter && !CheckADX(true))
        {
            if(EnableDebugLog) Print("❌ ADX filter failed for BUY");
            return;
        }

        // Multi-timeframe trend alignment - ALL timeframes must agree
        if(UseTrendAlignment && !CheckTrendAlignment(true))
        {
            if(EnableDebugLog) Print("❌ Trend alignment filter failed for BUY");
            return;
        }

        // Volume confirmation - require volume spike
        if(UseVolumeConfirmation && !CheckVolumeSpike())
        {
            if(EnableDebugLog) Print("❌ Volume confirmation failed for BUY");
            return;
        }

        if(EnableDebugLog)
            Print("✅ All filters passed - Opening BUY position");

        OpenPosition(ORDER_TYPE_BUY);
    }
    //--- Check for bearish breakout
    else if(bid < sellLevel)
    {
        if(EnableDebugLog)
            Print("🔍 Bearish breakout detected at ", DoubleToString(bid, _Digits));

        // RSI Filter - avoid oversold (STRICT)
        if(UseRSIFilter && !CheckRSI(false))
        {
            if(EnableDebugLog) Print("❌ RSI filter failed for SELL");
            return;
        }

        // Trend confirmation - MUST align
        if(UseMultiTimeframe && !ConfirmTrend(false))
        {
            if(EnableDebugLog) Print("❌ Trend confirmation failed for SELL");
            return;
        }

        // Momentum confirmation - MUST be negative
        if(UseMomentumFilter && !CheckMomentum(false))
        {
            if(EnableDebugLog) Print("❌ Momentum filter failed for SELL");
            return;
        }

        // ADX Filter - MUST show strong trend
        if(UseADXFilter && !CheckADX(false))
        {
            if(EnableDebugLog) Print("❌ ADX filter failed for SELL");
            return;
        }

        // Multi-timeframe trend alignment - ALL timeframes must agree
        if(UseTrendAlignment && !CheckTrendAlignment(false))
        {
            if(EnableDebugLog) Print("❌ Trend alignment filter failed for SELL");
            return;
        }

        // Volume confirmation - require volume spike
        if(UseVolumeConfirmation && !CheckVolumeSpike())
        {
            if(EnableDebugLog) Print("❌ Volume confirmation failed for SELL");
            return;
        }

        if(EnableDebugLog)
            Print("✅ All filters passed - Opening SELL position");

        OpenPosition(ORDER_TYPE_SELL);
    }
}

//+------------------------------------------------------------------+
//| Confirm trend on higher timeframe                                 |
//+------------------------------------------------------------------+
bool ConfirmTrend(bool bullish)
{
    if(!UseMultiTimeframe || maHandle == INVALID_HANDLE)
        return true;

    double ma20[];
    ArraySetAsSeries(ma20, true);

    if(CopyBuffer(maHandle, 0, 0, 1, ma20) <= 0)
        return false;

    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    if(bullish)
        return price > ma20[0];
    else
        return price < ma20[0];
}

//+------------------------------------------------------------------+
//| Check RSI filter                                                  |
//+------------------------------------------------------------------+
bool CheckRSI(bool bullish)
{
    if(!UseRSIFilter || rsiHandle == INVALID_HANDLE)
        return true;

    double rsi[];
    ArraySetAsSeries(rsi, true);

    if(CopyBuffer(rsiHandle, 0, 0, 1, rsi) <= 0)
        return true;

    if(bullish)
    {
        // For buy, RSI must not be overbought (< 70)
        return rsi[0] < RSIUpperLevel && rsi[0] > 35;
    }
    else
    {
        // For sell, RSI must not be oversold (> 30)
        return rsi[0] > RSILowerLevel && rsi[0] < 65;
    }
}

//+------------------------------------------------------------------+
//| Check ATR filter                                                  |
//+------------------------------------------------------------------+
bool CheckATRFilter()
{
    if(!UseATRFilter || atrHandle == INVALID_HANDLE)
        return true;

    double atr[];
    ArraySetAsSeries(atr, true);

    if(CopyBuffer(atrHandle, 0, 0, 2, atr) <= 0)
        return true;

    // Check if current ATR is above average (market is moving)
    double avgATR = (atr[0] + atr[1]) / 2.0;
    double atrInPips = atr[0] / pointValue / 10.0;

    return atrInPips > MinVolatilityPips * ATRMultiplier;
}

//+------------------------------------------------------------------+
//| Check momentum filter                                             |
//+------------------------------------------------------------------+
bool CheckMomentum(bool bullish)
{
    if(!UseMomentumFilter)
        return true;

    // Check recent price momentum
    double close[];
    ArraySetAsSeries(close, true);

    if(CopyClose(_Symbol, PERIOD_M5, 0, MomentumPeriod + 1, close) <= 0)
        return true;

    double currentMomentum = close[0] - close[MomentumPeriod];

    if(bullish)
        return currentMomentum > 0; // Positive momentum for buy
    else
        return currentMomentum < 0; // Negative momentum for sell
}

//+------------------------------------------------------------------+
//| Check ADX filter                                                  |
//+------------------------------------------------------------------+
bool CheckADX(bool bullish)
{
    if(!UseADXFilter || adxHandle == INVALID_HANDLE)
        return true;

    double adxMain[], adxPlus[], adxMinus[];
    ArraySetAsSeries(adxMain, true);
    ArraySetAsSeries(adxPlus, true);
    ArraySetAsSeries(adxMinus, true);

    if(CopyBuffer(adxHandle, 0, 0, 1, adxMain) <= 0)
        return true;
    if(CopyBuffer(adxHandle, 1, 0, 1, adxPlus) <= 0)
        return true;
    if(CopyBuffer(adxHandle, 2, 0, 1, adxMinus) <= 0)
        return true;

    // ADX must be above minimum level (strong trend)
    if(adxMain[0] < ADXMinLevel)
        return false;

    // Check directional movement
    if(bullish)
        return adxPlus[0] > adxMinus[0]; // +DI above -DI for uptrend
    else
        return adxMinus[0] > adxPlus[0]; // -DI above +DI for downtrend
}

//+------------------------------------------------------------------+
//| Check for strong signal to resume trading                        |
//+------------------------------------------------------------------+
bool CheckStrongSignal()
{
    if(!UseADXFilter || adxHandle == INVALID_HANDLE)
        return false;

    double adxMain[];
    ArraySetAsSeries(adxMain, true);

    if(CopyBuffer(adxHandle, 0, 0, 1, adxMain) <= 0)
        return false;

    // Require very strong trend (ADX > 30) to resume after loss
    return adxMain[0] > 30.0;
}

//+------------------------------------------------------------------+
//| Check multi-timeframe trend alignment                            |
//+------------------------------------------------------------------+
bool CheckTrendAlignment(bool bullish)
{
    if(!UseTrendAlignment)
        return true;

    // Check M5, M15, M30, H1 - all must agree
    double ma5_M5[], ma5_M15[], ma5_M30[], ma5_H1[];
    ArraySetAsSeries(ma5_M5, true);
    ArraySetAsSeries(ma5_M15, true);
    ArraySetAsSeries(ma5_M30, true);
    ArraySetAsSeries(ma5_H1, true);

    // Get MA values for different timeframes
    int handle_M5 = iMA(_Symbol, PERIOD_M5, 5, 0, MODE_SMA, PRICE_CLOSE);
    int handle_M15 = iMA(_Symbol, PERIOD_M15, 5, 0, MODE_SMA, PRICE_CLOSE);
    int handle_M30 = iMA(_Symbol, PERIOD_M30, 5, 0, MODE_SMA, PRICE_CLOSE);
    int handle_H1 = iMA(_Symbol, PERIOD_H1, 5, 0, MODE_SMA, PRICE_CLOSE);

    if(handle_M5 == INVALID_HANDLE || handle_M15 == INVALID_HANDLE ||
       handle_M30 == INVALID_HANDLE || handle_H1 == INVALID_HANDLE)
        return true; // If can't check, allow trade

    if(CopyBuffer(handle_M5, 0, 0, 2, ma5_M5) <= 0) return true;
    if(CopyBuffer(handle_M15, 0, 0, 2, ma5_M15) <= 0) return true;
    if(CopyBuffer(handle_M30, 0, 0, 2, ma5_M30) <= 0) return true;
    if(CopyBuffer(handle_H1, 0, 0, 2, ma5_H1) <= 0) return true;

    IndicatorRelease(handle_M5);
    IndicatorRelease(handle_M15);
    IndicatorRelease(handle_M30);
    IndicatorRelease(handle_H1);

    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    if(bullish)
    {
        // All MAs must be rising and price above all
        bool m5Rising = ma5_M5[0] > ma5_M5[1];
        bool m15Rising = ma5_M15[0] > ma5_M15[1];
        bool m30Rising = ma5_M30[0] > ma5_M30[1];
        bool h1Rising = ma5_H1[0] > ma5_H1[1];

        bool priceAbove = currentPrice > ma5_M5[0] && currentPrice > ma5_M15[0] &&
                         currentPrice > ma5_M30[0] && currentPrice > ma5_H1[0];

        return m5Rising && m15Rising && m30Rising && h1Rising && priceAbove;
    }
    else
    {
        // All MAs must be falling and price below all
        bool m5Falling = ma5_M5[0] < ma5_M5[1];
        bool m15Falling = ma5_M15[0] < ma5_M15[1];
        bool m30Falling = ma5_M30[0] < ma5_M30[1];
        bool h1Falling = ma5_H1[0] < ma5_H1[1];

        bool priceBelow = currentPrice < ma5_M5[0] && currentPrice < ma5_M15[0] &&
                         currentPrice < ma5_M30[0] && currentPrice < ma5_H1[0];

        return m5Falling && m15Falling && m30Falling && h1Falling && priceBelow;
    }
}

//+------------------------------------------------------------------+
//| Check volume spike confirmation                                  |
//+------------------------------------------------------------------+
bool CheckVolumeSpike()
{
    if(!UseVolumeConfirmation)
        return true;

    long volume[];
    ArraySetAsSeries(volume, true);

    // Get recent volume data
    if(CopyTickVolume(_Symbol, PERIOD_M5, 0, 20, volume) < 20)
        return true; // If can't check, allow trade

    // Calculate average volume
    double avgVolume = 0;
    for(int i = 1; i < 20; i++)
    {
        avgVolume += volume[i];
    }
    avgVolume = avgVolume / 19.0;

    // Current volume must be at least 1.5x average (volume spike)
    return volume[0] >= avgVolume * 1.5;
}

//+------------------------------------------------------------------+
//| Calculate dynamic lot size based on account balance               |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    if(!UseDynamicLotSize)
        return FixedLotSize;

    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

    // Calculate risk amount (aggressive 5% default)
    double riskAmount = balance * (RiskPercentPerTrade / 100.0);

    // Calculate pip value for the symbol
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double pipValue = (tickValue / tickSize) * 10 * pointValue;

    if(pipValue == 0)
        return FixedLotSize;

    // Calculate lot size based on risk
    double lotSize = riskAmount / (StopLossPips * pipValue);

    // Check margin requirements
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double requiredMargin = 0;

    // Calculate required margin for 1 lot
    if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, 1.0, SymbolInfoDouble(_Symbol, SYMBOL_ASK), requiredMargin))
    {
        Print("Failed to calculate margin");
        return FixedLotSize;
    }

    // Calculate max lot based on available margin (use 80% of free margin)
    double maxLotByMargin = (freeMargin * MarginUsagePercent / 100.0) / requiredMargin;

    // Use the smaller of risk-based or margin-based lot size
    if(maxLotByMargin < lotSize)
    {
        lotSize = maxLotByMargin;
        Print("⚠️ Lot size limited by margin: ", DoubleToString(lotSize, 2));
    }

    // Apply constraints
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

    // Ensure we don't exceed MaxLotSize parameter
    if(lotSize > MaxLotSize)
        lotSize = MaxLotSize;

    // Normalize to lot step
    lotSize = MathFloor(lotSize / lotStep) * lotStep;

    // Ensure within broker limits
    if(lotSize < minLot)
        lotSize = minLot;
    if(lotSize > maxLot)
        lotSize = maxLot;

    return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Open a position                                                    |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType)
{
    //--- Validate
    if(CountOpenPositions() >= MaxConcurrentPositions) return;

    //--- Calculate dynamic lot size
    double lotSize = CalculateLotSize();

    double price = (orderType == ORDER_TYPE_BUY) ?
                   SymbolInfoDouble(_Symbol, SYMBOL_ASK) :
                   SymbolInfoDouble(_Symbol, SYMBOL_BID);

    //--- Calculate SL and TP
    double sl = 0, tp = 0;

    if(orderType == ORDER_TYPE_BUY)
    {
        sl = price - StopLossPips * 10 * pointValue;
        tp = price + TakeProfitPips * 10 * pointValue;
    }
    else
    {
        sl = price + StopLossPips * 10 * pointValue;
        tp = price - TakeProfitPips * 10 * pointValue;
    }

    //--- Normalize prices
    sl = NormalizeDouble(sl, _Digits);
    tp = NormalizeDouble(tp, _Digits);

    //--- Open position
    if(trade.PositionOpen(_Symbol, orderType, lotSize, price, sl, tp, "HFT Breakout"))
    {
        dailyTradeCount++;
        Print("✅ Position opened: ", EnumToString(orderType),
              " | Lot: ", DoubleToString(lotSize, 2),
              " | Price: ", price,
              " | SL: ", sl,
              " | TP: ", tp);
    }
    else
    {
        Print("❌ Failed to open position: ", trade.ResultRetcodeDescription());
    }
}

//+------------------------------------------------------------------+
//| Manage open positions                                             |
//+------------------------------------------------------------------+
void ManagePositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
                              SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                              SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double sl = PositionGetDouble(POSITION_SL);
        double tp = PositionGetDouble(POSITION_TP);
        datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
        double volume = PositionGetDouble(POSITION_VOLUME);

        //--- Calculate profit in pips
        double profitPips = 0;
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            profitPips = (currentPrice - openPrice) / pointValue / 10.0;
        else
            profitPips = (openPrice - currentPrice) / pointValue / 10.0;

        //--- Time-based exit for losing trades
        if(UseTimeBasedExit && profitPips < 0)
        {
            int minutesInTrade = (int)((TimeCurrent() - openTime) / 60);
            if(minutesInTrade >= MaxTradeMinutes)
            {
                trade.PositionClose(ticket);
                Print("⏱️ Position closed by time: Ticket #", ticket, " | Minutes: ", minutesInTrade);
                continue;
            }
        }

        //--- Partial profit taking
        if(profitPips >= PartialProfitPips && volume > SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
        {
            double closeVolume = NormalizeDouble(volume * PartialProfitPercent / 100.0, 2);
            double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

            if(closeVolume >= minLot && (volume - closeVolume) >= minLot)
            {
                if(trade.PositionClosePartial(ticket, closeVolume))
                {
                    Print("💰 Partial profit taken: Ticket #", ticket,
                          " | Closed: ", closeVolume,
                          " | Profit: ", profitPips, " pips");
                }
            }
        }

        //--- Move to breakeven
        if(profitPips >= BreakevenPips && sl != openPrice)
        {
            double newSL = openPrice;
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
                if(sl < newSL || sl == 0)
                {
                    if(trade.PositionModify(ticket, newSL, tp))
                    {
                        Print("📊 Position moved to breakeven: Ticket #", ticket);
                    }
                }
            }
            else
            {
                if(sl > newSL || sl == 0)
                {
                    if(trade.PositionModify(ticket, newSL, tp))
                    {
                        Print("📊 Position moved to breakeven: Ticket #", ticket);
                    }
                }
            }
        }

        //--- Trailing stop
        if(profitPips >= TrailingStartPips)
        {
            double newSL = 0;

            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
                newSL = currentPrice - TrailingStepPips * 10 * pointValue;
                newSL = NormalizeDouble(newSL, _Digits);

                if(newSL > sl && newSL > openPrice)
                {
                    if(trade.PositionModify(ticket, newSL, tp))
                    {
                        Print("📈 Trailing stop updated: Ticket #", ticket, " | New SL: ", newSL);
                    }
                }
            }
            else
            {
                newSL = currentPrice + TrailingStepPips * 10 * pointValue;
                newSL = NormalizeDouble(newSL, _Digits);

                if((newSL < sl || sl == 0) && newSL < openPrice)
                {
                    if(trade.PositionModify(ticket, newSL, tp))
                    {
                        Print("📉 Trailing stop updated: Ticket #", ticket, " | New SL: ", newSL);
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Close all positions                                               |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        trade.PositionClose(ticket);
    }
    Print("🛑 All positions closed: ", reason);
}

//+------------------------------------------------------------------+
//| Count open positions                                              |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionGetSymbol(i) == _Symbol)
            count++;
    }
    return count;
}

//+------------------------------------------------------------------+
//| Get spread in pips                                                |
//+------------------------------------------------------------------+
double GetSpreadInPips()
{
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    return (ask - bid) / pointValue / 10.0;
}

//+------------------------------------------------------------------+
//| Check if valid trading session                                    |
//+------------------------------------------------------------------+
bool IsValidTradingSession()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int currentHour = dt.hour;

    //--- Check hour limits
    if(StartHour > 0 || EndHour < 24)
    {
        if(currentHour < StartHour || currentHour >= EndHour)
            return false;
    }

    //--- Check sessions
    bool inSession = false;

    // Asian: 00:00-09:00 GMT
    if(TradeAsianSession && currentHour >= 0 && currentHour < 9)
        inSession = true;

    // London: 08:00-17:00 GMT
    if(TradeLondonSession && currentHour >= 8 && currentHour < 17)
        inSession = true;

    // NY: 13:00-22:00 GMT
    if(TradeNYSession && currentHour >= 13 && currentHour < 22)
        inSession = true;

    return inSession;
}

//+------------------------------------------------------------------+
//| Check if new day                                                  |
//+------------------------------------------------------------------+
bool IsNewDay()
{
    datetime currentDay = (datetime)(TimeCurrent() / 86400) * 86400;
    if(currentDay != dailyResetTime)
    {
        dailyResetTime = currentDay;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Reset daily counters                                              |
//+------------------------------------------------------------------+
void ResetDailyCounters()
{
    dailyTradeCount = 0;
    dailyProfit = 0.0;
    dailyLoss = 0.0;
    dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    dailyTargetReached = false;
    dailyLossLimitReached = false;

    Print("📅 Daily counters reset | Balance: $", DoubleToString(dailyStartBalance, 2));
}

//+------------------------------------------------------------------+
//| Update daily profit                                               |
//+------------------------------------------------------------------+
void UpdateDailyProfit()
{
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    dailyProfit = currentEquity - dailyStartBalance;

    // Check for daily loss limit
    if(StopAfterDailyLoss && dailyProfit < 0)
    {
        dailyLoss = MathAbs(dailyProfit);

        if(dailyLoss >= MaxDailyLossDollars && !dailyLossLimitReached)
        {
            dailyLossLimitReached = true;
            CloseAllPositions("Daily loss limit reached");
            Print("🛑 DAILY LOSS LIMIT REACHED: $", DoubleToString(dailyLoss, 2));
            Print("⏸️ Trading paused until next day or strong signal");
        }
    }
}

//+------------------------------------------------------------------+
//| Create dashboard UI                                               |
//+------------------------------------------------------------------+
void CreateDashboard()
{
    int x = 10;
    int y = 20;
    int lineHeight = 18;

    CreateLabel("HFT_Title", x, y, "=== GOLD HFT BREAKOUT CHALLENGE ===", clrYellow, 10, "Arial Bold");
    y += lineHeight + 5;

    CreateLabel("HFT_Balance", x, y, "Balance:", ColorInfo, 9);
    y += lineHeight;
    CreateLabel("HFT_Equity", x, y, "Equity:", ColorInfo, 9);
    y += lineHeight;
    CreateLabel("HFT_DailyProfit", x, y, "Daily Profit:", ColorInfo, 9);
    y += lineHeight;
    CreateLabel("HFT_DailyTarget", x, y, "Daily Target:", ColorInfo, 9);
    y += lineHeight + 5;

    CreateLabel("HFT_LotSize", x, y, "Lot Size:", ColorInfo, 9);
    y += lineHeight;
    CreateLabel("HFT_Trades", x, y, "Trades Today:", ColorInfo, 9);
    y += lineHeight;
    CreateLabel("HFT_Positions", x, y, "Open Positions:", ColorInfo, 9);
    y += lineHeight;
    CreateLabel("HFT_Spread", x, y, "Spread:", ColorInfo, 9);
    y += lineHeight + 5;

    CreateLabel("HFT_Status", x, y, "Status:", ColorInfo, 9);
}

//+------------------------------------------------------------------+
//| Update dashboard UI                                               |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double spread = GetSpreadInPips();
    int positions = CountOpenPositions();
    double currentLotSize = CalculateLotSize();

    color profitColor = dailyProfit >= 0 ? ColorProfit : ColorLoss;

    ObjectSetString(0, "HFT_Balance", OBJPROP_TEXT, "Balance: $" + DoubleToString(balance, 2));
    ObjectSetString(0, "HFT_Equity", OBJPROP_TEXT, "Equity: $" + DoubleToString(equity, 2));
    ObjectSetString(0, "HFT_DailyProfit", OBJPROP_TEXT,
                    "Daily Profit: $" + DoubleToString(dailyProfit, 2) +
                    " (" + DoubleToString((dailyProfit/dailyStartBalance)*100, 1) + "%)");
    ObjectSetInteger(0, "HFT_DailyProfit", OBJPROP_COLOR, profitColor);

    ObjectSetString(0, "HFT_DailyTarget", OBJPROP_TEXT,
                    "Daily Target: $" + DoubleToString(DailyProfitTarget, 2) +
                    " (" + DoubleToString((dailyProfit/DailyProfitTarget)*100, 0) + "%)");

    string lotSizeText = "Lot Size: " + DoubleToString(currentLotSize, 2);
    if(UseDynamicLotSize)
        lotSizeText += " (Dynamic)";
    else
        lotSizeText += " (Fixed)";
    ObjectSetString(0, "HFT_LotSize", OBJPROP_TEXT, lotSizeText);

    ObjectSetString(0, "HFT_Trades", OBJPROP_TEXT,
                    "Trades Today: " + IntegerToString(dailyTradeCount) + "/" + IntegerToString(MaxDailyTrades));
    ObjectSetString(0, "HFT_Positions", OBJPROP_TEXT,
                    "Open Positions: " + IntegerToString(positions) + "/" + IntegerToString(MaxConcurrentPositions));
    ObjectSetString(0, "HFT_Spread", OBJPROP_TEXT,
                    "Spread: " + DoubleToString(spread, 1) + " pips");

    string status = "🟢 ACTIVE";
    color statusColor = ColorProfit;

    if(dailyLossLimitReached)
    {
        status = "🛑 DAILY LOSS LIMIT";
        statusColor = ColorLoss;
    }
    else if(dailyTargetReached)
    {
        status = "🎯 TARGET REACHED!";
        statusColor = clrGold;
    }
    else if(spread > MaxSpreadPips)
    {
        status = "⚠️ HIGH SPREAD";
        statusColor = clrOrange;
    }
    else if(dailyTradeCount >= MaxDailyTrades)
    {
        status = "🛑 MAX TRADES";
        statusColor = ColorLoss;
    }
    else if(!IsValidTradingSession())
    {
        status = "⏸️ OFF HOURS";
        statusColor = clrGray;
    }

    ObjectSetString(0, "HFT_Status", OBJPROP_TEXT, "Status: " + status);
    ObjectSetInteger(0, "HFT_Status", OBJPROP_COLOR, statusColor);

    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Create label object                                               |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int size = 9, string font = "Arial")
{
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
    ObjectSetString(0, name, OBJPROP_FONT, font);
}

//+------------------------------------------------------------------+
