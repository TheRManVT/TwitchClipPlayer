#!/bin/bash

CHANNEL_NAME="${CHANNEL_NAME:-your_twitch_channel_here}"
MAX_CLIPS="${MAX_CLIPS:-10}"
DOWNLOAD_DIR="/app/downloaded_clips"
HTML_FILE="/app/generated_index.html"

mkdir -p "$DOWNLOAD_DIR"

# Logic to download newest clips after one hour of the stream going offline
  # if [[ "$1" == "delayed" ]]; then
  # echo "Delaying 1 hour before downloading..." >> "$DOWNLOAD_DIR/main.log"
  # sleep 3600
# fi

# Download top clips
echo "Downloading top $MAX_CLIPS clips for $CHANNEL_NAME..."
twitch-dl clips "$CHANNEL_NAME" --download --limit "$MAX_CLIPS" --target-dir "$DOWNLOAD_DIR" --period last_week

# Generate randomized HTML
echo "Generating HTML player..."
cat <<EOF > "$HTML_FILE"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<title>Random Twitch Clips</title>
<meta http-equiv="refresh" content="1800"> <!-- Auto-refresh every 30 min -->
<style>
  body, html { margin:0; padding:0; background:#000; }
  video { width: 100%; height: auto; }
</style>
</head>
<body>
<video id="clipPlayer" controls autoplay></video>

<script>
  const clips = [
EOF

for clip in "$DOWNLOAD_DIR"/*.mp4; do
  filename=$(basename "$clip")
  echo "    \"downloaded_clips/$filename\"," >> "$HTML_FILE"
done

cat <<EOF >> "$HTML_FILE"
  ];

  const player = document.getElementById('clipPlayer');

  function playRandomClip() {
    const randomIndex = Math.floor(Math.random() * clips.length);
    player.src = clips[randomIndex];
    player.play();
  }

  player.addEventListener('ended', playRandomClip);
  playRandomClip();
</script>
</body>
</html>
EOF
