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
   void UpdateTradePanel(bool has_position, double sl, double tp, double profit, bool trailing_active);
   void UpdateRiskPanel(double balance, double lot_size, double risk_pct, double reward_pct);
   void UpdateExecutionPanel(double spread, int spread_status, string exec_quality);
   void UpdateStatsPanel(int signals_today, int signals_week, double win_rate, double total_profit);

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

   // Status indicator
   DrawStatusIndicator(m_prefix + "SignalIndicator", m_x_pos + 27, panel_y + 35,
                       signal_status == "ACTIVE" ? 2 : signal_status == "WATCHING" ? 1 : 0);

   // Signal status text
   color status_color = signal_status == "ACTIVE" ? DASHBOARD_SUCCESS_COLOR :
                       signal_status == "WATCHING" ? DASHBOARD_WARNING_COLOR : DASHBOARD_TEXT_MUTED;
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
   ChartRedraw();
}
//+------------------------------------------------------------------+
