import yt_dlp
import traceback
import sys

print("Hello from test_ytdlp.py", file=sys.stderr, flush=True)

options = {
    'format': 'bestaudio/best',
    'noplaylist': True,
    'quiet': False,
    'no_warnings': False,
    'outtmpl': './music/%(title)s.%(ext)s',
    'postprocessors': [
        {'key': 'FFmpegExtractAudio', 'preferredcodec': 'mp3', 'preferredquality': '192'},
    ]
}

url = 'https://music.youtube.com/watch?v=DGpKJLU4LHM&si=C2RORYh8iCwah8tJ'
print(f"Starting yt-dlp download for {url}...")
try:
    with yt_dlp.YoutubeDL(options) as ydl:
        info = ydl.extract_info(url, download=True)
        print("Extract info keys:", info.keys() if info else "None")
    print("Download finished successfully!")
except Exception as e:
    print("Download failed!")
    traceback.print_exc()

