/// `POST_NOTIFICATIONS` (Android 13+). Asked at the first start, never at
/// launch; the timer starts either way (`architecture.md` 5.7).
abstract interface class NotificationPermissions {
  /// Asks if not yet granted. True if notifications may be shown.
  Future<bool> request();
}

class NoopNotificationPermissions implements NotificationPermissions {
  const NoopNotificationPermissions();

  @override
  Future<bool> request() async => true;
}
