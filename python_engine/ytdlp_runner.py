import yt_dlp
import traceback

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

print("Starting yt-dlp download...")
try:
    with yt_dlp.YoutubeDL(options) as ydl:
        ydl.extract_info('https://www.youtube.com/watch?v=dQw4w9WgXcQ', download=True)
    print("Download finished successfully!")
except Exception as e:
    print("Download failed!")
    traceback.print_exc()

