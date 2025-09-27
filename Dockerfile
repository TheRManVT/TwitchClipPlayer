FROM python:3.11-slim

RUN apt update && apt install -y nginx ffmpeg curl nano && pip install twitch-dl flask

WORKDIR /app

COPY clips_downloader/main.sh .
COPY clips_downloader/obs_clips_template.html .
COPY clips_downloader/generated_index.html .
COPY clips_downloader/webhook_server.py .

RUN chmod +x /app/main.sh

CMD ["nginx", "-g", "daemon off;"]
