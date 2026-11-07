import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

final NumberFormat _inrFormatter = NumberFormat.currency(
  locale: 'en_IN',
  symbol: AppConstants.currencySymbol,
  decimalDigits: 2,
);

String formatIndianRupees(num amount) => _inrFormatter.format(amount);
