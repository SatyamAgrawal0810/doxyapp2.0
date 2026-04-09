// lib/screens/chat/chat_screen.dart — Blue Theme

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import 'controllers/chat_controller.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/typing_indicator.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with AutomaticKeepAliveClientMixin {
  ChatController? _controller;
  final TextEditingController _msgCtl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isListening = false;
  bool _sttAvailable = false;
  bool _isSpeaking = false;
  bool _autoSpeak = true;
  int _lastSpokenMsgCount = 0;

  bool _isSending = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initVoice();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) _initializeChat();
    });
  }

  Future<void> _initVoice() async {
    try {
      _sttAvailable = await _stt.initialize(
        onError: (e) => debugPrint('STT error: $e'),
      );
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _tts.setStartHandler(() {
        if (mounted) setState(() => _isSpeaking = true);
      });
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
      });
      _tts.setErrorHandler((_) {
        if (mounted) setState(() => _isSpeaking = false);
      });
    } catch (e) {
      debugPrint('Voice init error: $e');
    }
  }

  Future<void> _startListening() async {
    if (!_sttAvailable || _isListening) return;
    setState(() => _isListening = true);
    try {
      await _stt.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() => _msgCtl.text = result.recognizedWords);
          if (result.finalResult && _msgCtl.text.trim().isNotEmpty) {
            setState(() => _isListening = false);
            _sendMessage();
          }
        },
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(cancelOnError: true),
      );
    } catch (e) {
      debugPrint('STT listen error: $e');
      if (mounted) setState(() => _isListening = false);
    }
  }

  Future<void> _stopListening() async {
    await _stt.stop();
    if (mounted) setState(() => _isListening = false);
  }

  Future<void> _speakText(String text) async {
    if (text.isEmpty) return;
    if (_isSpeaking) {
      await _tts.stop();
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }
    final clean = text
        .replaceAll(RegExp(r'\*+'), '')
        .replaceAll(RegExp(r'_+'), '')
        .replaceAll(RegExp(r'`+'), '')
        .replaceAll(RegExp(r'#+\s'), '')
        .trim();
    await _tts.speak(clean);
  }

  void _initializeChat() async {
    if (_isInitialized || _isDisposed) return;
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final service = ChatService(
        baseUrl: 'https://doxy-bh96.onrender.com/api/chat',
        auth: auth,
      );
      _controller = ChatController(service);
      _controller!.addListener(_onControllerChanged);
      setState(() => _isInitialized = true);
      await _loadInitial();
    } catch (e) {
      debugPrint('Chat init error: $e');
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to initialize chat: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadInitial() async {
    if (_controller == null || _isDisposed) return;
    try {
      await _controller!.loadSessions();
      if (!mounted || _isDisposed) return;
      if (_controller!.sessions.isEmpty) {
        await _createNewChat();
      } else {
        final last = _controller!.sessions.last;
        final id = last['_id'] ?? last['id'];
        if (id != null) await _controller!.openSession(id);
      }
    } catch (e) {
      debugPrint('Load initial error: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stt.stop();
    _tts.stop();
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    _msgCtl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_isDisposed || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted && _scroll.hasClients) {
        try {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } catch (_) {}
      }
    });
    if (_autoSpeak && _controller != null && !_controller!.typing) {
      final msgs = _controller!.getCurrentMessages();
      if (msgs.length > _lastSpokenMsgCount && msgs.isNotEmpty) {
        _lastSpokenMsgCount = msgs.length;
        try {
          final last = msgs.last;
          if (last.sender == 'assistant' && last.text.isNotEmpty) {
            _speakText(last.text);
          }
        } catch (e) {
          debugPrint('TTS speak error: $e');
        }
      }
    }
    if (mounted && !_isDisposed) setState(() {});
  }

  Future<void> _createNewChat() async {
    if (_controller == null || _isDisposed) return;
    try {
      await _controller!.createSession();
      if (!mounted || _isDisposed) return;
      if (_controller!.sessions.isNotEmpty) {
        final last = _controller!.sessions.last;
        final id = last['_id'] ?? last['id'];
        if (id != null) await _controller!.openSession(id);
      }
    } catch (e) {
      debugPrint('Create chat error: $e');
    }
  }

  Future<void> _selectSession(String id) async {
    if (_controller == null || _isDisposed) return;
    _lastSpokenMsgCount = 0;
    await _controller!.openSession(id);
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  }

  Future<void> _deleteSession(String id) async {
    if (_controller == null || _isDisposed || !mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111125),
        title: const Text('Delete Chat', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true || _isDisposed || !mounted) return;
    await _controller!.deleteSession(id);
    if (!mounted || _isDisposed) return;
    if (_controller!.sessions.isEmpty) {
      await _createNewChat();
    } else {
      final last = _controller!.sessions.last;
      final lastId = last['_id'] ?? last['id'];
      if (lastId != null) await _controller!.openSession(lastId);
    }
  }

  Future<void> _sendMessage() async {
    if (_controller == null || _isDisposed || !mounted) return;
    final text = _msgCtl.text.trim();
    if (text.isEmpty || _controller!.openedSession == null) return;
    setState(() => _isSending = true);
    _msgCtl.clear();
    try {
      await _controller!.sendMessage(text);
    } catch (e) {
      debugPrint('Send error: $e');
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to send: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted && !_isDisposed) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF07070F),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(color: Color(0xFF2979FF)),
            SizedBox(height: 16),
            Text('Initializing chat...', style: TextStyle(color: Colors.grey)),
          ]),
        ),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF07070F),
      appBar: isMobile
          ? AppBar(
              backgroundColor: const Color(0xFF0D0D1A),
              title: const Text('AI Chat',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    _autoSpeak ? Icons.volume_up : Icons.volume_off,
                    color: _autoSpeak ? const Color(0xFF2979FF) : Colors.grey,
                  ),
                  tooltip: _autoSpeak ? 'Mute auto-speak' : 'Enable auto-speak',
                  onPressed: () {
                    setState(() => _autoSpeak = !_autoSpeak);
                    if (!_autoSpeak) _tts.stop();
                  },
                ),
                IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: _createNewChat),
              ],
            )
          : null,
      drawer: isMobile ? _buildDrawer() : null,
      body: SafeArea(
        child: Row(children: [
          if (!isMobile) _buildSidebar(320),
          Expanded(child: _buildChatArea()),
        ]),
      ),
    );
  }

  Widget _buildSidebar(double width) {
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D1A),
        border: Border(right: BorderSide(color: Color(0xFF1E1E38))),
      ),
      child: Column(children: [_buildSidebarHeader(), _buildSessionsList()]),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0D0D1A),
      child: Column(children: [_buildSidebarHeader(), _buildSessionsList()]),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF2979FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(children: [
        const Icon(Icons.chat_bubble, color: Colors.white, size: 24),
        const SizedBox(width: 12),
        const Expanded(
          child: Text('Chat History',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ),
        IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _createNewChat),
      ]),
    );
  }

  Widget _buildSessionsList() {
    if (_controller == null || _controller!.loadingSessions) {
      return const Expanded(
          child: Center(
              child: CircularProgressIndicator(color: Color(0xFF2979FF))));
    }

    if (_controller!.sessions.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text('No conversations yet',
                style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _createNewChat,
              icon: const Icon(Icons.add),
              label: const Text('Start New Chat'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2979FF),
                  foregroundColor: Colors.white),
            ),
          ]),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _controller!.sessions.length,
        itemBuilder: (context, i) {
          final session = _controller!.sessions[i];
          final id = session['_id'] ?? session['id'];
          final title = session['title'] ?? 'New Chat';
          final lastMsg = session['lastMessage'] ?? '';
          final msgCount = session['messageCount'] ?? 0;
          final isActive = _controller!.openedSession == id;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _selectSession(id),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF141428)
                      : const Color(0xFF111125),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isActive ? const Color(0xFF2979FF) : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2979FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.chat_bubble_outline,
                        color: Color(0xFF2979FF), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          if (lastMsg.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(lastMsg,
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                          const SizedBox(height: 4),
                          Text('$msgCount messages',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 11)),
                        ]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    iconSize: 20,
                    onPressed: () => _deleteSession(id),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatArea() {
    if (_controller == null || _controller!.openedSession == null) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF2979FF)));
    }

    final messages = _controller!.getCurrentMessages();

    return Column(children: [
      // Desktop header
      if (MediaQuery.of(context).size.width >= 800)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF0D0D1A),
            border: Border(bottom: BorderSide(color: Color(0xFF1E1E38))),
          ),
          child: Row(children: [
            const Icon(Icons.smart_toy, color: Color(0xFF2979FF)),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('AI Assistant',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: Icon(
                _autoSpeak ? Icons.volume_up : Icons.volume_off,
                color: _autoSpeak ? const Color(0xFF2979FF) : Colors.grey,
              ),
              onPressed: () {
                setState(() => _autoSpeak = !_autoSpeak);
                if (!_autoSpeak) _tts.stop();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () =>
                  _controller!.clearSession(_controller!.openedSession!),
            ),
          ]),
        ),

      // Messages
      Expanded(
        child: messages.isEmpty
            ? Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 64, color: Colors.grey[700]),
                      const SizedBox(height: 16),
                      Text('Start a conversation',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Ask me anything!',
                          style:
                              TextStyle(color: Colors.grey[700], fontSize: 14)),
                    ]),
              )
            : ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length + (_controller!.typing ? 1 : 0),
                itemBuilder: (context, idx) {
                  if (idx == messages.length && _controller!.typing) {
                    return const TypingIndicator();
                  }
                  return ChatBubble(message: messages[idx]);
                },
              ),
      ),

      // Input bar
      Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D1A),
          border: Border(top: BorderSide(color: Color(0xFF1E1E38))),
        ),
        child: SafeArea(
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            // Mic button
            if (_sttAvailable)
              GestureDetector(
                onTap: _isListening ? _stopListening : _startListening,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _isListening
                        ? Colors.red.withOpacity(0.15)
                        : const Color(0xFF141428),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          _isListening ? Colors.red : const Color(0xFF1E1E38),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.red : const Color(0xFF2979FF),
                    size: 20,
                  ),
                ),
              ),

            // Text field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141428),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF1E1E38)),
                ),
                child: TextField(
                  controller: _msgCtl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: 'Type or speak...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Send button
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF2979FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
              ),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send, color: Colors.white),
                onPressed: _isSending ? null : _sendMessage,
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}
