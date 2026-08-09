#!/bin/bash
set -e

# Run flutter build
flutter build web --release

# Inject the loading screen into index.html
HTML_FILE="build/web/index.html"

# Loading screen CSS and JS
LOADING_SCREEN="
<style>
  #loading-screen {
    position: fixed;
    top: 0; left: 0; width: 100%; height: 100%;
    background-color: #05050A;
    display: flex; justify-content: center; align-items: center;
    z-index: 9999;
    color: white; font-family: sans-serif;
    transition: opacity 0.5s ease-out;
  }
  .slide {
    position: absolute; opacity: 0; transition: opacity 0.5s ease-in-out;
    text-align: center;
  }
  .slide.active { opacity: 1; }
  .bolt { color: #F59E0B; font-size: 48px; margin-bottom: 20px; }
</style>
<div id=\"loading-screen\">
  <div class=\"slide active\">
    <div class=\"bolt\">⚡</div>
    <h2>inFlow</h2>
    <p>Initializing Stellar Engine...</p>
  </div>
  <div class=\"slide\">
    <div class=\"bolt\">⚡</div>
    <h2>Your salary. Per second.</h2>
    <p>Connecting to Soroban...</p>
  </div>
  <div class=\"slide\">
    <div class=\"bolt\">⚡</div>
    <h2>Almost ready...</h2>
    <p>Africa's first salary streaming protocol</p>
  </div>
</div>
<script>
  let slideIndex = 0;
  const slides = document.querySelectorAll('.slide');
  const slideInterval = setInterval(() => {
    slides[slideIndex].classList.remove('active');
    slideIndex = (slideIndex + 1) % slides.length;
    slides[slideIndex].classList.add('active');
  }, 2000);

  window.addEventListener('flutter-first-frame', function() {
    clearInterval(slideInterval);
    const ls = document.getElementById('loading-screen');
    ls.style.opacity = '0';
    setTimeout(() => ls.remove(), 500);
  });
</script>
"

# Insert the loading screen just after <body>
python3 -c '
import os
html_file = "build/web/index.html"
loading_screen = """'"$LOADING_SCREEN"'"""
if os.path.exists(html_file):
    with open(html_file, "r") as f:
        content = f.read()
    
    # Locate body tag (case insensitive or handling attributes)
    import re
    match = re.search(r"<body[^>]*>", content)
    if match:
        idx = match.end()
        new_content = content[:idx] + "\n" + loading_screen + content[idx:]
        with open(html_file, "w") as f:
            f.write(new_content)
        print("Injected loading screen successfully!")
    else:
        print("Warning: <body> tag not found in index.html")
else:
    print("Error: index.html not found")
'

echo "Build complete and loading screen injected!"
