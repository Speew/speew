import 'dart:async';
import 'dart:convert';
import '../core/utils.dart';

/// AI Assistant integrado ao chat
/// Sugere respostas, traduz mensagens, resume conversas, detecta sentimento
class AIAssistant {
  final StreamController<AISuggestion> _suggestionsController =
      StreamController<AISuggestion>.broadcast();

  Stream<AISuggestion> get suggestionsStream => _suggestionsController.stream;

  bool _isEnabled = true;
  final List<String> _conversationHistory = [];

  bool get isEnabled => _isEnabled;

  /// Ativar/desativar assistant
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    DebugUtils.log('AI Assistant ${enabled ? "enabled" : "disabled"}', tag: 'AI');
  }

  /// Sugerir respostas rápidas (Smart Reply)
  Future<List<String>> suggestReplies(String lastMessage) async {
    if (!_isEnabled) return [];

    try {
      // Analisar última mensagem
      final suggestions = _generateSmartReplies(lastMessage);
      
      DebugUtils.log('Generated ${suggestions.length} reply suggestions', tag: 'AI');
      
      return suggestions;
    } catch (e) {
      DebugUtils.logError('Failed to generate replies', error: e);
      return [];
    }
  }

  /// Gerar respostas inteligentes
  List<String> _generateSmartReplies(String message) {
    final msg = message.toLowerCase();
    
    // Respostas baseadas em padrões
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

    // Respostas genéricas
    return ['Ok 👍', 'Entendi', 'Combinado!'];
  }

  /// Traduzir mensagem
  Future<String?> translateMessage(String text, String targetLanguage) async {
    try {
      // Em produção: usar Google Translate API ou similar
      // Por ora: simulação
      
      DebugUtils.log('Translating to $targetLanguage', tag: 'AI');
      
      // Simulação
      if (targetLanguage == 'en') {
        return 'Hello, how are you?'; // Exemplo
      }
      
      return null;
    } catch (e) {
      DebugUtils.logError('Translation failed', error: e);
      return null;
    }
  }

  /// Detectar idioma da mensagem
  Future<String> detectLanguage(String text) async {
    // Análise simples de caracteres
    if (text.contains(RegExp(r'[а-яА-Я]'))) return 'ru';
    if (text.contains(RegExp(r'[一-龯]'))) return 'zh';
    if (text.contains(RegExp(r'[ぁ-ゔ]|[ァ-ヴ]'))) return 'ja';
    if (text.contains(RegExp(r'[가-힣]'))) return 'ko';
    
    // Análise de palavras comuns
    final words = text.toLowerCase().split(' ');
    final ptWords = ['o', 'a', 'de', 'para', 'com', 'não', 'que'];
    final enWords = ['the', 'a', 'to', 'of', 'and', 'is', 'in'];
    
    final ptScore = words.where((w) => ptWords.contains(w)).length;
    final enScore = words.where((w) => enWords.contains(w)).length;
    
    if (ptScore > enScore) return 'pt';
    if (enScore > ptScore) return 'en';
    
    return 'unknown';
  }

  /// Análise de sentimento (positivo, neutro, negativo)
  Future<Sentiment> analyzeSentiment(String text) async {
    final msg = text.toLowerCase();
    
    // Palavras positivas
    final positive = ['feliz', 'ótimo', 'excelente', 'maravilhoso', 'bom', 
                     'love', 'happy', 'great', 'awesome', '😊', '❤️', '😍'];
    
    // Palavras negativas
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

  /// Resumir conversa
  Future<String> summarizeConversation(List<String> messages) async {
    if (messages.isEmpty) return 'Sem mensagens';
    
    try {
      // Análise básica
      final totalMessages = messages.length;
      final totalWords = messages.join(' ').split(' ').length;
      final avgWordsPerMessage = totalWords ~/ totalMessages;
      
      // Tópicos principais (palavras mais frequentes)
      final words = messages.join(' ').toLowerCase().split(' ');
      final wordFreq = <String, int>{};
      
      for (final word in words) {
        if (word.length > 3) { // Ignorar palavras curtas
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

  /// Extrair informações importantes (datas, locais, números)
  Future<ExtractedInfo> extractInformation(String text) async {
    final info = ExtractedInfo();
    
    // Extrair números de telefone
    final phoneRegex = RegExp(r'\(?\d{2}\)?\s?\d{4,5}-?\d{4}');
    info.phoneNumbers = phoneRegex.allMatches(text)
        .map((m) => text.substring(m.start, m.end))
        .toList();
    
    // Extrair emails
    final emailRegex = RegExp(r'\b[\w\.-]+@[\w\.-]+\.\w+\b');
    info.emails = emailRegex.allMatches(text)
        .map((m) => text.substring(m.start, m.end))
        .toList();
    
    // Extrair URLs
    final urlRegex = RegExp(r'https?://[\w\.-]+\.[\w\.-]+[^\s]*');
    info.urls = urlRegex.allMatches(text)
        .map((m) => text.substring(m.start, m.end))
        .toList();
    
    // Extrair datas (formato simples)
    final dateRegex = RegExp(r'\d{1,2}/\d{1,2}/\d{2,4}');
    info.dates = dateRegex.allMatches(text)
        .map((m) => text.substring(m.start, m.end))
        .toList();
    
    return info;
  }

  /// Completar texto automaticamente
  Future<List<String>> autoComplete(String partial) async {
    // Em produção: usar modelo de linguagem
    // Por ora: sugestões simples
    
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

  /// Corrigir ortografia
  Future<String> correctSpelling(String text) async {
    // Em produção: usar API de correção ortográfica
    // Por ora: correções básicas
    
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
    
    var corrected = text;
    corrections.forEach((wrong, right) {
      corrected = corrected.replaceAll(
        RegExp('\\b$wrong\\b', caseSensitive: false),
        right,
      );
    });
    
    return corrected;
  }

  /// Adicionar à história da conversa
  void addToHistory(String message) {
    _conversationHistory.add(message);
    
    // Manter apenas últimas 100 mensagens
    if (_conversationHistory.length > 100) {
      _conversationHistory.removeAt(0);
    }
  }

  /// Limpar história
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
