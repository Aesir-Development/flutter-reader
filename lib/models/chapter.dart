class Chapter {
  final double number;
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
    double? number,
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
  // Handle the number conversion more robustly
  dynamic numberData = data['number'];
  double chapterNumber;

  if (numberData is int) {
    chapterNumber = numberData.toDouble();
    print('Converted int $numberData to double $chapterNumber');
  } else if (numberData is double) {
    chapterNumber = numberData;
    print('Already double: $chapterNumber');
  } else if (numberData is String) {
    chapterNumber = double.tryParse(numberData) ?? 0.0;
    print('Converted string "$numberData" to double $chapterNumber');
  } else {
    chapterNumber = 0.0;
    print('Unknown type ${numberData.runtimeType}, defaulting to 0.0');
  }

  return Chapter(
    number: chapterNumber,
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