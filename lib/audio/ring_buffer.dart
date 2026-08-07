class RingBuffer {
  RingBuffer(this.capacity) : _data = List<double>.filled(capacity, 0.0);

  final int capacity;
  final List<double> _data;
  int _writeIndex = 0;
  int _filled = 0;

  bool get isFull => _filled >= capacity;

  void addAll(List<double> samples) {
    for (final s in samples) {
      _data[_writeIndex] = s;
      _writeIndex = (_writeIndex + 1) % capacity;
      if (_filled < capacity) _filled++;
    }
  }


  List<double> snapshot() {
    if (_filled < capacity) {
      return _data.sublist(0, _filled);
    }
    return [
      ..._data.sublist(_writeIndex),
      ..._data.sublist(0, _writeIndex),
    ];
  }

  void clear() {
    _writeIndex = 0;
    _filled = 0;
  }
}