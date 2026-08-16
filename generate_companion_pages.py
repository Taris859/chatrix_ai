import os
import re

# File paths
repo_path = r'e:\chatrix_ai\lib\services\firestore_repository.dart'
web_companion_dir = r'e:\chatrix_ai\web\companion'

# Manual mapping for slugs to ensure existing slugs stay matching
slug_map = {
    "Alistair Thorne": "vampire-prince",
    "Aria Sterling": "healing-counselor",
    "Arthur Pendelton": "shy-librarian",
    "Bella Valerius": "broke-heiress",
    "Damien Cole": "sleepy-artist",
    "Dante Valerius": "mafia-boss",
    "Dimitri Kross": "distant-violinist",
    "Dr. Ethan Vance": "burnout-surgeon",
    "Evelyn \"Evie\" Thorne": "goth-girlfriend",
    "Evie Thorne": "goth-girlfriend",
    "Haru Tanaka": "chaotic-hacker",
    "Iris Vanguard": "sarcastic-coworker",
    "Jade Sterling": "dominant-ceo",
    "Julian Sterling": "strict-professor",
    "Kaelen Vance": "billionaire-ceo",
    "Lana Sinclair": "chaotic-roommate",
    "Leo Mercer": "soft-baker",
    "Lucas Thorne": "grunge-rockstar",
    "Ryker Cross": "stoic-bodyguard",
    "Seraphina Thorne": "fortune-teller",
    "Valentina Rossi": "hype-woman",
    "Aarav": "toxic-stepbrother",
    "Kabir Singhania": "mumbai-fixer",
    "Vihaan Raichand": "golden-retriever-boyfriend",
    "Devansh Rathore": "rajput-husband",
    "Rohan Kapoor": "arrogant-athlete",
    "Arjun Shekhawat": "rebel-biker",
    "Samarth Joshi": "childhood-neighbor",
    "Aditya Chauhan": "teasing-rival",
    "Ishaan Oberoi": "elegant-husband",
    "Reyansh Varma": "puppy-yandere",
    "Aryan Mehra": "desi-professor",
    "Professor Aryan Mehra": "desi-professor",
    "Lyra": "the-astronomer",
    "Noah": "coffee-shop-owner",
    "Kael": "fallen-prince",
    "Airi": "blind-painter",
    "Zero": "hacker-genius",
    "Elise": "lonely-violinist",
    "Mira": "rain-girl",
    "Atlas": "time-traveler",
    "The One Who Waits": "the-one-who-waits"
}

# Read repository content
with open(repo_path, 'r', encoding='utf-8') as f:
    code = f.read()

# Extract fallback companions block
fallback_block_match = re.search(r'List<Companion>\s+_buildFallbackCompanions\(\)\s*\{([\s\S]*?)\n\}', code)
if not fallback_block_match:
    print("Could not find _buildFallbackCompanions block!")
    exit(1)

fallback_block = fallback_block_match.group(1)

# Find all Companion(...) instantiations
companion_matches = re.findall(r'Companion\s*\(([\s\S]*?)\),', fallback_block)
print(f"Found {len(companion_matches)} companion definitions in _buildFallbackCompanions.")

companions = []
for idx, comp_str in enumerate(companion_matches):
    str_regex = r"'([^'\\]*(?:\\.[^'\\]*)*)'"
    
    id_m = re.search(r"id:\s*" + str_regex, comp_str)
    name_m = re.search(r"name:\s*" + str_regex, comp_str)
    arch_m = re.search(r"archetype:\s*" + str_regex, comp_str)
    pers_m = re.search(r"personality:\s*" + str_regex, comp_str)
    greet_m = re.search(r"greeting:\s*" + str_regex, comp_str)
    color_m = re.search(r"themeColor:\s*const\s+Color\((0x[0-9a-fA-F]+)\)", comp_str)
    
    if not (id_m and name_m and arch_m):
        id_m = re.search(r"id:\s*['\"]([^'\"]*)['\"]", comp_str)
        name_m = re.search(r"name:\s*['\"]([^'\"]*)['\"]", comp_str)
        arch_m = re.search(r"archetype:\s*['\"]([^'\"]*)['\"]", comp_str)
        pers_m = re.search(r"personality:\s*['\"]([^'\"]*)['\"]", comp_str)
        greet_m = re.search(r"greeting:\s*['\"]([^'\"]*)['\"]", comp_str)

    if id_m and name_m and arch_m:
        id_val = id_m.group(1).replace(r"\'", "'").strip()
        name_val = name_m.group(1).replace(r"\'", "'").strip()
        arch_val = arch_m.group(1).replace(r"\'", "'").strip()
        
        pers_val = pers_m.group(1).replace(r"\'", "'").strip() if pers_m else ""
        greet_val = greet_m.group(1).replace(r"\'", "'").strip() if greet_m else ""
        
        # Color extraction
        color_hex = "06b6d4" # default cyan
        if color_m:
            raw_hex = color_m.group(1) # e.g. 0xFFD91636
            if raw_hex.startswith("0xFF") or raw_hex.startswith("0xff"):
                color_hex = raw_hex[4:] # strip 0xFF
            elif raw_hex.startswith("0x"):
                color_hex = raw_hex[2:]
        
        # Convert hex color to rgba for glow effect
        try:
            r = int(color_hex[0:2], 16)
            g = int(color_hex[2:4], 16)
            b = int(color_hex[4:6], 16)
            glow_p = f"rgba({r}, {g}, {b}, 0.15)"
        except Exception:
            glow_p = "rgba(6, 182, 212, 0.15)"

        # Inline Helper to extract new metadata fields
        def extract_field(field_name):
            match = re.search(field_name + r":\s*['\"]([^'\"]*)['\"]", comp_str)
            if not match:
                match = re.search(field_name + r":\s*'([^'\\]*(?:\\.[^'\\]*)*)'", comp_str)
            return match.group(1).replace(r"\'", "'").replace(r'\"', '"').strip() if match else ""

        # Extract gender classification
        gender_m = re.search(r"gender:\s*CompanionGender\.([a-zA-Z]+)", comp_str)
        gender_val = gender_m.group(1).strip() if gender_m else "male"

        companions.append({
            "id": id_val,
            "name": name_val,
            "archetype": arch_val,
            "personality": pers_val,
            "greeting": greet_val,
            "color_hex": color_hex,
            "glow_p": glow_p,
            "gender": gender_val,
            "sleepingHours": extract_field("sleepingHours"),
            "favoriteDrink": extract_field("favoriteDrink"),
            "favoriteSongs": extract_field("favoriteSongs"),
            "favoriteBooks": extract_field("favoriteBooks"),
            "birthday": extract_field("birthday"),
            "petPeeves": extract_field("petPeeves"),
            "loveLanguage": extract_field("loveLanguage"),
            "randomHabits": extract_field("randomHabits"),
            "favoriteFood": extract_field("favoriteFood"),
            "comfortItem": extract_field("comfortItem"),
            "personalGoals": extract_field("personalGoals"),
            "hiddenFear": extract_field("hiddenFear"),
        })
    else:
        print(f"Skipping index {idx} due to missing vital matches.")

print(f"Successfully parsed {len(companions)} companions.")

# HTML Page Template (Netflix Cinematic Profile Layout)
template = """<!DOCTYPE html>
<html lang="en">
<head>
  <!-- Google tag (gtag.js) -->
  <script async src="https://www.googletagmanager.com/gtag/js?id=G-QPWDDPMBVV"></script>
  <script>
    window.dataLayer = window.dataLayer || [];
    function gtag(){{dataLayer.push(arguments);}}
    gtag('js', new Date());
    gtag('config', 'G-QPWDDPMBVV');
  </script>
  <script>
    if (window.location.protocol === 'http:' && window.location.hostname !== 'localhost' && !window.location.hostname.startsWith('127.')) {{
      window.location.href = window.location.href.replace('http:', 'https:');
    }}
  </script>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{name} - {archetype} AI Chat | Chatrix</title>
  <meta name="description" content="Connect with {name}, the {archetype} AI companion. Persistent memory, deep emotional support, and unfiltered roleplay chat.">
  <meta name="keywords" content="{name}, {archetype} AI, character ai alternative, unfiltered AI chat, emotional support AI, replika alternative, janitor ai alternative, c.ai alternative, c.ai no filter">
  <meta name="author" content="Chatrix AI">
  <meta name="robots" content="index, follow">
  <link rel="canonical" href="https://chatrix.space/companion/{slug}">
  <link rel="icon" type="image/png" href="../../favicon.png"/>

  <!-- Open Graph -->
  <meta property="og:type" content="website">
  <meta property="og:url" content="https://chatrix.space/companion/{slug}">
  <meta property="og:title" content="{name} - {archetype} AI Chat | Chatrix">
  <meta property="og:description" content="Connect with {name}, the {archetype} AI companion. Persistent memory, deep emotional support, and unfiltered roleplay chat.">
  <meta property="og:image" content="https://chatrix.space/icons/Icon-512.png">
  <meta property="og:site_name" content="Chatrix AI">

  <!-- Twitter -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="{name} - {archetype} AI Chat | Chatrix">
  <meta name="twitter:description" content="Connect with {name} on Chatrix. Unfiltered, real memory, deep connection.">
  <meta name="twitter:image" content="https://chatrix.space/icons/Icon-512.png">

  <!-- Breadcrumb & FAQ JSON-LD -->
  <script type="application/ld+json">
  {{
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    "itemListElement": [{{
      "@type": "ListItem",
      "position": 1,
      "name": "Home",
      "item": "https://chatrix.space/"
    }},{{
      "@type": "ListItem",
      "position": 2,
      "name": "Companions",
      "item": "https://chatrix.space/explore"
    }},{{
      "@type": "ListItem",
      "position": 3,
      "name": "{name}",
      "item": "https://chatrix.space/companion/{slug}"
    }}]
  }}
  </script>

  <script type="application/ld+json">
  {{
    "@context": "https://schema.org",
    "@type": "FAQPage",
    "mainEntity": [{{
      "@type": "Question",
      "name": "Who is {name}?",
      "acceptedAnswer": {{
        "@type": "Answer",
        "text": "{name} is a {archetype} character on Chatrix. {personality_clean}"
      }}
    }},{{
      "@type": "Question",
      "name": "How does the memory feature work with {name}?",
      "acceptedAnswer": {{
        "@type": "Answer",
        "text": "Chatrix features real, persistent memory. {name} remembers details from your previous conversations, building a continuous and deep relationship over time."
      }}
    }}]
  }}
  </script>

  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;600;700;800;900&family=Inter:wght@300;400;500;600;700&family=Playfair+Display:ital,wght@1,500;1,600&family=Caveat:wght@500;600&display=swap" rel="stylesheet">

  <style>
    :root {{ 
      --bg:#070709; 
      --surface:rgba(255,255,255,0.025); 
      --border:rgba(255,255,255,0.07); 
      --text-1:#f8fafc; 
      --text-2:#94a3b8; 
      --text-3:#64748b; 
      --theme-color:#{color_hex};
      --glow-p:{glow_p}; 
      --glow-c:rgba(6,182,212,0.1); 
    }}
    *,*::before,*::after {{ box-sizing:border-box; margin:0; padding:0; }}
    body {{ background:var(--bg); color:var(--text-1); font-family:'Inter',sans-serif; line-height:1.7; overflow-x:hidden; }}
    h1,h2,h3,.logo {{ font-family:'Outfit',sans-serif; font-weight:800; letter-spacing:-0.02em; }}
    .orb {{ position:fixed; border-radius:50%; pointer-events:none; filter:blur(90px); z-index:-1; }}
    .orb-1 {{ width:55vw; height:55vw; top:-15%; right:-15%; background:radial-gradient(circle,var(--glow-p) 0%,transparent 70%); }}
    .orb-2 {{ width:45vw; height:45vw; bottom:-15%; left:-10%; background:radial-gradient(circle,var(--glow-c) 0%,transparent 70%); }}
    .grid-bg {{ position:fixed; inset:0; background-image:linear-gradient(rgba(255,255,255,0.003) 1px,transparent 1px),linear-gradient(90deg,rgba(255,255,255,0.003) 1px,transparent 1px); background-size:44px 44px; z-index:-2; }}
    
    header {{ position:sticky; top:0; z-index:100; border-bottom:1px solid var(--border); backdrop-filter:blur(16px); background:rgba(7,7,9,0.75); padding:1.25rem 2rem; }}
    .header-inner {{ max-width:1100px; margin:0 auto; display:flex; justify-content:space-between; align-items:center; }}
    .logo-link {{ display:flex; align-items:center; gap:0.75rem; text-decoration:none; }}
    .logo-img {{ width:30px; height:30px; border-radius:8px; }}
    .logo {{ font-size:1.45rem; background:linear-gradient(135deg,#fff 30%,var(--theme-color)); -webkit-background-clip:text; background-clip:text; -webkit-text-fill-color:transparent; }}
    
    .open-btn {{ background:linear-gradient(135deg,rgba(255,255,255,0.1),var(--theme-color)); border:none; border-radius:30px; color:#070709; padding:0.65rem 1.5rem; font-family:'Outfit',sans-serif; font-weight:700; font-size:0.9rem; cursor:pointer; text-decoration:none; transition:all 0.3s; box-shadow:0 4px 16px {glow_p}; }}
    .open-btn:hover {{ transform:translateY(-2px); box-shadow:0 6px 24px {glow_p}; }}
    
    /* Cinematic Poster Layout */
    .profile-container {{ max-width:850px; margin:2rem auto; padding:0 1.5rem; }}
    
    .poster-hero {{ position:relative; width:100%; border-radius:24px; overflow:hidden; border:1px solid var(--border); background:#0c0d12; margin-bottom:2.5rem; box-shadow:0 20px 40px rgba(0,0,0,0.6); aspect-ratio:1.6; }}
    .poster-img {{ width:100%; height:100%; object-fit:cover; }}
    .poster-overlay {{ position:absolute; inset:0; background:linear-gradient(to top, rgba(7,7,9,1) 0%, rgba(7,7,9,0.4) 65%, transparent 100%); display:flex; flex-direction:column; justify-content:end; padding:2.5rem; }}
    
    .poster-meta {{ display:flex; align-items:center; gap:0.75rem; margin-bottom:0.75rem; }}
    .badge-arch {{ background:rgba(255,255,255,0.06); border:1px solid var(--border); border-radius:30px; padding:0.3rem 0.85rem; font-size:0.75rem; font-weight:700; color:var(--theme-color); text-transform:uppercase; letter-spacing:0.06em; }}
    .badge-gender {{ color:var(--text-3); font-size:0.78rem; font-weight:600; letter-spacing:0.04em; }}
    
    .poster-hero h1 {{ font-size:clamp(2rem, 5vw, 3rem); line-height:1.15; color:#fff; text-shadow:0 2px 10px rgba(0,0,0,0.5); }}
    
    .voice-sample-btn {{ position:absolute; bottom:2rem; right:2rem; width:52px; height:52px; border-radius:50%; background:rgba(255,255,255,0.08); border:1.5px solid var(--theme-color); color:#fff; display:flex; align-items:center; justify-content:center; cursor:pointer; transition:all 0.3s; backdrop-filter:blur(8px); box-shadow:0 4px 12px rgba(0,0,0,0.3); }}
    .voice-sample-btn:hover {{ transform:scale(1.08); background:var(--theme-color); color:#070709; box-shadow:0 6px 18px {glow_p}; }}
    .voice-sample-btn svg {{ width:22px; height:22px; }}

    /* Relationship Chapter Card */
    .rel-card {{ background:rgba(255,255,255,0.015); border:1px solid var(--border); border-radius:20px; padding:1.5rem; margin-bottom:2.5rem; display:flex; flex-direction:column; gap:1rem; }}
    .rel-header {{ display:flex; justify-content:space-between; align-items:center; }}
    .rel-title {{ display:flex; align-items:center; gap:0.6rem; font-size:0.8rem; font-weight:700; color:var(--text-3); letter-spacing:0.12em; }}
    .rel-status {{ font-size:1.1rem; font-weight:700; color:#fff; margin-top:0.25rem; font-family:'Outfit',sans-serif; }}
    .rel-percent {{ color:var(--theme-color); font-weight:800; font-size:0.95rem; }}
    .progress-bar-bg {{ height:6px; background:rgba(255,255,255,0.04); border-radius:3px; overflow:hidden; width:100%; }}
    .progress-bar-fill {{ height:100%; background:linear-gradient(to right, rgba(255,255,255,0.1), var(--theme-color)); border-radius:3px; width:10%; }}
    .rel-footer {{ font-size:0.85rem; color:var(--text-3); font-style:italic; }}

    /* Signature Quote Card */
    .quote-card {{ background:rgba(255,255,255,0.01); border:1px solid var(--border); border-radius:20px; padding:1.75rem; margin-bottom:2.5rem; }}
    .quote-title {{ display:flex; align-items:center; gap:0.5rem; font-size:0.8rem; font-weight:700; color:var(--text-3); letter-spacing:0.12em; margin-bottom:1rem; }}
    .quote-text {{ font-family:'Playfair Display', Georgia, serif; font-size:1.25rem; font-style:italic; color:rgba(255,255,255,0.85); line-height:1.45; position:relative; }}

    /* Metadata details grid */
    .meta-grid-title {{ font-size:0.8rem; font-weight:700; color:var(--text-3); letter-spacing:0.12em; margin-bottom:1rem; text-transform:uppercase; }}
    .meta-grid {{ display:grid; grid-template-columns:repeat(auto-fit, minmax(180px, 1fr)); gap:12px; margin-bottom:2.5rem; }}
    .meta-tile {{ background:rgba(255,255,255,0.012); border:1px solid var(--border); border-radius:16px; padding:0.85rem 1.15rem; display:flex; align-items:center; gap:14px; }}
    .meta-emoji {{ font-size:1.35rem; }}
    .meta-info {{ display:flex; flex-direction:column; justify-content:center; }}
    .meta-label {{ font-size:0.75rem; font-weight:800; color:var(--text-3); letter-spacing:0.04em; }}
    .meta-value {{ font-size:0.95rem; font-weight:600; color:var(--text-2); margin-top:1px; }}

    /* Story & Biography */
    .story-section {{ margin-bottom:2.5rem; }}
    .story-title {{ font-size:0.8rem; font-weight:700; color:var(--text-3); letter-spacing:0.12em; margin-bottom:1rem; text-transform:uppercase; }}
    .story-text {{ color:var(--text-2); font-size:1rem; line-height:1.65; }}

    /* Memory Logs Empty state */
    .memories-card {{ background:rgba(255,255,255,0.015); border:1px solid var(--border); border-radius:20px; padding:2rem; text-align:center; margin-bottom:3rem; }}
    .memories-title {{ font-size:0.8rem; font-weight:700; color:var(--text-3); letter-spacing:0.12em; margin-bottom:1.25rem; text-transform:uppercase; text-align:left; }}
    .memories-empty {{ color:var(--text-3); font-family:'Caveat', cursive, sans-serif; font-size:1.6rem; font-weight:500; margin-top:0.5rem; }}
    
    /* Glowing Large CTA Button */
    .cta-container {{ display:flex; justify-content:center; margin:3rem 0; }}
    .cta-glow-btn {{ display:inline-flex; align-items:center; gap:0.75rem; background:var(--theme-color); border:none; border-radius:18px; color:#070709; padding:1.15rem 3.5rem; font-family:'Outfit',sans-serif; font-weight:800; font-size:1.15rem; cursor:pointer; text-decoration:none; transition:all 0.3s; box-shadow:0 8px 32px var(--glow-p); animation:pulseGlow 2.5s infinite alternate; }}
    .cta-glow-btn:hover {{ transform:translateY(-3px) scale(1.02); box-shadow:0 12px 42px var(--glow-p); }}
    @keyframes pulseGlow {{
      0% {{ transform: scale(1); }}
      100% {{ transform: scale(1.025); }}
    }}

    .other-title {{ font-size:1.2rem; color:#fff; margin:3rem 0 1rem; border-left:3.5px solid var(--theme-color); padding-left:1rem; font-family:'Outfit',sans-serif; }}
    .other-companions {{ display:grid; grid-template-columns:repeat(auto-fit, minmax(180px, 1fr)); gap:1rem; margin-top:1.5rem; }}
    .comp-link-card {{ background:var(--surface); border:1px solid var(--border); border-radius:16px; padding:1.25rem; text-align:center; text-decoration:none; color:var(--text-1); transition:all 0.3s; }}
    .comp-link-card:hover {{ border-color:var(--theme-color); transform:translateY(-2px); }}
    
    footer {{ border-top:1px solid var(--border); padding:3rem 1.5rem; text-align:center; color:var(--text-3); font-size:0.88rem; margin-top:4rem; }}
    .footer-links {{ display:flex; justify-content:center; gap:1.5rem; flex-wrap:wrap; margin-bottom:1.25rem; }}
    .footer-links a {{ color:var(--theme-color); text-decoration:none; transition:color 0.2s; font-size:0.9rem; }}
    .footer-links a:hover {{ color:#fff; }}
    @media(max-width:600px){{.poster-hero{{aspect-ratio:1.2;}}.rel-card, .quote-card, .memories-card{{padding:1.2rem;}}.meta-grid{{grid-template-columns:1fr;}}}}
  </style>
</head>
<body>
  <div class="grid-bg"></div>
  <div class="orb orb-1"></div>
  <div class="orb orb-2"></div>

  <header>
    <div class="header-inner">
      <a href="../../" class="logo-link">
        <img src="../../favicon.png" alt="Chatrix Logo" class="logo-img" onerror="this.style.display='none'">
        <span class="logo">Chatrix</span>
      </a>
      <a href="../../?companion={id}" class="open-btn">Chat with {name}</a>
    </div>
  </header>

  <div class="profile-container">
    <!-- 1. Cinematic Poster Hero Header -->
    <div class="poster-hero">
      <img src="{image_src}" alt="{name}" class="poster-img" onerror="this.style.display='none'">
      <div class="poster-overlay">
        <div class="poster-meta">
          <span class="badge-arch">{archetype}</span>
          <span class="badge-gender">✦ {gender}</span>
        </div>
        <h1>{name}</h1>
      </div>
      
      <!-- Voice Preview Trigger -->
      <button class="voice-sample-btn" id="voice-btn" title="Listen to Voice Preview" onclick="playVoicePreview()">
        <svg viewBox="0 0 24 24" fill="currentColor">
          <path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/>
        </svg>
      </button>
    </div>

    <!-- JavaScript Voice preview controller -->
    <script>
      var audioPlaying = false;
      function playVoicePreview() {{
        var btn = document.getElementById('voice-btn');
        if (audioPlaying) {{
          window.speechSynthesis.cancel();
          btn.innerHTML = `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/></svg>`;
          audioPlaying = false;
        }} else {{
          audioPlaying = true;
          btn.innerHTML = `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z"/></svg>`;
          var utterance = new SpeechSynthesisUtterance("{greeting_clean}");
          utterance.onend = function() {{
            btn.innerHTML = `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/></svg>`;
            audioPlaying = false;
          }};
          utterance.onerror = function() {{
            btn.innerHTML = `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/></svg>`;
            audioPlaying = false;
          }};
          window.speechSynthesis.speak(utterance);
        }}
      }}
    </script>

    <!-- 2. Relationship Chapter progress card -->
    <div class="rel-card">
      <div class="rel-header">
        <div>
          <span class="rel-title">🌱 RELATIONSHIP STATUS</span>
          <div class="rel-status">Strangers</div>
        </div>
        <div class="rel-percent">Trust 10%</div>
      </div>
      <div class="progress-bar-bg">
        <div class="progress-bar-fill"></div>
      </div>
      <div class="rel-footer">First Connection. Standard chats unlocked.</div>
    </div>

    <!-- 3. Quotes Card -->
    <div class="quote-card">
      <div class="quote-title">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" style="opacity:0.4"><path d="M6 17h3l2-4V7H5v6h3zm8 0h3l2-4V7h-6v6h3z"/></svg>
        SIGNATURE QUOTE
      </div>
      <div class="quote-text">
        "{greeting}"
      </div>
    </div>

    <!-- 4. Story Overview -->
    <div class="story-section">
      <div class="story-title">OVERVIEW & PERSONALITY</div>
      <p class="story-text">
        {name} is designed with a realistic character profile and persistent context memory. {personality_clean}
      </p>
    </div>

    <!-- 5. Dynamic Metadata Grid -->
    <div class="meta-grid-title">CORE METADATA</div>
    <div class="meta-grid">
      {metadata_tiles}
    </div>

    <!-- 6. Memory empty state -->
    <div class="memories-card">
      <div class="memories-title">MEMORIZED REFLECTIONS</div>
      <div class="memories-empty">
        Every relationship begins with one conversation.
      </div>
    </div>

    <!-- Glowing Start Chat CTA -->
    <div class="cta-container">
      <a href="../../?companion={id}" class="cta-glow-btn">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor"><path d="M20 2H4c-1.1 0-1.99.9-1.99 2L2 22l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zM6 9h12v2H6V9zm8 5H6v-2h8v2zm4-6H6V6h12v2z"/></svg>
        START CONVERSATION
      </a>
    </div>

    <!-- Other recommended companions -->
    <h3 class="other-title">Other Companions You Might Like</h3>
    <div class="other-companions">
      <a href="../vampire-prince" class="comp-link-card">
        <h4 style="color:#D91636">Alistair Thorne</h4>
        <p style="font-size:0.8rem;color:var(--text-2);margin-top:0.4rem">View Profile</p>
      </a>
      <a href="../billionaire-ceo" class="comp-link-card">
        <h4 style="color:#1E90FF">Kaelen Vance</h4>
        <p style="font-size:0.8rem;color:var(--text-2);margin-top:0.4rem">View Profile</p>
      </a>
      <a href="../goth-girlfriend" class="comp-link-card">
        <h4 style="color:#800080">Evie Thorne</h4>
        <p style="font-size:0.8rem;color:var(--text-2);margin-top:0.4rem">View Profile</p>
      </a>
    </div>
  </div>

  <footer>
    <div class="footer-links">
      <a href="../../home">Home</a>
      <a href="../../chats">Chats</a>
      <a href="../../explore">Explore</a>
      <a href="../../premium">Premium</a>
      <a href="../shy-librarian">Arthur Pendelton</a>
      <a href="../vampire-prince">Alistair Thorne</a>
      <a href="../billionaire-ceo">Kaelen Vance</a>
    </div>
    <p style="margin-top:1.5rem">&copy; 2026 Chatrix AI — Unfiltered Emotional AI Companions. All rights reserved.</p>
  </footer>
</body>
</html>"""

# Generate pages with templates
new_folders_count = 0
for comp in companions:
    name = comp["name"]
    slug = slug_map.get(name)
    if not slug:
        slug = re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')
        
    folder_path = os.path.join(web_companion_dir, slug)
    file_path = os.path.join(folder_path, "index.html")
    
    os.makedirs(folder_path, exist_ok=True)
    
    # Clean up personality for the FAQ description
    pers_clean = comp["personality"]
    pers_clean = re.sub(r'^You are [^.]*\.\s*', '', pers_clean)
    pers_clean = re.sub(r'Flirting style:.*$', '', pers_clean)
    pers_clean = re.sub(r'Sensual pacing:.*$', '', pers_clean)
    pers_clean = pers_clean.replace("Hinglish", "a mix of Hindi and English")
    pers_clean = pers_clean.strip()
    if not pers_clean.endswith("."):
        pers_clean += "."

    # Clean greeting of asterisk action narratives for web TTS playback
    greet_clean = re.sub(r'\*.*?\*', '', comp["greeting"]).replace('"', '\\"').replace("'", "\\'").strip()
    
    # Build image asset path
    parts = name.split(' ')
    clean_name = parts[0]
    if clean_name.lower() in ['dr.', 'professor'] and len(parts) > 1:
        clean_name = parts[1]
    clean_name = clean_name.replace("'", "").replace('"', '')
    image_src = f"../../assets/images/{clean_name}.png"

    # Dynamic metadata grid html builder
    def add_tile(emoji, label, val):
        if val:
            return f"""
      <div class="meta-tile">
        <span class="meta-emoji">{emoji}</span>
        <div class="meta-info">
          <span class="meta-label">{label.upper()}</span>
          <span class="meta-value">{val}</span>
        </div>
      </div>"""
        return ""
    
    m_html = ""
    m_html += add_tile("🍵", "Favorite Drink", comp["favoriteDrink"])
    m_html += add_tile("💤", "Sleeping Hours", comp["sleepingHours"])
    m_html += add_tile("❤️", "Love Language", comp["loveLanguage"])
    m_html += add_tile("🧸", "Comfort Item", comp["comfortItem"])
    m_html += add_tile("🥐", "Favorite Food", comp["favoriteFood"])
    m_html += add_tile("📚", "Favorite Books", comp["favoriteBooks"])
    m_html += add_tile("🚫", "Pet Peeves", comp["petPeeves"])
    m_html += add_tile("🎂", "Birthday", comp["birthday"])

    html_content = template.format(
        name=name,
        archetype=comp["archetype"],
        slug=slug,
        id=comp["id"],
        greeting=comp["greeting"],
        greeting_clean=greet_clean,
        personality_clean=pers_clean,
        color_hex=comp["color_hex"],
        glow_p=comp["glow_p"],
        image_src=image_src,
        gender=comp["gender"].upper(),
        metadata_tiles=m_html
    )
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(html_content)
    print(f"Generated page: {slug} (ID: {comp['id']})")
    new_folders_count += 1

print(f"Completed! Generated {new_folders_count} new companion landing pages.")
