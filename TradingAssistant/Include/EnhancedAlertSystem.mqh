//+------------------------------------------------------------------+
//|                                         EnhancedAlertSystem.mqh |
//|                        Trading Assistant - Enhanced Alert System |
//|                          Telegram, Email, Custom sounds |
//+------------------------------------------------------------------+
#property copyright "Trading Assistant"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Enhanced Alert System Class                                      |
//+------------------------------------------------------------------+
class CEnhancedAlertSystem
{
private:
   // Settings
   bool     m_use_push_notifications;
   bool     m_use_terminal_alert;
   bool     m_use_sound_alert;
   bool     m_use_email_alert;
   bool     m_use_telegram;

   // Telegram settings
   string   m_telegram_token;
   string   m_telegram_chat_id;

   // Sound files
   string   m_signal_sound;
   string   m_tp_hit_sound;
   string   m_sl_hit_sound;

   // Email settings
   string   m_email_subject_prefix;

   // Cooldown
   datetime m_last_alert_time;
   int      m_alert_cooldown_seconds;

public:
   CEnhancedAlertSystem();
   ~CEnhancedAlertSystem();

   // Settings
   void SetPushNotifications(bool enabled);
   void SetTerminalAlert(bool enabled);
   void SetSoundAlert(bool enabled, string signal_sound, string tp_sound, string sl_sound);
   void SetEmailAlert(bool enabled, string subject_prefix);
   void SetTelegram(bool enabled, string token, string chat_id);
   void SetAlertCooldown(int seconds);

   // Send alerts
   void SendSignalAlert(string signal_type, int signal_strength, double price, double lot_size);
   void SendTPHitAlert(double profit, double pips);
   void SendSLHitAlert(double loss, double pips);
   void SendRiskLimitAlert(string limit_type, string message);
   void SendDailyReportAlert(string report);

private:
   bool CanSendAlert();
   bool SendTelegramMessage(string message);
   void PlayCustomSound(string filename);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CEnhancedAlertSystem::CEnhancedAlertSystem()
{
   m_use_push_notifications = true;
   m_use_terminal_alert = true;
   m_use_sound_alert = true;
   m_use_email_alert = false;
   m_use_telegram = false;

   m_telegram_token = "";
   m_telegram_chat_id = "";

   m_signal_sound = "alert2.wav";
   m_tp_hit_sound = "ok.wav";
   m_sl_hit_sound = "timeout.wav";

   m_email_subject_prefix = "[Trading Assistant]";

   m_last_alert_time = 0;
   m_alert_cooldown_seconds = 60;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CEnhancedAlertSystem::~CEnhancedAlertSystem()
{
}

//+------------------------------------------------------------------+
//| Set push notifications                                            |
//+------------------------------------------------------------------+
void CEnhancedAlertSystem::SetPushNotifications(bool enabled)
{
   m_use_push_notifications = enabled;
}

//+------------------------------------------------------------------+
//| Set terminal alert                                                |
//+------------------------------------------------------------------+
void CEnhancedAlertSystem::SetTerminalAlert(bool enabled)
{
   m_use_terminal_alert = enabled;
}

//+------------------------------------------------------------------+
//| Set sound alert                                                   |
//+------------------------------------------------------------------+
void CEnhancedAlertSystem::SetSoundAlert(bool enabled, string signal_sound, string tp_sound, string sl_sound)
{
   m_use_sound_alert = enabled;
   m_signal_sound = signal_sound;
   m_tp_hit_sound = tp_sound;
   m_sl_hit_sound = sl_sound;
}

//+------------------------------------------------------------------+
//| Set email alert                                                   |
//+------------------------------------------------------------------+
void CEnhancedAlertSystem::SetEmailAlert(bool enabled, string subject_prefix)
{
   m_use_email_alert = enabled;
   m_email_subject_prefix = subject_prefix;
}

//+------------------------------------------------------------------+
//| Set Telegram                                                      |
//+------------------------------------------------------------------+
void CEnhancedAlertSystem::SetTelegram(bool enabled, string token, string chat_id)
{
   m_use_telegram = enabled;
   m_telegram_token = token;
   m_telegram_chat_id = chat_id;
}

//+------------------------------------------------------------------+
//| Set alert cooldown                                                |
//+------------------------------------------------------------------+
void CEnhancedAlertSystem::SetAlertCooldown(int seconds)
{
   m_alert_cooldown_seconds = seconds;
}

//+------------------------------------------------------------------+
//| Send signal alert                                                 |
//+------------------------------------------------------------------+
void CEnhancedAlertSystem::SendSignalAlert(string signal_type, int signal_strength, double price, double lot_size)
{
   if(!CanSendAlert())
      return;

   string message = StringFormat("🎯 TRADING SIGNAL DETECTED!\n\n"
                                "Type: %s\n"
                                "Strength: %d%%\n"
                                "Price: %.5f\n"
                                "Recommended Lot: %.2f\n"
                                "Time: %s",
                                signal_type, signal_strength, price, lot_size,
                                TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));

   // Terminal alert
   if(m_use_terminal_alert)
      Alert(message);

   // Push notification
   if(m_use_push_notifications)
      SendNotification(message);

   // Sound
   if(m_use_sound_alert)
      PlayCustomSound(m_signal_sound);

   // Email
   if(m_use_email_alert)
      SendMail(m_email_subject_prefix + " Signal Alert", message);

   // Telegram
   if(m_use_telegram)
      SendTelegramMessage(message);

   m_last_alert_time = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Send TP hit alert                                                 |
//+------------------------------------------------------------------+
void CEnhancedAlertSystem::SendTPHitAlert(double profit, double pips)
{
   string message = StringFormat("✅ TAKE PROFIT HIT!\n\n"
                                "Profit: $%.2f\n"
                                "Pips: %.1f\n"
                                "Time: %s",
                                profit, pips,
                                TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));

   if(m_use_terminal_alert)
      Alert(message);

   if(m_use_push_notifications)
      SendNotification(message);

   if(m_use_sound_alert)
      PlayCustomSound(m_tp_hit_sound);

   if(m_use_telegram)
      SendTelegramMessage(message);
}

//+------------------------------------------------------------------+
//| Send SL hit alert                                                 |
//+------------------------------------------------------------------+
void CEnhancedAlertSystem::SendSLHitAlert(double loss, double pips)
{
   string message = StringFormat("⛔ STOP LOSS HIT\n\n"
                                "Loss: $%.2f\n"
                                "Pips: %.1f\n"
                                "Time: %s",
                                loss, pips,
                                TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));

   if(m_use_terminal_alert)
      Alert(message);

   if(m_use_push_notifications)
      SendNotification(message);

   if(m_use_sound_alert)
      PlayCustomSound(m_sl_hit_sound);

   if(m_use_telegram)
      SendTelegramMessage(message);
}

//+------------------------------------------------------------------+
//| Send risk limit alert                                             |
//+------------------------------------------------------------------+
void CEnhancedAlertSystem::SendRiskLimitAlert(string limit_type, string message)
{
   string full_message = StringFormat("⚠️ RISK LIMIT REACHED!\n\n"
                                     "Limit Type: %s\n"
                                     "Message: %s\n"
                                     "Trading is now BLOCKED\n"
                                     "Time: %s",
                                     limit_type, message,
                                     TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));

   if(m_use_terminal_alert)
      Alert(full_message);

   if(m_use_push_notifications)
      SendNotification(full_message);

   if(m_use_telegram)
      SendTelegramMessage(full_message);
}

//+------------------------------------------------------------------+
//| Send daily report alert                                           |
//+------------------------------------------------------------------+
void CEnhancedAlertSystem::SendDailyReportAlert(string report)
{
   string message = "📊 DAILY TRADING REPORT\n\n" + report;

   if(m_use_email_alert)
      SendMail(m_email_subject_prefix + " Daily Report", message);

   if(m_use_telegram)
      SendTelegramMessage(message);
}

//+------------------------------------------------------------------+
//| Check if can send alert (cooldown)                               |
//+------------------------------------------------------------------+
bool CEnhancedAlertSystem::CanSendAlert()
{
   if(m_alert_cooldown_seconds == 0)
      return true;

   return (TimeCurrent() - m_last_alert_time) >= m_alert_cooldown_seconds;
}

//+------------------------------------------------------------------+
//| Send Telegram message                                             |
//+------------------------------------------------------------------+
bool CEnhancedAlertSystem::SendTelegramMessage(string message)
{
   if(m_telegram_token == "" || m_telegram_chat_id == "")
   {
      Print("Telegram not configured. Set token and chat ID.");
      return false;
   }

   // Encode message for URL
   string encoded_message = message;
   StringReplace(encoded_message, "\n", "%0A");
   StringReplace(encoded_message, " ", "%20");

   // Build URL
   string url = "https://api.telegram.org/bot" + m_telegram_token +
                "/sendMessage?chat_id=" + m_telegram_chat_id +
                "&text=" + encoded_message;

   // Send request
   char post[], result[];
   string headers = "";
   int res = WebRequest("GET", url, headers, 5000, post, result, headers);

   if(res == 200)
   {
      Print("Telegram message sent successfully");
      return true;
   }
   else
   {
      Print("Failed to send Telegram message. Error: ", res);
      return false;
   }
}

//+------------------------------------------------------------------+
//| Play custom sound file                                           |
//+------------------------------------------------------------------+
void CEnhancedAlertSystem::PlayCustomSound(string filename)
{
   PlaySound(filename);
}
//+------------------------------------------------------------------+
