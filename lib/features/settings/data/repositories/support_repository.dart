import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/constants/app_constants.dart';

final supportRepositoryProvider = Provider((ref) => SupportRepository());

class SupportRepository {
  final String _configUrl = AppConstants.githubRawConfigUrl;
  
  /// Fetches the donation URL from the GitHub repository asynchronously.
  Future<String?> getDonateUrl() async {
    try {
      final response = await http.get(Uri.parse(_configUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['donate_url'] as String?;
      }
    } catch (_) {}
    return null; // Fallback to internal system if API fails
  }
}
