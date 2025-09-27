import os
import requests

CLIENT_ID = os.getenv("TWITCH_CLIENT_ID")
CLIENT_SECRET = os.getenv("TWITCH_CLIENT_SECRET")
WEBHOOK_SECRET = os.getenv("TWITCH_EVENTSUB_SECRET")
USER_ID = os.getenv("TWITCH_USER_ID")
WEBHOOK_URL = os.getenv("WEBHOOK_CALLBACK_URL")  # e.g. https://yourdomain.com/webhook

# Step 1: Get OAuth token
auth_resp = requests.post("https://id.twitch.tv/oauth2/token", {
    "client_id": CLIENT_ID,
    "client_secret": CLIENT_SECRET,
    "grant_type": "client_credentials"
})
auth_resp.raise_for_status()
access_token = auth_resp.json()["access_token"]

# Step 2: Register the EventSub subscription
headers = {
    "Client-ID": CLIENT_ID,
    "Authorization": f"Bearer {access_token}",
    "Content-Type": "application/json"
}
subscription = {
    "type": "stream.offline",
    "version": "1",
    "condition": { "broadcaster_user_id": USER_ID },
    "transport": {
        "method": "webhook",
        "callback": f"{WEBHOOK_URL}",
        "secret": WEBHOOK_SECRET
    }
}
resp = requests.post("https://api.twitch.tv/helix/eventsub/subscriptions", json=subscription, headers=headers)
resp.raise_for_status()

print("✅ Subscription successful!")
print(resp.json())
