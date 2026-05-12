import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../providers/providers.dart';

/// Creates the application-wide provider graph in startup order.
///
/// Data providers that must eagerly hydrate their lists do that here, keeping
/// bootstrap behavior visible and isolated from UI code.
List<SingleChildWidget> buildAppProviders() {
  return [
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => GroupProvider()..fetchGroups()),
    ChangeNotifierProvider(create: (_) => VendorProvider()..fetchVendors()),
    ChangeNotifierProvider(create: (_) => LoanProvider()..fetchLoans()),
    ChangeNotifierProvider(create: (_) => PaymentProvider()..fetchPayments()),
    ChangeNotifierProvider(create: (_) => SearchProvider()),
    ChangeNotifierProvider(create: (_) => CommentProvider()),
    ChangeNotifierProvider(create: (_) => DocumentProvider()),
    ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
    ChangeNotifierProvider(create: (_) => SavingsHistoryProvider()),
    ChangeNotifierProvider(create: (_) => DeveloperControlsProvider()),
    ChangeNotifierProvider(create: (_) => CenterProvider()..fetchCenters()),
    ChangeNotifierProvider(
      create: (_) => NotificationProvider()..fetchNotifications(),
    ),
  ];
}
