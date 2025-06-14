from flask import Flask, request, jsonify
import os
import hmac
import hashlib
import subprocess

app = Flask(__name__)

TWITCH_SECRET = os.getenv('TWITCH_EVENTSUB_SECRET')
TARGET_USER_ID = os.getenv('TWITCH_USER_ID')

@app.route('/webhook', methods=['POST'])
def webhook():
    msg_type = request.headers.get('Twitch-Eventsub-Message-Type')
    payload = request.get_json()

    if msg_type == 'webhook_callback_verification':
        return payload['challenge'], 200, {'Content-Type': 'text/plain'}

    if not verify_signature(request):
        return 'Invalid signature', 403

    event = payload.get('event', {})
    if payload.get('subscription', {}).get('type') == 'stream.offline':
        if event.get('broadcaster_user_id') == TARGET_USER_ID:
            print("Stream went offline — triggering download...")
            subprocess.Popen(["/bin/bash", "/app/main.sh"])
        return '', 204

    return '', 204

@app.route('/webhook', methods=['GET'])
def health_check():
    return '✅ Twitch Webhook is running', 200

def verify_signature(req):
    signature = req.headers.get('Twitch-Eventsub-Message-Signature', '')
    message_id = req.headers.get('Twitch-Eventsub-Message-Id', '')
    timestamp = req.headers.get('Twitch-Eventsub-Message-Timestamp', '')
    hmac_message = message_id + timestamp + req.data.decode('utf-8')
    computed = 'sha256=' + hmac.new(TWITCH_SECRET.encode(), hmac_message.encode(), hashlib.sha256).hexdigest()
    return hmac.compare_digest(computed, signature)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5405)
