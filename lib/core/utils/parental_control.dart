const kParentalPin = '1234';

/// Returns true if the category name looks like adult content.
bool isAdultCategory(String name) {
  final n = name.toLowerCase();
  return n.contains('adult')   ||
         n.contains('xxx')     ||
         n.contains('porn')    ||
         n.contains('18+')     ||
         n.contains('x-rated') ||
         n.contains('erotic')  ||
         n.contains('nude')    ||
         n.contains('sex')     ||
         n.contains('+18')     ||
         n.contains('hot');
}
