# 🎬 Twitch Clips Downloader + OBS HTML Player

This project automates the process of collecting top Twitch clips from a specific channel and serves them through a randomized HTML video player—perfect for embedding in OBS via a browser source.

The player runs on an external server and updates automatically after each stream ends using Twitch's EventSub webhook system.

---

## 🔧 Features

* ✅ Automatically downloads top Twitch clips when a stream ends.
* ✅ HTML video player plays clips randomly on loop.
* ✅ Fully containerized using Docker and docker-compose.
* ✅ Webhook integration via Twitch EventSub.
* ✅ Hosted externally and accessible behind a reverse proxy (e.g., Nginx Proxy Manager).
* ✅ Works seamlessly with OBS as a browser source.

---

## ⚠️ Before You Begin

### ✅ You MUST manually download all existing clips first!

Place them in the `clips_downloader/downloaded_clips/` folder using `twitch-dl` or other tools, e.g.:

```bash
twitch-dl clips your_channel_name --download --limit 100 --target-dir clips_downloader/downloaded_clips
```

This is necessary because the script is designed to only fetch *new clips after the stream ends*. Existing clips **won’t** be re-downloaded unless removed.

---

## 📁 Folder Structure

```
twitch_clips_downloader/
├── docker-compose.yml
├── Dockerfile
├── .env
├── .dockerignore
├── nginx/
│   └── nginx_default.conf
├── clips_downloader/
│   ├── main.sh
│   ├── webhook_server.py
│   ├── obs_clips_template.html
│   ├── generated_index.html
│   └── downloaded_clips/
│       └── (your pre-downloaded .mp4 clips)
```

---

## 🛠️ Setup Instructions

### 1. Clone the repository and prepare clips

```bash
git clone https://github.com/yourname/twitch_clips_downloader.git
cd twitch_clips_downloader
```

Download your existing clips using `twitch-dl` (or similar), and place them in `clips_downloader/downloaded_clips/`.

### 2. Fill out the `.env` file

Edit the `.env-example` file and save it as `.env`

```dotenv
CHANNEL_NAME=your_twitch_channel_here
MAX_CLIPS=10
TWITCH_CLIENT_ID=your_twitch_client_id
TWITCH_CLIENT_SECRET=your_twitch_client_secret
TWITCH_EVENTSUB_SECRET=a_random_secure_secret
TWITCH_USER_ID=your_channel_user_id
WEBHOOK_CALLBACK_URL=https://your.public.domain/webhook
```

> Use tools like [Twitch Token Generator](https://twitchtokengenerator.com/) to get your client credentials and User ID.

---

### 3. Configure Reverse Proxy

This project assumes you're using **Nginx Proxy Manager (NPM)**. Make sure:

* Port `5404` is exposed on your server (can be changed, if you want).
* Your proxy forwards `https://your.public.domain` → `http://localhost:5404`.

---

### 4. Build and Run

```bash
docker-compose up --build -d
```

This will:

* Start the webhook server (`webhook_server.py`) listening on port `5405`.
* Start an Nginx container serving the HTML player and clip files on port `5404`.

---

## 🧪 Test It

* Open `https://your.public.domain` — you should see the HTML player start playing clips randomly.
* You can also open it inside OBS via the **Browser Source** using the same public URL.

---

## 🔁 Subscribing to `stream.offline` Events

To trigger automatic clip downloads when a Twitch stream ends, you need to subscribe to the `stream.offline` event for your channel using Twitch’s EventSub API.

### Step 1: Generate an App Access Token

Run this command to get an access token:

```bash
curl -X POST "https://id.twitch.tv/oauth2/token" \
-d "client_id=YOUR_TWITCH_CLIENT_ID" \
-d "client_secret=YOUR_TWITCH_CLIENT_SECRET" \
-d "grant_type=client_credentials"
```

The response will include an `access_token`. Copy it for use in the next step.

---

### Step 2: Subscribe to the `stream.offline` Event

Now subscribe your webhook server to listen for the `stream.offline` event:

```bash
curl -X POST https://api.twitch.tv/helix/eventsub/subscriptions \
-H "Client-ID: YOUR_TWITCH_CLIENT_ID" \
-H "Authorization: Bearer YOUR_APP_ACCESS_TOKEN_FROM_STEP_1" \
-H "Content-Type: application/json" \
-d '{
  "type": "stream.offline",
  "version": "1",
  "condition": {
    "broadcaster_user_id": "YOUR_TWITCH_USER_ID"
  },
  "transport": {
    "method": "webhook",
    "callback": "https://your.public.domain/webhook",
    "secret": "YOUR_TWITCH_EVENTSUB_SECRET"
  }
}'
```

---

## 🔁 What Happens After a Stream Ends?

Once the Twitch channel goes offline:

1. Twitch sends an EventSub notification to the webhook.
2. The webhook server triggers `main.sh`.
3. It downloads the latest top clips (if new ones are available).
4. Regenerates the HTML file (`generated_index.html`) with the new list of clips.

---

## 📌 Notes

* OBS will show player controls by default. You can remove them by editing `main.sh` if desired.
* The HTML auto-refreshes every 30 minutes to load new clips.
* The script avoids re-downloading clips that are already present in `downloaded_clips/`.

---

## 🧹 Clean Up Docker Context (optional)

To avoid Docker copying all `.mp4` files during the build process, the `.dockerignore` excludes them.

If needed, clean Docker's build cache:

```bash
docker builder prune
```

---
NOTE: This project was made with the help of ChatGPT
