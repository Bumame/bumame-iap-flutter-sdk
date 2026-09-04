/// Mutable request context for resource-scoped applications. It stores no
/// credential; it only supplies business headers such as `X-Clinic-ID`.
class IapResourceContext {
  IapResourceContext({
    Map<String, Object?> initialHeaders = const {},
    void Function(Map<String, Object?> headers)? onChanged,
  })  : _headers = Map.of(initialHeaders),
        _onChanged = onChanged;

  final Map<String, Object?> _headers;
  final void Function(Map<String, Object?> headers)? _onChanged;

  void set(String header, Object? value) {
    if (value == null || value.toString().trim().isEmpty) {
      _headers.remove(header);
    } else {
      _headers[header] = value;
    }
    _onChanged?.call(headers());
  }

  void remove(String header) {
    _headers.remove(header);
    _onChanged?.call(headers());
  }

  void clear() {
    _headers.clear();
    _onChanged?.call(headers());
  }

  Map<String, Object?> headers() => Map.unmodifiable(_headers);
}
