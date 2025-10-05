#!/bin/bash
export LANG=C.UTF-8

CHANNEL_NAME="${CHANNEL_NAME:-your_twitch_channel_here}"
MAX_CLIPS="${MAX_CLIPS:-10}"
DOWNLOAD_DIR="/app/downloaded_clips"
HTML_FILE="/app/generated_index.html"
JSON_FILE="/app/clips.json"
INDEX_FILE="/app/downloaded_clips/downloaded_clips_index.html"


mkdir -p "$DOWNLOAD_DIR"

if [[ "$1" == "delayed" ]]; then
  echo "Delaying 1 hour before downloading..." >> "$DOWNLOAD_DIR/main.log"
  sleep 3600
fi


#echo "
#<html>
#<head>
#<title>Clips</title>
#<meta charset="UTF-8">
#</head>
#<body>
#<h1>Downloaded Clips</h1>
#<ul>" > "$INDEX_FILE"
#
#for f in "$DOWNLOAD_DIR"/*.mp4; do
#  size=$(du -h "$f" | cut -f1)
#  datetime=$(date -r "$f" "+%Y-%m-%d %H:%M:%S")
#  filename=$(basename "$f")
#  echo "<li><a href=\"$filename\">$filename</a> - $size - $datetime</li>" >> "$INDEX_FILE"
#done
#
#echo "</ul>
#</body>
#</html>" >> "$INDEX_FILE"


# Download top clips
echo "Downloading top $MAX_CLIPS clips for $CHANNEL_NAME..."
twitch-dl clips "$CHANNEL_NAME" --download --limit "$MAX_CLIPS" --target-dir "$DOWNLOAD_DIR" --period last_week

# Generate JSON list of clips
echo "Generating clips.json..."
echo "[" > "$JSON_FILE"
first=true
for clip in "$DOWNLOAD_DIR"/*.mp4; do
  filename=$(basename "$clip")
  if [ "$first" = true ]; then
    first=false
  else
    echo "," >> "$JSON_FILE"
  fi
  echo "  \"downloaded_clips/$filename\"" >> "$JSON_FILE"
done
echo "]" >> "$JSON_FILE"

# Generate dynamic HTML index of all clips based on JSON
echo "Regenerating downloaded_clips_index.html..."
cat <<EOF > "$INDEX_FILE"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Downloaded Twitch Clips</title>
<meta http-equiv="refresh" content="600"> <!-- Auto-refresh every 10 min -->
<style>
  body {
    font-family: 'Segoe UI', Tahoma, sans-serif;
    background: #0e0e10;
    color: #efeff1;
    margin: 40px;
  }
  h1 { color: #4CAF50; }
  input[type="text"] {
    width: 100%;
    padding: 10px;
    margin-bottom: 20px;
    border: none;
    border-radius: 6px;
    background: #1f1f23;
    color: #fff;
    font-size: 1em;
  }
  ul { list-style-type: none; padding: 0; }
  li {
    margin: 10px 0;
    background: #1f1f23;
    padding: 10px;
    border-radius: 8px;
    transition: background 0.2s;
    display: flex;
    align-items: center;
  }
  li:hover {
    background: #27272b;
  }
  a {
    color: #00b0ff;
    text-decoration: none;
    font-weight: bold;
  }
  a:hover { text-decoration: underline; }
  .info {
    font-size: 0.9em;
    color: #aaa;
    margin-left: auto;
    text-align: right;
  }
  video.preview {
    display: none;
    position: fixed;
    width: 300px;
    height: auto;
    border: 2px solid #4CAF50;
    border-radius: 8px;
    z-index: 1000;
    pointer-events: none;
  }
</style>
</head>
<body>
<h1>Downloaded Twitch Clips</h1>
<input type="text" id="searchBox" placeholder="Search clips by name...">
<ul id="clipsList"><li>Loading clips...</li></ul>

<video id="preview" class="preview" muted></video>

<script>
async function loadClips() {
  try {
    const response = await fetch("/clips.json?v=" + Date.now()); // cache-busting
    const clips = await response.json();
    const list = document.getElementById("clipsList");
    const preview = document.getElementById("preview");
    list.innerHTML = "";

    const clipMeta = await Promise.all(
      clips.map(async clip => {
        const name = clip.split("/").pop();
        const url = "../" + clip;

        const head = await fetch(url, { method: "HEAD" });
        const size = head.headers.get("Content-Length");
        const lastMod = head.headers.get("Last-Modified");
        const readableSize = size ? (size / 1024 / 1024).toFixed(2) + " MB" : "Unknown";
        const dateStr = lastMod ? new Date(lastMod).toLocaleString() : "Unknown";

        return { name, url, readableSize, dateStr, lastMod: new Date(lastMod).getTime() || 0 };
      })
    );

    // Sort by most recent modified date (newest first)
    clipMeta.sort((a, b) => b.lastMod - a.lastMod);

    for (const clip of clipMeta) {
      const li = document.createElement("li");
      li.innerHTML = \`<a href="\${clip.url}" target="_blank">\${clip.name}</a>
        <span class="info">\${clip.readableSize} | \${clip.dateStr}</span>\`;

      // Hover video preview
      li.addEventListener("mouseenter", e => {
        preview.src = clip.url;
        preview.style.display = "block";
        preview.style.top = (e.pageY + 10) + "px";
        preview.style.left = (e.pageX + 10) + "px";
        preview.play();
      });
      li.addEventListener("mousemove", e => {
        preview.style.top = (e.pageY + 10) + "px";
        preview.style.left = (e.pageX + 10) + "px";
      });
      li.addEventListener("mouseleave", () => {
        preview.pause();
        preview.src = "";
        preview.style.display = "none";
      });

      list.appendChild(li);
    }

    if (clipMeta.length === 0) {
      list.innerHTML = "<li>No clips available.</li>";
    }

    // Search/filter functionality
    const searchBox = document.getElementById("searchBox");
    searchBox.addEventListener("input", () => {
      const query = searchBox.value.toLowerCase();
      for (const li of list.children) {
        const text = li.textContent.toLowerCase();
        li.style.display = text.includes(query) ? "flex" : "none";
      }
    });
  } catch (err) {
    console.error("Error loading clips.json:", err);
    document.getElementById("clipsList").innerHTML =
      "<li>Failed to load clip list.</li>";
  }
}

loadClips();
</script>

</body>
</html>
EOF


# Only generate HTML if it doesn't already exist
if [ ! -f "$HTML_FILE" ]; then
  echo "Generating HTML player..."
  cat <<EOF > "$HTML_FILE"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<title>Romans Twitch Clips - Random Player</title>
<link rel="icon" type="image/png" sizes="16x16" href="./favicon_io/favicon-16.png?v=$(date +%s)">
<link rel="icon" type="image/png" sizes="32x32" href="./favicon_io/favicon-32.png?v=$(date +%s)">
<link rel="icon" type="image/png" sizes="128x128" href="./favicon_io/favicon-128.png?v=$(date +%s)">
<link rel="icon" type="image/png" sizes="48x48" href="./favicon_io/favicon-192.png?v=$(date +%s)">
<link rel="icon" type="image/png" sizes="64x64" href="./favicon_io/favicon-512.png?v=$(date +%s)">
<link rel="icon" type="image/x-icon" href="./favicon_io/favicon.ico?v=$(date +%s)">

<meta http-equiv="refresh" content="1800"> <!-- Auto-refresh every 30 min -->
<style>
  body, html { margin:0; padding:0; background:#000; }
  video { width: 100%; height: auto; }
</style>
</head>
<body>
<video id="clipPlayer" controls autoplay></video>

<script>
  async function loadClips() {
    try {
      const response = await fetch("clips.json?v=" + Date.now()); // bust cache
      const clips = await response.json();
      const player = document.getElementById('clipPlayer');

      function playRandomClip() {
        if (clips.length === 0) return;
        const randomIndex = Math.floor(Math.random() * clips.length);
        player.src = clips[randomIndex];
        player.play();
      }

      player.addEventListener('ended', playRandomClip);
      playRandomClip();
    } catch (err) {
      console.error("Error loading clips.json:", err);
    }
  }

  loadClips();
</script>
</body>
</html>
EOF
fi
