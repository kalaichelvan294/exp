import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../logging/app_logger.dart';
import 'api_client.dart';

/// Single shared [ApiClient] instance for the app.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    config: ref.watch(appConfigProvider),
    logger: ref.watch(loggerProvider),
  );
  ref.onDispose(client.dispose);
  return client;
});
