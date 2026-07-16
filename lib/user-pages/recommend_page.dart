import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:energy_application/components/Recommandation_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Recommendation {
  final String deviceid;
  bool is_peak_hours;
  final String type;
  final String message;
  final DateTime timestamp;

  Recommendation({
    required this.deviceid,
    required this.is_peak_hours,
    required this.type,
    required this.message,
    required this.timestamp,
  });

  factory Recommendation.fromMap(Map<String, dynamic> map) {
    return Recommendation(
      deviceid: map['deviceid'] ?? 'No Device ID',
      is_peak_hours: map['is_peak_hours'] ?? false,
      type: map['type'] ?? 'No Type',
      message: map['message'] ?? 'No Message',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp)
                .toDate()
          : DateTime.now(),
    );
  }
}

class RecommendPage extends StatefulWidget {
  const RecommendPage({super.key});

  @override
  State<RecommendPage> createState() => _RecommendPageState();
}

class _RecommendPageState extends State<RecommendPage> {
  String _selectedFilter = "All";

  void _showChatbot(BuildContext context) {
    final TextEditingController _chatController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Crucial for keyboard handling
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              children: [
                _buildHandleBar(),
                _buildChatHeader(context),
                const Divider(height: 1),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildChatBubble(
                        "Hello! I'm analyzing your current usage. You've used 4.2 units today.",
                        false,
                      ),
                      _buildChatBubble("Is that normal for a Wednesday?", true),
                      _buildChatBubble(
                        "Hello! I'm analyzing your current usage. You've used 4.2 units today.",
                        false,
                      ),
                      _buildChatBubble("Is that normal for a Wednesday?", true),
                      _buildChatBubble(
                        "Hello! I'm analyzing your current usage. You've used 4.2 units today.",
                        false,
                      ),
                      _buildChatBubble("Is that normal for a Wednesday?", true),
                      _buildChatBubble(
                        "Hello! I'm analyzing your current usage. You've used 4.2 units today.",
                        false,
                      ),
                      _buildChatBubble("Is that normal for a Wednesday?", true),
                      _buildChatBubble(
                        "Hello! I'm analyzing your current usage. You've used 4.2 units today.",
                        false,
                      ),
                      _buildChatBubble("Is that normal for a Wednesday?", true),
                      _buildChatBubble(
                        "Hello! I'm analyzing your current usage. You've used 4.2 units today.",
                        false,
                      ),
                      _buildChatBubble("Is that normal for a Wednesday?", true),
                    ],
                  ),
                ),

            
                Padding(
                  padding: EdgeInsets.only(
                    bottom: bottomInset,
                  ),
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            offset: const Offset(0, -2),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatController,
                              autofocus: false,
                              decoration: InputDecoration(
                                hintText: "Ask about energy saving...",
                                filled: true,
                                fillColor: const Color.fromARGB(
                                  255,
                                  24,
                                  24,
                                  24,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              if (_chatController.text.isNotEmpty) {
                                _chatController.clear();
                              }
                            },
                            child: const CircleAvatar(
                              backgroundColor: Colors.green,
                              child: Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHandleBar() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildChatHeader(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFE8F5E9),
        child: Icon(Icons.auto_awesome, color: Colors.green),
      ),
      title: const Text(
        "Energy Advisor",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: const Text("Sri Lanka Tariff Specialist"),
      trailing: IconButton(
        icon: const Icon(Icons.close_fullscreen, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.green : Colors.grey[200],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          text,
          style: TextStyle(color: isUser ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showChatbot(context),
          backgroundColor: Colors.green,
          child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
        ),
        backgroundColor: Colors.white,
        body: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>?>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .collection('notifications')
                    .get()
                    .then(
                      (snapshot) =>
                          snapshot.docs.map((doc) => doc.data()).toList(),
                    ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data ?? [];

                  print(data);

                  List<Recommendation> items = data
                      .map((map) => Recommendation.fromMap(map))
                      .toList();

                  if (items.isEmpty) {
                    return const Center(
                      child: Text("No recommendations found."),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return RecommendationCard(
                        title: item.type,
                        description: item.message,
                        status: "Normal",
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
