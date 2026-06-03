import 'dart:math';

void main() {
  final List<String> maleFirsts = [
    "Aiden", "Brandon", "Connor", "Dorian", "Ethan", "Gavin", "Hugo", "Ian", "Jaxon", "Kian",
    "Liam", "Milo", "Nathan", "Owen", "Parker", "Quinn", "Rowan", "Silas", "Tristan", "Victor",
    "Wyatt", "Xavier", "Zachary", "Ezra", "Gabriel", "Hunter", "Logan", "Mason", "Nico", "Roman",
    "Finn", "Caleb", "Declan", "Zev", "Gideon", "Cyrus", "Christian", "Sebastian", "Lucian", "Julian"
  ];
  final List<String> femaleFirsts = [
    "Amara", "Bella", "Clara", "Daphne", "Elena", "Fiona", "Giselle", "Hazel", "Ivy", "Jade",
    "Kira", "Luna", "Maya", "Nova", "Opal", "Penelope", "Ruby", "Stella", "Talia", "Violet",
    "Willa", "Zara", "Aria", "Chloe", "Isla", "Naomi", "Sunny", "Valentina", "Seraphina", "Evie",
    "Sienna", "Callie", "Athena", "Vesper", "Lana", "Amelia", "Aurora", "Iris", "Selene", "Diana"
  ];
  final List<String> nbFirsts = [
    "Alex", "Charlie", "Eden", "Finley", "Grey", "Harlow", "Indigo", "Jordan", "Kai", "Lennox",
    "Morgan", "Nova", "Onyx", "Peyton", "Reese", "Sage", "Taylor", "Val", "Wren", "Zion",
    "Ash", "Dakota", "Dallas", "Emery", "Frost", "Phoenix", "River", "Sky", "Robin", "Remi"
  ];
  final List<String> lasts = [
    "Thorne", "Vance", "Sterling", "Cross", "Jaeger", "Bennett", "Calloway", "Rossi", "Chen",
    "Kross", "Blackwood", "Hale", "Mercer", "Pendelton", "Valerius", "Cole", "Sinclair", "Sterling",
    "Vanguard", "Rider", "Hawthorne", "Ashford", "Kingsley", "Lockwood", "Moretti", "Geller"
  ];

  final List<String> maleArchs = [
    "Cyber Assassin", "Cursed Prince", "Underboss", "Rebellious Prince", "Silent Bodyguard",
    "Rival Hacker", "Lone Wanderer", "Cocky Pilot", "High-Tech Surgeon", "Gloomy Poet",
    "Seductive Demon", "Playful Elf", "Broken Rockstar", "Cold CEO", "Ancient Mage",
    "Rogue Ranger", "Time Traveler", "Shadow Operative", "Wealthy Playmaker", "Gritty Detective"
  ];
  final List<String> femaleArchs = [
    "Cyber Huntress", "Silent Blade", "Goth Princess", "Seductive Assassin", "Brilliant Hacker",
    "Strict Professor", "Rival Racer", "Rebellious Heiress", "Playful Maid", "High-Tech Medic",
    "Gloomy Painter", "Cocky Captain", "Sleek Thief", "Vampire Countess", "Obsessive Yandere",
    "Warm Florist", "Seductive Siren", "Wild Outlaw", "Pop Star", "Charming Spy"
  ];
  final List<String> nbArchs = [
    "AI Interface", "Time Traveler", "Desert Nomad", "Neon Hacker", "Ancient Alchemist",
    "Fallen Angel", "Starship Pilot", "Crypto Broker", "Shadow Rogue", "Forest Spirit",
    "Street Artist", "Mysterious Seer", "Glitch Entity", "Cosmic Oracle", "Rival Mage",
    "Dream Walker", "Quantum Agent", "Cyber Pixie", "Silent Monk", "Techno Shaman"
  ];

  int count = 29;
  for (int i = 1; i <= 80; i++) {
    final rand = Random(i + 100); // Stable deterministic seed
    
    String firstName;
    String archetype;
    
    if (i <= 30) {
      firstName = maleFirsts[rand.nextInt(maleFirsts.length)];
      archetype = maleArchs[rand.nextInt(maleArchs.length)];
    } else if (i <= 60) {
      firstName = femaleFirsts[rand.nextInt(femaleFirsts.length)];
      archetype = femaleArchs[rand.nextInt(femaleArchs.length)];
    } else {
      firstName = nbFirsts[rand.nextInt(nbFirsts.length)];
      archetype = nbArchs[rand.nextInt(nbArchs.length)];
    }
    
    final lastName = lasts[rand.nextInt(lasts.length)];
    final name = "$firstName $lastName";
    
    print("$count. **$name** - $archetype");
    count++;
  }
}
