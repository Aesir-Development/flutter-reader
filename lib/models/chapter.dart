class Chapter {
  final int number;
  final String title;
  final DateTime releaseDate;
  final bool isRead;
  final bool isDownloaded;
  final List<String> images;

  const Chapter({
    required this.number,
    required this.title,
    required this.releaseDate,
    required this.isRead,
    required this.isDownloaded,
    required this.images,
  });

  Chapter copyWith({
    int? number,
    String? title,
    DateTime? releaseDate,
    bool? isRead,
    bool? isDownloaded,
    List<String>? images,
  }) {
    return Chapter(
      number: number ?? this.number,
      title: title ?? this.title,
      releaseDate: releaseDate ?? this.releaseDate,
      isRead: isRead ?? this.isRead,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      images: images ?? this.images,
    );
  }

  factory Chapter.fromPluginData(Map<String, dynamic> data) {
    return Chapter(
      number: data['number'] ?? 0,
      title: data['title'] ?? 'Untitled Chapter',
      releaseDate: data['releaseDate'] != null
          ? DateTime.tryParse(data['releaseDate']) ?? DateTime.now()
          : DateTime.now(),
      isRead: data['isRead'] ?? false,
      isDownloaded: data['isDownloaded'] ?? false,
      images: data['images'] != null
          ? List<String>.from(data['images'])
          : [],
    );
  }
}