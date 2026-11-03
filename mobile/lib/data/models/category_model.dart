class CategoryModel {
  final String id;
  final String name;
  final String slug;
  final String description;
  final String icon;
  final bool isActive;
  final int videoCount;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description = '',
    this.icon = 'Tag',
    this.isActive = true,
    this.videoCount = 0,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'Tag',
      isActive: json['is_active'] == true || json['is_active'] == 1,
      videoCount: (json['video_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'icon': icon,
      'is_active': isActive,
      'video_count': videoCount,
    };
  }

  static List<CategoryModel> defaultCategories() {
    return const [
      CategoryModel(
        id: 'cat-all',
        name: 'All',
        slug: 'all',
        description: 'All videos and topics',
        icon: 'Sparkles',
        videoCount: 120,
      ),
      CategoryModel(
        id: 'cat-self',
        name: 'Self / Personal Brand',
        slug: 'self',
        description: 'Personal branding, life updates, thoughts',
        icon: 'User',
        videoCount: 42,
      ),
      CategoryModel(
        id: 'cat-promotion',
        name: 'Promotion & Sponsorship',
        slug: 'promotion',
        description: 'Sponsor showcases and promotional campaigns',
        icon: 'Megaphone',
        videoCount: 35,
      ),
      CategoryModel(
        id: 'cat-business',
        name: 'Business & MSME',
        slug: 'business',
        description: 'Small business growth, entrepreneurship',
        icon: 'Briefcase',
        videoCount: 28,
      ),
      CategoryModel(
        id: 'cat-product',
        name: 'Product Review',
        slug: 'product',
        description: 'In-depth gadget, gear, and software reviews',
        icon: 'ShoppingBag',
        videoCount: 15,
      ),
    ];
  }
}

