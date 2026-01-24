import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

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

  /// Invoke an admin edge function.
  /// 
  /// This method:
  /// 1. Waits for auth recovery to complete (prevents Invalid JWT on page refresh)
  /// 2. Sends explicit Authorization header with access token
  /// 3. Retries once on 401 after refreshing session
  static Future<Map<String, dynamic>> invokeAdminEdge(
    String functionName, {
    Map<String, dynamic>? body,
  }) async {
    // Wait for auth recovery to complete before making any edge calls.
    // This prevents Invalid JWT errors that occur when calling edge functions
    // before the session has been recovered from storage on page refresh.
    final service = SupabaseService.instance;
    if (!service.isAuthReady) {
      if (kDebugMode) {
        debugPrint('[EdgeAdminClient] Waiting for auth recovery...');
      }
      await service.authReady;
      if (kDebugMode) {
        debugPrint('[EdgeAdminClient] Auth recovery complete: ${service.authReadyState}');
      }
    }
    
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;

    if (session == null) {
      throw EdgeAdminException(
        401,
        null,
        'Not logged in. Please sign in.',
      );
    }

    try {
      return await _invokeOnce(
        client,
        functionName,
        body ?? {},
        session.accessToken,
      );
    } on EdgeAdminException catch (e) {
      if (e.status != 401) rethrow;
    }

    // 401 received - try refreshing session and retry once
    if (kDebugMode) {
      debugPrint('[EdgeAdminClient] Got 401, attempting session refresh...');
    }
    
    final refresh = await client.auth.refreshSession();
    final refreshedSession = refresh.session ?? client.auth.currentSession;

    if (refreshedSession == null) {
      throw EdgeAdminException(
        401,
        null,
        'Session expired. Log out/in.',
      );
    }
    
    if (kDebugMode) {
      debugPrint('[EdgeAdminClient] Session refreshed, retrying...');
    }

    return _invokeOnce(
      client,
      functionName,
      body ?? {},
      refreshedSession.accessToken,
    );
  }

  static Future<Map<String, dynamic>> _invokeOnce(
    SupabaseClient client,
    String functionName,
    Map<String, dynamic> body,
    String jwt,
  ) async {
    try {
      final response = await client.functions.invoke(
        functionName,
        body: body,
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.status != 200) {
        throw EdgeAdminException(
          response.status,
          response.data,
          _formatEdgeError(response.status, response.data),
        );
      }

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }

      return {'data': response.data};
    } on FunctionException catch (e) {
      final status = e.status;
      final parsedDetails = _parseDetails(e.details);
      throw EdgeAdminException(
        status,
        parsedDetails,
        _formatEdgeError(status, parsedDetails),
      );
    }
  }

  static String _formatEdgeError(int? status, dynamic data) {
    if (data is Map<String, dynamic>) {
      final error = data['error'] as String?;
      final hint = data['hint'] as String?;
      if (error != null && status == 401) {
        if (error.toLowerCase().contains('missing authorization')) {
          return 'Missing Authorization header. Log in again.';
        }
        if (error.toLowerCase().contains('invalid jwt')) {
          return 'Invalid session. Log out/in.';
        }
      }
      if (error != null && status == 403) {
        return 'Not an admin.';
      }
      if (error != null && hint != null) {
        return '$error. $hint';
      }
      if (error != null) {
        return error;
      }
    }
    if (status == 401) {
      return 'Session expired. Log out/in.';
    }
    if (status == 403) {
      return 'Not an admin.';
    }
    return 'Request failed (${status ?? 'unknown'})';
  }

  static dynamic _parseDetails(dynamic details) {
    if (details is String) {
      try {
        return jsonDecode(details);
      } catch (_) {
        return details;
      }
    }
    return details;
  }
}
