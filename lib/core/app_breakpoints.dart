/// Named layout widths used across the admin shell and feature screens.
///
/// Different surfaces use different thresholds on purpose (for example the
/// shell switches to a sidebar earlier than chart grids need two columns).
abstract final class AppBreakpoints {
  /// [MainShell]: drawer vs persistent sidebar and top chrome.
  static const double shellDesktopMin = 800;

  /// Dashboard / analytics style two-column chart grids.
  static const double wideContentMin = 1100;

  /// Comfortable horizontal padding and stat row layouts.
  static const double contentTabletMin = 700;

  /// Login marketing + form split layout.
  static const double loginSplitMin = 900;

  /// [GroupDetailsScreen] two-column body.
  static const double groupDetailsDesktopMin = 1050;

  /// [GroupDetailsScreen] relaxed padding breakpoint.
  static const double groupDetailsTabletMin = 600;

  /// [VendorProfileScreen] two-column body.
  static const double vendorProfileDesktopMin = 950;

  /// [VendorProfileScreen] tablet padding.
  static const double vendorProfileTabletMin = 650;
}
