import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../tokens.dart';

/// Shared checkout UI components following premium design system
/// Consistent white-canvas, restrained color usage, clear hierarchy

// ============================================================================
// CHECKOUT CARD
// ============================================================================

/// Standard card wrapper for checkout sections
class CheckoutCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const CheckoutCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface1,
        borderRadius: AppRadii.br16,
        boxShadow: AppShadows.soft,
      ),
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );
  }
}

// ============================================================================
// SECTION HEADER
// ============================================================================

/// Section header with title, optional subtitle, and optional trailing action
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                    height: 1.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// INLINE BANNER
// ============================================================================

enum BannerType { info, success, warning, error }

/// Inline banner with left accent border (not full color fill)
class InlineBanner extends StatelessWidget {
  final BannerType type;
  final String message;
  final Widget? icon;
  final EdgeInsetsGeometry? margin;

  const InlineBanner({
    super.key,
    required this.type,
    required this.message,
    this.icon,
    this.margin,
  });

  Color get _backgroundColor {
    switch (type) {
      case BannerType.info:
        return AppColors.surface2;
      case BannerType.success:
        return const Color(0xFFE8F5F0);
      case BannerType.warning:
        return const Color(0xFFFFF8E6);
      case BannerType.error:
        return const Color(0xFFFFF0F0);
    }
  }

  Color get _accentColor {
    switch (type) {
      case BannerType.info:
        return AppColors.green;
      case BannerType.success:
        return AppColors.success;
      case BannerType.warning:
        return AppColors.warning;
      case BannerType.error:
        return AppColors.danger;
    }
  }

  IconData get _defaultIcon {
    switch (type) {
      case BannerType.info:
        return Icons.info_outline;
      case BannerType.success:
        return Icons.check_circle_outline;
      case BannerType.warning:
        return Icons.warning_amber_rounded;
      case BannerType.error:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: AppRadii.br12,
        border: Border(
          left: BorderSide(color: _accentColor, width: 3),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon != null ? (icon as Icon).icon : _defaultIcon,
            color: _accentColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.text,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BUTTONS
// ============================================================================

/// Primary filled button with brand styling
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final EdgeInsetsGeometry? padding;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surface3,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.br12,
          ),
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.textMuted),
                ),
              )
            : Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
      ),
    );
  }
}

/// Secondary outlined button
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final double? width;
  final IconData? icon;

  const SecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.width,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.br12,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tertiary text button
class TertiaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;

  const TertiaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.green,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FORM FIELD THEME
// ============================================================================

/// Standard input decoration for checkout forms
InputDecoration checkoutInputDecoration({
  required String label,
  String? hint,
  String? prefix,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefix,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.surface2,
    border: OutlineInputBorder(
      borderRadius: AppRadii.br12,
      borderSide: const BorderSide(color: AppColors.border, width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadii.br12,
      borderSide: const BorderSide(color: AppColors.border, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadii.br12,
      borderSide: const BorderSide(color: AppColors.green, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: AppRadii.br12,
      borderSide: const BorderSide(color: AppColors.danger, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: AppRadii.br12,
      borderSide: const BorderSide(color: AppColors.danger, width: 2),
    ),
    labelStyle: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.textMuted,
    ),
    hintStyle: GoogleFonts.inter(
      fontSize: 14,
      color: AppColors.textSubtle,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );
}

// ============================================================================
// PINNED CTA BAR
// ============================================================================

/// Bottom pinned CTA bar with primary and optional secondary actions
class PinnedCTABar extends StatelessWidget {
  final String primaryText;
  final VoidCallback? onPrimaryPressed;
  final bool isPrimaryLoading;
  final String? secondaryText;
  final VoidCallback? onSecondaryPressed;
  final Color? backgroundColor;

  const PinnedCTABar({
    super.key,
    required this.primaryText,
    this.onPrimaryPressed,
    this.isPrimaryLoading = false,
    this.secondaryText,
    this.onSecondaryPressed,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface1,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          if (secondaryText != null) ...[
            Expanded(
              child: SecondaryButton(
                text: secondaryText!,
                onPressed: onSecondaryPressed,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: secondaryText != null ? 1 : 2,
            child: PrimaryButton(
              text: primaryText,
              onPressed: onPrimaryPressed,
              isLoading: isPrimaryLoading,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// INFO ROW
// ============================================================================

/// Label-value row for displaying information
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;
  final EdgeInsetsGeometry? padding;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
                color: valueColor ?? AppColors.text,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DIVIDER
// ============================================================================

class CheckoutDivider extends StatelessWidget {
  final EdgeInsetsGeometry? margin;

  const CheckoutDivider({super.key, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 16),
      height: 1,
      color: AppColors.border,
    );
  }
}
