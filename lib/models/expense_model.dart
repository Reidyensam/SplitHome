class Expense {
  final String id;
  final String groupId;
  final String userId;
  final String title;
  final double amount;
  final DateTime date;
  final List<String> sharedWith;

  Expense({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.title,
    required this.amount,
    required this.date,
    required this.sharedWith,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      groupId: json['groupId'],
      userId: json['userId'],
      title: json['title'],
      amount: json['amount'].toDouble(),
      date: DateTime.parse(json['date']),
      sharedWith: List<String>.from(json['sharedWith']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'groupId': groupId,
    'userId': userId,
    'title': title,
    'amount': amount,
    'date': date.toUtc().toIso8601String(),
    'sharedWith': sharedWith,
  };
}