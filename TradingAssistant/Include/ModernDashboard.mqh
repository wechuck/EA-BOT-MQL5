//+------------------------------------------------------------------+
//|                                            ModernDashboard.mqh   |
//|                                      Trading Assistant Dashboard |
//|                                          Modern 2026 UI/UX Design |
//+------------------------------------------------------------------+
#property copyright "Trading Assistant 2026"
#property version   "1.00"
#property strict

//--- Dashboard color scheme (Modern 2026 - Dark theme with accent colors)
#define DASHBOARD_BG_COLOR        C'18,18,24'      // Deep dark background
#define DASHBOARD_PANEL_COLOR     C'28,28,36'      // Panel background
#define DASHBOARD_BORDER_COLOR    C'68,138,255'    // Accent blue border
#define DASHBOARD_TEXT_COLOR      clrWhite         // Primary text
#define DASHBOARD_TEXT_MUTED      C'156,163,175'   // Muted text
#define DASHBOARD_SUCCESS_COLOR   C'52,211,153'    // Green for positive
#define DASHBOARD_WARNING_COLOR   C'251,191,36'    // Yellow for warning
#define DASHBOARD_DANGER_COLOR    C'239,68,68'     // Red for danger
#define DASHBOARD_INFO_COLOR      C'96,165,250'    // Info blue
#define DASHBOARD_ACCENT_COLOR    C'139,92,246'    // Purple accent

//--- Box/Card styling
#define BOX_SHADOW_COLOR          C'10,10,15'      // Shadow effect
#define BOX_RADIUS                8                // Corner radius effect
#define BOX_PADDING               12               // Internal padding

//+------------------------------------------------------------------+
//| Modern Dashboard Class                                           |
//+------------------------------------------------------------------+
class CModernDashboard
{
private:
   string   m_prefix;          // Object name prefix
   int      m_x_pos;           // X position
   int      m_y_pos;           // Y position
   int      m_width;           // Dashboard width
   int      m_height;          // Dashboard height
   bool     m_is_visible;      // Visibility state

   // Dashboard panels
   string   m_panel_signal;    // Signal status panel
   string   m_panel_trade;     // Trade management panel
   string   m_panel_risk;      // Risk & position sizing panel
   string   m_panel_exec;      // Execution quality panel
   string   m_panel_stats;     // Statistics panel

   // Entry popup alert
   datetime m_popup_time;      // Time when popup was shown
   bool     m_popup_active;    // Is popup currently displayed
   string   m_popup_signal;    // Signal type for popup

public:
   CModernDashboard();
   ~CModernDashboard();

   // Initialization
   bool Init(string prefix, int x, int y, int width = 450, int height = 650);
   void Deinit();

   // Main dashboard drawing
   void Draw();
   void Update();
   void Hide();
   void Show();

   // Panel updates
   void UpdateSignalPanel(string signal_status, int signal_strength, string next_signal);
   void UpdateSignalPanel(string signal_status, int signal_strength, string next_signal, double recommended_lot);
   void UpdateTradePanel(bool has_position, double sl, double tp, double profit, bool trailing_active);
   void UpdateRiskPanel(double balance, double lot_size, double risk_pct, double reward_pct);
   void UpdateExecutionPanel(double spread, int spread_status, string exec_quality);
   void UpdateStatsPanel(int signals_today, int signals_week, double win_rate, double total_profit);

   // NEW PANELS - Enhanced features
   void UpdateSignalHistoryPanel(string recent_signals[]);
   void UpdateMarketAnalysisPanel(string trend, string volatility, double support, double resistance, double atr);
   void UpdatePerformancePanel(double total_profit, double win_rate, double profit_factor, int total_trades);
   void UpdateFilterStatusPanel(string active_filters, bool trading_allowed, string block_reason);
   void UpdateRiskLimitsPanel(double daily_pnl, double weekly_pnl, int trades_today, int consecutive_losses);

   // Overloaded with signal direction
   void UpdateSignalPanel(string signal_status, int signal_strength, string next_signal, double recommended_lot, string signal_direction);

   // Entry popup alert
   void ShowEntryPopup(string signal_type, double lot_size);
   void HideEntryPopup();
   void UpdateEntryPopup();

   // Chart visual helpers
   void DrawSLTPLines(string signal_type, double entry_price, double sl_price, double tp_price);
   void DrawSignalArrow(string signal_type, double price);
   void ClearChartLines();

private:
   // Drawing helpers
   void DrawPanel(string name, int x, int y, int width, int height, color bg_color, color border_color);
   void DrawLabel(string name, int x, int y, string text, color clr, int font_size = 9, string font = "Segoe UI");
   void DrawBox(string name, int x, int y, int width, int height, color bg_color, bool with_shadow = true);
   void DrawProgressBar(string name, int x, int y, int width, int height, double percent, color bar_color);
   void DrawStatusIndicator(string name, int x, int y, int status);
   void DrawMetricCard(string name, int x, int y, int width, string label, string value, color value_color);

   void DeleteObject(string name);
   void DeleteAllObjects();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CModernDashboard::CModernDashboard()
{
   m_prefix = "TradingAssist_";
   m_x_pos = 20;
   m_y_pos = 30;
   m_width = 450;
   m_height = 650;
   m_is_visible = true;

   // Popup alert
   m_popup_active = false;
   m_popup_time = 0;
   m_popup_signal = "";
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CModernDashboard::~CModernDashboard()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Initialize dashboard                                             |
//+------------------------------------------------------------------+
bool CModernDashboard::Init(string prefix, int x, int y, int width = 450, int height = 650)
{
   m_prefix = prefix + "_";
   m_x_pos = x;
   m_y_pos = y;
   m_width = width;
   m_height = height;

   m_panel_signal = m_prefix + "PanelSignal";
   m_panel_trade = m_prefix + "PanelTrade";
   m_panel_risk = m_prefix + "PanelRisk";
   m_panel_exec = m_prefix + "PanelExec";
   m_panel_stats = m_prefix + "PanelStats";

   Draw();
   return true;
}

//+------------------------------------------------------------------+
//| Cleanup dashboard objects                                        |
//+------------------------------------------------------------------+
void CModernDashboard::Deinit()
{
   DeleteAllObjects();
}

//+------------------------------------------------------------------+
//| Draw main dashboard structure                                    |
//+------------------------------------------------------------------+
void CModernDashboard::Draw()
{
   if(!m_is_visible) return;

   int y_offset = m_y_pos;

   // Main background panel
   DrawBox(m_prefix + "MainBG", m_x_pos, m_y_pos, m_width, m_height, DASHBOARD_BG_COLOR, true);

   // Header
   DrawLabel(m_prefix + "HeaderTitle", m_x_pos + 20, y_offset + 15, "TRADING ASSISTANT", DASHBOARD_BORDER_COLOR, 14, "Segoe UI Semibold");
   DrawLabel(m_prefix + "HeaderSubtitle", m_x_pos + 20, y_offset + 38, "Signal & Trade Management System", DASHBOARD_TEXT_MUTED, 8);
   y_offset += 70;

   // Signal Status Panel
   DrawPanel(m_panel_signal, m_x_pos + 15, y_offset, m_width - 30, 120, DASHBOARD_PANEL_COLOR, DASHBOARD_BORDER_COLOR);
   DrawLabel(m_prefix + "SignalTitle", m_x_pos + 27, y_offset + 12, "SIGNAL STATUS", DASHBOARD_TEXT_MUTED, 8);
   y_offset += 140;

   // Trade Management Panel
   DrawPanel(m_panel_trade, m_x_pos + 15, y_offset, m_width - 30, 110, DASHBOARD_PANEL_COLOR, DASHBOARD_BORDER_COLOR);
   DrawLabel(m_prefix + "TradeTitle", m_x_pos + 27, y_offset + 12, "TRADE MANAGEMENT", DASHBOARD_TEXT_MUTED, 8);
   y_offset += 130;

   // Risk & Position Sizing Panel
   DrawPanel(m_panel_risk, m_x_pos + 15, y_offset, m_width - 30, 110, DASHBOARD_PANEL_COLOR, DASHBOARD_BORDER_COLOR);
   DrawLabel(m_prefix + "RiskTitle", m_x_pos + 27, y_offset + 12, "POSITION SIZING", DASHBOARD_TEXT_MUTED, 8);
   y_offset += 130;

   // Execution Quality Panel
   DrawPanel(m_panel_exec, m_x_pos + 15, y_offset, m_width - 30, 80, DASHBOARD_PANEL_COLOR, DASHBOARD_BORDER_COLOR);
   DrawLabel(m_prefix + "ExecTitle", m_x_pos + 27, y_offset + 12, "EXECUTION QUALITY", DASHBOARD_TEXT_MUTED, 8);
   y_offset += 100;

   // Statistics Panel (bottom)
   DrawPanel(m_panel_stats, m_x_pos + 15, y_offset, m_width - 30, 70, DASHBOARD_PANEL_COLOR, DASHBOARD_BORDER_COLOR);
   DrawLabel(m_prefix + "StatsTitle", m_x_pos + 27, y_offset + 12, "STATISTICS", DASHBOARD_TEXT_MUTED, 8);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update Signal Panel                                              |
//+------------------------------------------------------------------+
void CModernDashboard::UpdateSignalPanel(string signal_status, int signal_strength, string next_signal)
{
   int panel_y = m_y_pos + 70;

   // Status indicator with more states
   int status_level = 0;
   if(signal_status == "ACTIVE")
      status_level = 2;       // Green - signal active
   else if(signal_status == "SCANNING")
      status_level = 1;       // Yellow - analyzing potential signal
   else if(signal_status == "WATCHING")
      status_level = 1;       // Yellow - watching market
   else
      status_level = 0;       // Red/Gray - idle

   DrawStatusIndicator(m_prefix + "SignalIndicator", m_x_pos + 27, panel_y + 35, status_level);

   // Signal status text with color
   color status_color = DASHBOARD_TEXT_MUTED;
   if(signal_status == "ACTIVE")
      status_color = DASHBOARD_SUCCESS_COLOR;
   else if(signal_status == "SCANNING")
      status_color = DASHBOARD_WARNING_COLOR;
   else if(signal_status == "WATCHING")
      status_color = DASHBOARD_INFO_COLOR;
   else // IDLE
      status_color = DASHBOARD_TEXT_MUTED;

   DrawLabel(m_prefix + "SignalStatus", m_x_pos + 55, panel_y + 32, signal_status, status_color, 11, "Segoe UI Semibold");

   // Signal strength bar
   DrawLabel(m_prefix + "SignalStrengthLabel", m_x_pos + 27, panel_y + 58, "Signal Strength:", DASHBOARD_TEXT_MUTED, 8);
   DrawProgressBar(m_prefix + "SignalStrengthBar", m_x_pos + 27, panel_y + 75, m_width - 84, 15, signal_strength,
                   signal_strength >= 80 ? DASHBOARD_SUCCESS_COLOR :
                   signal_strength >= 50 ? DASHBOARD_WARNING_COLOR : DASHBOARD_DANGER_COLOR);
   DrawLabel(m_prefix + "SignalStrengthValue", m_x_pos + m_width - 55, panel_y + 73, IntegerToString(signal_strength) + "%", DASHBOARD_TEXT_COLOR, 9);

   // Next signal countdown
   DrawLabel(m_prefix + "NextSignalLabel", m_x_pos + 27, panel_y + 100, "Next Signal:", DASHBOARD_TEXT_MUTED, 8);
   DrawLabel(m_prefix + "NextSignalValue", m_x_pos + 100, panel_y + 100, next_signal, DASHBOARD_INFO_COLOR, 8);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update Trade Management Panel                                    |
//+------------------------------------------------------------------+
void CModernDashboard::UpdateTradePanel(bool has_position, double sl, double tp, double profit, bool trailing_active)
{
   int panel_y = m_y_pos + 210;

   if(has_position)
   {
      // Position active
      DrawLabel(m_prefix + "TradeActive", m_x_pos + 27, panel_y + 35, "Position Active", DASHBOARD_SUCCESS_COLOR, 10, "Segoe UI Semibold");

      // SL and TP
      DrawLabel(m_prefix + "TradeSL", m_x_pos + 27, panel_y + 55, "Stop Loss: " + DoubleToString(sl, 2), DASHBOARD_TEXT_COLOR, 9);
      DrawLabel(m_prefix + "TradeTP", m_x_pos + 27, panel_y + 73, "Take Profit: " + DoubleToString(tp, 2), DASHBOARD_TEXT_COLOR, 9);

      // Profit display
      color profit_color = profit >= 0 ? DASHBOARD_SUCCESS_COLOR : DASHBOARD_DANGER_COLOR;
      string profit_text = (profit >= 0 ? "+" : "") + DoubleToString(profit, 2) + " USD";
      DrawLabel(m_prefix + "TradeProfit", m_x_pos + m_width - 135, panel_y + 35, profit_text, profit_color, 11, "Segoe UI Semibold");

      // Trailing stop status
      if(trailing_active)
         DrawLabel(m_prefix + "TradeTrailing", m_x_pos + 27, panel_y + 91, "⚡ Trailing Active", DASHBOARD_ACCENT_COLOR, 8);
      else
         DrawLabel(m_prefix + "TradeTrailing", m_x_pos + 27, panel_y + 91, "Trailing Standby", DASHBOARD_TEXT_MUTED, 8);
   }
   else
   {
      // No position
      DrawLabel(m_prefix + "TradeActive", m_x_pos + 27, panel_y + 35, "No Active Position", DASHBOARD_TEXT_MUTED, 10);
      DrawLabel(m_prefix + "TradeSL", m_x_pos + 27, panel_y + 60, "Waiting for manual entry...", DASHBOARD_TEXT_MUTED, 9);
      DeleteObject(m_prefix + "TradeTP");
      DeleteObject(m_prefix + "TradeProfit");
      DeleteObject(m_prefix + "TradeTrailing");
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update Risk & Position Sizing Panel                             |
//+------------------------------------------------------------------+
void CModernDashboard::UpdateRiskPanel(double balance, double lot_size, double risk_pct, double reward_pct)
{
   int panel_y = m_y_pos + 340;

   // Balance
   DrawLabel(m_prefix + "RiskBalance", m_x_pos + 27, panel_y + 35, "Balance: $" + DoubleToString(balance, 2), DASHBOARD_TEXT_COLOR, 10, "Segoe UI Semibold");

   // Recommended lot size
   DrawLabel(m_prefix + "RiskLotLabel", m_x_pos + 27, panel_y + 58, "Recommended Lot:", DASHBOARD_TEXT_MUTED, 8);
   DrawLabel(m_prefix + "RiskLotValue", m_x_pos + 135, panel_y + 58, DoubleToString(lot_size, 2), DASHBOARD_INFO_COLOR, 9, "Segoe UI Semibold");

   // Risk/Reward display
   DrawLabel(m_prefix + "RiskRatio", m_x_pos + 27, panel_y + 76, "Risk: " + DoubleToString(risk_pct, 1) + "%", DASHBOARD_DANGER_COLOR, 9);
   DrawLabel(m_prefix + "RewardRatio", m_x_pos + 120, panel_y + 76, "→ Reward: " + DoubleToString(reward_pct, 1) + "%", DASHBOARD_SUCCESS_COLOR, 9);

   // R:R calculation
   double rr_ratio = risk_pct > 0 ? reward_pct / risk_pct : 0;
   DrawLabel(m_prefix + "RRRatio", m_x_pos + m_width - 100, panel_y + 76, "R:R = 1:" + DoubleToString(rr_ratio, 1), DASHBOARD_ACCENT_COLOR, 9, "Segoe UI Semibold");

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update Execution Quality Panel                                   |
//+------------------------------------------------------------------+
void CModernDashboard::UpdateExecutionPanel(double spread, int spread_status, string exec_quality)
{
   int panel_y = m_y_pos + 470;

   // Spread display
   DrawLabel(m_prefix + "ExecSpreadLabel", m_x_pos + 27, panel_y + 35, "Current Spread:", DASHBOARD_TEXT_MUTED, 8);

   color spread_color = spread_status == 2 ? DASHBOARD_SUCCESS_COLOR :
                       spread_status == 1 ? DASHBOARD_WARNING_COLOR : DASHBOARD_DANGER_COLOR;
   DrawLabel(m_prefix + "ExecSpreadValue", m_x_pos + 120, panel_y + 35, DoubleToString(spread, 1) + " pts", spread_color, 9, "Segoe UI Semibold");

   // Status indicator
   DrawStatusIndicator(m_prefix + "ExecIndicator", m_x_pos + m_width - 60, panel_y + 35, spread_status);

   // Execution quality message
   DrawLabel(m_prefix + "ExecQuality", m_x_pos + 27, panel_y + 55, exec_quality, DASHBOARD_TEXT_COLOR, 8);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update Statistics Panel                                          |
//+------------------------------------------------------------------+
void CModernDashboard::UpdateStatsPanel(int signals_today, int signals_week, double win_rate, double total_profit)
{
   int panel_y = m_y_pos + 570;

   // Signals count
   DrawLabel(m_prefix + "StatsSignalsToday", m_x_pos + 27, panel_y + 35, "Today: " + IntegerToString(signals_today), DASHBOARD_TEXT_COLOR, 8);
   DrawLabel(m_prefix + "StatsSignalsWeek", m_x_pos + 100, panel_y + 35, "This Week: " + IntegerToString(signals_week), DASHBOARD_TEXT_COLOR, 8);

   // Win rate
   color wr_color = win_rate >= 60 ? DASHBOARD_SUCCESS_COLOR :
                   win_rate >= 45 ? DASHBOARD_WARNING_COLOR : DASHBOARD_DANGER_COLOR;
   DrawLabel(m_prefix + "StatsWinRate", m_x_pos + 210, panel_y + 35, "Win Rate: " + DoubleToString(win_rate, 1) + "%", wr_color, 8);

   // Total profit
   color profit_color = total_profit >= 0 ? DASHBOARD_SUCCESS_COLOR : DASHBOARD_DANGER_COLOR;
   string profit_text = (total_profit >= 0 ? "+" : "") + DoubleToString(total_profit, 2);
   DrawLabel(m_prefix + "StatsProfit", m_x_pos + 27, panel_y + 53, "Total P/L: $" + profit_text, profit_color, 8, "Segoe UI Semibold");

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Draw panel with border                                           |
//+------------------------------------------------------------------+
void CModernDashboard::DrawPanel(string name, int x, int y, int width, int height, color bg_color, color border_color)
{
   // Background
   DrawBox(name + "_BG", x, y, width, height, bg_color, false);

   // Border (using thin rectangles)
   ObjectCreate(0, name + "_Border", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name + "_Border", OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name + "_Border", OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name + "_Border", OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name + "_Border", OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name + "_Border", OBJPROP_BGCOLOR, bg_color);
   ObjectSetInteger(0, name + "_Border", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name + "_Border", OBJPROP_COLOR, border_color);
   ObjectSetInteger(0, name + "_Border", OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name + "_Border", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name + "_Border", OBJPROP_BACK, true);
   ObjectSetInteger(0, name + "_Border", OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Draw label                                                        |
//+------------------------------------------------------------------+
void CModernDashboard::DrawLabel(string name, int x, int y, string text, color clr, int font_size = 9, string font = "Segoe UI")
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Draw box/card                                                     |
//+------------------------------------------------------------------+
void CModernDashboard::DrawBox(string name, int x, int y, int width, int height, color bg_color, bool with_shadow = true)
{
   // Shadow effect (optional)
   if(with_shadow)
   {
      ObjectCreate(0, name + "_Shadow", OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name + "_Shadow", OBJPROP_XDISTANCE, x + 3);
      ObjectSetInteger(0, name + "_Shadow", OBJPROP_YDISTANCE, y + 3);
      ObjectSetInteger(0, name + "_Shadow", OBJPROP_XSIZE, width);
      ObjectSetInteger(0, name + "_Shadow", OBJPROP_YSIZE, height);
      ObjectSetInteger(0, name + "_Shadow", OBJPROP_BGCOLOR, BOX_SHADOW_COLOR);
      ObjectSetInteger(0, name + "_Shadow", OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name + "_Shadow", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name + "_Shadow", OBJPROP_BACK, true);
      ObjectSetInteger(0, name + "_Shadow", OBJPROP_SELECTABLE, false);
   }

   // Main box
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Draw progress bar                                                 |
//+------------------------------------------------------------------+
void CModernDashboard::DrawProgressBar(string name, int x, int y, int width, int height, double percent, color bar_color)
{
   // Background bar
   DrawBox(name + "_BG", x, y, width, height, C'40,40,48', false);

   // Progress fill
   int fill_width = (int)(width * MathMin(percent / 100.0, 1.0));
   if(fill_width > 0)
      DrawBox(name + "_Fill", x, y, fill_width, height, bar_color, false);
}

//+------------------------------------------------------------------+
//| Draw status indicator (dot)                                      |
//+------------------------------------------------------------------+
void CModernDashboard::DrawStatusIndicator(string name, int x, int y, int status)
{
   color dot_color = status == 2 ? DASHBOARD_SUCCESS_COLOR :
                    status == 1 ? DASHBOARD_WARNING_COLOR : DASHBOARD_DANGER_COLOR;

   // Draw filled circle using label with bullet character
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, dot_color);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 16);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, "●");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Delete single object                                             |
//+------------------------------------------------------------------+
void CModernDashboard::DeleteObject(string name)
{
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
}

//+------------------------------------------------------------------+
//| Delete all dashboard objects                                     |
//+------------------------------------------------------------------+
void CModernDashboard::DeleteAllObjects()
{
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, m_prefix) == 0)
         ObjectDelete(0, name);
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Hide dashboard                                                    |
//+------------------------------------------------------------------+
void CModernDashboard::Hide()
{
   m_is_visible = false;
   DeleteAllObjects();
}

//+------------------------------------------------------------------+
//| Show dashboard                                                    |
//+------------------------------------------------------------------+
void CModernDashboard::Show()
{
   m_is_visible = true;
   Draw();
}

//+------------------------------------------------------------------+
//| Update dashboard (refresh)                                       |
//+------------------------------------------------------------------+
void CModernDashboard::Update()
{
   // Called periodically to refresh display
   UpdateEntryPopup(); // Check if popup should be hidden
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Overloaded UpdateSignalPanel with lot size                      |
//+------------------------------------------------------------------+
void CModernDashboard::UpdateSignalPanel(string signal_status, int signal_strength, string next_signal, double recommended_lot)
{
   int panel_y = m_y_pos + 70;

   // Status indicator with more states
   int status_level = 0;
   if(signal_status == "ACTIVE")
      status_level = 2;       // Green - signal active
   else if(signal_status == "SCANNING")
      status_level = 1;       // Yellow - analyzing potential signal
   else if(signal_status == "WATCHING")
      status_level = 1;       // Yellow - watching market
   else
      status_level = 0;       // Red/Gray - idle

   DrawStatusIndicator(m_prefix + "SignalIndicator", m_x_pos + 27, panel_y + 35, status_level);

   // Signal status text with color
   color status_color = DASHBOARD_TEXT_MUTED;
   if(signal_status == "ACTIVE")
      status_color = DASHBOARD_SUCCESS_COLOR;
   else if(signal_status == "SCANNING")
      status_color = DASHBOARD_WARNING_COLOR;
   else if(signal_status == "WATCHING")
      status_color = DASHBOARD_INFO_COLOR;
   else // IDLE
      status_color = DASHBOARD_TEXT_MUTED;

   DrawLabel(m_prefix + "SignalStatus", m_x_pos + 55, panel_y + 32, signal_status, status_color, 11, "Segoe UI Semibold");

   // Signal strength bar
   DrawLabel(m_prefix + "SignalStrengthLabel", m_x_pos + 27, panel_y + 58, "Signal Strength:", DASHBOARD_TEXT_MUTED, 8);
   DrawProgressBar(m_prefix + "SignalStrengthBar", m_x_pos + 27, panel_y + 75, m_width - 84, 15, signal_strength,
                   signal_strength >= 80 ? DASHBOARD_SUCCESS_COLOR :
                   signal_strength >= 50 ? DASHBOARD_WARNING_COLOR : DASHBOARD_DANGER_COLOR);
   DrawLabel(m_prefix + "SignalStrengthValue", m_x_pos + m_width - 55, panel_y + 73, IntegerToString(signal_strength) + "%", DASHBOARD_TEXT_COLOR, 9);

   // Next signal countdown
   DrawLabel(m_prefix + "NextSignalLabel", m_x_pos + 27, panel_y + 100, "Next Signal:", DASHBOARD_TEXT_MUTED, 8);
   DrawLabel(m_prefix + "NextSignalValue", m_x_pos + 100, panel_y + 100, next_signal, DASHBOARD_INFO_COLOR, 8);

   // Recommended lot size (prominent display)
   if(signal_status == "ACTIVE" && recommended_lot > 0)
   {
      DrawLabel(m_prefix + "RecommendedLotLabel", m_x_pos + 220, panel_y + 100, "USE LOT:", DASHBOARD_TEXT_MUTED, 8);
      DrawLabel(m_prefix + "RecommendedLotValue", m_x_pos + 280, panel_y + 98, DoubleToString(recommended_lot, 2),
                DASHBOARD_ACCENT_COLOR, 12, "Segoe UI Bold");
   }
   else
   {
      DeleteObject(m_prefix + "RecommendedLotLabel");
      DeleteObject(m_prefix + "RecommendedLotValue");
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Overloaded UpdateSignalPanel with signal direction              |
//+------------------------------------------------------------------+
void CModernDashboard::UpdateSignalPanel(string signal_status, int signal_strength, string next_signal, double recommended_lot, string signal_direction)
{
   int panel_y = m_y_pos + 70;

   // Status indicator with more states
   int status_level = 0;
   if(signal_status == "ACTIVE")
      status_level = 2;       // Green - signal active
   else if(signal_status == "SCANNING")
      status_level = 1;       // Yellow - analyzing potential signal
   else if(signal_status == "WATCHING")
      status_level = 1;       // Yellow - watching market
   else
      status_level = 0;       // Red/Gray - idle

   DrawStatusIndicator(m_prefix + "SignalIndicator", m_x_pos + 27, panel_y + 35, status_level);

   // Signal status text with color
   color status_color = DASHBOARD_TEXT_MUTED;
   if(signal_status == "ACTIVE")
      status_color = DASHBOARD_SUCCESS_COLOR;
   else if(signal_status == "SCANNING")
      status_color = DASHBOARD_WARNING_COLOR;
   else if(signal_status == "WATCHING")
      status_color = DASHBOARD_INFO_COLOR;
   else // IDLE
      status_color = DASHBOARD_TEXT_MUTED;

   DrawLabel(m_prefix + "SignalStatus", m_x_pos + 55, panel_y + 32, signal_status, status_color, 11, "Segoe UI Semibold");

   // Signal direction (BUY/SELL) - prominently displayed
   if(signal_direction != "" && signal_direction != "NONE")
   {
      color dir_color = (StringFind(signal_direction, "BUY") >= 0) ? DASHBOARD_SUCCESS_COLOR : DASHBOARD_DANGER_COLOR;
      string dir_icon = (StringFind(signal_direction, "BUY") >= 0) ? "▲ " : "▼ ";
      DrawLabel(m_prefix + "SignalDirection", m_x_pos + 160, panel_y + 30, dir_icon + signal_direction, dir_color, 14, "Segoe UI Bold");
   }
   else
   {
      DeleteObject(m_prefix + "SignalDirection");
   }

   // Signal strength bar
   DrawLabel(m_prefix + "SignalStrengthLabel", m_x_pos + 27, panel_y + 58, "Signal Strength:", DASHBOARD_TEXT_MUTED, 8);
   DrawProgressBar(m_prefix + "SignalStrengthBar", m_x_pos + 27, panel_y + 75, m_width - 84, 15, signal_strength,
                   signal_strength >= 80 ? DASHBOARD_SUCCESS_COLOR :
                   signal_strength >= 50 ? DASHBOARD_WARNING_COLOR : DASHBOARD_DANGER_COLOR);
   DrawLabel(m_prefix + "SignalStrengthValue", m_x_pos + m_width - 55, panel_y + 73, IntegerToString(signal_strength) + "%", DASHBOARD_TEXT_COLOR, 9);

   // Next signal countdown
   DrawLabel(m_prefix + "NextSignalLabel", m_x_pos + 27, panel_y + 100, "Next Signal:", DASHBOARD_TEXT_MUTED, 8);
   DrawLabel(m_prefix + "NextSignalValue", m_x_pos + 100, panel_y + 100, next_signal, DASHBOARD_INFO_COLOR, 8);

   // Recommended lot size (prominent display)
   if(signal_status == "ACTIVE" && recommended_lot > 0)
   {
      DrawLabel(m_prefix + "RecommendedLotLabel", m_x_pos + 220, panel_y + 100, "USE LOT:", DASHBOARD_TEXT_MUTED, 8);
      DrawLabel(m_prefix + "RecommendedLotValue", m_x_pos + 280, panel_y + 98, DoubleToString(recommended_lot, 2),
                DASHBOARD_ACCENT_COLOR, 12, "Segoe UI Bold");
   }
   else
   {
      DeleteObject(m_prefix + "RecommendedLotLabel");
      DeleteObject(m_prefix + "RecommendedLotValue");
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Show Entry Popup Alert                                          |
//+------------------------------------------------------------------+
void CModernDashboard::ShowEntryPopup(string signal_type, double lot_size)
{
   m_popup_active = true;
   m_popup_time = TimeCurrent();
   m_popup_signal = signal_type;

   // Center of screen position
   int chart_width = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chart_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   int popup_x = chart_width / 2 - 200;
   int popup_y = chart_height / 2 - 100;

   // Background box with shadow
   DrawBox(m_prefix + "PopupBG", popup_x, popup_y, 400, 200, C'139,92,246', true); // Purple background

   // "ENTRY NOW!" text
   DrawLabel(m_prefix + "PopupTitle", popup_x + 80, popup_y + 30, "⚡ ENTRY NOW! ⚡", clrWhite, 24, "Arial Black");

   // Signal type
   DrawLabel(m_prefix + "PopupSignal", popup_x + 100, popup_y + 80, signal_type, DASHBOARD_SUCCESS_COLOR, 16, "Segoe UI Semibold");

   // Lot size
   DrawLabel(m_prefix + "PopupLotLabel", popup_x + 50, popup_y + 120, "Recommended Lot:", clrWhite, 12);
   DrawLabel(m_prefix + "PopupLotValue", popup_x + 230, popup_y + 118, DoubleToString(lot_size, 2),
             DASHBOARD_WARNING_COLOR, 16, "Segoe UI Bold");

   // Auto-hide message
   DrawLabel(m_prefix + "PopupTimer", popup_x + 110, popup_y + 160, "(Auto-hide in 60 seconds)", C'200,200,200', 8);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Hide Entry Popup Alert                                          |
//+------------------------------------------------------------------+
void CModernDashboard::HideEntryPopup()
{
   if(!m_popup_active)
      return;

   m_popup_active = false;
   m_popup_time = 0;

   // Delete all popup objects
   DeleteObject(m_prefix + "PopupBG");
   DeleteObject(m_prefix + "PopupBG_Shadow");
   DeleteObject(m_prefix + "PopupTitle");
   DeleteObject(m_prefix + "PopupSignal");
   DeleteObject(m_prefix + "PopupLotLabel");
   DeleteObject(m_prefix + "PopupLotValue");
   DeleteObject(m_prefix + "PopupTimer");

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update Entry Popup (auto-hide after 60 seconds)                 |
//+------------------------------------------------------------------+
void CModernDashboard::UpdateEntryPopup()
{
   if(!m_popup_active)
      return;

   // Hide after 60 seconds
   if(TimeCurrent() - m_popup_time >= 60)
   {
      HideEntryPopup();
   }
}

//+------------------------------------------------------------------+
//| Draw SL and TP lines on chart                                   |
//+------------------------------------------------------------------+
void CModernDashboard::DrawSLTPLines(string signal_type, double entry_price, double sl_price, double tp_price)
{
   // Clear previous lines first
   ClearChartLines();

   datetime current_time = TimeCurrent();
   datetime future_time = current_time + 3600 * 4; // 4 hours ahead

   // Determine if BUY or SELL
   bool is_buy = (StringFind(signal_type, "BUY") >= 0);

   // Entry line (blue dashed)
   ObjectCreate(0, m_prefix + "EntryLine", OBJ_TREND, 0, current_time, entry_price, future_time, entry_price);
   ObjectSetInteger(0, m_prefix + "EntryLine", OBJPROP_COLOR, DASHBOARD_INFO_COLOR);
   ObjectSetInteger(0, m_prefix + "EntryLine", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, m_prefix + "EntryLine", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, m_prefix + "EntryLine", OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, m_prefix + "EntryLine", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, m_prefix + "EntryLine", OBJPROP_BACK, false);
   ObjectSetString(0, m_prefix + "EntryLine", OBJPROP_TEXT, "ENTRY: " + DoubleToString(entry_price, _Digits));

   // Stop Loss line (red solid)
   ObjectCreate(0, m_prefix + "SLLine", OBJ_TREND, 0, current_time, sl_price, future_time, sl_price);
   ObjectSetInteger(0, m_prefix + "SLLine", OBJPROP_COLOR, DASHBOARD_DANGER_COLOR);
   ObjectSetInteger(0, m_prefix + "SLLine", OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, m_prefix + "SLLine", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, m_prefix + "SLLine", OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, m_prefix + "SLLine", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, m_prefix + "SLLine", OBJPROP_BACK, false);
   ObjectSetString(0, m_prefix + "SLLine", OBJPROP_TEXT, "SL: " + DoubleToString(sl_price, _Digits));

   // Take Profit line (green solid)
   ObjectCreate(0, m_prefix + "TPLine", OBJ_TREND, 0, current_time, tp_price, future_time, tp_price);
   ObjectSetInteger(0, m_prefix + "TPLine", OBJPROP_COLOR, DASHBOARD_SUCCESS_COLOR);
   ObjectSetInteger(0, m_prefix + "TPLine", OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, m_prefix + "TPLine", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, m_prefix + "TPLine", OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, m_prefix + "TPLine", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, m_prefix + "TPLine", OBJPROP_BACK, false);
   ObjectSetString(0, m_prefix + "TPLine", OBJPROP_TEXT, "TP: " + DoubleToString(tp_price, _Digits));

   // Draw signal arrow at entry point
   DrawSignalArrow(signal_type, entry_price);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Draw signal arrow on chart                                      |
//+------------------------------------------------------------------+
void CModernDashboard::DrawSignalArrow(string signal_type, double price)
{
   datetime current_time = TimeCurrent();
   bool is_buy = (StringFind(signal_type, "BUY") >= 0);

   // Create arrow object
   int arrow_code = is_buy ? 233 : 234; // Up arrow for BUY, Down arrow for SELL
   color arrow_color = is_buy ? DASHBOARD_SUCCESS_COLOR : DASHBOARD_DANGER_COLOR;

   ObjectCreate(0, m_prefix + "SignalArrow", OBJ_ARROW, 0, current_time, price);
   ObjectSetInteger(0, m_prefix + "SignalArrow", OBJPROP_COLOR, arrow_color);
   ObjectSetInteger(0, m_prefix + "SignalArrow", OBJPROP_ARROWCODE, arrow_code);
   ObjectSetInteger(0, m_prefix + "SignalArrow", OBJPROP_WIDTH, 5);
   ObjectSetInteger(0, m_prefix + "SignalArrow", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, m_prefix + "SignalArrow", OBJPROP_BACK, false);

   // Add text label showing direction
   string direction = is_buy ? "▲ BUY" : "▼ SELL";
   ObjectCreate(0, m_prefix + "SignalText", OBJ_TEXT, 0, current_time, price);
   ObjectSetString(0, m_prefix + "SignalText", OBJPROP_TEXT, direction);
   ObjectSetInteger(0, m_prefix + "SignalText", OBJPROP_COLOR, arrow_color);
   ObjectSetInteger(0, m_prefix + "SignalText", OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, m_prefix + "SignalText", OBJPROP_FONT, "Arial Black");
   ObjectSetInteger(0, m_prefix + "SignalText", OBJPROP_ANCHOR, is_buy ? ANCHOR_TOP : ANCHOR_BOTTOM);
   ObjectSetInteger(0, m_prefix + "SignalText", OBJPROP_SELECTABLE, false);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Clear all chart lines and arrows                                |
//+------------------------------------------------------------------+
void CModernDashboard::ClearChartLines()
{
   ObjectDelete(0, m_prefix + "EntryLine");
   ObjectDelete(0, m_prefix + "SLLine");
   ObjectDelete(0, m_prefix + "TPLine");
   ObjectDelete(0, m_prefix + "SignalArrow");
   ObjectDelete(0, m_prefix + "SignalText");
}

//+------------------------------------------------------------------+
//| Update Market Analysis Panel                                     |
//+------------------------------------------------------------------+
void CModernDashboard::UpdateMarketAnalysisPanel(string trend, string volatility, double support, double resistance, double atr)
{
   int panel_y = m_y_pos + 540;

   // Trend
   color trend_color = (trend == "BULLISH") ? DASHBOARD_SUCCESS_COLOR :
                       (trend == "BEARISH") ? DASHBOARD_DANGER_COLOR : DASHBOARD_WARNING_COLOR;
   DrawLabel(m_prefix + "TrendLabel", m_x_pos + 27, panel_y + 32, "Trend:", DASHBOARD_TEXT_MUTED, 8);
   DrawLabel(m_prefix + "TrendValue", m_x_pos + 80, panel_y + 30, trend, trend_color, 10, "Segoe UI Semibold");

   // Volatility
   color vol_color = (volatility == "HIGH") ? DASHBOARD_DANGER_COLOR :
                     (volatility == "LOW") ? DASHBOARD_INFO_COLOR : DASHBOARD_WARNING_COLOR;
   DrawLabel(m_prefix + "VolLabel", m_x_pos + 200, panel_y + 32, "Volatility:", DASHBOARD_TEXT_MUTED, 8);
   DrawLabel(m_prefix + "VolValue", m_x_pos + 270, panel_y + 30, volatility, vol_color, 10, "Segoe UI Semibold");

   // Support/Resistance
   DrawLabel(m_prefix + "SRLabel", m_x_pos + 27, panel_y + 58, "Support:", DASHBOARD_TEXT_MUTED, 8);
   DrawLabel(m_prefix + "SupportValue", m_x_pos + 85, panel_y + 58, DoubleToString(support, _Digits), DASHBOARD_INFO_COLOR, 8);

   DrawLabel(m_prefix + "ResLabel", m_x_pos + 200, panel_y + 58, "Resistance:", DASHBOARD_TEXT_MUTED, 8);
   DrawLabel(m_prefix + "ResValue", m_x_pos + 270, panel_y + 58, DoubleToString(resistance, _Digits), DASHBOARD_INFO_COLOR, 8);

   // ATR
   DrawLabel(m_prefix + "ATRLabel", m_x_pos + 27, panel_y + 78, "ATR:", DASHBOARD_TEXT_MUTED, 8);
   DrawLabel(m_prefix + "ATRValue", m_x_pos + 60, panel_y + 78, DoubleToString(atr, _Digits), DASHBOARD_TEXT_COLOR, 8);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update Performance Panel                                          |
//+------------------------------------------------------------------+
void CModernDashboard::UpdatePerformancePanel(double total_profit, double win_rate, double profit_factor, int total_trades)
{
   int panel_y = m_y_pos + 440;

   // Total Profit
   color profit_color = (total_profit > 0) ? DASHBOARD_SUCCESS_COLOR : DASHBOARD_DANGER_COLOR;
   DrawLabel(m_prefix + "ProfitLabel", m_x_pos + 27, panel_y + 32, "Total Profit:", DASHBOARD_TEXT_MUTED, 8);
   DrawLabel(m_prefix + "ProfitValue", m_x_pos + 110, panel_y + 30, "$" + DoubleToString(total_profit, 2), profit_color, 11, "Segoe UI Bold");

   // Win Rate
   color wr_color = (win_rate >= 60) ? DASHBOARD_SUCCESS_COLOR :
                    (win_rate >= 45) ? DASHBOARD_WARNING_COLOR : DASHBOARD_DANGER_COLOR;
   DrawLabel(m_prefix + "WRLabel", m_x_pos + 240, panel_y + 32, "Win Rate:", DASHBOARD_TEXT_MUTED, 8);
   DrawLabel(m_prefix + "WRValue", m_x_pos + 310, panel_y + 30, DoubleToString(win_rate, 1) + "%", wr_color, 11, "Segoe UI Bold");

   // Profit Factor
   color pf_color = (profit_factor >= 2.0) ? DASHBOARD_SUCCESS_COLOR :
                    (profit_factor >= 1.5) ? DASHBOARD_WARNING_COLOR : DASHBOARD_DANGER_COLOR;
   DrawLabel(m_prefix + "PFLabel", m_x_pos + 27, panel_y + 58, "Profit Factor:", DASHBOARD_TEXT_MUTED, 8);
   DrawLabel(m_prefix + "PFValue", m_x_pos + 120, panel_y + 58, DoubleToString(profit_factor, 2), pf_color, 9);

   // Total Trades
   DrawLabel(m_prefix + "TTLabel", m_x_pos + 240, panel_y + 58, "Total Trades:", DASHBOARD_TEXT_MUTED, 8);
   DrawLabel(m_prefix + "TTValue", m_x_pos + 330, panel_y + 58, IntegerToString(total_trades), DASHBOARD_TEXT_COLOR, 9);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update Filter Status Panel                                       |
//+------------------------------------------------------------------+
void CModernDashboard::UpdateFilterStatusPanel(string active_filters, bool trading_allowed, string block_reason)
{
   int panel_y = m_y_pos + 340;

   // Active Filters
   DrawLabel(m_prefix + "FiltersLabel", m_x_pos + 27, panel_y + 32, "Active Filters:", DASHBOARD_TEXT_MUTED, 8);
   DrawLabel(m_prefix + "FiltersValue", m_x_pos + 120, panel_y + 30, active_filters, DASHBOARD_INFO_COLOR, 9);

   // Trading Status
   color status_color = trading_allowed ? DASHBOARD_SUCCESS_COLOR : DASHBOARD_DANGER_COLOR;
   string status_text = trading_allowed ? "ALLOWED" : "BLOCKED";
   DrawLabel(m_prefix + "TradingStatusLabel", m_x_pos + 27, panel_y + 58, "Trading:", DASHBOARD_TEXT_MUTED, 8);
   DrawLabel(m_prefix + "TradingStatusValue", m_x_pos + 90, panel_y + 56, status_text, status_color, 11, "Segoe UI Bold");

   // Block Reason (if applicable)
   if(!trading_allowed && block_reason != "")
   {
      DrawLabel(m_prefix + "BlockReasonLabel", m_x_pos + 27, panel_y + 78, "Reason:", DASHBOARD_TEXT_MUTED, 8);
      DrawLabel(m_prefix + "BlockReasonValue", m_x_pos + 80, panel_y + 78, block_reason, DASHBOARD_WARNING_COLOR, 8);
   }
   else
   {
      DeleteObject(m_prefix + "BlockReasonLabel");
      DeleteObject(m_prefix + "BlockReasonValue");
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update Risk Limits Panel                                         |
//+------------------------------------------------------------------+
void CModernDashboard::UpdateRiskLimitsPanel(double daily_pnl, double weekly_pnl, int trades_today, int consecutive_losses)
{
   int panel_y = m_y_pos + 640;

   // Daily P&L
   color daily_color = (daily_pnl > 0) ? DASHBOARD_SUCCESS_COLOR : DASHBOARD_DANGER_COLOR;
   DrawLabel(m_prefix + "DailyPnLLabel", m_x_pos + 27, panel_y + 32, "Daily P&L:", DASHBOARD_TEXT_MUTED, 8);
   DrawLabel(m_prefix + "DailyPnLValue", m_x_pos + 100, panel_y + 30, "$" + DoubleToString(daily_pnl, 2), daily_color, 10);

   // Weekly P&L
   color weekly_color = (weekly_pnl > 0) ? DASHBOARD_SUCCESS_COLOR : DASHBOARD_DANGER_COLOR;
   DrawLabel(m_prefix + "WeeklyPnLLabel", m_x_pos + 230, panel_y + 32, "Weekly P&L:", DASHBOARD_TEXT_MUTED, 8);
   DrawLabel(m_prefix + "WeeklyPnLValue", m_x_pos + 310, panel_y + 30, "$" + DoubleToString(weekly_pnl, 2), weekly_color, 10);

   // Trades Today
   DrawLabel(m_prefix + "TradesTodayLabel", m_x_pos + 27, panel_y + 58, "Trades Today:", DASHBOARD_TEXT_MUTED, 8);
   DrawLabel(m_prefix + "TradesTodayValue", m_x_pos + 120, panel_y + 58, IntegerToString(trades_today), DASHBOARD_TEXT_COLOR, 9);

   // Consecutive Losses
   color cl_color = (consecutive_losses >= 3) ? DASHBOARD_DANGER_COLOR : DASHBOARD_TEXT_COLOR;
   DrawLabel(m_prefix + "ConsecLossLabel", m_x_pos + 230, panel_y + 58, "Consec. Losses:", DASHBOARD_TEXT_MUTED, 8);
   DrawLabel(m_prefix + "ConsecLossValue", m_x_pos + 350, panel_y + 58, IntegerToString(consecutive_losses), cl_color, 9);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update Signal History Panel                                      |
//+------------------------------------------------------------------+
void CModernDashboard::UpdateSignalHistoryPanel(string recent_signals[])
{
   int panel_y = m_y_pos + 740;
   int array_size = ArraySize(recent_signals);

   // Display last 5 signals
   for(int i = 0; i < MathMin(5, array_size); i++)
   {
      string obj_name = m_prefix + "History_" + IntegerToString(i);
      DrawLabel(obj_name, m_x_pos + 27, panel_y + 32 + (i * 20), recent_signals[i], DASHBOARD_TEXT_MUTED, 7);
   }

   // Clear unused slots
   for(int i = array_size; i < 5; i++)
   {
      DeleteObject(m_prefix + "History_" + IntegerToString(i));
   }

   ChartRedraw();
}
//+------------------------------------------------------------------+
