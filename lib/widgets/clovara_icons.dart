import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';

/// Clovara brand icon widget for loading SVG icons from the UI kit
/// 
/// Usage:
/// ```dart
/// ClovaraIcon('icon_paw')
/// ClovaraIcon('icon_shield_check', size: 28, color: ClovaraColors.clover)
/// ```
class ClovaraIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  const ClovaraIcon(this.name, {super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/clovara_ui_kit_svg/$name.svg',
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : (Theme.of(context).iconTheme.color != null
              ? ColorFilter.mode(
                  Theme.of(context).iconTheme.color!,
                  BlendMode.srcIn,
                )
              : null),
    );
  }
}

/// Helper class with icon name constants for type safety
class ClovaraIcons {
  // Pet & Animal
  static const String paw = 'icon_paw';
  
  // Coverage & Protection
  static const String shieldCheck = 'icon_shield_check';
  static const String shield = 'icon_shield';
  
  // Medical & Health
  static const String stethoscope = 'icon_stethoscope';
  static const String heartbeat = 'icon_heartbeat';
  static const String medical = 'icon_medical';
  
  // Payment & Financial
  static const String card = 'icon_card';
  static const String bank = 'icon_bank';
  static const String dollar = 'icon_dollar';
  
  // Actions & Speed
  static const String bolt = 'icon_bolt';
  static const String lightning = 'icon_lightning';
  
  // Communication
  static const String chat = 'icon_chat';
  static const String message = 'icon_message';
  
  // Information & Help
  static const String info = 'icon_info';
  static const String help = 'icon_help';
  static const String question = 'icon_question';
  
  // Documents & Files
  static const String document = 'icon_document';
  static const String file = 'icon_file';
  static const String upload = 'icon_upload';
  
  // Status
  static const String check = 'icon_check';
  static const String checkCircle = 'icon_check_circle';
  static const String xCircle = 'icon_x_circle';
  static const String warning = 'icon_warning';
  
  // Navigation
  static const String arrowRight = 'icon_arrow_right';
  static const String arrowLeft = 'icon_arrow_left';
  static const String chevronRight = 'icon_chevron_right';
  static const String chevronLeft = 'icon_chevron_left';
  
  // User & Account
  static const String user = 'icon_user';
  static const String userCircle = 'icon_user_circle';
  
  // Other
  static const String calendar = 'icon_calendar';
  static const String clock = 'icon_clock';
  static const String settings = 'icon_settings';
  static const String home = 'icon_home';
}
