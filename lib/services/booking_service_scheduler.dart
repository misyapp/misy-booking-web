import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis/cloudscheduler/v1.dart'; // Correct package
import 'package:googleapis_auth/auth_io.dart';

class BookingServiceScheduler {
  final String _projectId = "misy-95336";
  final String _location = "us-central1";
  // final String _location = "us-east1";
  Future<void> createScheduledJob(
      {required DateTime timestamp, required String bookingId}) async {
    try {
      // Load the service account credentials
      final serviceAccountJson = await loadServiceAccountJson();
      final serviceAccountCredentials =
          ServiceAccountCredentials.fromJson(serviceAccountJson);

      // Authenticate with Google APIs
      final client = await clientViaServiceAccount(
          serviceAccountCredentials, [CloudSchedulerApi.cloudPlatformScope]);

      // Initialize the Cloud Scheduler API
      final cloudSchedulerApi = CloudSchedulerApi(
        client,
      );

      // Define the job
      final job = Job()
        ..name = 'projects/$_projectId/locations/$_location/jobs/$bookingId'
        ..httpTarget = (HttpTarget()
          ..uri =
              'https://$_location-$_projectId.cloudfunctions.net/mainFunction'
          ..httpMethod = 'POST' // Change to POST to send a body
          ..body = base64Encode(utf8.encode(encodeRequestBody(
              bookingId: bookingId)))) // Encode the request body
        ..schedule = formatCronExpression(timestamp) // Use cron expression
        ..timeZone = 'UTC'; // Optional: set timezone

      // Create the job
      final parent = 'projects/$_projectId/locations/$_location';

      final createdJob =
          await cloudSchedulerApi.projects.locations.jobs.create(job, parent);

      print('Job created: ${createdJob.name}');
    } catch (e) {
      print("Error creating job: $e");
    }
  }

  Future<void> deleteScheduledJob({required String bookingId}) async {
    try {
      // Load the service account credentials
      final serviceAccountJson = await loadServiceAccountJson();
      final serviceAccountCredentials =
          ServiceAccountCredentials.fromJson(serviceAccountJson);

      // Authenticate with Google APIs
      final client = await clientViaServiceAccount(
          serviceAccountCredentials, [CloudSchedulerApi.cloudPlatformScope]);

      // Initialize the Cloud Scheduler API
      final cloudSchedulerApi = CloudSchedulerApi(client);

      // Define the job name
      final jobName =
          'projects/$_projectId/locations/$_location/jobs/$bookingId';

      // Delete the job
      await cloudSchedulerApi.projects.locations.jobs.delete(jobName);

      print('Job deleted: $jobName');
    } catch (e) {
      print("Error deleting job: $e");
    }
  }

  Future<void> updateScheduledJob(
      {required String bookingId, required DateTime newTimestamp}) async {
    try {
      // Load the service account credentials
      final serviceAccountJson = await loadServiceAccountJson();
      final serviceAccountCredentials =
          ServiceAccountCredentials.fromJson(serviceAccountJson);

      // Authenticate with Google APIs
      final client = await clientViaServiceAccount(
          serviceAccountCredentials, [CloudSchedulerApi.cloudPlatformScope]);

      // Initialize the Cloud Scheduler API
      final cloudSchedulerApi = CloudSchedulerApi(client);

      // Define the job name
      final jobName =
          'projects/$_projectId/locations/$_location/jobs/$bookingId';

      // Fetch the existing job
      final existingJob =
          await cloudSchedulerApi.projects.locations.jobs.get(jobName);

      // Update the job's schedule
      existingJob.schedule = formatCronExpression(newTimestamp);

      // Update the job
      final updatedJob = await cloudSchedulerApi.projects.locations.jobs.patch(
        existingJob,
        jobName,
        updateMask: 'schedule',
      );

      print('Job updated: ${updatedJob.name}');
    } catch (e) {
      print("Error updating job: $e");
    }
  }

// Helper function to load Service Account As String
  Future<String> loadServiceAccountJson() async {
    // Load the asset content as a string
    final jsonString = await rootBundle
        .loadString('assets/json_files/service_account_credential.json');
    return jsonString;
  }

  // Helper function to convert DateTime to cron expression
  String formatCronExpression(DateTime timestamp) {
    final minutes = timestamp.minute;
    final hours = timestamp.hour;
    final dayOfMonth = timestamp.day;
    final month = timestamp.month;
    const dayOfWeek = '*'; // Use '*' for every day of the week

    return '$minutes $hours $dayOfMonth $month $dayOfWeek';
  }

// Helper function to encode the request body
  String encodeRequestBody({required String bookingId}) {
    final data = {
      'bookingId': bookingId,
    };
    return jsonEncode(data);
  }
}
