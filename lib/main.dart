import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

// LedIndicator reutilizável
class LedIndicator extends StatelessWidget {
  final bool isOn;
  final Color onColor;
  final Color offColor;
  final double size;

  const LedIndicator({
    Key? key,
    required this.isOn,
    this.onColor = Colors.red,
    this.offColor = const Color(0xFF333333),
    this.size = 20,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isOn ? onColor : offColor,
        shape: BoxShape.circle,
        boxShadow: isOn
            ? [
          BoxShadow(
            color: onColor.withOpacity(0.8),
            blurRadius: 6,
            spreadRadius: 2,
          ),
        ]
            : [],
        border: Border.all(color: Colors.black54, width: 1.5),
      ),
    );
  }
}

void main() => runApp(const MorseWithButtonApp());

class MorseWithButtonApp extends StatelessWidget {
  const MorseWithButtonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Morse + Telégrafo',
      theme: ThemeData.dark(),
      home: const MorseTranslatorPage(),
    );
  }
}

class MorseTranslatorPage extends StatefulWidget {
  const MorseTranslatorPage({super.key});

  @override
  State<MorseTranslatorPage> createState() => _MorseTranslatorPageState();
}

class _MorseTranslatorPageState extends State<MorseTranslatorPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _scrollController = ScrollController();

  DateTime? _pressStartTime;
  Timer? _pauseTimer;

  String _morseSequence = '';
  String _translatedLetter = '';
  final List<String> _history = [];

  bool _isPlayingTone = false;

  final Map<String, String> _morseToLetter = {
    // Letras A–Z
    '.-': 'A',    '-...': 'B',  '-.-.': 'C',  '-..': 'D',   '.': 'E',
    '..-.': 'F',  '--.': 'G',   '....': 'H',  '..': 'I',    '.---': 'J',
    '-.-': 'K',   '.-..': 'L',  '--': 'M',    '-.': 'N',    '---': 'O',
    '.--.': 'P',  '--.-': 'Q',  '.-.': 'R',   '...': 'S',   '-': 'T',
    '..-': 'U',   '...-': 'V',  '.--': 'W',   '-..-': 'X',  '-.--': 'Y',
    '--..': 'Z',

    // Números 0–9
    '-----': '0', '.----': '1', '..---': '2', '...--': '3', '....-': '4',
    '.....': '5', '-....': '6', '--...': '7', '---..': '8', '----.': '9',

    // Símbolos comuns
    '.-.-.-': '.',  '--..--': ',',  '..--..': '?',  '.----.': "'",
    '-.-.--': '!',  '-..-.': '/',   '-.--.': '(',   '-.--.-': ')',
    '.-...': '&',   '---...': ':',  '-.-.-.': ';',  '-...-': '=',
    '.-.-.': '+',   '-....-': '-',  '..--.-': '_',  '.-..-.': '"',
    '...-..-': '\$', '.--.-.': '@',

    // Espaço entre palavras
    '/': ' '
  };

  String _selectedTone = 'tone_500.wav';

  Map<String, String> _toneOptions = {
    'tone_500.wav': 'Militar (500 Hz)',
    'tone_700.wav': 'Estudante (700 Hz)',
    'tone_900.wav': 'Radioamador (900 Hz)',
    'tone_long.wav': 'DX (1000 Hz)',
  };

  Future<void> _startTone() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('sounds/$_selectedTone'));
    setState(() => _isPlayingTone = true);
  }

  Future<void> _stopTone() async {
    await _audioPlayer.stop();
    setState(() => _isPlayingTone = false);
  }

  void _onTapDown(_) {
    _pressStartTime = DateTime.now();
    _pauseTimer?.cancel();
    _startTone();
  }

  void _onTapUp(_) {
    final duration = DateTime.now().difference(_pressStartTime!);
    _stopTone();

    setState(() {
      if (_morseSequence.length < 6) {
        _morseSequence += duration.inMilliseconds < 300 ? '.' : '-';
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Limite de sinais alcançado. Aguarde a tradução.')),
        );
      }
    });

    _pauseTimer = Timer(const Duration(seconds: 2), _decodeMorse);
  }

  void _decodeMorse() {
    setState(() {
      _translatedLetter = _morseToLetter[_morseSequence] ?? '?';
      _history.add(_translatedLetter);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      _morseSequence = '';
    });
  }

  void _clearAll() {
    _pauseTimer?.cancel();
    setState(() {
      _morseSequence = '';
      _translatedLetter = '';
      _history.clear();
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _pauseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tradutor Telegrafista')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTapDown: _onTapDown,
              onTapUp: _onTapUp,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _isPlayingTone ? Colors.green : Colors.blueAccent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _isPlayingTone
                      ? [
                    BoxShadow(
                      color: Colors.greenAccent.withAlpha((0.6 * 255).round()),
                      spreadRadius: 4,
                      blurRadius: 12,
                    ),
                  ]
                      : [],
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cell_tower, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Segure para Telegrafar',
                      style: TextStyle(fontSize: 22, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Código Morse: $_morseSequence', style: const TextStyle(fontSize: 20)),
                ElevatedButton(onPressed: _clearAll, child: const Text('Limpar')),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Sinal: ', style: TextStyle(fontSize: 16)),
                LedIndicator(isOn: _isPlayingTone, onColor: Colors.red, size: 24),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedTone,
                  items: _toneOptions.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedTone = value);
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              'Letra: $_translatedLetter',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),

            const Text(
              'Histórico:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _history.length,
                itemBuilder: (_, i) => ListTile(
                  leading: Text('${i + 1}', style: const TextStyle(fontSize: 18)),
                  title: Text(_history[i], style: const TextStyle(fontSize: 24)),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Botão redondo simples estilo "segure para telegrar" mas redondo
            GestureDetector(
              onTapDown: _onTapDown,
              onTapUp: _onTapUp,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: _isPlayingTone ? Colors.green : Colors.blueAccent,
                  shape: BoxShape.circle,
                  boxShadow: _isPlayingTone
                      ? [
                    BoxShadow(
                      color: Colors.greenAccent.withAlpha((0.6 * 255).round()),
                      spreadRadius: 4,
                      blurRadius: 12,
                    ),
                  ]
                      : [],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.radio_button_checked,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
