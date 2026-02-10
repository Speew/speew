import 'dart:async';
import 'dart:convert';
import '../core/utils.dart';

class AIAssistant {
  final StreamController<AISuggestion> _suggestionsController =
      StreamController<AISuggestion>.broadcast();

  Stream<AISuggestion> get suggestionsStream => _suggestionsController.stream;

  bool _isEnabled = true;
  final List<String> _conversationHistory = [];

  bool get isEnabled => _isEnabled;

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    DebugUtils.log('AI Assistant ${enabled ? "enabled" : "disabled"}', tag: 'AI');
  }

  Future<List<String>> suggestReplies(String lastMessage) async {
    if (!_isEnabled) return [];

    try {
      
      final suggestions = _generateSmartReplies(lastMessage);
      
      DebugUtils.log('Generated ${suggestions.length} reply suggestions', tag: 'AI');
      
      return suggestions;
    } catch (e) {
      DebugUtils.logError('Failed to generate replies', error: e);
      return [];
    }
  }

  List<String> _generateSmartReplies(String message) {
    final msg = message.toLowerCase();

    if (msg.contains('como') && msg.contains('você')) {
      return ['Estou bem, e você?', 'Tudo ótimo!', 'Indo bem 👍'];
    }
    
    if (msg.contains('quando')) {
      return ['Daqui a pouco', 'Em 10 minutos', 'Agora mesmo'];
    }
    
    if (msg.contains('onde')) {
      return ['No lugar de sempre', 'Te mando localização', 'Aqui perto'];
    }

    if (msg.contains('?')) {
      return ['Sim!', 'Não', 'Talvez', 'Deixa eu ver'];
    }

    return ['Ok 👍', 'Entendi', 'Combinado!'];
  }

  Future<String?> translateMessage(String text, String targetLanguage) async {
    try {

      DebugUtils.log('Translating to $targetLanguage', tag: 'AI');

      if (targetLanguage == 'en') {
        return 'Hello, how are you?'; 
      }
      
      return null;
    } catch (e) {
      DebugUtils.logError('Translation failed', error: e);
      return null;
    }
  }

  Future<String> detectLanguage(String text) async {
    
    if (text.contains(RegExp(r'[а-яА-Я]'))) return 'ru';
    if (text.contains(RegExp(r'[一-龯]'))) return 'zh';
    if (text.contains(RegExp(r'[ぁ-ゔ]|[ァ-ヴ]'))) return 'ja';
    if (text.contains(RegExp(r'[가-힣]'))) return 'ko';

    final words = text.toLowerCase().split(' ');
    final ptWords = ['o', 'a', 'de', 'para', 'com', 'não', 'que'];
    final enWords = ['the', 'a', 'to', 'of', 'and', 'is', 'in'];
    
    final ptScore = words.where((w) => ptWords.contains(w)).length;
    final enScore = words.where((w) => enWords.contains(w)).length;
    
    if (ptScore > enScore) return 'pt';
    if (enScore > ptScore) return 'en';
    
    return 'unknown';
  }

  Future<Sentiment> analyzeSentiment(String text) async {
    final msg = text.toLowerCase();

    final positive = ['feliz', 'ótimo', 'excelente', 'maravilhoso', 'bom', 
                     'love', 'happy', 'great', 'awesome', '😊', '❤️', '😍'];

    final negative = ['triste', 'ruim', 'horrível', 'péssimo', 'odeio',
                     'sad', 'bad', 'terrible', 'hate', '😢', '😠', '😡'];
    
    int positiveScore = 0;
    int negativeScore = 0;
    
    for (final word in positive) {
      if (msg.contains(word)) positiveScore++;
    }
    
    for (final word in negative) {
      if (msg.contains(word)) negativeScore++;
    }
    
    if (positiveScore > negativeScore) {
      return Sentiment.positive;
    } else if (negativeScore > positiveScore) {
      return Sentiment.negative;
    } else {
      return Sentiment.neutral;
    }
  }

  Future<String> summarizeConversation(List<String> messages) async {
    if (messages.isEmpty) return 'Sem mensagens';
    
    try {
      
      final totalMessages = messages.length;
      final totalWords = messages.join(' ').split(' ').length;
      final avgWordsPerMessage = totalWords ~/ totalMessages;

      final words = messages.join(' ').toLowerCase().split(' ');
      final wordFreq = <String, int>{};
      
      for (final word in words) {
        if (word.length > 3) { 
          wordFreq[word] = (wordFreq[word] ?? 0) + 1;
        }
      }
      
      final topWords = wordFreq.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final topics = topWords.take(3).map((e) => e.key).join(', ');
      
      return 'Conversa com $totalMessages mensagens sobre: $topics';
    } catch (e) {
      return 'Erro ao resumir';
    }
  }

  Future<ExtractedInfo> extractInformation(String text) async {
    final info = ExtractedInfo();

    final phoneRegex = RegExp(r'\(?\d{2}\)?\s?\d{4,5}-?\d{4}');
    info.phoneNumbers = phoneRegex.allMatches(text)
        .map((m) => text.substring(m.start, m.end))
        .toList();

    final emailRegex = RegExp(r'\b[\w\.-]+@[\w\.-]+\.\w+\b');
    info.emails = emailRegex.allMatches(text)
        .map((m) => text.substring(m.start, m.end))
        .toList();

    final urlRegex = RegExp(r'https?:
    info.urls = urlRegex.allMatches(text)
        .map((m) => text.substring(m.start, m.end))
        .toList();

    final dateRegex = RegExp(r'\d{1,2}/\d{1,2}/\d{2,4}');
    info.dates = dateRegex.allMatches(text)
        .map((m) => text.substring(m.start, m.end))
        .toList();
    
    return info;
  }

  Future<List<String>> autoComplete(String partial) async {

    final completions = <String>[];
    
    if (partial.startsWith('voc')) {
      completions.addAll(['você está', 'você pode', 'você quer']);
    } else if (partial.startsWith('qu')) {
      completions.addAll(['que horas', 'quando', 'qual']);
    } else if (partial.startsWith('on')) {
      completions.addAll(['onde', 'ontem', 'online']);
    }
    
    return completions;
  }

  Future<String> correctSpelling(String text) async {

    final corrections = {
      'vc': 'você',
      'tb': 'também',
      'q': 'que',
      'n': 'não',
      'pq': 'porque',
      'msg': 'mensagem',
      'blz': 'beleza',
      'flw': 'falou',
    };
    
    final corrected = text;
    corrections.forEach((wrong, right) {
      corrected = corrected.replaceAll(
        RegExp('\\b$wrong\\b', caseSensitive: false),
        right,
      );
    });
    
    return corrected;
  }

  void addToHistory(String message) {
    _conversationHistory.add(message);

    if (_conversationHistory.length > 100) {
      _conversationHistory.removeAt(0);
    }
  }

  void clearHistory() {
    _conversationHistory.clear();
  }

  void dispose() {
    _suggestionsController.close();
  }
}

enum Sentiment {
  positive,
  neutral,
  negative,
}

class AISuggestion {
  final String text;
  final double confidence;
  final SuggestionType type;

  AISuggestion({
    required this.text,
    required this.confidence,
    required this.type,
  });
}

enum SuggestionType {
  reply,
  translation,
  correction,
  completion,
}

class ExtractedInfo {
  List<String> phoneNumbers = [];
  List<String> emails = [];
  List<String> urls = [];
  List<String> dates = [];

  bool get isEmpty =>
      phoneNumbers.isEmpty &&
      emails.isEmpty &&
      urls.isEmpty &&
      dates.isEmpty;
}