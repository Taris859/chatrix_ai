import re

chat_screen_path = r'e:\chatrix_ai\lib\ui\chat_screen.dart'
settings_screen_path = r'e:\chatrix_ai\lib\ui\settings_screen.dart'

# ================================
# chat_screen.dart
# ================================
with open(chat_screen_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the timer declaration
content = re.sub(r'^\s*Timer\?\s+_presenceTimer;\n', '', content, flags=re.MULTILINE)
# Remove timer cancel
content = re.sub(r'^\s*_presenceTimer\?\.cancel\(\);\n', '', content, flags=re.MULTILINE)
# Remove _startPresenceTimer calls
content = re.sub(r'^\s*_startPresenceTimer\(\);.*?$', '', content, flags=re.MULTILINE)
# Remove _syncPresenceStateToFirestore calls
content = re.sub(r'^\s*_syncPresenceStateToFirestore\(\);.*?$', '', content, flags=re.MULTILINE)

# Remove the three method definitions:
# _syncPresenceStateToFirestore
content = re.sub(r'^\s*Future<void>\s+_syncPresenceStateToFirestore\(\)\s*async\s*\{.*?(?=\n\s*[A-Za-z0-9_<>]+ [A-Za-z0-9_]+\()', '', content, flags=re.MULTILINE | re.DOTALL)
# _startPresenceTimer
content = re.sub(r'^\s*void\s+_startPresenceTimer\(\)\s*\{.*?(?=\n\s*[A-Za-z0-9_<>]+ [A-Za-z0-9_]+\()', '', content, flags=re.MULTILINE | re.DOTALL)
# _triggerAmbientPresenceThought
content = re.sub(r'^\s*void\s+_triggerAmbientPresenceThought\(\)\s*\{.*?(?=\n\s*(?:@override|Widget|Future|void|String))', '', content, flags=re.MULTILINE | re.DOTALL)

with open(chat_screen_path, 'w', encoding='utf-8') as f:
    f.write(content)

# ================================
# settings_screen.dart
# ================================
with open(settings_screen_path, 'r', encoding='utf-8') as f:
    content2 = f.read()

# Remove _silentPresence references
content2 = re.sub(r'^\s*bool\s+_silentPresence\s*=\s*false;\n', '', content2, flags=re.MULTILINE)
content2 = re.sub(r'^\s*_silentPresence\s*=\s*prefs\.getBool\(\'silentPresence\'\)\s*\?\?\s*false;\n', '', content2, flags=re.MULTILINE)
content2 = re.sub(r'^\s*_silentPresence\s*=\s*settings\[\'silentPresence\'\]\s*\?\?\s*_silentPresence;\n', '', content2, flags=re.MULTILINE)
content2 = re.sub(r'^\s*await\s+prefs\.setBool\(\'silentPresence\'\,\s*_silentPresence\);\n', '', content2, flags=re.MULTILINE)
content2 = re.sub(r'^\s*\'silentPresence\':\s*_silentPresence,\n', '', content2, flags=re.MULTILINE)

# Remove the section
section_pattern = r'^\s*_buildSectionTitle\("Presence & Connection"\).*?(?=\n\s*_buildSectionTitle|\n\s*const SizedBox|\n\s*\])'
content2 = re.sub(section_pattern, '', content2, flags=re.MULTILINE | re.DOTALL)

with open(settings_screen_path, 'w', encoding='utf-8') as f:
    f.write(content2)

print("Presence logic removed.")
