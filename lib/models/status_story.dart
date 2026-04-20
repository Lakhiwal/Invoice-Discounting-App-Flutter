class StatusStory {
  const StatusStory({
    required this.id,
    required this.imageUrls,
    required this.timestamp,
    this.isSeen = false,
  });

  factory StatusStory.fromJson(Map<String, dynamic> json) => StatusStory(
        id: json['id'] as String? ?? '',
        imageUrls: List<String>.from(json['image_urls'] as Iterable? ?? []),
        timestamp: DateTime.parse(
          json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
        ),
        isSeen: json['is_seen'] as bool? ?? false,
      );

  final String id;
  final List<String> imageUrls;
  final DateTime timestamp;
  final bool isSeen;

  StatusStory copyWith({
    String? id,
    List<String>? imageUrls,
    DateTime? timestamp,
    bool? isSeen,
  }) =>
      StatusStory(
        id: id ?? this.id,
        imageUrls: imageUrls ?? this.imageUrls,
        timestamp: timestamp ?? this.timestamp,
        isSeen: isSeen ?? this.isSeen,
      );
}
