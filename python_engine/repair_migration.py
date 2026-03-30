import os
import hashlib
from pathlib import Path
import re

def generate_loc_id(file_name):
    hash_object = hashlib.sha256(file_name.encode())
    return f"loc_{hash_object.hexdigest()[:10]}"

def get_safe_filename(id_str):
    # This matches the dart MediaCacheService.getSafeFilename
    return re.sub(r'[^a-zA-Z0-9_-]', '_', id_str)

def repair_migration(music_dir, lyrics_dir):
    print("🛠️ Starting Migration Repair...")
    music_path = Path(music_dir)
    lyrics_path = Path(lyrics_dir)
    
    if not music_path.exists() or not lyrics_path.exists():
        print("❌ Directories not found!")
        return

    # 1. Repair Lyrics files
    # We iterate over all .lrc files that don't start with loc_
    repaired_lyrics = 0
    for lrc_file in lyrics_path.glob("*.lrc"):
        if lrc_file.stem.startswith("loc_"):
            continue
            
        old_stem = lrc_file.stem
        loc_id = generate_loc_id(old_stem)
        
        # Check if corresponding loc_ file exists in music dir
        # Wait, if old_stem was exactly the filename of music file
        mp3_file = music_path / f"{loc_id}.mp3"
        m4a_file = music_path / f"{loc_id}.m4a"
        if mp3_file.exists() or m4a_file.exists():
            new_lrc_path = lyrics_path / f"{loc_id}.lrc"
            try:
                lrc_file.rename(new_lrc_path)
                print(f"✅ Repaired Lyric: {old_stem}.lrc -> {loc_id}.lrc")
                repaired_lyrics += 1
            except Exception as e:
                print(f"❌ Failed to rename {lrc_file.name}: {e}")

    # 2. Repair Thumbnail Caches
    # Look for art_*.jpg in the music_dir (because the cache was likely pointing there)
    # The old cached arts were named art_D__ACER_Music_FileName_mp3.jpg
    # By hashing the filename extracted from the lrc file, or by brute-forcing from Music tags...
    # Since we can't easily reverse 'art_x_y_z.jpg', we can construct what the safe ID *would* have been
    repaired_arts = 0
    
    # We can use the lyrics stems we know about to guess the old paths
    # Or, we can just iterate all loc_ files, read their ID3 title, and construct the old path to see if it exists!
    # Because 'title' is usually the filename!
    try:
        from mutagen.easyid3 import EasyID3
        from mutagen.mp4 import MP4
    except ImportError:
        print("⚠️ mutagen not installed. Basic stem matching will be used for art.")

    for audio_file in music_path.glob("loc_*.mp3"):
        title_guess = None
        try:
            tags = EasyID3(audio_file)
            if 'title' in tags:
                title_guess = tags['title'][0]
        except:
            pass
            
        if title_guess:
            # Reconstruct what the safe cache ID would have been
            # Old audio path was likely D:\ACER\Music\{title}.mp3
            old_path_guess = str(music_path / f"{title_guess}.mp3")
            safe_id = get_safe_filename(old_path_guess)
            
            old_art_path = music_path / f"art_{safe_id}.jpg"
            if old_art_path.exists():
                new_art_path = music_path / f"art_{audio_file.stem}.jpg"
                try:
                    old_art_path.rename(new_art_path)
                    print(f"✅ Repaired Art: {old_art_path.name} -> {new_art_path.name}")
                    repaired_arts += 1
                except Exception as e:
                    pass

    print(f"✨ Repair complete. Fixed {repaired_lyrics} lyrics and {repaired_arts} arts.")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("music", help="Music folder path")
    parser.add_argument("lyrics", help="Lyrics folder path")
    args = parser.parse_args()
    repair_migration(args.music, args.lyrics)
