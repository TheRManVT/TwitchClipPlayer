#!/bin/bash
export LANG=C.UTF-8

CHANNEL_NAME="${CHANNEL_NAME:-your_twitch_channel_here}"
MAX_CLIPS="${MAX_CLIPS:-10}"
DOWNLOAD_DIR="/public/downloaded_clips"
JSON_FILE="/public/clips.json"
HTML_FILE="/public/generated_index.html"
INDEX_FILE="/public/downloaded_clips/downloaded_clips_index.html"

mkdir -p "$DOWNLOAD_DIR"

LOG_FILE="$DOWNLOAD_DIR/main.log"

exec > >(while IFS= read -r line; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $line"
done | tee -a "$LOG_FILE") 2>&1

log() {
    echo "$*"
}

log "===== Script started ====="

if [[ "$1" == "delayed" ]]; then
  log "Delaying 1 hour before downloading..."
  sleep 3600
fi

# Download top clips (try twitch-dl first, fall back to Helix API + yt-dlp)
log "Downloading top $MAX_CLIPS clips for $CHANNEL_NAME..."

TWITCH_DL_FAILED=false

#twitch-dl clips "$CHANNEL_NAME" --download --limit "$MAX_CLIPS" --target-dir "$DOWNLOAD_DIR" --period last_week 2>&1 | grep -q "GraphQL query failed" && TWITCH_DL_FAILED=true
TWITCH_OUTPUT=$(twitch-dl clips "$CHANNEL_NAME" \
  --download \
  --limit "$MAX_CLIPS" \
  --target-dir "$DOWNLOAD_DIR" \
  --period last_week 2>&1)

echo "$TWITCH_OUTPUT"

if echo "$TWITCH_OUTPUT" | grep -q "GraphQL query failed"; then
    TWITCH_DL_FAILED=true
fi

if [ "$TWITCH_DL_FAILED" = true ]; then
  log "twitch-dl failed, falling back to Helix API..."

  TOKEN_RESPONSE=$(curl -s -X POST "https://id.twitch.tv/oauth2/token" \
    -d "client_id=$TWITCH_CLIENT_ID" \
    -d "client_secret=$TWITCH_CLIENT_SECRET" \
    -d "grant_type=client_credentials")

  ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

  if [[ -z "$ACCESS_TOKEN" || "$ACCESS_TOKEN" == "null" ]]; then
    log "Failed to get access token: $TOKEN_RESPONSE"
    exit 1
  fi

  STARTED_AT=$(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)
  ENDED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  
  yt_dlp_updated=false
  
  CLIPS_RESPONSE=$(curl -s \
  -H "Client-ID: $TWITCH_CLIENT_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  "https://api.twitch.tv/helix/clips?broadcaster_id=$TWITCH_USER_ID&first=$MAX_CLIPS&started_at=$STARTED_AT&ended_at=$ENDED_AT")

  log "Helix response: $CLIPS_RESPONSE"

  echo "$CLIPS_RESPONSE" | jq -c '.data[]' | while read -r clip; do
    url=$(echo "$clip" | jq -r '.url')
    clip_id=$(echo "$clip" | jq -r '.id')
    video_id=$(echo "$clip" | jq -r '.video_id')
    created_at=$(echo "$clip" | jq -r '.created_at')
    title=$(echo "$clip" | jq -r '.title')
    broadcaster_login=$(echo "$clip" | jq -r '.broadcaster_name' | tr '[:upper:]' '[:lower:]')

    # Format date prefix: YYYYMMDD
    date_prefix=$(date -u -d "$created_at" +%Y%m%d 2>/dev/null || echo "${created_at:0:10}" | tr -d '-')

    # Slugify title (lowercase, spaces -> hyphens, strip non-alphanumerics)
    safe_title=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr -s ' ' '-' | tr -cd '[:alnum:]-')

    base_name="${date_prefix}_${video_id}_${broadcaster_login}_${safe_title}"
    out_path="$DOWNLOAD_DIR/${base_name}.mp4"

    # Handle collisions
    if [ -f "$out_path" ]; then
      counter=1
      while [ -f "$DOWNLOAD_DIR/${base_name}(${counter}).mp4" ]; do
        counter=$((counter + 1))
      done
      out_path="$DOWNLOAD_DIR/${base_name}(${counter}).mp4"
    fi

    # Use clip_id (slug) for temp file uniqueness, since video_id can repeat
    tmp_file="$DOWNLOAD_DIR/.tmp_${clip_id}_$$"

    output=$(yt-dlp --no-part -o "${tmp_file}.%(ext)s" "$url" 2>&1)
    status=$?

    if ! $yt_dlp_updated && grep -q "older than 90 days" <<< "$output"; then
        log "Updating yt-dlp..."
        pip install --upgrade yt-dlp
        yt_dlp_updated=true
    fi

    if [ $status -ne 0 ]; then
        log "Failed to download clip $clip_id"
        continue
    fi

    downloaded=$(ls "${tmp_file}".* 2>/dev/null | head -n1)
    if [ -n "$downloaded" ]; then
      mv "$downloaded" "$out_path"
      log "Saved: $(basename "$out_path")"
    else
      log "WARNING: yt-dlp produced no output for clip $clip_id"
    fi
  done
fi


# Generate JSON list of clips
log "Generating clips.json..."
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
# NOTE: <<'EOF' (quoted) prevents bash from expanding ${ } and backticks inside,
# which is required because the JS uses template literals with ${clip.url} etc.
log "Regenerating downloaded_clips_index.html..."
cat <<'EOF' > "$INDEX_FILE"
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
  li:hover { background: #27272b; }
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
      preview.play();
      });

      li.addEventListener("mousemove", e => {
      // Use clientX/clientY instead of pageY/pageX — unaffected by scroll
      const offsetX = 20;
      const offsetY = 20;
      preview.style.top = (e.clientY + offsetY) + "px";
      preview.style.left = (e.clientX + offsetX) + "px";
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
# NOTE: <<EOF (unquoted) is intentional here — $(date +%s) must be expanded
# so the favicon URLs get a fresh cache-busting timestamp at generation time.
if [ ! -f "$HTML_FILE" ]; then
  log "Generating HTML player..."
  cat <<EOF > "$HTML_FILE"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<title>Random Twitch Clips Player</title>
#<link rel="icon" type="image/png" sizes="16x16" href="./favicon_io/favicon-16.png?v=$(date +%s)">
#<link rel="icon" type="image/png" sizes="32x32" href="./favicon_io/favicon-32.png?v=$(date +%s)">
#<link rel="icon" type="image/png" sizes="128x128" href="./favicon_io/favicon-128.png?v=$(date +%s)">
#<link rel="icon" type="image/png" sizes="48x48" href="./favicon_io/favicon-192.png?v=$(date +%s)">
#<link rel="icon" type="image/png" sizes="64x64" href="./favicon_io/favicon-512.png?v=$(date +%s)">
#<link rel="icon" type="image/x-icon" href="./favicon_io/favicon.ico?v=$(date +%s)">

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

      // Buffer configuration - clips can repeat after this many clips have been played
      const BUFFER_SIZE = 5;
      const recentlyPlayed = [];

      function playRandomClip() {
        if (clips.length === 0) return;

        let availableClips = clips;

        // If we have enough clips and our buffer is full, exclude recently played clips
        if (clips.length > BUFFER_SIZE && recentlyPlayed.length >= BUFFER_SIZE) {
          availableClips = clips.filter(clip => !recentlyPlayed.includes(clip));
        }

        // If filtering left us with no clips, reset and use all clips
        if (availableClips.length === 0) {
          availableClips = clips;
        }

        // Select random clip from available pool
        const randomIndex = Math.floor(Math.random() * availableClips.length);
        const selectedClip = availableClips[randomIndex];

        // Add to recently played buffer
        recentlyPlayed.push(selectedClip);

        // Keep buffer at max size
        if (recentlyPlayed.length > BUFFER_SIZE) {
          recentlyPlayed.shift(); // Remove oldest
        }

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
log "===== Script finished ====="
