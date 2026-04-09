// lib/screens/chat/widgets/voice_input_button.dart
// 🎙️ Month 3 — Animated Voice Input Button
// Shows pulsing waveform while listening, sends transcript to chat

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../services/voice_input_service.dart';

class VoiceInputButton extends StatefulWidget {
  final void Function(String text) onTranscript;
  final bool enabled;

  const VoiceInputButton({
    Key? key,
    required this.onTranscript,
    this.enabled = true,
  }) : super(key: key);

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton>
    with TickerProviderStateMixin {
  final VoiceInputService _voice = VoiceInputService();

  bool _listening = false;
  bool _initializing = false;
  String _partial = '';

  // Waveform bars animation
  late List<AnimationController> _barControllers;
  late List<Animation<double>> _barAnims;
  static const int _barCount = 5;

  @override
  void initState() {
    super.initState();
    _voice.init();

    // Staggered bar animations
    _barControllers = List.generate(
      _barCount,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 300 + i * 80),
      ),
    );
    _barAnims = _barControllers.map((c) {
      return Tween<double>(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();
  }

  void _startBars() {
    for (int i = 0; i < _barCount; i++) {
      Future.delayed(Duration(milliseconds: i * 60), () {
        if (mounted && _listening) {
          _barControllers[i].repeat(reverse: true);
        }
      });
    }
  }

  void _stopBars() {
    for (final c in _barControllers) {
      c.stop();
      c.reset();
    }
  }

  Future<void> _toggle() async {
    if (!widget.enabled) return;

    if (_listening) {
      await _voice.stopListening();
      setState(() {
        _listening = false;
        _partial = '';
      });
      _stopBars();
    } else {
      setState(() {
        _initializing = true;
        _partial = '';
      });

      await _voice.startListening(
        onPartial: (text) {
          if (mounted) setState(() => _partial = text);
        },
        onFinal: (text) {
          if (mounted) {
            setState(() {
              _listening = false;
              _partial = '';
            });
            _stopBars();
            if (text.trim().isNotEmpty) {
              widget.onTranscript(text.trim());
            }
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _listening = false;
              _initializing = false;
              _partial = '';
            });
            _stopBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🎤 $err'),
                backgroundColor: Colors.red[900],
              ),
            );
          }
        },
      );

      if (mounted) {
        setState(() {
          _listening = true;
          _initializing = false;
        });
        _startBars();
      }
    }
  }

  @override
  void dispose() {
    _voice.dispose();
    for (final c in _barControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Color(0xFFFF6A00),
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Partial transcript label
        if (_listening && _partial.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFFFF6A00).withOpacity(0.4)),
            ),
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              _partial,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        GestureDetector(
          onTap: _toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _listening
                  ? const Color(0xFFFF6A00)
                  : const Color(0xFF2A2A2A),
              boxShadow: _listening
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF6A00).withOpacity(0.4),
                        blurRadius: 14,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: _listening
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        _barCount,
                        (i) => AnimatedBuilder(
                          animation: _barAnims[i],
                          builder: (_, __) => Container(
                            width: 3,
                            height: 18 * _barAnims[i].value,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : const Icon(Icons.mic_none_rounded,
                    color: Colors.white70, size: 20),
          ),
        ),
      ],
    );
  }
}
