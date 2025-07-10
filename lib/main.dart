import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:vibration/vibration.dart';

bool _showedLimitSnackBar = false;

class LedIndicator extends StatelessWidget {
  final bool isOn;
  final Color onColor;
  final Color offColor;
  final double size;

  const LedIndicator({
    super.key,
    required this.isOn,
    this.onColor = Colors.amber,
    this.offColor = const Color(0xFF572525),
    this.size = 20,
  });

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
      debugShowCheckedModeBanner: false,
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
    '.-': 'A', '-...': 'B', '-.-.': 'C', '-..': 'D', '.': 'E',
    '..-.': 'F', '--.': 'G', '....': 'H', '..': 'I', '.---': 'J',
    '-.-': 'K', '.-..': 'L', '--': 'M', '-.': 'N', '---': 'O',
    '.--.': 'P', '--.-': 'Q', '.-.': 'R', '...': 'S', '-': 'T',
    '..-': 'U', '...-': 'V', '.--': 'W', '-..-': 'X', '-.--': 'Y',
    '--..': 'Z',
    '-----': '0', '.----': '1', '..---': '2', '...--': '3', '....-': '4',
    '.....': '5', '-....': '6', '--...': '7', '---..': '8', '----.': '9',
    '.-.-.-': '.', '--..--': ',', '..--..': '?', '.----.': "'",
    '-.-.--': '!', '-..-.': '/', '-.--.': '(', '-.--.-': ')',
    '.-...': '&', '---...': ':', '-.-.-.': ';', '-...-': '=',
    '.-.-.': '+', '-....-': '-', '..--.-': '_', '.-..-.': '"',
    '...-..-': '\$', '.--.-.': '@', '/': ' '
  };

  String _selectedTone = 'tone_500.wav';

  final Map<String, String> _toneOptions = {
    'tone_500.wav': 'Militar (500 Hz)',
    'tone_700.wav': 'Estudante (700 Hz)',
    'tone_900.wav': 'Radioamador (900 Hz)',
    'tone_long.wav': 'DX (1000 Hz)',
  };

  Future<void> _startTone() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    await _audioPlayer.play(AssetSource('sounds/$_selectedTone'));
    setState(() => _isPlayingTone = true);

    Timer(const Duration(milliseconds: 600), () {
      if (_isPlayingTone) _stopTone();
    });
  }

  Future<void> _stopTone() async {
    await _audioPlayer.stop();
    setState(() => _isPlayingTone = false);
  }

  Future<void> vibrateShort() async {
    if (await Vibration.hasVibrator() ?? false) {
      if (kDebugMode) print('Dispositivo suporta vibração. Vibrando...');
      await Vibration.vibrate(duration: 80);
    } else {
      if (kDebugMode) print('Dispositivo não suporta vibração.');
    }
  }

  Future<void> _onTapDown(_) async {
    _pressStartTime = DateTime.now();
    _pauseTimer?.cancel();
    _startTone();
    await vibrateShort();
  }

  void _onTapUp(_) {
    final duration = DateTime.now().difference(_pressStartTime!);
    _stopTone();

    if (_morseSequence.length < 6) {
      setState(() {
        _morseSequence += duration.inMilliseconds < 300 ? '.' : '-';
        _showedLimitSnackBar = false;
      });
    } else {
      if (!_showedLimitSnackBar) {
        _showedLimitSnackBar = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.black,
            content: Text(
              'Limite de sinais alcançado. Aguarde a tradução.',
              style: TextStyle(color: Colors.red),
            ),
          ),
        );
      }
    }

    _pauseTimer = Timer(const Duration(milliseconds: 700), _decodeMorse);
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

  Map<String, Color> getLedColors() {
    switch (_selectedTone) {
      case 'tone_500.wav':
        return {'on': Colors.red, 'off': const Color(0xFF330000)};
      case 'tone_700.wav':
        return {'on': Colors.amber, 'off': const Color(0xFF4A3A00)};
      case 'tone_900.wav':
        return {'on': Colors.green, 'off': const Color(0xFF003300)};
      case 'tone_long.wav':
        return {'on': Colors.blue, 'off': const Color(0xFF001133)};
      default:
        return {'on': Colors.white, 'off': const Color(0xFF333333)};
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _pauseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ledColors = getLedColors();

    return Scaffold(
      appBar: AppBar(title: const Text('Tradutor Telegrafista')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTapDown: _onTapDown,
              onTapUp: _onTapUp,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 100,
                decoration: BoxDecoration(
                  color: _isPlayingTone ? Colors.green : Colors.blueAccent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _isPlayingTone
                      ? [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.6),
                      spreadRadius: 4,
                      blurRadius: 12,
                    ),
                  ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isPlayingTone ? FontAwesomeIcons.towerCell : FontAwesomeIcons.towerCell,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Segure para Telegrafar',
                      style: TextStyle(fontSize: 22, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Código Morse:', style: TextStyle(fontSize: 20, color: Colors.lightBlue)),
                ElevatedButton.icon(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.clear, color: Colors.purpleAccent),
                  label: const Text('Limpar', style: TextStyle(color: Colors.blue)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _morseSequence,
              style: const TextStyle(fontSize: 36, color: Colors.lightBlue),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Sinal: ', style: TextStyle(fontSize: 16)),
                LedIndicator(
                  isOn: _isPlayingTone,
                  onColor: ledColors['on']!,
                  offColor: ledColors['off']!,
                  size: 24,
                ),
                const SizedBox(width: 12),
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
            const SizedBox(height: 24),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Caractere: ',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  TextSpan(
                    text: _translatedLetter,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _translatedLetter == '?' ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Text('Histórico:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
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
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
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
                        color: Colors.greenAccent.withOpacity(0.6),
                        spreadRadius: 4,
                        blurRadius: 12,
                      ),
                    ]
                        : [],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.radio_button_checked, size: 40, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
