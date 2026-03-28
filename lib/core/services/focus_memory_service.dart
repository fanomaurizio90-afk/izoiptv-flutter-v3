/// Remembers which item index was focused on each route so focus can be
/// restored when the user navigates back.
class FocusMemoryService {
  FocusMemoryService._();
  static final instance = FocusMemoryService._();

  final Map<String, int> _memory = {};

  /// Save the focused item index for a route.
  void save(String route, int index) => _memory[route] = index;

  /// Retrieve and clear the saved index (returns null if none saved).
  int? restore(String route) => _memory.remove(route);

  /// Peek without clearing.
  int? peek(String route) => _memory[route];

  /// Clear all stored focus positions.
  void clear() => _memory.clear();
}
