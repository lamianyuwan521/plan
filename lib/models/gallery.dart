import 'dart:typed_data';

const Object _unset = Object();

String _string(Object? value) => value == null ? '' : '$value';

int _int(Object? value, [int fallback = 1]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

/// 图集分类。名字由用户自己起。
class GalleryCategory {
  const GalleryCategory({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  GalleryCategory copyWith({String? name}) {
    return GalleryCategory(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory GalleryCategory.fromJson(Map<String, dynamic> json) {
    return GalleryCategory(
      id: _string(json['id']),
      name: _string(json['name']),
      createdAt:
          DateTime.tryParse(_string(json['createdAt'])) ?? DateTime.now(),
    );
  }
}

/// 一张图集图片。二进制内容另存在本机，这里只留元数据。
class GalleryPhoto {
  const GalleryPhoto({
    required this.id,
    required this.createdAt,
    this.categoryId,
    this.width = 1,
    this.height = 1,
  });

  final String id;
  final String? categoryId;
  final int width;
  final int height;
  final DateTime createdAt;

  GalleryPhoto copyWith({Object? categoryId = _unset}) {
    return GalleryPhoto(
      id: id,
      categoryId: identical(categoryId, _unset)
          ? this.categoryId
          : categoryId as String?,
      width: width,
      height: height,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'categoryId': categoryId,
    'width': width,
    'height': height,
    'createdAt': createdAt.toIso8601String(),
  };

  factory GalleryPhoto.fromJson(Map<String, dynamic> json) {
    final rawCategory = json['categoryId'];
    return GalleryPhoto(
      id: _string(json['id']),
      categoryId: rawCategory == null || '$rawCategory'.isEmpty
          ? null
          : '$rawCategory',
      width: _int(json['width']),
      height: _int(json['height']),
      createdAt:
          DateTime.tryParse(_string(json['createdAt'])) ?? DateTime.now(),
    );
  }
}

/// 待写入的一张图片。宽高用于瀑布流排版，不必等图片解码完成后再测量。
class GalleryPhotoInput {
  const GalleryPhotoInput({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}
