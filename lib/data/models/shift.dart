class Shift {
  final int id;
  final int userId;
  final DateTime openedAt;
  final DateTime? closedAt;
  final double openingCash;
  final double? closingCash;
  final String status; // open | closed

  const Shift({
    required this.id,
    required this.userId,
    required this.openedAt,
    this.closedAt,
    this.openingCash = 0,
    this.closingCash,
    required this.status,
  });

  bool get isOpen => status == 'open';

  factory Shift.fromMap(Map<String, Object?> m) => Shift(
        id: m['id'] as int,
        userId: m['user_id'] as int,
        openedAt: DateTime.parse(m['opened_at'] as String),
        closedAt: m['closed_at'] != null
            ? DateTime.parse(m['closed_at'] as String)
            : null,
        openingCash: (m['opening_cash'] as num?)?.toDouble() ?? 0,
        closingCash: (m['closing_cash'] as num?)?.toDouble(),
        status: m['status'] as String,
      );

  String get displayLabel {
    final d = openedAt.toLocal();
    return 'กะ #${id.toString().padLeft(4, '0')} • ${d.day}/${d.month}/${d.year + 543} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
