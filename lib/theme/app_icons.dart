import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Centralized icon management for the application.
/// Allows swapping between Iconsax (Premium) and Material (Backup) icons.
class AppIcons {
  // Global toggle for icon set
  static const bool useIconsax = true;

  // --- Bottom Navigation ---
  static IconData get home => useIconsax ? Iconsax.home_1 : Icons.home_outlined;
  static IconData get homeBold =>
      useIconsax ? Iconsax.home : Icons.home_rounded;

  static IconData get market =>
      useIconsax ? Iconsax.receipt_text : Icons.receipt_long_outlined;
  static IconData get marketBold =>
      useIconsax ? Iconsax.receipt_1 : Icons.receipt_long_rounded;

  static IconData get portfolio =>
      useIconsax ? Iconsax.wallet_3 : Icons.pie_chart_outline_rounded;
  static IconData get portfolioBold =>
      useIconsax ? Iconsax.wallet : Icons.pie_chart_rounded;

  static IconData get analytics =>
      useIconsax ? Iconsax.chart_21 : Icons.bar_chart_outlined;
  static IconData get analyticsBold =>
      useIconsax ? Iconsax.chart_2 : Icons.bar_chart_rounded;

  // --- Common Actions ---
  static IconData get back =>
      useIconsax ? Iconsax.arrow_left_3 : Icons.arrow_back_ios_new_rounded;
  static IconData get chevronLeft =>
      useIconsax ? Iconsax.arrow_left_3 : Icons.chevron_left_rounded;
  static IconData get chevronRight =>
      useIconsax ? Iconsax.arrow_right_3 : Icons.chevron_right_rounded;
  static IconData get next => chevronRight;
  static IconData get close => Icons.close_rounded;
  static IconData get refresh =>
      useIconsax ? Iconsax.refresh_2 : Icons.refresh_rounded;
  static IconData get search =>
      useIconsax ? Iconsax.search_normal : Icons.search_rounded;
  static IconData get searchOff =>
      useIconsax ? Iconsax.search_status : Icons.search_off_rounded;
  static IconData get filter =>
      useIconsax ? Iconsax.filter : Icons.tune_rounded;
  static IconData get filterOff =>
      useIconsax ? Iconsax.filter_edit : Icons.filter_alt_off_rounded;
  static IconData get copy => useIconsax ? Iconsax.copy : Icons.copy_rounded;
  static IconData get delete =>
      useIconsax ? Iconsax.trash : Icons.delete_outline_rounded;
  static IconData get trash => delete;
  static IconData get edit => useIconsax ? Iconsax.edit_2 : Icons.edit_outlined;
  static IconData get download =>
      useIconsax ? Iconsax.import : Icons.download_rounded;
  static IconData get calendar =>
      useIconsax ? Iconsax.calendar : Icons.calendar_today_outlined;
  static IconData get notification =>
      useIconsax ? Iconsax.notification : Icons.notifications_outlined;
  static IconData get quiet =>
      useIconsax ? Iconsax.glass : Icons.do_not_disturb_on_outlined;
  static IconData get bug =>
      useIconsax ? Iconsax.info_circle : Icons.bug_report_outlined;
  static IconData get history =>
      useIconsax ? Iconsax.clock : Icons.history_rounded;
  static IconData get link => useIconsax ? Iconsax.link : Icons.link_rounded;
  static IconData get export =>
      useIconsax ? Iconsax.export : Icons.ios_share_rounded;

  // --- Auth & Profile ---
  static IconData get user =>
      useIconsax ? Iconsax.user : Icons.person_outline_rounded;
  static IconData get userBold =>
      useIconsax ? Iconsax.user : Icons.person_rounded;
  static IconData get mail =>
      useIconsax ? Iconsax.sms : Icons.mail_outline_rounded;
  static IconData get lock =>
      useIconsax ? Iconsax.lock : Icons.lock_outline_rounded;
  static IconData get password =>
      useIconsax ? Iconsax.password_check : Icons.password_rounded;
  static IconData get eye =>
      useIconsax ? Iconsax.eye : Icons.visibility_outlined;
  static IconData get eyeSlash =>
      useIconsax ? Iconsax.eye_slash : Icons.visibility_off_outlined;
  static IconData get logout =>
      useIconsax ? Iconsax.logout : Icons.logout_rounded;
  static IconData get settings =>
      useIconsax ? Iconsax.setting_2 : Icons.settings_outlined;
  static IconData get info =>
      useIconsax ? Iconsax.info_circle : Icons.info_outline_rounded;
  static IconData get description =>
      useIconsax ? Iconsax.document_text : Icons.description_outlined;
  static IconData get document => description;
  static IconData get shield =>
      useIconsax ? Iconsax.security_safe : Icons.shield_outlined;
  static IconData get shieldBold =>
      useIconsax ? Iconsax.security_safe : Icons.shield_rounded;
  static IconData get fingerPrint =>
      useIconsax ? Iconsax.finger_scan : Icons.fingerprint_rounded;
  static IconData get camera =>
      useIconsax ? Iconsax.camera : Icons.camera_alt_rounded;
  static IconData get gallery =>
      useIconsax ? Iconsax.gallery : Icons.photo_library_rounded;
  static IconData get cake => useIconsax ? Iconsax.cake : Icons.cake_outlined;
  static IconData get wc => useIconsax ? Iconsax.man : Icons.wc_rounded;
  static IconData get people =>
      useIconsax ? Iconsax.people : Icons.people_outline_rounded;

  // --- Status & Indications ---
  static IconData get check =>
      useIconsax ? Iconsax.tick_circle : Icons.check_circle_rounded;
  static IconData get warning =>
      useIconsax ? Iconsax.warning_2 : Icons.warning_amber_rounded;
  static IconData get error =>
      useIconsax ? Iconsax.danger : Icons.error_outline_rounded;
  static IconData get empty => useIconsax ? Iconsax.box : Icons.inbox_outlined;
  static IconData get wifiOff =>
      useIconsax ? Iconsax.wifi_square : Icons.wifi_off_rounded;
  static IconData get battery =>
      useIconsax ? Iconsax.battery_charging : Icons.battery_saver_rounded;
  static IconData get fullscreen =>
      useIconsax ? Iconsax.maximize_4 : Icons.fullscreen_rounded;
  static IconData get vibration =>
      useIconsax ? Iconsax.notification_status : Icons.vibration_rounded;
  static IconData get lightMode =>
      useIconsax ? Iconsax.sun : Icons.light_mode_rounded;
  static IconData get darkMode =>
      useIconsax ? Iconsax.moon : Icons.dark_mode_rounded;
  static IconData get smartphone =>
      useIconsax ? Iconsax.mobile : Icons.smartphone_rounded;
  static IconData get rocket =>
      useIconsax ? Iconsax.flash : Icons.rocket_launch_rounded;
  static IconData get pending => useIconsax ? Iconsax.timer : Icons.pending;
  static IconData get insight =>
      useIconsax ? Iconsax.lamp_on : Icons.lightbulb_outline_rounded;

  // --- Financial ---
  static IconData get bank =>
      useIconsax ? Iconsax.bank : Icons.account_balance_rounded;
  static IconData get wallet =>
      useIconsax ? Iconsax.wallet_2 : Icons.account_balance_wallet_outlined;
  static IconData get walletBold =>
      useIconsax ? Iconsax.wallet : AppIcons.wallet;
  static IconData get card =>
      useIconsax ? Iconsax.card : Icons.credit_card_outlined;
  static IconData get receipt =>
      useIconsax ? Iconsax.receipt_2_1 : Icons.receipt_long_outlined;
  static IconData get trendingUp =>
      useIconsax ? Iconsax.trend_up : Icons.trending_up_rounded;
  static IconData get trendingDown =>
      useIconsax ? Iconsax.trend_down : Icons.trending_down_rounded;
  static IconData get arrowUp =>
      useIconsax ? Iconsax.arrow_up_1 : Icons.north_rounded;
  static IconData get arrowDown =>
      useIconsax ? Iconsax.arrow_down_1 : Icons.south_rounded;
  static IconData get withdraw =>
      useIconsax ? Iconsax.export_1 : Icons.south_rounded;
  static IconData get flash =>
      useIconsax ? Iconsax.flash : Icons.flash_on_rounded;
  static IconData get partner =>
      useIconsax ? Iconsax.profile_2user : Icons.handshake_rounded;
  static IconData get phone => useIconsax ? Iconsax.call : Icons.phone_outlined;
  static IconData get addCircle =>
      useIconsax ? Iconsax.add : Icons.add_circle_outline_rounded;
  static IconData get add => useIconsax ? Iconsax.add : Icons.add_rounded;
  static IconData get remove =>
      useIconsax ? Iconsax.minus : Icons.remove_rounded;
  static IconData get star => useIconsax ? Iconsax.star_1 : Icons.star_rounded;
  static IconData get barcode =>
      useIconsax ? Iconsax.barcode : Icons.qr_code_rounded;
  static IconData get hashtag =>
      useIconsax ? Iconsax.hashtag_1 : Icons.numbers_rounded;
  static IconData get location =>
      useIconsax ? Iconsax.location : Icons.location_on_rounded;
  static IconData get verifiedUser =>
      useIconsax ? Iconsax.user_tick : Icons.verified_user_rounded;
  static IconData get chart =>
      useIconsax ? Iconsax.chart_21 : Icons.show_chart_rounded;
  static IconData get business =>
      useIconsax ? Iconsax.buildings_2 : Icons.business_outlined;
  static IconData get unfoldLess =>
      useIconsax ? Iconsax.arrow_up_2 : Icons.unfold_less_rounded;
  static IconData get unfoldMore =>
      useIconsax ? Iconsax.arrow_down_1 : Icons.unfold_more_rounded;
  static IconData get timer =>
      useIconsax ? Iconsax.timer_1 : Icons.timer_rounded;

  // --- Invoice Discounting Specific ---
  static IconData get moneyReceive =>
      useIconsax ? Iconsax.money_recive : Icons.savings_outlined;
  static IconData get moneySend =>
      useIconsax ? Iconsax.money_send : Icons.payments_outlined;
  static IconData get discount =>
      useIconsax ? Iconsax.discount_shape : Icons.percent_rounded;
  static IconData get percentage =>
      useIconsax ? Iconsax.percentage_square : Icons.percent_rounded;
  static IconData get moneyChange =>
      useIconsax ? Iconsax.money_change : Icons.currency_exchange_rounded;
  static IconData get statusUp =>
      useIconsax ? Iconsax.status_up : Icons.analytics_rounded;

  // --- Aliases & Specialized ---
  static IconData get browse => gallery;
  static IconData get invoice => market;
  static IconData get male => useIconsax ? Iconsax.man : Icons.male_rounded;
  static IconData get female =>
      useIconsax ? Iconsax.woman : Icons.female_rounded;
  static IconData get nonBinary =>
      useIconsax ? Iconsax.unlimited : Icons.transgender_rounded;
  static IconData get magic =>
      useIconsax ? Iconsax.magicpen : Icons.auto_awesome_rounded;
  static IconData get verified =>
      useIconsax ? Iconsax.shield_tick : Icons.verified_user_rounded;
  static IconData get layers =>
      useIconsax ? Iconsax.element_4 : Icons.layers_rounded;
  static IconData get badge =>
      useIconsax ? Iconsax.profile_circle : Icons.badge_rounded;
}
