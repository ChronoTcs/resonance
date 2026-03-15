#!/usr/bin/env python3
"""
Resonance Downloader Bridge
=======================================================
A JSON IPC bridge between Flutter (Dart) and yt-dlp.

Protocol:
  - Flutter sends ONE JSON command per line on stdin.
  - This script replies with multiple JSON event lines on stdout.

Command format:
  {
    "action": "download",
    "id": "<unique_id>",
    "url": "<url_or_search_query>",
    "type": "audio" | "video",
    "source": "ytmusic" | "youtube" | "url",
    "music_path": "<path>",
    "video_path": "<path>",
    "lyrics_path": "<path>",
    "quality": "192" | "320" | "128",    (audio only)
    "max_retries": 3,
    "socket_timeout": 30,
    "concurrent_fragments": 4
  }

Event format (one per stdout line):
  { "id": "<id>", "type": "progress", "percent": 45.2, "speed": "1.2MiB/s", "eta": 12 }
  { "id": "<id>", "type": "done",     "title": "Song Title", "path": "/absolute/path.mp3" }
  { "id": "<id>", "type": "error",    "message": "error description" }
  { "id": "<id>", "type": "lyrics",   "status": "found" | "not_found" }
"""

import sys
import os
import json
import threading
import urllib.parse
from typing import Optional

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
        print(json.dumps(obj, ensure_ascii=True), flush=True)
    except Exception:
        pass



# ── Helpers ────────────────────────────────────────────────────────────────────

def _primary_artist(artist: str) -> str:
    """
    Extract the primary artist name.
    YouTube Music returns comma-separated collaborators — take only the first.
    """
    if not artist:
        return ""
    primary = artist.split(",")[0].strip()
    for suffix in [" - Topic", "VEVO", " Official", " Music", " TV"]:
        if primary.endswith(suffix):
            primary = primary[: -len(suffix)].strip()
    return primary


def _clean_title(title: str) -> str:
    """Remove YouTube noise and collaborator tags from title."""
    noise_terms = [
        "(Official Video)", "[Official Video]", "(Official Audio)", "[Official Audio]",
        "(OFFICIAL MUSIC VIDEO)", "(Lyric Video)", "(Official Lyric Video)",
        "(Lyrics)", "[Lyrics]", "(HD)", "(HQ)", "(4K)",
    ]
    clean = title
    for noise in noise_terms:
        # Case-insensitive removal
        idx = clean.lower().find(noise.lower())
        while idx != -1:
            clean = clean[:idx] + clean[idx + len(noise):]
            idx = clean.lower().find(noise.lower())
    # Strip feat. brackets
    for bracket in ["(feat.", "[feat.", "(ft.", "[ft.", "(with "]:
        if bracket.lower() in clean.lower():
            idx = clean.lower().find(bracket.lower())
            clean = clean[:idx]
    return clean.strip()


def _strip_punctuation(text: str) -> str:
    """Remove all punctuation for a softer search query."""
    import string
    return text.translate(str.maketrans("", "", string.punctuation)).strip()


def _safe_filename(title: str) -> str:
    """
    Produce a filename that matches what yt-dlp uses for downloaded audio files.
    Strips Windows-illegal characters: / \\ : * ? " < > |
    This ensures the .lrc file has the same stem as the corresponding .mp3.
    """
    illegal = r'/\:*?"<>|'
    safe = "".join(c if c not in illegal else "_" for c in title)
    # Collapse multiple spaces/underscores
    safe = " ".join(safe.split())
    return safe.strip(" .")


def _fetch_lrclib(track: str, artist: str, duration: int = 0, download_id: str = "") -> Optional[str]:
    """
    Fetch synced lyrics from lrclib.net REST API.
    Tries multiple query strategies to maximise success rate.
    """
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
        except Exception as e:
            emit({"id": download_id, "type": "log", "message": f"  ↳ error: {e}"})
        return None

    def _get(params: dict, label: str) -> Optional[str]:
        try:
            emit({"id": download_id, "type": "log", "message": f"Lyrics [{label}]"})
            resp = _requests.get("https://lrclib.net/api/get", params=params, timeout=timeout)
            if resp.status_code == 200:
                synced = resp.json().get("syncedLyrics") or ""
                if synced.strip():
                    return synced
        except Exception as e:
            emit({"id": download_id, "type": "log", "message": f"  ↳ error: {e}"})
        return None

    track_stripped = _strip_punctuation(track)
    artist_stripped = _strip_punctuation(artist)

    # Strategy 1: Exact match with duration (highest precision)
    if duration > 0 and artist:
        result = _get(
            {"track_name": track, "artist_name": artist, "duration": duration},
            f"exact: '{track} - {artist}' (dur={duration}s)"
        )
        if result:
            return result

    # Strategy 2: Exact match without duration
    if artist:
        result = _get(
            {"track_name": track, "artist_name": artist},
            f"exact: '{track} - {artist}'"
        )
        if result:
            return result

    # Strategy 3: Fuzzy search "Title Artist"
    if artist:
        result = _search({"q": f"{track} {artist}"}, f"search: '{track} {artist}'")
        if result:
            return result

    # Strategy 4: Fuzzy search "Artist Title"
    if artist:
        result = _search({"q": f"{artist} {track}"}, f"search: '{artist} {track}'")
        if result:
            return result

    # Strategy 5: Strip punctuation, try again
    if track_stripped != track:
        result = _search(
            {"q": f"{track_stripped} {artist_stripped}"},
            f"search (no punct): '{track_stripped} {artist_stripped}'"
        )
        if result:
            return result

    # Strategy 6: Title-only (widest net)
    result = _search({"q": track}, f"title-only: '{track}'")
    if result:
        return result

    # Strategy 7: Title without punctuation only
    if track_stripped != track:
        result = _search({"q": track_stripped}, f"title-only (no punct): '{track_stripped}'")
        if result:
            return result

    return None


def fetch_lyrics(
    title: str,
    output_path: str,
    download_id: str,
    artist: str = "",
    duration: int = 0,
):
    """
    Search for synced .lrc lyrics using Lrclib.net REST API.
    The .lrc file is named using _safe_filename() to match yt-dlp's naming.
    """
    if not HAVE_REQUESTS:
        emit({"id": download_id, "type": "log", "message": "⚠ requests library not available — skipping lyrics"})
        emit({"id": download_id, "type": "lyrics", "status": "not_found",
              "reason": "requests library not available"})
        return

    clean_artist = _primary_artist(artist)
    clean_title = _clean_title(title)

    emit({"id": download_id, "type": "log",
          "message": f"🔍 Searching lyrics: '{clean_title}' by '{clean_artist}' (dur={duration}s)"})

    lrc_text = _fetch_lrclib(clean_title, clean_artist, duration, download_id)

    if lrc_text:
        # Use _safe_filename to match exactly what yt-dlp names the .mp3 file
        fname = _safe_filename(title)
        lrc_path = os.path.join(output_path, f"{fname}.lrc")
        try:
            with open(lrc_path, "w", encoding="utf-8") as f:
                f.write(lrc_text)
            emit({"id": download_id, "type": "log",
                  "message": f"✅ Lyrics saved → {lrc_path}"})
            emit({
                "id": download_id,
                "type": "lyrics",
                "status": "found",
                "path": lrc_path,
            })
        except Exception as e:
            emit({"id": download_id, "type": "log",
                  "message": f"❌ Failed to write lyrics file: {e}"})
            emit({"id": download_id, "type": "lyrics",
                  "status": "error", "message": str(e)})
    else:
        emit({"id": download_id, "type": "log",
              "message": "❌ No lyrics found after trying all 7 strategies"})
        emit({"id": download_id, "type": "lyrics", "status": "not_found"})


def build_progress_hook(download_id: str):
    def hook(d):
        if d["status"] == "downloading":
            raw_percent = d.get("_percent_str", "0%").strip().replace("%", "")
            try:
                percent = float(raw_percent)
            except ValueError:
                percent = 0.0
            emit({
                "id": download_id,
                "type": "progress",
                "percent": percent,
                "speed": d.get("_speed_str", "").strip(),
                "eta": d.get("eta", 0),
                "downloaded_bytes": d.get("downloaded_bytes", 0),
                "total_bytes": d.get("total_bytes") or d.get("total_bytes_estimate", 0),
            })
    return hook


def build_pp_hook(download_id: str):
    """Hooks into FFmpeg processing stages (conversion, metadata, etc)."""
    def hook(d):
        if d["status"] == "started":
            pp_name = d.get("postprocessor", "unknown")
            emit({"id": download_id, "type": "log", "message": f"Processing: {pp_name}..."})
        elif d["status"] == "finished":
            emit({"id": download_id, "type": "log", "message": "Step finished."})
    return hook


def handle_download(cmd: dict):
    download_id = cmd.get("id", "unknown")
    url = cmd.get("url", "")
    dl_type = cmd.get("type", "audio")          # "audio" or "video"
    source = cmd.get("source", "ytmusic")       # "ytmusic" | "youtube" | "url"

    # Use 'or' fallback so that empty strings from Flutter also get a sane default
    music_path = cmd.get("music_path", "") or os.path.join(os.path.expanduser("~"), "Music", "Resonance Downloads")
    video_path = cmd.get("video_path", "") or os.path.join(os.path.expanduser("~"), "Videos", "Resonance Downloads")
    lyrics_path = cmd.get("lyrics_path", "") or os.path.join(music_path, "Lyrics")

    # Emit debug info about paths so user can see what's being used in the log
    emit({"id": download_id, "type": "log", "message": f"Paths → Music: {music_path} | Lyrics: {lyrics_path}"})

    quality = str(cmd.get("quality", "192"))
    max_retries = int(cmd.get("max_retries", 3))
    socket_timeout = int(cmd.get("socket_timeout", 30))
    concurrent_fragments = int(cmd.get("concurrent_fragments", 4))

    os.makedirs(music_path, exist_ok=True)
    os.makedirs(video_path, exist_ok=True)
    os.makedirs(lyrics_path, exist_ok=True)

    # Resolve search prefix
    is_direct_url = url.startswith("http://") or url.startswith("https://")

    if dl_type == "audio":
        output_dir = music_path
        ydl_opts = {
            "format": "bestaudio/best",
            "writethumbnail": True,
            "postprocessors": [
                {"key": "FFmpegExtractAudio", "preferredcodec": "mp3", "preferredquality": quality},
                {"key": "FFmpegMetadata", "add_metadata": True},
                {"key": "EmbedThumbnail", "already_have_thumbnail": False},
            ],
            "outtmpl": os.path.join(output_dir, "%(title)s.%(ext)s"),
        }
    else:
        output_dir = video_path
        ydl_opts = {
            "format": "bestvideo+bestaudio/best",
            "merge_output_format": "mp4",
            "outtmpl": os.path.join(output_dir, "%(title)s.%(ext)s"),
        }

    if not is_direct_url:
        if source == "ytmusic":
            ydl_opts["default_search"] = "ytmsearch1"
        else:
            ydl_opts["default_search"] = "ytsearch1"

    ydl_opts.update({
        "noplaylist": True,
        "quiet": True,
        "no_warnings": True,
        "retries": max_retries,
        "socket_timeout": socket_timeout,
        "concurrent_fragment_downloads": concurrent_fragments,
        "progress_hooks": [build_progress_hook(download_id)],
        "postprocessor_hooks": [build_pp_hook(download_id)],
    })

    try:
        emit({"id": download_id, "type": "log", "message": f"Starting download: {url}"})
        emit({"id": download_id, "type": "log", "message": "Resolving metadata..."})
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)
            if info and "entries" in info:
                info = info["entries"][0]
            title = info.get("title", url) if info else url
            # yt-dlp exposes artist under several possible keys depending on the extractor
            artist = (
                (info.get("artist") or info.get("uploader") or info.get("channel") or "")
                if info else ""
            )
            # Duration in seconds — used for exact lrclib.net matching
            duration = int(info.get("duration") or 0) if info else 0
        
        # Fetch lyrics for audio downloads – pass artist + duration for exact matching
        if dl_type == "audio":
            emit({"id": download_id, "type": "log", "message": "Searching lyrics..."})
            fetch_lyrics(title, lyrics_path, download_id, artist=artist, duration=duration)

        # Report success
        emit({"id": download_id, "type": "log", "message": "Finalizing files..."})
        emit({"id": download_id, "type": "done", "title": title, "path": output_dir})


    except yt_dlp.utils.DownloadError as e:
        emit({"id": download_id, "type": "error", "message": str(e)})
    except Exception as e:
        emit({"id": download_id, "type": "error", "message": str(e)})


def main():
    # Signal readiness
    emit({"type": "ready"})

    for raw_line in sys.stdin:
        raw_line = raw_line.strip()
        if not raw_line:
            continue
        try:
            cmd = json.loads(raw_line)
        except json.JSONDecodeError as e:
            emit({"type": "error", "message": f"Invalid JSON: {e}"})
            continue

        action = cmd.get("action", "")
        if action == "download":
            # Run each download in a daemon thread so the main loop stays responsive
            t = threading.Thread(target=handle_download, args=(cmd,), daemon=True)
            t.start()
        elif action == "ping":
            emit({"type": "pong"})
        elif action == "quit":
            break
        else:
            emit({"type": "error", "message": f"Unknown action: {action}"})


if __name__ == "__main__":
    import multiprocessing
    multiprocessing.freeze_support()
    
    main()
