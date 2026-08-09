#!/bin/bash
# build_web.sh - Build flutter web and inject premium loading screen

# Ensure we're in the correct directory
cd "$(dirname "$0")" || exit 1

echo "Fetching dependencies..."
flutter pub get

echo "Building Flutter Web..."
flutter build web --release

echo "Injecting premium loading screen into index.html..."
INDEX_HTML="build/web/index.html"

# Premium loading screen HTML, CSS & JS
LOADING_SCREEN='
<style>
  body, html { margin: 0; padding: 0; width: 100%; height: 100%; background: #0A0A0F; color: white; font-family: "Syne", sans-serif; overflow: hidden; }
  #loader-container { position: fixed; top: 0; left: 0; width: 100%; height: 100%; z-index: 9999; display: flex; flex-direction: column; justify-content: center; align-items: center; background: radial-gradient(circle at center, #13131A, #0A0A0F); transition: opacity 0.8s ease; }
  .slide { display: none; text-align: center; animation: fadeSlide 1s ease forwards; }
  .slide.active { display: block; }
  .spinner { width: 60px; height: 60px; border: 4px solid rgba(20, 241, 149, 0.2); border-top-color: #14F195; border-radius: 50%; animation: spin 1s linear infinite; margin: 0 auto 30px; }
  h2 { margin: 0; font-size: 28px; background: -webkit-linear-gradient(#14F195, #9945FF); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
  p { color: #8B8B99; font-size: 16px; margin-top: 10px; max-width: 400px; }
  @keyframes spin { to { transform: rotate(360deg); } }
  @keyframes fadeSlide { from { opacity: 0; transform: translateY(20px); } to { opacity: 1; transform: translateY(0); } }
</style>
<div id="loader-container">
  <div class="spinner"></div>
  <div class="slide active" id="slide1">
    <h2>Welcome to inFlow Stellar</h2>
    <p>Loading the future of real-time payroll...</p>
  </div>
  <div class="slide" id="slide2">
    <h2>Lightning Fast</h2>
    <p>Powered by Soroban smart contracts on the Stellar network.</p>
  </div>
  <div class="slide" id="slide3">
    <h2>Almost there...</h2>
    <p>Initializing zero-fee streaming engine.</p>
  </div>
</div>
<script>
  let slideIndex = 1;
  setInterval(() => {
    document.getElementById("slide" + slideIndex).classList.remove("active");
    slideIndex = slideIndex < 3 ? slideIndex + 1 : 1;
    document.getElementById("slide" + slideIndex).classList.add("active");
  }, 2500);
  
  window.addEventListener("load", function() {
    // Hide loader once Flutter engine has initialized
    setTimeout(() => {
      let loader = document.getElementById("loader-container");
      if (loader) {
        loader.style.opacity = "0";
        setTimeout(() => loader.remove(), 800);
      }
    }, 8000); // Wait for flutter engine (can be hooked into flutter init)
  });
</script>
'

# Inject just after <body>
sed -i -e '/<body[^>]*>/a \'"$LOADING_SCREEN"'' "$INDEX_HTML"

echo "Build and injection complete!"
