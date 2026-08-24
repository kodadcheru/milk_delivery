import 'package:flutter/material.dart';

import 'ui_tokens.dart';

/// Maps an order / delivery-task status string to its accent color.
///
/// Promoted verbatim from the customer `delivery_tracker_tab._getStatusColor`
/// so the provider, driver, and customer surfaces color statuses identically.
/// Exhaustive over the known order/task statuses; unknown values fall back to
/// [UiTone.primary].
Color uiStatusColor(String status) {
  final s = status.toUpperCase();
  if (s == 'DELIVERED' || s == 'COMPLETED') return UiTone.accentBlue;
  if (s == 'CANCELLED' || s == 'REJECTED' || s == 'FAILED' || s == 'SKIPPED') {
    return UiTone.error;
  }
  if (s == 'PAUSED') return UiTone.warning;
  if (s == 'OUT_FOR_DELIVERY' ||
      s == 'PACKED' ||
      s == 'IN_TRANSIT' ||
      s == 'ACTIVE') {
    return UiTone.success;
  }
  if (s == 'PLACED' ||
      s == 'PENDING' ||
      s == 'CONFIRMED' ||
      s == 'PREPARING' ||
      s == 'PROCESSING') {
    return UiTone.warning;
  }
  return UiTone.primary;
}
