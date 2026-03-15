import sys
import os
import json
import subprocess

script_path = r"d:\File Mata Kuliah\Projek\streamly\resonance_app\python_engine\resonance_downloader.py"
cmd = [sys.executable, script_path]

p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

test_cmd = json.dumps({
    "action": "download", 
    "id": "t1", 
    "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ", 
    "type": "audio", 
    "source": "url", 
    "music_path": "./music", 
    "video_path": "./music", 
    "lyrics_path": "./lyrics", 
    "quality": "192", 
    "max_retries": 1, 
    "socket_timeout": 30, 
    "concurrent_fragments": 1
})

p.stdin.write(test_cmd + "\n")
p.stdin.flush()

# Read until 'done' or 'error'
while True:
    line = p.stdout.readline()
    if not line:
        break
    print("STDOUT:", line.strip())
    
p.stdin.write(json.dumps({"action": "quit"}) + "\n")
p.stdin.flush()
p.wait()
print("STDERR:", p.stderr.read())

