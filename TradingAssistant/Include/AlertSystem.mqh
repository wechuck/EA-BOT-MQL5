//+------------------------------------------------------------------+
//|                                            AlertSystem.mqh       |
//|                                  Push Notification System        |
//|                                     Phone-Compatible Alerts      |
//+------------------------------------------------------------------+
#property copyright "Trading Assistant 2026"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Alert System Class                                               |
//+------------------------------------------------------------------+
class CAlertSystem
{
private:
   bool     m_alerts_enabled;
   bool     m_push_enabled;
   bool     m_sound_enabled;
   bool     m_popup_enabled;

   datetime m_last_signal_alert;
   datetime m_last_spread_alert;
   datetime m_last_trade_alert;

   int      m_alert_cooldown_seconds;

public:
   CAlertSystem();
   ~CAlertSystem();

   // Configuration
   void EnableAlerts(bool enable);
   void EnablePush(bool enable);
   void EnableSound(bool enable);
   void EnablePopup(bool enable);
   void SetCooldown(int seconds);

   // Alert methods
   void SendSignalAlert(string signal_type, int strength);
   void SendTradeAlert(string message);
   void SendSpreadAlert(double spread);
   void SendManagementAlert(string message);
   void SendGeneralAlert(string message);

private:
   bool CanSendAlert(datetime &last_alert_time);
   void SendAlert(string message, bool use_push, bool use_sound, bool use_popup);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CAlertSystem::CAlertSystem()
{
   m_alerts_enabled = true;
   m_push_enabled = true;
   m_sound_enabled = true;
   m_popup_enabled = false;

   m_last_signal_alert = 0;
   m_last_spread_alert = 0;
   m_last_trade_alert = 0;

   m_alert_cooldown_seconds = 60;  // 1 minute cooldown
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CAlertSystem::~CAlertSystem()
{
}

//+------------------------------------------------------------------+
//| Enable/disable alerts                                            |
//+------------------------------------------------------------------+
void CAlertSystem::EnableAlerts(bool enable)
{
   m_alerts_enabled = enable;
}

//+------------------------------------------------------------------+
//| Enable/disable push notifications                                |
//+------------------------------------------------------------------+
void CAlertSystem::EnablePush(bool enable)
{
   m_push_enabled = enable;
}

//+------------------------------------------------------------------+
//| Enable/disable sound alerts                                      |
//+------------------------------------------------------------------+
void CAlertSystem::EnableSound(bool enable)
{
   m_sound_enabled = enable;
}

//+------------------------------------------------------------------+
//| Enable/disable popup alerts                                      |
//+------------------------------------------------------------------+
void CAlertSystem::EnablePopup(bool enable)
{
   m_popup_enabled = enable;
}

//+------------------------------------------------------------------+
//| Set alert cooldown                                               |
//+------------------------------------------------------------------+
void CAlertSystem::SetCooldown(int seconds)
{
   m_alert_cooldown_seconds = seconds;
}

//+------------------------------------------------------------------+
//| Check if can send alert (cooldown logic)                         |
//+------------------------------------------------------------------+
bool CAlertSystem::CanSendAlert(datetime &last_alert_time)
{
   if(!m_alerts_enabled)
      return false;

   if(last_alert_time == 0)
      return true;

   if(TimeCurrent() - last_alert_time >= m_alert_cooldown_seconds)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Send signal alert                                                |
//+------------------------------------------------------------------+
void CAlertSystem::SendSignalAlert(string signal_type, int strength)
{
   if(!CanSendAlert(m_last_signal_alert))
      return;

   string message = StringFormat("🎯 TRADING SIGNAL DETECTED\n%s\nStrength: %d%%\nSymbol: %s\nReview chart and decide entry",
                                signal_type, strength, _Symbol);

   SendAlert(message, true, true, true);
   m_last_signal_alert = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Send trade management alert                                      |
//+------------------------------------------------------------------+
void CAlertSystem::SendTradeAlert(string message)
{
   if(!CanSendAlert(m_last_trade_alert))
      return;

   string full_message = "📊 Trade Update: " + message;
   SendAlert(full_message, true, false, false);
   m_last_trade_alert = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Send spread warning alert                                        |
//+------------------------------------------------------------------+
void CAlertSystem::SendSpreadAlert(double spread)
{
   if(!CanSendAlert(m_last_spread_alert))
      return;

   string message = StringFormat("⚠️ HIGH SPREAD WARNING\nCurrent: %.1f points\nAvoid trading until spread normalizes", spread);

   SendAlert(message, true, true, false);
   m_last_spread_alert = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Send trade management alert                                      |
//+------------------------------------------------------------------+
void CAlertSystem::SendManagementAlert(string message)
{
   string full_message = "⚙️ " + message;
   SendAlert(full_message, false, false, false);
}

//+------------------------------------------------------------------+
//| Send general alert                                               |
//+------------------------------------------------------------------+
void CAlertSystem::SendGeneralAlert(string message)
{
   SendAlert(message, false, false, false);
}

//+------------------------------------------------------------------+
//| Core alert sending function                                      |
//+------------------------------------------------------------------+
void CAlertSystem::SendAlert(string message, bool use_push, bool use_sound, bool use_popup)
{
   if(!m_alerts_enabled)
      return;

   // Print to log
   Print(message);

   // Sound alert
   if(m_sound_enabled && use_sound)
      Alert(message);

   // Popup
   if(m_popup_enabled && use_popup)
      MessageBox(message, "Trading Assistant", MB_OK | MB_ICONINFORMATION);

   // Push notification (MT5 mobile)
   if(m_push_enabled && use_push)
      SendNotification(message);
}
//+------------------------------------------------------------------+
