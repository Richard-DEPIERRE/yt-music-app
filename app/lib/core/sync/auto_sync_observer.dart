import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ytmusic/core/sync/auto_sync_providers.dart';

/// Triggers a (debounced) liked auto-sync when the app starts and each time it
/// returns to the foreground. Renders [child] unchanged.
class AutoSyncObserver extends ConsumerStatefulWidget {
  const AutoSyncObserver({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AutoSyncObserver> createState() => _AutoSyncObserverState();
}

class _AutoSyncObserverState extends ConsumerState<AutoSyncObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  void _sync() {
    unawaited(ref.read(triggerLikedAutoSyncProvider)());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
