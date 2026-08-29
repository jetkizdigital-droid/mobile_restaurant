String? resolveRestaurantIdFromMe(Map<String, dynamic> me) {
  final candidates = <dynamic>[
    me['activeRestaurantId'],
    me['restaurantId'],
    (me['restaurant'] is Map ? (me['restaurant'] as Map)['id'] : null),
  ];

  for (final candidate in candidates) {
    final value = candidate?.toString().trim() ?? '';
    if (value.isNotEmpty) {
      return value;
    }
  }

  return null;
}
