#!/usr/bin/env python3
"""
Resonance Downloader Bridge
=======================================================
A JSON IPC bridge between Flutter (Dart) and yt-dlp.

Protocol:
  - Flutter sends ONE JSON command per line on stdin.
  - This script replies with multiple JSON event lines on stdout.
"""

import hashlib
import string
import subprocess
import re
import urllib.parse
import threading
import json
import os
import sys
from typing import Optional
import threading

_active_events = {}
_events_lock = threading.Lock()
_stdout_lock = threading.Lock()

try:
    import yt_dlp
except ImportError:
    sys.stderr.write("MISSING_DEP:yt-dlp\n")
    sys.exit(2)

try:
    import requests as _requests
    HAVE_REQUESTS = True
except ImportError:
    HAVE_REQUESTS = False
    sys.stderr.write("WARN:requests not found, lyrics will be skipped\n")


def emit(obj: dict):
    """Write a JSON event to stdout and flush immediately."""
    try:
        line = (json.dumps(obj, ensure_ascii=True) + '\n').encode('utf-8')
        with _stdout_lock:
            sys.stdout.write(line)
            sys.stdout.flush()
    except TypeError:
        # stdout is still text mode (before main() swaps it)
        with _stdout_lock:
            sys.stdout.write(json.dumps(obj, ensure_ascii=True) + '\n')
            sys.stdout.flush()
    except Exception:
        pass


# ── Helpers ────────────────────────────────────────────────────────────────────

def _primary_artist(artist: str) -> str:
    """Extract primary artist name."""
    if not artist:
        return ""
    primary = artist.split(",")[0].strip()
    for suffix in [" - Topic", "VEVO", " Official", " Music", " TV"]:
        if primary.endswith(suffix):
            primary = primary[: -len(suffix)].strip()
    return primary


def _clean_title(title: str) -> str:
    """Remove YouTube noise from title."""
    noise_terms = [
        "(Official Video)", "[Official Video]", "(Official Audio)", "[Official Audio]",
        "(OFFICIAL MUSIC VIDEO)", "(Lyric Video)", "(Official Lyric Video)",
        "(Lyrics)", "[Lyrics]", "(HD)", "(HQ)", "(4K)",
    ]
    clean = title
    for noise in noise_terms:
        idx = clean.lower().find(noise.lower())
        while idx != -1:
            clean = clean[:idx] + clean[idx + len(noise):]
            idx = clean.lower().find(noise.lower())
    for bracket in ["(feat.", "[feat.", "(ft.", "[ft.", "(with "]:
        if bracket.lower() in clean.lower():
            idx = clean.lower().find(bracket.lower())
            clean = clean[:idx]
    return clean.strip()


def _strip_punctuation(text: str) -> str:
    """Remove punctuation for searching."""
    return text.translate(str.maketrans("", "", string.punctuation)).strip()


def _get_safe_id(song_id: str) -> str:
    """Standardized ID sanitization matching Dart side."""
    return re.sub(r'[^a-zA-Z0-9_-]', '_', song_id)


def _generate_loc_id(song_id: str) -> str:
    """Generate a stable local ID based on the source Video ID."""
    if not song_id:
        return "loc_unknown"
    hash_val = hashlib.sha256(song_id.encode()).hexdigest()[:10]
    return f"loc_{hash_val}"


def _fetch_lrclib(track: str, artist: str, duration: int = 0, download_id: str = "") -> Optional[str]:
    """Fetch synced lyrics from lrclib.net."""
    if not HAVE_REQUESTS:
        return None
    timeout = 10
    
    def _search(params: dict, label: str) -> Optional[str]:
        try:
            emit({"id": download_id, "type": "log", "message": f"Lyrics [{label}]"})
            resp = _requests.get("https://lrclib.net/api/search", params=params, timeout=timeout)
            if resp.status_code == 200:
                for item in resp.json():
                    synced = item.get("syncedLyrics") or ""
                    if synced.strip():
                        return synced
        except Exception: pass
        return None

    def _get(params: dict, label: str) -> Optional[str]:
        try:
            emit({"id": download_id, "type": "log", "message": f"Lyrics [{label}]"})
            resp = _requests.get("https://lrclib.net/api/get", params=params, timeout=timeout)
            if resp.status_code == 200:
                synced = resp.json().get("syncedLyrics") or ""
                if synced.strip():
                    return synced
        except Exception: pass
        return None

    track_stripped = _strip_punctuation(track)
    if duration > 0 and artist:
        res = _get({"track_name": track, "artist_name": artist, "duration": duration}, "exact+dur")
        if res: return res
    if artist:
        res = _get({"track_name": track, "artist_name": artist}, "exact")
        if res: return res
        res = _search({"q": f"{track} {artist}"}, "fuzzy")
        if res: return res
    res = _search({"q": track}, "title-only")
    return res


def fetch_lyrics(title: str, lyrics_path: str, download_id: str, loc_id: str, artist: str = "", duration: int = 0):
    """Search for lyrics and save using stable unified ID: [loc_id].lrc."""
    if not HAVE_REQUESTS: return
    clean_artist = _primary_artist(artist)
    clean_title = _clean_title(title)
    
    emit({"id": download_id, "type": "log", "message": f"🔍 Searching lyrics: '{clean_title}'"})
    lrc_text = _fetch_lrclib(clean_title, clean_artist, duration, download_id)
    
    if lrc_text:
        lrc_file_path = os.path.join(lyrics_path, f"{loc_id}.lrc")
        try:
            with open(lrc_file_path, "w", encoding="utf-8") as f:
                f.write(lrc_text)
            emit({"id": download_id, "type": "log", "message": f"✅ Lyrics saved: {loc_id}.lrc"})
            emit({"id": download_id, "type": "lyrics", "status": "found", "path": lrc_file_path})
        except Exception as e:
            emit({"id": download_id, "type": "log", "message": f"❌ Lyrics write error: {e}"})
    else:
        emit({"id": download_id, "type": "lyrics", "status": "not_found"})


class YDLimiterLogger:
    def __init__(self, download_id: str):
        self.download_id = download_id
    def debug(self, msg):
        if not msg.startswith('[debug] '):
            emit({"id": self.download_id, "type": "log", "message": f"Info: {msg}"})
    def info(self, msg):
        emit({"id": self.download_id, "type": "log", "message": msg})
    def warning(self, msg):
        emit({"id": self.download_id, "type": "log", "message": f"⚠ {msg}"})
    def error(self, msg):
        emit({"id": self.download_id, "type": "log", "message": f"❌ {msg}"})


def build_progress_hook(download_id: str):
    def hook(d):
        with _events_lock:
            event = _active_events.get(download_id)
        if event and event.is_set():
            raise Exception("CANCELLED_BY_USER")

        if d["status"] == "downloading":
            raw_percent = d.get("_percent_str", "0%").strip().replace("%", "")
            try: percent = float(raw_percent)
            except: percent = 0.0
            emit({
                "id": download_id, "type": "progress", "percent": percent,
                "speed": d.get("_speed_str", "").strip(), "eta": d.get("eta", 0)
            })
    return hook


def handle_download(cmd: dict):
    download_id = cmd.get("id", "unknown")
    url = cmd.get("url", "")
    dl_type = cmd.get("type", "audio")
    source = cmd.get("source", "ytmusic")
    music_path = cmd.get("music_path", "")
    video_path = cmd.get("video_path", "")
    lyrics_path = cmd.get("lyrics_path", "")
    images_path = cmd.get("images_path", "")
    quality = str(cmd.get("quality", "192"))
    ffmpeg_path = cmd.get("ffmpeg_path")
    
    emit({"id": download_id, "type": "log", "message": f"ℹ FFmpeg Internal Path: {ffmpeg_path}"})
    
    os.makedirs(music_path, exist_ok=True)
    os.makedirs(video_path, exist_ok=True)
    os.makedirs(lyrics_path, exist_ok=True)
    if images_path:
        os.makedirs(images_path, exist_ok=True)

    event = threading.Event()
    with _events_lock:
        _active_events[download_id] = event

    is_direct_url = url.startswith("http://") or url.startswith("https://")
    
    common_opts = {
        "noplaylist": True, "quiet": True, "no_warnings": True, "nocheckcertificate": True,
        "progress_hooks": [build_progress_hook(download_id)],
        "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "extractor_args": {
            "youtube": {
                "player_client": ["android", "ios", "web", "mweb"]
            },
            "youtubepot-bgutilhttp": {
                "base_url": "http://127.0.0.1:4416"
            }
        }
    }

    if not is_direct_url:
        common_opts["default_search"] = "ytmsearch1" if source == "ytmusic" else "ytsearch1"

    if dl_type == "audio":
        output_dir = music_path
        ydl_opts = {
            **common_opts, "format": "bestaudio/best", "writethumbnail": True,
            "postprocessors": [
                {"key": "FFmpegExtractAudio", "preferredcodec": "mp3", "preferredquality": quality},
                {"key": "FFmpegMetadata", "add_metadata": True},
                {"key": "EmbedThumbnail", "already_have_thumbnail": False},
            ],
            # Use stable hashed loc_ prefix instead of raw video ID
            "outtmpl": os.path.join(output_dir, "temp_%(id)s.%(ext)s"),
            "logger": YDLimiterLogger(download_id),
            "ffmpeg_location": ffmpeg_path,
        }
    else:
        output_dir = video_path
        ydl_opts = {
            **common_opts, "format": "bestvideo[ext=mp4][height<=1080]+bestaudio[ext=m4a]/best[ext=mp4][height<=1080]/best", "merge_output_format": "mp4",
            "writethumbnail": True,
            "outtmpl": os.path.join(output_dir, "temp_%(id)s.%(ext)s"),
            "logger": YDLimiterLogger(download_id),
            "ffmpeg_location": ffmpeg_path,
        }

    try:
        emit({"id": download_id, "type": "log", "message": "Resolving metadata..."})
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)
            if info and "entries" in info: info = info["entries"][0]
            
            song_id = info.get("id") or download_id
            loc_id = _generate_loc_id(song_id)
            safe_id = _get_safe_id(song_id)
            title = info.get("title", url)
            artist = _primary_artist(info.get("artist") or info.get("uploader") or "")
            duration = int(info.get("duration", 0))

            # Final Renaming to stable loc_ ID
            final_ext = "mp3" if dl_type == "audio" else "mp4"
            temp_path = os.path.join(output_dir, f"temp_{song_id}.{final_ext}")
            final_path = os.path.join(output_dir, f"{loc_id}.{final_ext}")
            
            if os.path.exists(temp_path):
                if os.path.exists(final_path): os.remove(final_path)
                os.rename(temp_path, final_path)
            elif not os.path.exists(final_path):
                # Fallback if yt-dlp didn't use temp prefix correctly
                actual_path = os.path.join(output_dir, f"{song_id}.{final_ext}")
                if os.path.exists(actual_path):
                    os.rename(actual_path, final_path)
            
            # 1. Handle Thumbnail Sidecar (Standard art_[id].jpg)
            target_art = None
            target_dir = images_path if images_path else output_dir
            potential_art = os.path.join(target_dir, f"art_{loc_id}.jpg")
            thumb_found = False
            
            for ext in ["jpg", "png", "webp"]:
                thumb_temp = os.path.join(output_dir, f"temp_{song_id}.{ext}")
                if os.path.exists(thumb_temp):
                    try:
                        if os.path.exists(potential_art): os.remove(potential_art)
                        os.rename(thumb_temp, potential_art)
                        thumb_found = True
                    except: pass
                    break

            # Fallback: yt-dlp's EmbedThumbnail deletes the sidecar image after embedding.
            # We explicitly redownload it so Resonance App can use it in the centralized cache.
            if not thumb_found and HAVE_REQUESTS and info.get("thumbnails"):
                try:
                    thumb_url = info["thumbnails"][-1]["url"]
                    r = _requests.get(thumb_url, timeout=10)
                    if r.status_code == 200:
                        with open(potential_art, "wb") as f:
                            f.write(r.content)
                        thumb_found = True
                        emit({"id": download_id, "type": "log", "message": "✅ Thumbnail restored to cache."})
                except Exception as e:
                    emit({"id": download_id, "type": "log", "message": f"⚠ Thumbnail restore failed: {e}"})

            if thumb_found:
                target_art = potential_art

            # 2. Skip Metadata Sidecar (Ditched in Overhaul)

            # 3. Fetch Lyrics ([loc_id].lrc)
            if dl_type == "audio":
                fetch_lyrics(title, lyrics_path, download_id, loc_id, artist=artist, duration=duration)

            if not os.path.exists(final_path):
                raise Exception("Download failed: Video file missing or merge failed (check ffmpeg installation).")

            emit({
                "id": download_id, "type": "done", "title": title, "path": final_path, "songId": loc_id, "art_path": target_art
            })

    except Exception as e:
        if str(e) == "CANCELLED_BY_USER":
            emit({"id": download_id, "type": "error", "message": "Download cancelled."})
        else:
            emit({"id": download_id, "type": "error", "message": str(e)})
    finally:
        with _events_lock:
            if download_id in _active_events:
                del _active_events[download_id]


def handle_resolve_stream(cmd: dict):
    req_id = cmd.get("id", "unknown")
    video_id = cmd.get("videoId", "")
    sys.stderr.write(f"[resolve] START req_id={req_id} videoId={video_id}\n")
    sys.stderr.flush()
    try:
        url = f"https://www.youtube.com/watch?v={video_id}"
        ydl_opts = {
            "quiet": True,
            "no_warnings": True,
            "nocheckcertificate": True,
            "format": "ba[ext=m4a]/ba[ext=mp4]/bestaudio/best",
            "youtube_include_dash_manifest": False,
            "youtube_include_hls_playlist": False,
            "extractor_args": {
                "youtube": {
                    "player_client": ["android", "ios", "web", "mweb"]
                },
                "youtubepot-bgutilhttp": {
                    "base_url": "http://127.0.0.1:4416"
                }
            }
        }
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            stream_url = info.get("url")
            sys.stderr.write(f"[resolve] DONE req_id={req_id} url_len={len(stream_url or '')}\n")
            sys.stderr.flush()
            emit({"id": req_id, "type": "resolved", "url": stream_url})
    except Exception as e:
        sys.stderr.write(f"[resolve] ERROR req_id={req_id}: {e}\n")
        sys.stderr.flush()
        emit({"id": req_id, "type": "error", "message": str(e)})


def main():
    # Force stdin/stdout to unbuffered binary on Windows to fix pipe blocking
    sys.stdout = open(sys.stdout.fileno(), 'wb', buffering=0)
    stdin_raw = open(sys.stdin.fileno(), 'rb', buffering=0)

    # Emit ready as bytes directly
    sys.stdout.write(b'{"type": "ready"}\n')
    sys.stdout.flush()

    sys.stderr.write('[main] Entering stdin loop\n')
    sys.stderr.flush()

    buf = b''
    while True:
        chunk = stdin_raw.read(1)
        if not chunk:
            break
        buf += chunk
        if b'\n' in buf:
            line_bytes, buf = buf.split(b'\n', 1)
            line = line_bytes.strip().decode('utf-8', errors='replace')
            if not line:
                continue
            sys.stderr.write(f'[main] Got line: {repr(line)}\n')
            sys.stderr.flush()
            try:
                cmd = json.loads(line)
                if cmd.get('action') == 'download':
                    threading.Thread(target=handle_download, args=(cmd,), daemon=True).start()
                elif cmd.get('action') == 'resolve_stream':
                    threading.Thread(target=handle_resolve_stream, args=(cmd,), daemon=True).start()
                elif cmd.get('action') == 'cancel':
                    cid = cmd.get('id')
                    with _events_lock:
                        if cid in _active_events:
                            _active_events[cid].set()
                elif cmd.get('action') == 'ping':
                    emit({'type': 'pong'})
                elif cmd.get('action') == 'quit':
                    break
            except Exception as ex:
                sys.stderr.write(f'[main] JSON parse error: {ex} line={repr(line)}\n')
                sys.stderr.flush()
                continue

if __name__ == "__main__":
    import multiprocessing
    multiprocessing.freeze_support()

    # One-shot mode: python resonance_downloader.py --resolve <videoId>
    # No stdin pipe needed — ideal for Windows process spawning
    if len(sys.argv) == 3 and sys.argv[1] == '--resolve':
        video_id = sys.argv[2]
        # Use text stdout for one-shot (Process.run captures it cleanly)
        sys.stdout = sys.__stdout__
        handle_resolve_stream({"id": "oneshot", "videoId": video_id})
        sys.exit(0)

    main()
