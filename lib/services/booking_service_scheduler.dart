import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:googleapis/cloudscheduler/v1.dart';
import 'package:googleapis_auth/auth_io.dart';

class BookingServiceScheduler {
  final String _projectId = "misy-95336";
  final String _location = "us-central1";

  /// Crée un job Cloud Scheduler pour un booking planifié.
  /// Retry x3 avec backoff. Si échec total → triggerMainFunctionImmediately.
  /// Retourne true si le job a été créé ou le fallback a fonctionné.
  Future<bool> createScheduledJob(
      {required DateTime timestamp, required String bookingId}) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final client = await _getAuthClient();
        try {
          final cloudSchedulerApi = CloudSchedulerApi(client);
          final job = _buildJob(bookingId, timestamp);
          final parent = 'projects/$_projectId/locations/$_location';

          print('📅 SCHEDULER: Creating job with schedule: '
              '${formatCronExpression(timestamp)} (attempt $attempt)');

          final createdJob =
              await cloudSchedulerApi.projects.locations.jobs.create(
                  job, parent);

          print('✅ SCHEDULER: Job created successfully: ${createdJob.name}');
          return true;
        } finally {
          client.close();
        }
      } on DetailedApiRequestError catch (e) {
        if (e.status == 409) {
          // Job existe déjà → update au lieu de create
          print('⚠️ SCHEDULER: Job $bookingId already exists (409), '
              'updating schedule instead');
          return updateScheduledJob(
              bookingId: bookingId, newTimestamp: timestamp);
        }
        print('❌ SCHEDULER: createJob attempt $attempt failed '
            '(HTTP ${e.status}): ${e.message}');
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
        }
      } catch (e) {
        print('❌ SCHEDULER: createJob attempt $attempt failed: $e');
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
        }
      }
    }

    // Fallback : appel direct de la cloud function
    print('⚠️ SCHEDULER: Create exhausted, triggering mainFunction directly');
    try {
      await triggerMainFunctionImmediately(bookingId: bookingId);
      return true;
    } catch (e) {
      print('❌ SCHEDULER: Fallback triggerMainFunctionImmediately failed: $e');
    }

    await _logSchedulerError(bookingId, 'createScheduledJob',
        'Failed after 3 retries + immediate fallback');
    return false;
  }

  /// Supprime un job Cloud Scheduler.
  /// Retourne true si supprimé ou déjà inexistant (404 = OK).
  Future<bool> deleteScheduledJob({required String bookingId}) async {
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final client = await _getAuthClient();
        try {
          final cloudSchedulerApi = CloudSchedulerApi(client);
          final jobName =
              'projects/$_projectId/locations/$_location/jobs/$bookingId';
          await cloudSchedulerApi.projects.locations.jobs.delete(jobName);
          print('✅ SCHEDULER: Job deleted: $jobName');
          return true;
        } finally {
          client.close();
        }
      } on DetailedApiRequestError catch (e) {
        if (e.status == 404) {
          print('ℹ️ SCHEDULER: Job $bookingId already deleted (404)');
          return true;
        }
        print('❌ SCHEDULER: deleteJob attempt $attempt failed '
            '(HTTP ${e.status}): ${e.message}');
        if (attempt < 2) {
          await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
        }
      } catch (e) {
        print('❌ SCHEDULER: deleteJob attempt $attempt failed: $e');
        if (attempt < 2) {
          await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
        }
      }
    }

    await _logSchedulerError(bookingId, 'deleteScheduledJob',
        'Failed after 2 retries');
    return false;
  }

  /// Met à jour le schedule d'un job existant.
  /// Si le job n'existe pas (404) → fallback: crée le job.
  /// Retourne true si le job est à jour.
  Future<bool> updateScheduledJob(
      {required String bookingId, required DateTime newTimestamp}) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final client = await _getAuthClient();
        try {
          final cloudSchedulerApi = CloudSchedulerApi(client);
          final jobName =
              'projects/$_projectId/locations/$_location/jobs/$bookingId';

          final existingJob =
              await cloudSchedulerApi.projects.locations.jobs.get(jobName);

          existingJob.schedule = formatCronExpression(newTimestamp);
          final updatedJob =
              await cloudSchedulerApi.projects.locations.jobs.patch(
            existingJob,
            jobName,
            updateMask: 'schedule',
          );

          print('✅ SCHEDULER: Job updated: ${updatedJob.name} → '
              '${formatCronExpression(newTimestamp)} '
              '(attempt $attempt)');
          return true;
        } finally {
          client.close();
        }
      } on DetailedApiRequestError catch (e) {
        if (e.status == 404) {
          print('⚠️ SCHEDULER: Job $bookingId not found (404), '
              'creating new job as fallback');
          return createScheduledJob(
              timestamp: newTimestamp, bookingId: bookingId);
        }
        print('❌ SCHEDULER: updateJob attempt $attempt failed '
            '(HTTP ${e.status}): ${e.message}');
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
        }
      } catch (e) {
        print('❌ SCHEDULER: updateJob attempt $attempt failed: $e');
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
        }
      }
    }

    print('⚠️ SCHEDULER: updateJob exhausted retries, '
        'attempting create as last resort');
    try {
      return await createScheduledJob(
          timestamp: newTimestamp, bookingId: bookingId);
    } catch (e) {
      await _logSchedulerError(bookingId, 'updateScheduledJob',
          'Failed after 3 retries + create fallback: $e');
      return false;
    }
  }

  /// Appelle directement la cloud function mainFunction sans passer par Cloud Scheduler.
  /// Utilisé quand le timing serait dans le passé ou comme fallback.
  Future<void> triggerMainFunctionImmediately(
      {required String bookingId}) async {
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        print('📅 SCHEDULER: Triggering mainFunction immediately for '
            '$bookingId (attempt $attempt)');

        final client = await _getAuthClient();
        try {
          final uri = Uri.parse(
              'https://$_location-$_projectId.cloudfunctions.net/mainFunction');
          final response = await client.post(
            uri,
            body: jsonEncode({'bookingId': bookingId}),
          );

          if (response.statusCode == 200) {
            print('✅ SCHEDULER: mainFunction triggered successfully '
                'for $bookingId');
            return;
          } else {
            print('❌ SCHEDULER: mainFunction trigger failed with '
                'status ${response.statusCode}: ${response.body}');
          }
        } finally {
          client.close();
        }
      } catch (e) {
        print('❌ SCHEDULER: triggerMainFunction attempt $attempt '
            'failed: $e');
      }
      if (attempt < 2) {
        await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
      }
    }
  }

  /// Calcule le temps de rappel approprié pour une course planifiée.
  DateTime? calculateSchedulerTime({
    required DateTime scheduleTime,
    required bool isPreAssigned,
  }) {
    final offsetMinutes = isPreAssigned ? 60 : 20;
    final schedulerTime =
        scheduleTime.subtract(Duration(minutes: offsetMinutes)).toUtc();
    final now = DateTime.now().toUtc();
    if (schedulerTime.isBefore(now)) {
      print('⚠️ SCHEDULER: schedulerTime ($schedulerTime) is in the past '
          '(now: $now)');
      return null;
    }
    return schedulerTime;
  }

  // ─── Helpers ──────────────────────────────────────────────

  Job _buildJob(String bookingId, DateTime timestamp) {
    return Job()
      ..name = 'projects/$_projectId/locations/$_location/jobs/$bookingId'
      ..httpTarget = (HttpTarget()
        ..uri =
            'https://$_location-$_projectId.cloudfunctions.net/mainFunction'
        ..httpMethod = 'POST'
        ..body = base64Encode(
            utf8.encode(encodeRequestBody(bookingId: bookingId))))
      ..schedule = formatCronExpression(timestamp)
      ..timeZone = 'UTC';
  }

  Future<AutoRefreshingAuthClient> _getAuthClient() async {
    final serviceAccountJson = await loadServiceAccountJson();
    final serviceAccountCredentials =
        ServiceAccountCredentials.fromJson(serviceAccountJson);
    return clientViaServiceAccount(
        serviceAccountCredentials, [CloudSchedulerApi.cloudPlatformScope]);
  }

  Future<void> _logSchedulerError(
      String bookingId, String method, String error) async {
    try {
      await FirebaseFirestore.instance
          .collection('scheduler_errors')
          .doc(bookingId)
          .set({
        'bookingId': bookingId,
        'method': method,
        'error': error,
        'timestamp': FieldValue.serverTimestamp(),
        'source': 'booking-web',
      }, SetOptions(merge: true));
      print('📝 SCHEDULER: Error logged to Firestore for $bookingId');
    } catch (e) {
      print('❌ SCHEDULER: Failed to log error to Firestore: $e');
    }
  }

  Future<String> loadServiceAccountJson() async {
    final jsonString = await rootBundle
        .loadString('assets/json_files/service_account_credential.json');
    return jsonString;
  }

  String formatCronExpression(DateTime timestamp) {
    final minutes = timestamp.minute;
    final hours = timestamp.hour;
    final dayOfMonth = timestamp.day;
    final month = timestamp.month;
    const dayOfWeek = '*';
    return '$minutes $hours $dayOfMonth $month $dayOfWeek';
  }

  String encodeRequestBody({required String bookingId}) {
    final data = {'bookingId': bookingId};
    return jsonEncode(data);
  }
}
