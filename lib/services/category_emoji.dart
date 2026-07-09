const _kEmojiMap = {
  'puffs': '🥟',
  'rolls': '🌯',
  'buns': '🍞',
  'cakes': '🍰',
  'cookies': '🍪',
  'bread': '🥖',
  'sweets': '🍬',
  'snacks': '🥨',
  'beverages': '☕',
};

String emojiFor(String? categoryName) {
  if (categoryName == null) return '🍽️';
  final lower = categoryName.toLowerCase();
  for (final entry in _kEmojiMap.entries) {
    if (RegExp(r'\b' + entry.key + r'\b').hasMatch(lower)) return entry.value;
  }
  return '🍽️';
}
