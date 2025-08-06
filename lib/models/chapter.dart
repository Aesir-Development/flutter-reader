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
}