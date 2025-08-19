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
  });

  // Convenience getters
  String get genreString => genres.join(', ');
  int get totalChapters => chapters.length;
  DateTime? get latestChapterDate => chapters.isNotEmpty 
      ? chapters.map((c) => c.releaseDate).reduce((a, b) => a.isAfter(b) ? a : b)
      : null;
  
  // Get reading progress
  int get readChapters => chapters.where((c) => c.isRead).length;
  int get downloadedChapters => chapters.where((c) => c.isDownloaded).length;
  double get readingProgress => chapters.isNotEmpty ? readChapters / totalChapters : 0.0;
  
  // Find last read chapter number
  int get lastReadChapter {
    for (int i = chapters.length - 1; i >= 0; i--) {
      if (chapters[i].isRead) return chapters[i].number;
    }
    return 0;
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
      chapters: data['chapters'] != null
          ? (data['chapters'] as List).map((chapterData) => Chapter.fromPluginData(chapterData)).toList()
          : [],
      coverImageUrl: data['coverImageUrl'],
    );
  }
}