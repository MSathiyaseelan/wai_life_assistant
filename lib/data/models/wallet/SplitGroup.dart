class SplitGroup {
  final String name;
  final String type;
  final List<String> members;
  final double youOwe;
  final double youGet;
  final String? imagePath;

  SplitGroup({
    required this.name,
    required this.type,
    required this.members,
    required this.youOwe,
    required this.youGet,
    this.imagePath,
  });
}
