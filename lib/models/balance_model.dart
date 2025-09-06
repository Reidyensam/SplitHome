class Balance {
  final String fromUserId;
  final String toUserId;
  final double amount;

  Balance({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });

  factory Balance.fromJson(Map<String, dynamic> json) {
    return Balance(
      fromUserId: json['fromUserId'],
      toUserId: json['toUserId'],
      amount: json['amount'].toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'fromUserId': fromUserId,
    'toUserId': toUserId,
    'amount': amount,
  };
}