import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_providers.dart';
import '../domain/analytics.dart';

/// API-bridge data source for the Reports module.
class ReportsRepository {
  ReportsRepository(this._api);

  final ApiClient _api;

  /// Requests period analytics. [payload] comes from
  /// `ReportFilters.buildPayload()`.
  Future<Analytics> getAnalytics(Map<String, dynamic> payload) async {
    final response =
        await _api.postJson(ApiEndpoints.reportsAnalytics, body: payload);
    return Analytics.fromJson(response);
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(ref.watch(apiClientProvider)),
);
