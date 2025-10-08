import 'chapter.dart';

class Manhwa {
  final String id;
  final String name;
  final String description;
  final List<String> genres;
  final double rating;
  final String status; // 'Ongoing', 'Completed', 'Hiatus'
  final String author;
  final String artist;
  final DateTime? lastUpdated;
  final List<Chapter> chapters;
  final String? coverImageUrl;
  final String? pluginName;
  final int chapterCount;
  const Manhwa({
    required this.id,
    required this.name,
    required this.description,
    required this.genres,
    required this.rating,
    required this.status,
    required this.author,
    required this.artist,
    this.lastUpdated,
    required this.chapters,
    this.coverImageUrl,
    this.pluginName,
    this.chapterCount = 0,
  });

  // Convenience getters
  String get genreString => genres.join(', ');
  double get totalChapters {
  if (chapters.isEmpty) return 0.0;
  return chapters.length.toDouble();
}
  DateTime? get latestChapterDate => chapters.isNotEmpty 
      ? chapters.map((c) => c.releaseDate).reduce((a, b) => a.isAfter(b) ? a : b)
      : null;
  
  // Get reading progress
  int get readChapters => chapters.where((c) => c.isRead).length;
  int get downloadedChapters => chapters.where((c) => c.isDownloaded).length;
  double get readingProgress => chapters.isNotEmpty ? readChapters / totalChapters : 0.0;
  
  // Find last read chapter number
double get lastReadChapter {
  for (int i = chapters.length - 1; i >= 0; i--) {
    if (chapters[i].isRead) return chapters[i].number;
  }
  return 0.0; // Changed to double
}

  Manhwa copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? genres,
    double? rating,
    String? status,
    String? author,
    String? artist,
    DateTime? lastUpdated,
    List<Chapter>? chapters,
    String? coverImageUrl,
  }) {
    return Manhwa(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      genres: genres ?? this.genres,
      rating: rating ?? this.rating,
      status: status ?? this.status,
      author: author ?? this.author,
      artist: artist ?? this.artist,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      chapters: chapters ?? this.chapters,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
    );
  }

factory Manhwa.fromPluginData(Map<String, dynamic> data) {
  // Debug: check what's coming in
  print('Manhwa data received: ${data['name']}');
  
  List<Chapter> chapterList = [];
  if (data['chapters'] != null) {
    for (var i = 0; i < (data['chapters'] as List).length; i++) {
      var chapterData = (data['chapters'] as List)[i];
      print('Processing chapter $i: ${chapterData['number']} (type: ${chapterData['number']?.runtimeType})');
      try {
        chapterList.add(Chapter.fromPluginData(chapterData));
      } catch (e) {
        print('ERROR converting chapter $i: $e');
        print('Chapter data: $chapterData');
        rethrow;
      }
    }
  }

  return Manhwa(
    id: data['id'] ?? '',
    name: data['name'] ?? 'Unknown Title',
    description: data['description'] ?? '',
    genres: data['genres'] != null 
        ? List<String>.from(data['genres'])
        : [],
    rating: (data['rating'] ?? 0.0).toDouble(),
    status: data['status'] ?? 'Unknown',
    author: data['author'] ?? 'Unknown Author',
    artist: data['artist'] ?? 'Unknown Artist',
    lastUpdated: data['lastUpdated'] != null 
        ? DateTime.tryParse(data['lastUpdated']) ?? DateTime.now()
        : DateTime.now(),
    chapters: chapterList,
    coverImageUrl: data['coverImageUrl'],
  );
}
}