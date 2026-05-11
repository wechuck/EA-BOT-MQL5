# Trading Assistant EA - User Manual

## 🎯 Overview

**Trading Assistant EA** is a signal detection and trade management system designed for manual traders who want:
- High-quality trade setup alerts (NOT auto-trading)
- Automatic trade management after manual entry
- Execution quality protection
- Modern, intuitive dashboard interface

### **CRITICAL: This EA Does NOT Auto-Trade**

✓ The EA **ONLY** detects signals and sends alerts
✓ **YOU** must manually open every trade
✓ The EA manages trades **AFTER** you open them
✗ The EA will **NEVER** open a trade automatically

---

## 📋 Table of Contents

1. [Installation](#installation)
2. [Setup & Configuration](#setup--configuration)
3. [How It Works](#how-it-works)
4. [Dashboard Guide](#dashboard-guide)
5. [Trading Workflow](#trading-workflow)
6. [Signal Logic](#signal-logic)
7. [Trade Management](#trade-management)
8. [Position Sizing](#position-sizing)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)

---

## 🔧 Installation

### Step 1: Copy Files
1. Navigate to your MT5 data folder: `File → Open Data Folder`
2. Copy the entire `TradingAssistant` folder to `MQL5/Experts/`
3. Your structure should look like:
   ```
   MQL5/
   └── Experts/
       └── TradingAssistant/
           ├── TradingAssistant_EA.mq5
           ├── Include/
           │   ├── ModernDashboard.mqh
           │   ├── SignalDetector.mqh
           │   ├── TradeManager.mqh
           │   ├── ExecutionProtection.mqh
           │   ├── PositionSizing.mqh
           │   └── AlertSystem.mqh
           └── Docs/
               ├── ScalingPlan_XAUUSD.md
               └── UserManual.md
   ```

### Step 2: Compile
1. Open MetaEditor (F4 in MT5)
2. Open `TradingAssistant_EA.mq5`
3. Click Compile (F7)
4. Check for zero errors

### Step 3: Attach to Chart
1. Open a chart for your trading symbol (XAUUSD recommended)
2. Drag `TradingAssistant_EA` from Navigator onto the chart
3. Enable AutoTrading (even though EA doesn't auto-trade, it needs permission to manage positions)
4. Set your preferred timeframe (H1 or H4 recommended)

---

## ⚙️ Setup & Configuration

### Essential Settings

#### **Signal Detection**
```
RSI Period: 14
RSI Oversold: 30
RSI Overbought: 70
Stochastic %K: 5
Stochastic %D: 3
ADX Period: 14
ADX Minimum: 20
Max Signals Per Day: 1
```

These settings focus on **quality over quantity**, generating 4-7 signals per week.

#### **Trade Management**
```
Risk:Reward Ratio: 3.0 (1:3)
ATR Multiplier for SL: 1.5
Trailing Distance: 200 points
Trailing Step: 50 points
Breakeven Distance: 100 points
```

The EA will automatically set SL and TP when you open a trade, based on ATR-calculated distances.

#### **Position Sizing**
```
Base Risk Per Trade: 5%
Aggressive Risk: 30%
Base Reward: 15%
Aggressive Reward: 70%
Aggressive Mode: false (use carefully!)
Contract Size: 100 (for XAUUSD)
```

Start with conservative settings. Only use aggressive mode for exceptional A+ setups.

#### **Execution Protection**
```
Maximum Spread: 30 points
Warning Spread: 20 points
Maximum Slippage: 10 points
```

The EA will warn you when spread is too high and prevent trade modifications during poor conditions.

#### **Alerts**
```
Enable Alerts: true
Enable Push Notifications: true
Enable Sound: true
Enable Popup: false
```

Push notifications allow you to receive alerts on your phone via MT5 mobile app.

---

## 🔍 How It Works

### System Components

1. **Signal Detector**
   - Monitors RSI, Stochastic, ADX, and market structure
   - Identifies high-probability setups
   - Sends alerts when all conditions align
   - Limits signals to prevent overtrading

2. **Trade Manager**
   - Detects when YOU manually open a position
   - Automatically sets Stop Loss and Take Profit
   - Manages trailing stop as trade moves in profit
   - Moves SL to breakeven when appropriate

3. **Execution Protection**
   - Monitors spread in real-time
   - Blocks modifications during high spread
   - Alerts you to poor execution conditions
   - Protects against slippage

4. **Position Sizing Calculator**
   - Recommends lot size based on account balance
   - Calculates risk and reward percentages
   - Tracks scaling progress
   - Adjusts for conservative or aggressive mode

5. **Modern Dashboard**
   - Real-time visual display of all system components
   - Signal status and strength
   - Trade management status
   - Execution quality indicators
   - Statistics and progress tracking

---

## 📊 Dashboard Guide

### Dashboard Layout (Top to Bottom)

#### **1. Header Section**
- **Title**: "TRADING ASSISTANT"
- **Subtitle**: System description

#### **2. Signal Status Panel** (Blue border)
- **Status Indicator**:
  - 🟢 Green = Active signal
  - 🟡 Yellow = Watching/analyzing
  - 🔴 Red = No signal
- **Signal Strength Bar**: 0-100% quality score
- **Next Signal**: Countdown or status

#### **3. Trade Management Panel** (Blue border)
- **Position Status**: Active or waiting
- **Stop Loss**: Current SL level
- **Take Profit**: Current TP level
- **Current Profit**: Live P&L in USD
- **Trailing Status**: Active or standby

#### **4. Position Sizing Panel** (Blue border)
- **Balance**: Current account balance
- **Recommended Lot**: Calculated position size
- **Risk**: Percentage risked on next trade
- **Reward**: Target profit percentage
- **R:R Ratio**: Risk to reward calculation

#### **5. Execution Quality Panel** (Blue border)
- **Current Spread**: Real-time spread in points
- **Status Indicator**:
  - 🟢 Green = Excellent conditions
  - 🟡 Yellow = Caution - elevated spread
  - 🔴 Red = Warning - avoid trading
- **Quality Message**: Execution advice

#### **6. Statistics Panel** (Blue border)
- **Signals Today**: Count for current day
- **Signals This Week**: Weekly total
- **Win Rate**: Performance tracking (requires history)
- **Total P/L**: Overall profit/loss

### Color Scheme

- **Background**: Dark theme (2026 modern design)
- **Panels**: Slightly lighter dark with blue borders
- **Text**: White for primary, gray for secondary
- **Success**: Green (profits, good conditions)
- **Warning**: Yellow/Orange (caution)
- **Danger**: Red (losses, bad conditions)
- **Info**: Blue (neutral information)
- **Accent**: Purple (special highlights)

---

## 🔄 Trading Workflow

### Daily Routine

#### **Morning (Pre-Market or Market Open)**
1. Check dashboard for overnight signals
2. Review execution quality (spread status)
3. Note any active positions being managed

#### **During Trading Hours**
1. **Wait for Signal Alert**
   - EA monitors the market continuously
   - When a high-quality setup forms, you'll receive:
     - Push notification (phone)
     - Sound alert (computer)
     - Dashboard update

2. **Review the Setup**
   - Check the chart manually
   - Confirm you agree with the signal
   - Verify spread is acceptable
   - Check recommended lot size

3. **Make Your Decision**
   - If you agree: Manually open the trade
   - If you disagree: Ignore the signal
   - EA respects YOUR final decision

4. **EA Takes Over Management**
   - EA detects your manually opened position
   - Automatically sets SL and TP
   - Begins monitoring for trailing stop
   - Protects against adverse spread movements

5. **Monitor Dashboard**
   - Watch profit progress
   - See when trailing activates
   - Track execution quality

6. **Trade Closes**
   - Either hits TP (profit) or SL (loss)
   - EA stops managing that position
   - Ready for next signal

#### **Evening (After Market)**
1. Review day's statistics on dashboard
2. Note signals generated
3. Plan for tomorrow

---

## 📈 Signal Logic

### What Creates a Signal?

A valid signal requires **ALL** of these conditions:

#### **1. RSI Condition**
- **For Buy Signals**:
  - RSI < 30 (oversold/reversal)
  - OR RSI in 30-50 range (pullback in uptrend)
- **For Sell Signals**:
  - RSI > 70 (overbought/reversal)
  - OR RSI in 50-70 range (pullback in downtrend)

#### **2. Stochastic Confirmation**
- Stochastic in oversold (<20) or overbought (>80) zone
- OR bullish/bearish crossover occurring
- Confirms timing of entry

#### **3. ADX Momentum**
- ADX > 20 (minimum threshold)
- Shows market has enough momentum
- Prevents trading in choppy conditions

#### **4. Market Structure**
- Price near support (for buys) or resistance (for sells)
- Validates setup location
- Based on recent swing highs/lows

#### **5. Signal Strength > 70%**
- Composite score from all indicators
- Only high-quality setups generate alerts
- Ensures selective trading

### Signal Types

1. **Buy - Reversal Dip**
   - RSI deeply oversold (<30)
   - At support zone
   - Momentum building

2. **Sell - Reversal Peak**
   - RSI deeply overbought (>70)
   - At resistance zone
   - Momentum building

3. **Buy - Continuation Dip**
   - RSI pullback in uptrend (30-50)
   - Buying opportunity in trend
   - Momentum confirming

4. **Sell - Continuation Peak**
   - RSI pullback in downtrend (50-70)
   - Selling opportunity in trend
   - Momentum confirming

### Frequency Control

- **Maximum**: 1 signal per day
- **Target**: 4-7 signals per week
- **Cooldown**: 4 hours between signals (configurable)
- **Philosophy**: Quality over quantity

---

## 🛡️ Trade Management

### Automatic Actions After Manual Entry

#### **1. Stop Loss Placement**
- Calculated using ATR (Average True Range)
- Formula: `SL = Entry ± (ATR × 1.5)`
- Adapts to market volatility
- Set immediately after position detected

#### **2. Take Profit Placement**
- Based on Risk:Reward ratio (default 1:3)
- Formula: `TP = Entry ± (SL Distance × 3)`
- Ensures favorable reward potential
- Set simultaneously with SL

#### **3. Breakeven Move**
- Triggers when profit > 100 points (configurable)
- Moves SL to entry price
- Protects against reversal
- Risk-free trade from this point

#### **4. Trailing Stop**
- Activates when profit > 200 points (configurable)
- Maintains 200-point distance from current price
- Updates in 50-point steps
- Locks in profits as trade progresses

#### **5. Spread Protection**
- Blocks modifications when spread > 30 points
- Prevents unfavorable SL/TP adjustments
- Alerts you to wait for better conditions

### What EA Will NOT Do

✗ Open trades automatically
✗ Close trades early (unless TP/SL hit)
✗ Override your manual SL/TP if already set
✗ Trade during your blocked times
✗ Ignore spread warnings

---

## 💰 Position Sizing

### How Lot Size is Calculated

```
Risk Amount = Balance × Risk%
SL Distance = ATR × 1.5
Lot Size = Risk Amount / (SL Distance × Point Value)
```

### Example Calculations

#### **Conservative Trade ($100 balance)**
- Risk: 5% = $5
- SL Distance: 150 points
- XAUUSD point value: ~$0.10 per point per 0.01 lot
- Lot = $5 / (150 × $0.10) = **0.03 lots**

#### **Aggressive Trade ($100 balance)**
- Risk: 30% = $30
- SL Distance: 150 points
- Lot = $30 / (150 × $0.10) = **0.20 lots**

### Scaling Strategy

See `ScalingPlan_XAUUSD.md` for detailed progression from $17 to $40,000.

**Key Principle**: As balance grows, lot size grows proportionally, but risk percentage stays constant.

---

## ✅ Best Practices

### Do's

✓ **Trust the System**
  - When you get a signal, review it seriously
  - The EA has filtered hundreds of possibilities

✓ **Be Selective**
  - It's OK to skip signals you're not confident about
  - Better to miss a trade than force a bad one

✓ **Follow Risk Management**
  - Use recommended lot sizes
  - Don't increase risk% when losing
  - Save aggressive mode for perfect setups

✓ **Let EA Manage Trades**
  - Don't manually move SL/TP after EA sets them
  - Trust the trailing stop logic
  - Resist urge to interfere

✓ **Monitor Spread**
  - Heed spread warnings
  - Don't trade when red indicator shows
  - Wait for green "excellent conditions"

✓ **Keep Dashboard Visible**
  - Quick visual reference
  - Real-time status updates
  - Execution quality awareness

### Don'ts

✗ **Don't Overtrade**
  - Respect the 4-7 signals/week limit
  - More trades ≠ more profit
  - Quality beats quantity

✗ **Don't Ignore Spread Warnings**
  - High spread = hidden costs
  - Can turn winning trade into loser
  - Wait for better conditions

✗ **Don't Use Aggressive Mode Frequently**
  - Only for exceptional A+ setups
  - 30% risk can wipe out progress quickly
  - Reserve for highest conviction

✗ **Don't Manually Close Early**
  - Let TP/SL do their job
  - Emotional exits destroy R:R ratio
  - Trust your plan

✗ **Don't Revenge Trade**
  - After a loss, wait for next signal
  - Don't double position size to "get it back"
  - Stick to the system

---

## 🔧 Troubleshooting

### Dashboard Not Showing
- **Cause**: Objects may be hidden
- **Fix**: Right-click chart → Properties → Common → Show Objects

### No Signals Generated
- **Check**: Are you in cooldown period?
- **Check**: Have you hit max signals for today?
- **Check**: Is signal strength threshold too high?
- **Solution**: Review EA logs for "Scanning..." messages

### EA Not Managing My Position
- **Check**: Is position on the same symbol as chart?
- **Check**: Did you open position AFTER EA was attached?
- **Check**: Check EA logs for "New position detected" message
- **Solution**: Restart EA or re-attach to chart

### Spread Always Shows Red
- **Cause**: Spread may genuinely be too high
- **Check**: What's actual spread? (Market Watch → Symbol → Spread)
- **Solution**: Adjust `InpMaxSpread` parameter or wait for better conditions
- **Note**: During news events, spread legitimately widens

### Lot Size Seems Wrong
- **Check**: Balance in dashboard vs actual balance
- **Check**: Risk% setting
- **Check**: Current ATR value (affects SL distance)
- **Solution**: Manually verify calculation or adjust risk%

### Trailing Stop Not Activating
- **Check**: Has position reached 200 points profit?
- **Check**: Is spread currently acceptable?
- **Solution**: Be patient, trailing activates automatically when threshold met

### Alerts Not Received on Phone
- **Setup**: Enable push notifications in MT5 mobile app
- **Setup**: Tools → Options → Notifications → Enable Push
- **Check**: Test with simple script: `SendNotification("Test")`

---

## 📱 Mobile Trading

### Using with MT5 Mobile App

1. **Install MT5 Mobile**
   - Download from App Store or Google Play
   - Log in with same account

2. **Enable Notifications**
   - Settings → Notifications → Enable
   - Allow notifications at OS level

3. **When Alert Arrives**
   - Tap notification to open app
   - Review chart on phone
   - Can enter trade from mobile
   - EA will manage once position opens

4. **Monitor Dashboard**
   - Not visible on mobile chart
   - Check desktop periodically
   - Or rely on push alerts for status

---

## 📚 Additional Resources

### Recommended Reading
- `ScalingPlan_XAUUSD.md` - Detailed $17 to $40k roadmap
- MT5 Help → MQL5 → Expert Advisors

### Support & Updates
- GitHub: https://github.com/wechuck/EA-BOT-MQL5
- Issues: Report bugs or request features

### Learning Resources
- Study your winning trades: What made the setup strong?
- Review losing trades: Was signal strength below 80%?
- Track your manual decisions: Do you skip signals that win?

---

## ⚖️ Legal Disclaimer

**Trading involves risk. This EA is a tool, not a guarantee of profit.**

- Past performance does not indicate future results
- You can lose more than your initial investment
- Only trade with money you can afford to lose
- The EA provides signals and management, but YOU make final decisions
- No warranty or guarantee of profitability is provided
- Use at your own risk

---

## 🎓 Philosophy

**This EA embodies a specific trading approach:**

1. **Quality over Quantity** - Few excellent trades beat many mediocre ones
2. **Human + Machine** - You analyze, EA executes and protects
3. **Discipline over Emotion** - System prevents impulsive decisions
4. **Protection over Prediction** - Manage risk first, chase profit second
5. **Consistency over Home Runs** - Steady growth compounds

**Your role**: Chart analyst and decision maker
**EA's role**: Signal detector, trade protector, statistics tracker

---

**Trade with discipline. Scale with patience. Succeed with consistency.**

*Good luck on your journey from $17 to $40,000!*
