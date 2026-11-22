/// One-slot bridge that lets pushed screens ask the MainTabs shell to
/// switch tabs.
///
/// The shell owns its tab index privately and hands callbacks to its tab
/// children (e.g. ProfileContent's onGoToRewards), but pushed routes — the
/// episode player above all — cannot receive those callbacks. MainTabs
/// registers its switcher on init and unregisters on dispose; callers use
/// [goTo] after popping back to the shell.
class TabRouter {
  TabRouter._();

  static void Function(int index)? _switch;

  static void register(void Function(int index) switchTab) {
    _switch = switchTab;
  }

  static void unregister(void Function(int index) switchTab) {
    if (_switch == switchTab) _switch = null;
  }

  static void goTo(int index) => _switch?.call(index);

  // Tab indices in MainTabs' IndexedStack order.
  static const int discover = 0;
  static const int shorts = 1;
  static const int rewards = 2;
  static const int myList = 3;
  static const int profile = 4;
}
