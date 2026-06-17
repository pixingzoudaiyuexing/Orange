import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class PlanDescriptionWidget extends StatelessWidget {
  final String content;
  final List<String> features;
  const PlanDescriptionWidget({
    super.key,
    required this.content,
    this.features = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final display = PlanDescriptionDisplayData.from(
      content: content,
      features: features,
    );
    if (display.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: display.items.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: display.items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 15,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            )
          : MarkdownBody(
              data: display.text!,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: WrapAlignment.start,
              ),
            ),
    );
  }
}

class PlanDescriptionDisplayData {
  final List<String> items;
  final String? text;

  const PlanDescriptionDisplayData._({required this.items, required this.text});

  factory PlanDescriptionDisplayData.from({
    required String content,
    List<String> features = const [],
  }) {
    final items = <String>[];
    items.addAll(features.map(_cleanText).where((item) => item.isNotEmpty));

    final trimmed = content.trim();
    final parsedItems = _parseJsonFeatureItems(trimmed);
    if (parsedItems != null) {
      items.addAll(parsedItems);
      return PlanDescriptionDisplayData._(items: _dedupe(items), text: null);
    }

    if (items.isNotEmpty) {
      final sanitizedText = _sanitizeJsonText(trimmed);
      if (sanitizedText.isNotEmpty) {
        items.add(sanitizedText);
      }
      return PlanDescriptionDisplayData._(items: _dedupe(items), text: null);
    }

    return PlanDescriptionDisplayData._(
      items: const [],
      text: _sanitizeJsonText(trimmed),
    );
  }

  bool get isEmpty => items.isEmpty && (text == null || text!.isEmpty);

  static List<String>? _parseJsonFeatureItems(String value) {
    if (value.isEmpty || !(value.startsWith('[') || value.startsWith('{'))) {
      return null;
    }
    try {
      final decoded = jsonDecode(value);
      final rawItems = decoded is Map ? decoded['features'] : decoded;
      if (rawItems is! List) {
        return const [];
      }
      return rawItems
          .whereType<Map>()
          .where((item) => _readBool(item['support'], defaultValue: true))
          .map((item) => _cleanText(item['feature'] ?? item['name']))
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    } on FormatException {
      return null;
    }
  }

  static bool _readBool(Object? value, {required bool defaultValue}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return defaultValue;
  }

  static String _sanitizeJsonText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      final parsed = _parseJsonFeatureItems(trimmed);
      if (parsed != null) {
        return parsed.join('\n');
      }
      return trimmed
          .replaceAll(RegExp(r'^\s*[\[{]\s*'), '')
          .replaceAll(RegExp(r'\s*[\]}]\s*$'), '')
          .replaceAll(RegExp(r'"?(feature|name|support)"?\s*:\s*'), '')
          .replaceAll(RegExp(r'[{}\[\]"]'), '')
          .replaceAll(RegExp(r'\s*,\s*'), '\n')
          .trim();
    }
    return trimmed;
  }

  static String _cleanText(Object? value) {
    return value
            ?.toString()
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll('： ', '：')
            .trim() ??
        '';
  }

  static List<String> _dedupe(List<String> values) {
    final seen = <String>{};
    return values.where((item) => seen.add(item)).toList(growable: false);
  }
}
