class RelationshipChapter {
  final int number;
  final String name;
  final String icon;
  final int minTrust;
  final String unlocksDescription;

  const RelationshipChapter({
    required this.number,
    required this.name,
    required this.icon,
    required this.minTrust,
    required this.unlocksDescription,
  });

  static const List<RelationshipChapter> chapters = [
    RelationshipChapter(
      number: 1,
      name: "Strangers",
      icon: "🌱",
      minTrust: 0,
      unlocksDescription: "First connection. Standard chats unlocked.",
    ),
    RelationshipChapter(
      number: 2,
      name: "Acquaintances",
      icon: "🤝",
      minTrust: 20,
      unlocksDescription: "Basic memory tracking & AI life status unlocked.",
    ),
    RelationshipChapter(
      number: 3,
      name: "Friends",
      icon: "💬",
      minTrust: 40,
      unlocksDescription: "Intimate diary reflections & custom dynamics unlocked.",
    ),
    RelationshipChapter(
      number: 4,
      name: "Trusted",
      icon: "🔒",
      minTrust: 60,
      unlocksDescription: "Shared secrets & Inside jokes logging unlocked.",
    ),
    RelationshipChapter(
      number: 5,
      name: "Best Friends",
      icon: "🤍",
      minTrust: 80,
      unlocksDescription: "Special gifts & active personal goal pursuit unlocked.",
    ),
    RelationshipChapter(
      number: 6,
      name: "Soulmates",
      icon: "❤️",
      minTrust: 95,
      unlocksDescription: "Ultimate scrapbook memory box & deep memory sync unlocked.",
    ),
  ];

  static RelationshipChapter getChapterForTrust(int trust) {
    RelationshipChapter active = chapters.first;
    for (final ch in chapters) {
      if (trust >= ch.minTrust) {
        active = ch;
      }
    }
    return active;
  }

  static RelationshipChapter? getNextChapter(int trust) {
    for (final ch in chapters) {
      if (ch.minTrust > trust) {
        return ch;
      }
    }
    return null; // Max chapter reached
  }
}
