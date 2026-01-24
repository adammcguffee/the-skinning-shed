import 'package:supabase_flutter/supabase_flutter.dart';

class EdgeAdminException implements Exception {
  EdgeAdminException(this.status, this.data, this.message);

  final int? status;
  final dynamic data;
  final String message;

  @override
  String toString() => message;
}

class EdgeAdminClient {
  EdgeAdminClient._();

  static Future<Map<String, dynamic>> invokeAdminEdge(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;

    if (session == null) {
      throw EdgeAdminException(
        401,
        null,
        'Not logged in. Please sign in.',
      );
    }

    var response = await client.functions.invoke(
      functionName,
      body: body ?? {},
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );

    if (response.status == 401) {
      final refresh = await client.auth.refreshSession();
      final refreshedSession = refresh.session ?? client.auth.currentSession;

      if (refreshedSession == null) {
        throw EdgeAdminException(
          401,
          response.data,
          'Session expired. Log out/in.',
        );
      }

      response = await client.functions.invoke(
        functionName,
        body: body ?? {},
        headers: {'Authorization': 'Bearer ${refreshedSession.accessToken}'},
      );
    }

    if (response.status != 200) {
      throw EdgeAdminException(
        response.status,
        response.data,
        _formatEdgeError(response.status, response.data),
      );
    }

    return response.data as Map<String, dynamic>;
  }

  static String _formatEdgeError(int? status, dynamic data) {
    if (status == 401) {
      return 'Session expired. Log out/in.';
    }
    if (status == 403) {
      return 'Not an admin.';
    }
    if (data is Map<String, dynamic>) {
      final error = data['error'] as String?;
      final hint = data['hint'] as String?;
      if (error != null && hint != null) {
        return '$error. $hint';
      }
      if (error != null) {
        return error;
      }
    }
    return 'Request failed (${status ?? 'unknown'})';
  }
}
