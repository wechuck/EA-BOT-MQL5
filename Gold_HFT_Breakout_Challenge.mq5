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
input double   RiskPercentPerTrade = 2.0;       // Risk Per Trade (% of balance)
input double   MaxLotSize = 0.1;                // Maximum Lot Size
input int      StopLossPips = 150;              // Stop Loss (pips)
input int      TakeProfitPips = 500;            // Take Profit (pips)
input int      BreakevenPips = 50;              // Move to Breakeven at (pips)
input int      TrailingStartPips = 100;         // Start Trailing at (pips)
input int      TrailingStepPips = 20;           // Trailing Step (pips)

input group "=== Breakout Strategy ==="
input int      BreakoutPeriod = 20;             // Breakout Period (bars)
input int      BreakoutBuffer = 5;              // Breakout Buffer (pips)
input int      MinVolatilityPips = 30;          // Minimum Volatility (pips)
input bool     UseMultiTimeframe = true;        // Use Multi-Timeframe Confirmation

input group "=== Risk Management ==="
input int      MaxSpreadPips = 40;              // Maximum Allowed Spread (pips)
input int      MaxSlippagePips = 40;            // Maximum Allowed Slippage (pips)
input double   MaxDailyDrawdownPercent = 30.0;  // Max Daily Drawdown (%)
input int      MaxConcurrentPositions = 2;      // Max Concurrent Positions

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

//--- Global Variables
CTrade trade;
datetime lastBarTime = 0;
datetime dailyResetTime = 0;
int dailyTradeCount = 0;
double dailyProfit = 0.0;
double dailyStartBalance = 0.0;
bool dailyTargetReached = false;
double pointValue = 0.0;

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
        return; // Not enough volatility
    }

    //--- Add buffer
    double bufferPoints = BreakoutBuffer * 10 * pointValue;
    double buyLevel = highLevel + bufferPoints;
    double sellLevel = lowLevel - bufferPoints;

    //--- Check for bullish breakout
    if(ask > buyLevel)
    {
        if(UseMultiTimeframe && !ConfirmTrend(true)) return;
        OpenPosition(ORDER_TYPE_BUY);
    }
    //--- Check for bearish breakout
    else if(bid < sellLevel)
    {
        if(UseMultiTimeframe && !ConfirmTrend(false)) return;
        OpenPosition(ORDER_TYPE_SELL);
    }
}

//+------------------------------------------------------------------+
//| Confirm trend on higher timeframe                                 |
//+------------------------------------------------------------------+
bool ConfirmTrend(bool bullish)
{
    int maHandle = iMA(_Symbol, PERIOD_M15, 20, 0, MODE_SMA, PRICE_CLOSE);
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
//| Calculate dynamic lot size based on account balance               |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    if(!UseDynamicLotSize)
        return FixedLotSize;

    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * (RiskPercentPerTrade / 100.0);

    // Calculate pip value for the symbol
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double pipValue = (tickValue / tickSize) * 10 * pointValue;

    if(pipValue == 0)
        return FixedLotSize;

    // Calculate lot size based on risk
    double lotSize = riskAmount / (StopLossPips * pipValue);

    // Apply lot size constraints
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

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

        //--- Calculate profit in pips
        double profitPips = 0;
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            profitPips = (currentPrice - openPrice) / pointValue / 10.0;
        else
            profitPips = (openPrice - currentPrice) / pointValue / 10.0;

        //--- Move to breakeven
        if(profitPips >= BreakevenPips && sl != openPrice)
        {
            if(trade.PositionModify(ticket, openPrice, tp))
            {
                Print("📊 Position moved to breakeven: Ticket #", ticket);
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

                if(newSL > sl)
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

                if(newSL < sl || sl == 0)
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
    dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    dailyTargetReached = false;

    Print("📅 Daily counters reset | Balance: $", DoubleToString(dailyStartBalance, 2));
}

//+------------------------------------------------------------------+
//| Update daily profit                                               |
//+------------------------------------------------------------------+
void UpdateDailyProfit()
{
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    dailyProfit = currentEquity - dailyStartBalance;
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

    if(dailyTargetReached)
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
