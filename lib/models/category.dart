class Category {
  final int id;
  final int? parentId;
  final String name;
  final String slug;
  final int sortOrder;
  final bool isActive;
  final String? image;
  final String? colorFrom;
  final String? colorTo;

  const Category({
    required this.id,
    this.parentId,
    required this.name,
    required this.slug,
    this.sortOrder = 0,
    this.isActive = true,
    this.image,
    this.colorFrom,
    this.colorTo,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      parentId: json['parent_id'] as int?,
      name: json['name'] as String,
      slug: json['slug'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      image: json['image'] as String?,
      colorFrom: json['color_from'] as String?,
      colorTo: json['color_to'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'slug': slug,
      'sort_order': sortOrder,
      'parent_id': parentId,
      'is_active': isActive,
      if (image != null) 'image': image,
      if (colorFrom != null) 'color_from': colorFrom,
      if (colorTo != null) 'color_to': colorTo,
    };
  }
}
