import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

final String _groqApiKey = dotenv.env['GROQ_API_KEY']!;
final String _groqModel = dotenv.env['GROQ_MODEL'] ?? 'llama-3.3-70b-versatile';

const String _systemPrompt = '''
You are Watt, an expert AI energy advisor for Sri Lankan households. 
You help users understand their electricity consumption, reduce their bills, 
and make smarter energy decisions based on the Ceylon Electricity Board (CEB) 
tiered tariff system.

Your expertise includes:
- CEB domestic tariff tiers (0–30 kWh, 31–60 kWh, 61–90 kWh, 91–120 kWh, 121–180 kWh, 181+ kWh)
- Peak hour surcharges (6 PM – 10 PM)
- Practical tips to shift load away from peak hours
- Appliance-specific consumption advice (ACs, water heaters, washing machines, fridges, lighting)
- Solar panel ROI calculations for Sri Lanka
- Smart home automation for energy saving
- Reading and interpreting PZEM energy meter data (voltage, current, power, energy, frequency, power factor)
- Monthly bill estimation and budget planning in LKR

Communication style:
- Friendly, clear, and encouraging — never condescending
- Use concrete numbers and LKR amounts whenever possible
- Keep responses concise (3–5 sentences for simple questions, structured lists for complex ones)
- Always end with one actionable tip the user can try today
- If asked something outside energy topics, gently redirect to energy advice
''';


class Message {
  final String role;
  final String content;
  Message({required this.role, required this.content});
  Map<String, String> toJson() => {'role': role, 'content': content};
}

class EnergyChatPage extends StatefulWidget {
  const EnergyChatPage({super.key});
  @override
  State<EnergyChatPage> createState() => _EnergyChatPageState();
}

class _EnergyChatPageState extends State<EnergyChatPage>
    with TickerProviderStateMixin {
  final List<Message> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _loading = false;

  final List<String> _suggestions = [
    '💡 How can I lower my CEB bill?',
    '⚡ What uses the most electricity at home?',
    '🌙 What are peak hours and why do they matter?',
    '🌞 Is solar worth it in Sri Lanka?',
    '📊 Explain CEB tariff tiers',
    '❄️ How much does an AC cost to run?',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(
      Message(
        role: 'assistant',
        content:
            "Hi! I'm **Watt** ⚡, your energy advisor. Ask me anything about reducing your electricity bill, understanding your CEB tariff, or getting the most from your energy monitor. How can I help today?",
      ),
    );
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _loading) return;
    _inputCtrl.clear();

    setState(() {
      _messages.add(Message(role: 'user', content: text.trim()));
      _loading = true;
    });
    _scrollToBottom();

    try {
      final history = _messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .map((m) => m.toJson())
          .toList();

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_groqApiKey',
        },
        body: jsonEncode({
          'model': _groqModel,
          'messages': [
            {'role': 'system', 'content': _systemPrompt},
            ...history,
          ],
          'max_tokens': 600,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply =
            data['choices'][0]['message']['content'] as String? ?? '...';
        setState(
          () => _messages.add(Message(role: 'assistant', content: reply)),
        );
      } else {
        setState(
          () => _messages.add(
            Message(
              role: 'assistant',
              content: '⚠️ Error ${response.statusCode}. Please try again.',
            ),
          ),
        );
      }
    } catch (e) {
      setState(
        () => _messages.add(
          Message(
            role: 'assistant',
            content: '⚠️ Connection error. Check your internet and try again.',
          ),
        ),
      );
    } finally {
      setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: _messages.length == 1
                ? _buildWelcomeScreen()
                : _buildMessageList(),
          ),
          if (_loading) _buildTypingIndicator(),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D1117),
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.bolt, color: Colors.black, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Watt',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E676),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Energy Advisor · Online',
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF8B949E)),
          onPressed: () => setState(() {
            _messages.clear();
            _messages.add(
              Message(
                role: 'assistant',
                content:
                    "Hi! I'm **Watt** ⚡, your energy advisor. Ask me anything about reducing your electricity bill, understanding your CEB tariff, or getting the most from your energy monitor. How can I help today?",
              ),
            );
          }),
          tooltip: 'New chat',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFF21262D)),
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Welcome bubble
          _buildMessageBubble(_messages[0]),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Try asking:',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((s) => _buildSuggestionChip(s)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () => _sendMessage(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildMessageBubble(_messages[i]),
    );
  }

  Widget _buildMessageBubble(Message msg) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8, top: 2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)],
                ),
              ),
              child: const Icon(Icons.bolt, color: Colors.black, size: 16),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF00B0FF).withOpacity(0.15)
                    : const Color(0xFF161B22),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? 18 : 4),
                  topRight: Radius.circular(isUser ? 4 : 18),
                  bottomLeft: const Radius.circular(18),
                  bottomRight: const Radius.circular(18),
                ),
                border: Border.all(
                  color: isUser
                      ? const Color(0xFF00B0FF).withOpacity(0.3)
                      : const Color(0xFF21262D),
                ),
              ),
              child: _renderText(msg.content, isUser),
            ),
          ),
          if (isUser)
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(left: 8, top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF21262D),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: const Icon(
                Icons.person,
                color: Color(0xFF8B949E),
                size: 16,
              ),
            ),
        ],
      ),
    );
  }

  Widget _renderText(String text, bool isUser) {
    final parts = text.split(RegExp(r'\*\*(.*?)\*\*'));
    if (parts.length == 1) {
      return Text(
        text,
        style: TextStyle(
          color: isUser ? const Color(0xFFCAE8FF) : const Color(0xFFE6EDF3),
          fontSize: 14,
          height: 1.5,
        ),
      );
    }
    final spans = <TextSpan>[];
    final matches = RegExp(r'\*\*(.*?)\*\*').allMatches(text);
    int cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(1),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color.fromARGB(255, 6, 146, 69),
          ),
        ),
      );
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: isUser ? const Color(0xFFCAE8FF) : const Color(0xFFE6EDF3),
          fontSize: 14,
          height: 1.5,
        ),
        children: spans,
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 56, bottom: 8),
      child: Row(
        children: [
          _dot(0),
          const SizedBox(width: 4),
          _dot(150),
          const SizedBox(width: 4),
          _dot(300),
          const SizedBox(width: 8),
          const Text(
            'Watt is thinking...',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _dot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (_, val, __) => Opacity(
        opacity: val,
        child: Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Color.fromARGB(255, 9, 151, 56),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        border: Border(top: BorderSide(color: Color(0xFF21262D))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: TextField(
                controller: _inputCtrl,
                style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 14),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                decoration: const InputDecoration(
                  hintText: 'Ask about energy saving...',
                  hintStyle: TextStyle(color: Color(0xFF484F58), fontSize: 14),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _sendMessage(_inputCtrl.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _loading
                    ? const LinearGradient(
                        colors: [Color(0xFF21262D), Color(0xFF21262D)],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                boxShadow: _loading
                    ? []
                    : [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
              ),
              child: Icon(
                _loading ? Icons.hourglass_empty_rounded : Icons.send_rounded,
                color: _loading ? const Color(0xFF484F58) : Colors.black,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
