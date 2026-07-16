// lib/services/groq_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/energy_usage.dart';
import '../models/user_limits.dart';

class GroqService {
  final String apiKey;
  final String baseUrl;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  GroqService({
    required this.apiKey,
    this.baseUrl = 'https://api.groq.com/openai/v1',
  });

  Future<List<EnergyUsage>> getUsageHistory(String userId, {int days = 7}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    
    final querySnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('history')
        .where('timestamp', isGreaterThanOrEqualTo: cutoffDate)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .get();

    return querySnapshot.docs
        .map((doc) => EnergyUsage.fromFirestore(doc.data()))
        .toList();
  }

  Future<UserLimits?> getUserLimits(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      return UserLimits.fromFirestore(doc.data()!);
    }
    return null;
  }

  Map<String, dynamic> analyzePatterns(List<EnergyUsage> history) {
    if (history.isEmpty) {
      return {'error': 'No data available'};
    }

    final totalUsage = history.fold(0.0, (sum, item) => sum + item.power);
    final avgUsage = totalUsage / history.length;
    final maxUsage = history.map((e) => e.power).reduce((a, b) => a > b ? a : b);
    final minUsage = history.map((e) => e.power).reduce((a, b) => a < b ? a : b);
    
    final peakHourUsage = history
        .where((e) => e.isPeakHours)
        .fold(0.0, (sum, item) => sum + item.power);
    final normalHourUsage = history
        .where((e) => !e.isPeakHours)
        .fold(0.0, (sum, item) => sum + item.power);
    
    final deviceUsage = <String, double>{};
    for (var usage in history) {
      deviceUsage[usage.deviceId] = (deviceUsage[usage.deviceId] ?? 0) + usage.power;
    }
    
    String mostUsedDevice = 'Unknown';
    if (deviceUsage.isNotEmpty) {
      mostUsedDevice = deviceUsage.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }
    
    final hourUsage = <int, double>{};
    for (var usage in history) {
      final hour = usage.timestamp.hour;
      hourUsage[hour] = (hourUsage[hour] ?? 0) + usage.power;
    }
    
    int peakUsageHour = 12;
    if (hourUsage.isNotEmpty) {
      peakUsageHour = hourUsage.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }
    
    final exceedances = history.where((e) => e.limitExceeded).length;
    final exceedanceRate = history.isNotEmpty ? exceedances / history.length : 0.0;
    
    final recentCount = (history.length * 0.3).toInt();
    final recentAvg = history.take(recentCount).fold(0.0, (sum, e) => sum + e.power) / recentCount;
    final olderAvg = history.skip(recentCount).fold(0.0, (sum, e) => sum + e.power) / (history.length - recentCount);
    final trend = recentAvg - olderAvg;

    return {
      'avgUsage': avgUsage,
      'maxUsage': maxUsage,
      'minUsage': minUsage,
      'totalUsage': totalUsage,
      'peakHourUsage': peakHourUsage,
      'normalHourUsage': normalHourUsage,
      'mostUsedDevice': mostUsedDevice,
      'peakUsageHour': peakUsageHour,
      'exceedances': exceedances,
      'exceedanceRate': exceedanceRate,
      'trend': trend,
      'dataPoints': history.length,
    };
  }

  String generatePrompt(UserLimits limits, Map<String, dynamic> patterns, String query) {
    if (patterns.containsKey('error')) {
      return '''
User has no energy usage data yet. 
Please provide general energy-saving tips for a new user.
Keep response concise (max 3 sentences) and encouraging.
''';
    }
    
    final savingsPotential = patterns['peakHourUsage'] * 0.2; // 20% potential savings
    final peakHoursExceedance = patterns['peakHourUsage'] > limits.peakWattLimit * 10;
    
    return '''
You are an energy efficiency expert assistant. Analyze this user's energy usage data and provide personalized recommendations.

USER DATA:
- Normal limit: ${limits.normalWattLimit}W
- Peak limit (6PM-10PM): ${limits.peakWattLimit}W

USAGE STATISTICS (last 7 days):
- Average usage: ${patterns['avgUsage'].toStringAsFixed(1)}W
- Maximum usage: ${patterns['maxUsage'].toStringAsFixed(1)}W
- Minimum usage: ${patterns['minUsage'].toStringAsFixed(1)}W
- Peak hour usage: ${patterns['peakHourUsage'].toStringAsFixed(1)}Wh
- Normal hour usage: ${patterns['normalHourUsage'].toStringAsFixed(1)}Wh
- Most used device: ${patterns['mostUsedDevice']}
- Peak usage hour: ${patterns['peakUsageHour']}:00
- Limit exceedances: ${patterns['exceedances']} times (${(patterns['exceedanceRate'] * 100).toStringAsFixed(1)}% of readings)
- Usage trend: ${patterns['trend'] > 0 ? '↑ Increasing' : '↓ Decreasing'} (${patterns['trend'].abs().toStringAsFixed(1)}W change)

CONTEXT:
${peakHoursExceedance ? '⚠️ User frequently exceeds peak hour limits' : '✓ User stays within limits most of the time'}
${savingsPotential > 100 ? '💡 Potential savings: ${savingsPotential.toStringAsFixed(0)}Wh by optimizing peak usage' : ''}

USER QUESTION: "$query"

Provide a helpful response with:
1. Direct answer to their question (1-2 sentences)
2. 2-3 specific, actionable recommendations based on their data
3. If applicable, suggest how to reduce peak hour usage
4. Keep total response under 150 words
5. Use friendly, encouraging tone

FORMAT: Plain text only (no markdown)
''';
  }

  Future<String> callGroqAPI(String prompt) async {
    final url = '$baseUrl/chat/completions';
    
    final requestBody = {
      'model': 'mixtral-8x7b-32768',
      'messages': [
        {
          'role': 'system',
          'content': 'You are an energy efficiency expert assistant. Provide practical, data-driven recommendations in a friendly tone. Keep responses concise and actionable.'
        },
        {
          'role': 'user',
          'content': prompt,
        }
      ],
      'temperature': 0.7,
      'max_tokens': 500,
      'top_p': 1,
    };
    
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        print('Groq API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to get response from Groq');
      }
    } catch (e) {
      print('Exception calling Groq API: $e');
      rethrow;
    }
  }

  Future<String> getRecommendations(String userId, String query) async {
    try {
      final history = await getUsageHistory(userId);
      final limits = await getUserLimits(userId);
      
      if (limits == null) {
        return "Please set your power limits in settings first to get personalized recommendations. You can set your Normal and Peak hour limits there.";
      }
      
      final patterns = analyzePatterns(history);
      
      final prompt = generatePrompt(limits, patterns, query);
      
      final response = await callGroqAPI(prompt);
      
      return response;
    } catch (e) {
      print('Error in getRecommendations: $e');
      return getFallbackResponse(query);
    }
  }
  
  String getFallbackResponse(String query) {
    final lowerQuery = query.toLowerCase();
    
    if (lowerQuery.contains('bill') || lowerQuery.contains('reduce')) {
      return "To reduce your energy bill:\n\n• Shift high-power appliances to off-peak hours (before 6PM or after 10PM)\n• Unplug devices when not in use\n• Use energy-efficient appliances\n• Set AC to 24°C for optimal efficiency\n\nWould you like more specific tips based on your usage?";
    }
    else if (lowerQuery.contains('peak')) {
      return "To reduce peak hour usage:\n\n• Schedule heavy appliances like AC, washing machine before 6PM\n• Use fans instead of AC during early peak hours\n• Consider using timers for water heaters\n• Check your PeakWattLimit and try to stay below it\n\nI can provide more personalized advice once I analyze your usage pattern.";
    }
    else {
      return "I'm your energy assistant! I can help you with:\n\n• Reducing energy bills\n• Managing peak hour usage\n• Understanding your consumption patterns\n• Saving energy with appliances\n\nWhat would you like to know more about?";
    }
  }
}