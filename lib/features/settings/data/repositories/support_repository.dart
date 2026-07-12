import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final supportRepositoryProvider = Provider((ref) => SupportRepository());

class SupportRepository {
  final String _configUrl = 'https://raw.githubusercontent.com/ChronoTechs/resonance/refs/heads/main/app_config.json';
  
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
