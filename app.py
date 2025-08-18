from flask import Flask, render_template_string, request, jsonify
from pytube import YouTube
import requests
import threading
import os

app = Flask(__name__)

# Global variable to track download progress
progress = {"percent": 0, "status": ""}

HTML_PAGE = """
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Steal YT Videos</title>
<style>
  body { background-color: #111; color: white; font-family: Arial, sans-serif; }
  .floating-panel {
    position: fixed; top: 20%; left: 50%; transform: translate(-50%, -50%);
    background: rgba(0,0,0,0.9); border: 3px solid red; border-radius: 10px;
    padding: 20px; text-align: center; box-shadow: 0 0 20px red;
    width: 350px;
  }
  input { width: 90%; padding: 10px; margin: 10px 0; border-radius: 5px; border: 2px solid red; background: #222; color: white; }
  button { padding: 10px 20px; border: none; border-radius: 5px; background: red; color: white; font-weight: bold; cursor: pointer; box-shadow: 0 0 10px red; }
  button:hover { background: #ff3333; }
  #progress-container { width: 100%; background: #222; border: 2px solid red; border-radius: 5px; margin-top: 15px; height: 25px; }
  #progress-bar { height: 100%; width: 0%; background: red; text-align: center; color: white; line-height: 25px; border-radius: 3px; }
</style>
</head>
<body>
<div class="floating-panel">
  <h2>YouTube to Webhook</h2>
  <form id="videoForm">
    <input type="text" name="youtube_url" placeholder="YouTube Video URL" required><br>
    <input type="text" name="webhook_url" placeholder="Webhook URL" required><br>
    <button type="submit">Send</button>
  </form>
  <div id="progress-container">
    <div id="progress-bar">0%</div>
  </div>
  <p id="status"></p>
</div>

<script>
const form = document.getElementById('videoForm');
form.addEventListener('submit', async (e) => {
  e.preventDefault();
  document.getElementById('status').innerText = "Starting download...";
  
  const formData = new FormData(form);
  const data = {
    youtube_url: formData.get('youtube_url'),
    webhook_url: formData.get('webhook_url')
  };

  fetch('/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  });

  const progressBar = document.getElementById('progress-bar');
  const statusText = document.getElementById('status');

  const interval = setInterval(async () => {
    const res = await fetch('/progress');
    const json = await res.json();
    progressBar.style.width = json.percent + '%';
    progressBar.innerText = json.percent + '%';
    statusText.innerText = json.status;
    if (json.percent >= 100 || json.status.includes("Error") || json.status.includes("Sent")) {
      clearInterval(interval);
    }
  }, 500);
});
</script>
</body>
</html>
"""

def upload_to_transfersh(file_path):
    """Uploads file to transfer.sh and returns the public link"""
    with open(file_path, "rb") as f:
        filename = os.path.basename(file_path)
        response = requests.put(f"https://transfer.sh/{filename}", data=f)
        if response.status_code == 200:
            return response.text.strip()
        else:
            return None

def download_and_send(youtube_url, webhook_url):
    global progress
    try:
        yt = YouTube(youtube_url, on_progress_callback=on_progress)
        stream = yt.streams.filter(progressive=True, file_extension="mp4").order_by('resolution').desc().first()
        filename = f"{yt.title}.mp4"
        progress["status"] = "Downloading..."
        stream.download(filename=filename)

        file_size = os.path.getsize(filename)

        if file_size <= 25 * 1024 * 1024:  # Send directly if under 25MB
            progress["status"] = "Sending to webhook..."
            with open(filename, "rb") as f:
                payload = {"content": f"Video: {yt.title}"}
                files = {"file": f}
                r = requests.post(webhook_url, data=payload, files=files)
            if r.status_code in [200, 204]:
                progress["status"] = "Sent successfully!"
            else:
                progress["status"] = f"Failed to send. Status {r.status_code}: {r.text}"
        else:  # Upload to transfer.sh and send link
            progress["status"] = "File too large, uploading to transfer.sh..."
            link = upload_to_transfersh(filename)
            if link:
                payload = {"content": f"Video too large for Discord (>{file_size//1024//1024}MB). Download here: {link}"}
                r = requests.post(webhook_url, data=payload)
                if r.status_code in [200, 204]:
                    progress["status"] = "Link sent successfully!"
                else:
                    progress["status"] = f"Failed to send link. Status {r.status_code}: {r.text}"
            else:
                progress["status"] = "Error: Failed to upload to transfer.sh"

        progress["percent"] = 100
        os.remove(filename)

    except Exception as e:
        progress["status"] = f"Error: {str(e)}"
        progress["percent"] = 100

def on_progress(stream, chunk, bytes_remaining):
    total_size = stream.filesize
    bytes_downloaded = total_size - bytes_remaining
    percent = int(bytes_downloaded / total_size * 100)
    progress["percent"] = percent
    progress["status"] = f"Downloading... {percent}%"

@app.route("/", methods=["GET", "POST"])
def index():
    if request.method == "POST":
        data = request.get_json()
        youtube_url = data.get("youtube_url")
        webhook_url = data.get("webhook_url")
        threading.Thread(target=download_and_send, args=(youtube_url, webhook_url)).start()
        return '', 202
    return render_template_string(HTML_PAGE)

@app.route("/progress")
def get_progress():
    return jsonify(progress)

if __name__ == "__main__":
    app.run(debug=True)
