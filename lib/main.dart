import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:vibration/vibration.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/services.dart';
bool _showedLimitSnackBar = false;
final List<String> _recordedMorse = [];
bool _isLooping = false;
const duracaoMorseLED = 400; // milissegundos resposta da led Rx
const duracaoMorsePonto = 60;
const duracaoMorseTraco = 400;
String _loopingMorseDisplay = '';

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

// Future<void> playToneReal(int freqHz, int durationMs) async {
//   try {
//     await platform.invokeMethod('playTone', {
//       'freq': freqHz,
//       'duration': durationMs,
//     });
//   } on PlatformException catch (e) {
//     debugPrint("Erro ao tocar tom real: ${e.message}");
//   }
// }







class MorseTranslatorPage extends StatefulWidget {
  const MorseTranslatorPage({super.key});

  @override
  State<MorseTranslatorPage> createState() => _MorseTranslatorPageState();
}

class _MorseTranslatorPageState extends State<MorseTranslatorPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _scrollController = ScrollController();
  static const int dit = 200; // duração de um ponto
  static const int dah = dit * 3; // traço
  static const int intraSymbolPause = dit; // entre . e - da mesma letra
  static const int interLetterPause = dit * 3;
  static const int interWordPause = dit * 7;
  bool _blinkCharLed = false;

  DateTime? _pressStartTime;
  Timer? _pauseTimer;
  bool _blinkLastCharLed = false;

  String _morseSequence = '';
  String _translatedLetter = '';
  final List<String> _history = [];

  bool _isPlayingTone = false;

  final Map<String, String> morseToLetter = {
    // Letras A–Z
    '.-': 'A',
    '-...': 'B',
    '-.-.': 'C',
    '-..': 'D',
    '.': 'E',
    '..-.': 'F',
    '--.': 'G',
    '....': 'H',
    '..': 'I',
    '.---': 'J',
    '-.-': 'K',
    '.-..': 'L',
    '--': 'M',
    '-.': 'N',
    '---': 'O',
    '.--.': 'P',
    '--.-': 'Q',
    '.-.': 'R',
    '...': 'S',
    '-': 'T',
    '..-': 'U',
    '...-': 'V',
    '.--': 'W',
    '-..-': 'X',
    '-.--': 'Y',
    '--..': 'Z',

    // Números 0–9
    '-----': '0',
    '.----': '1',
    '..---': '2',
    '...--': '3',
    '....-': '4',
    '.....': '5',
    '-....': '6',
    '--...': '7',
    '---..': '8',
    '----.': '9',

    // Pontuação e símbolos
    '.-.-.-': '.',
    '--..--': ',',
    '..--..': '?',
    '.----.': "'",
    '-.-.--': '!',
    '-..-.': '/',
    '-.--.': '(',
    '-.--.-': ')',
    '.-...': '&',
    '---...': ':',
    '-.-.-.': ';',
    '-...-': '=',
    '.-.-.': '+',
    '-....-': '-',
    '..--.-': '_',
    '.-..-.': '"',
    '...-..-': '\$',
    '.--.-.': '@',
    '/': ' ',

    // Letras com acento ou especiais
    '.--.-': 'Á',
    '..-..': 'É',
    '--.--': 'Ñ',
    '..--': 'Ü',
    '---.': 'Ö',
    '.-..-': 'À',
    '...-.': 'Š',
    '----': 'CH',
  };

  String _selectedTone = 'tone_500.wav';

  final Map<String, String> _toneOptions = {
    'tone_500.wav': 'Militar (500 Hz)',
    'tone_700.wav': 'Estudante (700 Hz)',
    'tone_900.wav': 'Radioamador (900 Hz)',
    'tone_long.wav': 'DX (1000 Hz)',
    'tone_real': 'Tom Real (nativo)',
  };

  Future<void> _startTone() async {
    await _audioPlayer.stop();

    if (_selectedTone == 'tone_real') {

    } else {
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.play(AssetSource('sounds/$_selectedTone'));
    }

    setState(() => _isPlayingTone = true);
  }



  Future<void> _stopTone() async {
    if (_selectedTone == 'tone_real') {

    } else {
      await _audioPlayer.stop();
    }

    setState(() => _isPlayingTone = false);
  }


  Future<void> vibrateShort() async {
    if (await Vibration.hasVibrator() ?? false) {
      await Vibration.vibrate(duration: 50);
    }
  }

  Future<void> _onTapDown(_) async {
    _pressStartTime = DateTime.now();
    _pauseTimer?.cancel();
    _startTone();

    await vibrateShort();
  }

  void _startLoopPlayback() async {
    setState(() => _isLooping = true);

    for (final morse in _recordedMorse) {
      if (!_isLooping) return;

      setState(() {
        _loopingMorseDisplay = morse; // Atualiza o Morse que está tocando
      });

      if (kDebugMode) {
        print('Looping Morse: $morse');
      }

      for (var symbol in morse.split('')) {
        if (!_isLooping) return;
        await _playSymbol(symbol);
      }

      // Atualiza letra traduzida no histórico
      final translated = morseToLetter[morse] ?? '?';
      setState(() {
        _translatedLetter = translated;
        _history.add(translated);
      });

      await Future.delayed(Duration(milliseconds: interLetterPause));
    }

    // Limpa o símbolo após o loop
    setState(() => _loopingMorseDisplay = '');

    if (_isLooping) _startLoopPlayback();
  }

  Future<void> _playSymbol(String symbol) async {
    setState(() {
      _isPlayingTone = true;
      _blinkCharLed = true; // Liga LED ao começar
    });

    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    await _audioPlayer.play(AssetSource('sounds/$_selectedTone'));
    await Future.delayed(Duration(milliseconds: symbol == '.' ? dit : dah));

    await _audioPlayer.stop();

    setState(() {
      _isPlayingTone = false;
      _blinkCharLed = false; // Apaga LED ao finalizar
    });

    await Future.delayed(Duration(milliseconds: intraSymbolPause));
  }

  Future<void> _onTapUp(_) async {
    //await platform.invokeMethod('stopTone');

    final duration = DateTime.now().difference(_pressStartTime!);
    _stopTone();


    if (_morseSequence.length < 6) { // limite de 6 sinais
      final signal = duration.inMilliseconds < 300 ? '.' : '-';

      setState(() {
        _morseSequence += signal;
        _showedLimitSnackBar = false;
      });
      if (kDebugMode) {
        print('Sinal inserido: $signal');
      }
      if (kDebugMode) {
        print('Sequência atual: $_morseSequence');
      }
    } else {
      if (!_showedLimitSnackBar) {
        _showedLimitSnackBar = true;
        Flushbar(
          backgroundColor: Colors.black,
          margin: const EdgeInsets.all(8),
          borderRadius: BorderRadius.circular(8),
          flushbarPosition: FlushbarPosition.TOP,
          messageText: const Text(
            'Limite de sinais alcançado. Aguarde a tradução.',
            style: TextStyle(color: Colors.red),
          ),
          duration: const Duration(seconds: 2),
        ).show(context);
      }
    }

    _pauseTimer = Timer(
      const Duration(milliseconds: duracaoMorseLED),
      _decodeMorse,
    );
  }

  Future<void> _blinkCharacterLed(String morseSymbol) async {
    for (int i = 0; i < morseSymbol.length; i++) {
      final char = morseSymbol[i];

      final duration = char == '.'
          ? const Duration(milliseconds: duracaoMorsePonto) // ponto led
          : const Duration(milliseconds: duracaoMorseTraco); // traço led

      setState(() => _blinkCharLed = true);
      await Future.delayed(duration);
      setState(() => _blinkCharLed = false);
      await Future.delayed(duration); // pequena pausa entre piscadas
    }
  }

  void _decodeMorse() {
    final currentSequence = _morseSequence; // salva antes de limpar
    _recordedMorse.add(_morseSequence);

    setState(() {
      _translatedLetter = morseToLetter[_morseSequence] ?? '?';
      _history.add(_translatedLetter);
      _morseSequence = '';
    });

    _blinkCharacterLed(currentSequence);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearAll() {
    _pauseTimer?.cancel();
    setState(() {
      _morseSequence = '';
      _translatedLetter = '';
      _history.clear();
      _loopingMorseDisplay = '';
      _isLooping = false;
    });
  }

  void _removeLastCharacter() {
    if (_history.isNotEmpty) {
      setState(() {
        _history.removeLast();
        _translatedLetter = '';
      });
    }
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
      appBar: AppBar(title: const Text('Morse Code Training - CW')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTapDown: _onTapDown,
              onTapUp: _onTapUp,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 1000),
                height: 50,
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
                      _isPlayingTone
                          ? FontAwesomeIcons.towerCell
                          : FontAwesomeIcons.towerCell,
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
                const Text(
                  'Morse:',
                  style: TextStyle(fontSize: 20, color: Colors.lightBlue),
                ),
                ElevatedButton.icon(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.clear, color: Colors.red),
                  label: const Text(
                    'Limpar',
                    style: TextStyle(color: Colors.blue),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isLooping = !_isLooping;
                    });
                    if (_isLooping) {
                      _startLoopPlayback();
                    }
                  },
                  icon: Icon(_isLooping ? Icons.stop : Icons.repeat),
                  label: Text(_isLooping ? 'Stop' : 'Loop'),
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
              _isLooping && _loopingMorseDisplay.isNotEmpty
                  ? _loopingMorseDisplay
                  : _morseSequence,
              style: const TextStyle(fontSize: 35, color: Colors.lightBlue),
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
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(
                    text: _translatedLetter,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _translatedLetter == '?'
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            Center(
              child: Row(
                children: [
                  Text('Rx', style: TextStyle(color: Colors.lightBlue)),
                  const SizedBox(width: 10),
                  LedIndicator(
                    isOn: _blinkCharLed,
                    onColor: Colors.purpleAccent,
                    offColor: const Color(0xFF250032),
                    size: 8, // LED pequena e discreta
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Histórico:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _history.length,
                itemBuilder: (_, i) {
                  final isLast = i == _history.length - 1;
                  return ListTile(
                    leading: Text(
                      '${i + 1}',
                      style: const TextStyle(fontSize: 18),
                    ),
                    title: Row(
                      children: [
                        Text(_history[i], style: const TextStyle(fontSize: 24)),
                        if (i == _history.length - 1 && _blinkLastCharLed) ...[
                          const SizedBox(width: 8),
                          LedIndicator(
                            isOn: true,
                            onColor: getLedColors()['on']!,
                            offColor: getLedColors()['off']!,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                  );
                },
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
                  child: const Icon(
                    Icons.radio_button_checked,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
