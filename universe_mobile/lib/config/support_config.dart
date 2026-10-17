/// Where students can reach a human.
///
/// FOUNDER: replace these placeholders with your real details before the
/// usability test. Nothing else needs to change; Help Center and the
/// feedback screen read from here.
class SupportConfig {
  SupportConfig._();

  /// FOUNDER: your real support email address.
  static const String email = 'support@universe.app';

  /// FOUNDER: your WhatsApp number in international format, digits only,
  /// no "+" or spaces. Example for a Nigerian number: 2348012345678.
  /// Leave as an empty string to hide the WhatsApp option.
  static const String whatsapp = '';

  /// Pre-filled first message when a student opens WhatsApp.
  static const String whatsappGreeting = 'Hi UniVerse, I need help with...';

  static bool get hasWhatsapp => whatsapp.trim().isNotEmpty;

  /// mailto: link with a subject line. Built by hand so spaces become %20
  /// (Uri.queryParameters would use "+", which some mail apps show literally).
  static Uri emailUri({String subject = 'UniVerse support'}) =>
      Uri.parse('mailto:$email?subject=${Uri.encodeComponent(subject)}');

  /// https://wa.me link (works on phones and desktop browsers).
  static Uri whatsappUri() => Uri.parse(
    'https://wa.me/${whatsapp.trim()}?text=${Uri.encodeComponent(whatsappGreeting)}',
  );
}
