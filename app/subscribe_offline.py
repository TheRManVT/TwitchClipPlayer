import os
import requests

# Load from environment or hardcode temporarily
CLIENT_ID = os.getenv("TWITCH_CLIENT_ID")
CLIENT_SECRET = os.getenv("TWITCH_CLIENT_SECRET")
TWITCH_USER_ID = os.getenv("TWITCH_USER_ID")  # Broadcaster user ID
CALLBACK_URL = os.getenv("TWITCH_WEBHOOK_CALLBACK")  # e.g., https://your-ngrok-url/webhook
EVENTSUB_SECRET = os.getenv("TWITCH_EVENTSUB_SECRET")

def get_app_access_token(client_id, client_secret):
    url = "https://id.twitch.tv/oauth2/token"
    params = {
        "client_id": client_id,
        "client_secret": client_secret,
        "grant_type": "client_credentials"
    }
    response = requests.post(url, params=params)
    response.raise_for_status()
    return response.json()["access_token"]

def subscribe_to_stream_offline(client_id, access_token, user_id, callback_url, secret):
    url = "https://api.twitch.tv/helix/eventsub/subscriptions"
    headers = {
        "Client-ID": client_id,
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }
    body = {
        "type": "stream.offline",
        "version": "1",
        "condition": {
            "broadcaster_user_id": user_id
        },
        "transport": {
            "method": "webhook",
            "callback": callback_url,
            "secret": secret
        }
    }
    response = requests.post(url, json=body, headers=headers)
    print(f"Response status: {response.status_code}")
    print(response.json())
    response.raise_for_status()

if __name__ == "__main__":
    if not all([CLIENT_ID, CLIENT_SECRET, TWITCH_USER_ID, CALLBACK_URL, EVENTSUB_SECRET]):
        print("❌ Missing environment variables.")
        exit(1)

    print("🔑 Getting access token...")
    token = get_app_access_token(CLIENT_ID, CLIENT_SECRET)

    print("📡 Subscribing to stream.offline event...")
    subscribe_to_stream_offline(CLIENT_ID, token, TWITCH_USER_ID, CALLBACK_URL, EVENTSUB_SECRET)

    print("✅ Done.")
