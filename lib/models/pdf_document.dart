class PdfFolder {
  final String id;
  String name;
  final DateTime createdAt;

  PdfFolder({required this.id, required this.name, required this.createdAt});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PdfFolder.fromJson(Map<String, dynamic> json) => PdfFolder(
    id: json['id'],
    name: json['name'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}

class PdfDocument {
  final String id;
  String title;
  final String filePath;   // app documents 下的相对路径
  String? folderId;        // null = 根目录 / 未分类
  bool isFavorite;
  final DateTime createdAt;

  PdfDocument({
    required this.id,
    required this.title,
    required this.filePath,
    this.folderId,
    this.isFavorite = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'filePath': filePath,
    'folderId': folderId,
    'isFavorite': isFavorite,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PdfDocument.fromJson(Map<String, dynamic> json) => PdfDocument(
    id: json['id'],
    title: json['title'],
    filePath: json['filePath'],
    folderId: json['folderId'],
    isFavorite: json['isFavorite'] ?? false,
    createdAt: DateTime.parse(json['createdAt']),
  );
}
