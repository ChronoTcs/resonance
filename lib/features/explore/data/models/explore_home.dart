class ExploreHomeSection {
  final String title;
  final List<ExploreHomeItem> items;
  
  ExploreHomeSection({required this.title, required this.items});
}

class ExploreHomeItem {
  final String id;
  final String title;
  final String subtitle;
  final String thumbnailUrl;
  final bool isPlaylist;
  
  ExploreHomeItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.thumbnailUrl,
    required this.isPlaylist,
  });
}
