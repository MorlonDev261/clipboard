import 'package:meta/meta.dart';

/// A tool the model asked to run.
@immutable
class ToolCall {
  const ToolCall({required this.id, required this.name, required this.args});

  /// Provider-issued id, echoed back with the result.
  final String id;
  final String name;
  final Map<String, dynamic> args;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'args': args};

  static ToolCall? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final args = raw['args'];
    return ToolCall(
      id: '${raw['id']}',
      name: '${raw['name']}',
      args: args is Map ? args.cast<String, dynamic>() : const {},
    );
  }
}

/// The outcome of a [ToolCall], sent back to the model.
@immutable
class ToolOutcome {
  const ToolOutcome({
    required this.callId,
    required this.name,
    required this.content,
    this.isError = false,
  });

  final String callId;
  final String name;

  /// JSON (or plain text) handed to the model.
  final String content;
  final bool isError;

  ToolOutcome withContent(String content) => ToolOutcome(
      callId: callId, name: name, content: content, isError: isError);

  Map<String, dynamic> toJson() => {
        'callId': callId,
        'name': name,
        'content': content,
        if (isError) 'isError': true,
      };

  static ToolOutcome? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return ToolOutcome(
      callId: '${raw['callId']}',
      name: '${raw['name']}',
      content: raw['content'] is String ? raw['content'] as String : '',
      isError: raw['isError'] == true,
    );
  }
}

enum ChatRole { user, assistant, tool }

/// One turn of the conversation, in a provider-neutral shape.
///
/// [raw] keeps the provider's own wire form of an assistant turn (keyed by
/// protocol name). It is sent back verbatim to the same provider, which some
/// APIs require (Claude thinking blocks, Gemini thought signatures); another
/// provider rebuilds the turn from the neutral fields instead.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.role,
    this.text = '',
    this.toolCalls = const [],
    this.toolResults = const [],
    this.raw = const {},
  });

  const ChatMessage.user(String text) : this(role: ChatRole.user, text: text);

  final ChatRole role;
  final String text;
  final List<ToolCall> toolCalls;

  /// For [ChatRole.tool]: every result of the previous assistant turn.
  final List<ToolOutcome> toolResults;
  final Map<String, Object?> raw;

  /// Same turn without its provider wire form: rebuilt from the neutral
  /// fields next time (after the history was shortened, replaying the
  /// original reasoning blocks would no longer be valid).
  ChatMessage withoutRaw({List<ToolOutcome>? toolResults}) => ChatMessage(
        role: role,
        text: text,
        toolCalls: toolCalls,
        toolResults: toolResults ?? this.toolResults,
      );

  Map<String, dynamic> toJson() => {
        'role': role.name,
        if (text.isNotEmpty) 'text': text,
        if (toolCalls.isNotEmpty)
          'toolCalls': [for (final c in toolCalls) c.toJson()],
        if (toolResults.isNotEmpty)
          'toolResults': [for (final r in toolResults) r.toJson()],
        if (raw.isNotEmpty) 'raw': raw,
      };

  static ChatMessage? fromJson(Object? json) {
    if (json is! Map) return null;
    final role = ChatRole.values.where((r) => r.name == json['role']);
    if (role.isEmpty) return null;
    final calls = json['toolCalls'];
    final results = json['toolResults'];
    final raw = json['raw'];
    return ChatMessage(
      role: role.first,
      text: json['text'] is String ? json['text'] as String : '',
      toolCalls: [
        if (calls is List)
          for (final c in calls)
            if (ToolCall.fromJson(c) case final call?) call,
      ],
      toolResults: [
        if (results is List)
          for (final r in results)
            if (ToolOutcome.fromJson(r) case final outcome?) outcome,
      ],
      raw: raw is Map ? raw.cast<String, Object?>() : const {},
    );
  }
}

/// What the model answered for one request.
@immutable
class LlmReply {
  const LlmReply({
    required this.message,
    this.stopReason,
    this.refused = false,
  });

  /// The assistant turn (text and/or tool calls), with [ChatMessage.raw] set.
  final ChatMessage message;
  final String? stopReason;

  /// The provider declined the request (safety refusal).
  final bool refused;
}

/// What a streamed reply emits, token by token, before its final [LlmReply].
sealed class LlmEvent {
  const LlmEvent();
}

/// A piece of the visible answer.
class TextDelta extends LlmEvent {
  const TextDelta(this.text);

  final String text;
}

/// A piece of the model's reasoning, when the provider exposes it.
class ThinkingDelta extends LlmEvent {
  const ThinkingDelta(this.text);

  final String text;
}

/// The model started writing a tool call (its arguments are still coming).
class ToolCallDelta extends LlmEvent {
  const ToolCallDelta(this.name);

  final String name;
}

/// End of the stream: the complete assistant turn.
class ReplyDone extends LlmEvent {
  const ReplyDone(this.reply);

  final LlmReply reply;
}

/// A tool as advertised to the model.
@immutable
class ToolSchema {
  const ToolSchema({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;

  /// JSON Schema of the arguments (always an `object`).
  final Map<String, dynamic> parameters;
}
