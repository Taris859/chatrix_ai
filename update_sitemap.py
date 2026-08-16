import os
import re

sitemap_path = r'e:\chatrix_ai\web\sitemap.xml'
companion_dir = r'e:\chatrix_ai\web\companion'

# Read sitemap.xml
with open(sitemap_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Get all companion slugs (directories in web/companion)
slugs = sorted([d for d in os.listdir(companion_dir) if os.path.isdir(os.path.join(companion_dir, d))])
print(f"Found {len(slugs)} companion directories in {companion_dir}.")

# Find the header part of the sitemap
header_match = re.search(r'^([\s\S]*?<!--\s*Companion\s*Pages\s*-->)', content)
if not header_match:
    print("Could not find the '<!-- Companion Pages -->' marker in sitemap.xml!")
    exit(1)

header_content = header_match.group(1)

# Generate companion URL tags
companion_urls = []
for slug in slugs:
    url_tag = f"""  <url>
    <loc>https://chatrix.space/companion/{slug}</loc>
    <lastmod>2026-06-26</lastmod>
    <changefreq>weekly</changefreq>
    <priority>0.9</priority>
  </url>"""
    companion_urls.append(url_tag)

new_sitemap_content = header_content + "\n" + "\n".join(companion_urls) + "\n</urlset>\n"

with open(sitemap_path, 'w', encoding='utf-8') as f:
    f.write(new_sitemap_content)

print(f"Successfully updated sitemap.xml with {len(slugs)} companion pages.")
