const kParentalPin = '1234';

/// Returns true if the category name looks like adult content.
/// Pass [isAdult] = 1 when the Xtream API explicitly marks the category adult
/// — that takes priority over keyword matching.
bool isAdultCategory(String name, {int? isAdult}) {
  if (isAdult == 1) return true;

  final lower = name.toLowerCase().trim();

  const adultKeywords = [
    'xxx',
    'porn',
    'pornography',
    '18+',
    '+18',
    'x-rated',
    'xrated',
    'erotic',
    'erotica',
    'adult only',
    'adults only',
    'nude',
  ];

  for (final keyword in adultKeywords) {
    if (lower.contains(keyword)) return true;
  }

  return false;
}
