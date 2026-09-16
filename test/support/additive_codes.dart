/// Distinct additive codes for fixtures that only care how many there are.
///
/// `FoodPanel.additiveCount` is derived from the list rather than stored
/// (T34), so a fixture that wants "a food with nine additives" has to name
/// nine of them. These are real E-numbers in ascending order, which keeps the
/// fixtures plausible without anyone having to invent a plausible one each
/// time.
library;

const List<String> _pool = [
  'E100', 'E101', 'E102', 'E104', 'E110', 'E120', 'E122', 'E124',
  'E127', 'E129', 'E131', 'E132', 'E133', 'E140', 'E141', 'E142',
  'E150a', 'E150b', 'E150c', 'E150d', 'E151', 'E153', 'E155', 'E160a',
  'E161b', 'E162', 'E163', 'E170', 'E171', 'E172', 'E173', 'E174',
  'E175', 'E180', 'E200', 'E202', 'E210', 'E211', 'E212', 'E213',
];

/// [count] distinct codes, drawn from a fixed pool so a fixture is stable
/// across runs. Beyond the pool it falls back to generated numbers.
List<String> additiveCodes(int count) => [
      for (var i = 0; i < count; i++)
        i < _pool.length ? _pool[i] : 'E${900 + i}',
    ];
