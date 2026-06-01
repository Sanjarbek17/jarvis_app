import os
import re
import subprocess
import sys
import urllib.request
import urllib.parse

def run_command(cmd, cwd=None):
    print(f"Running: {cmd}")
    process = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, cwd=cwd)
    for line in process.stdout:
        print(line, end="")
    process.wait()
    if process.returncode != 0:
        print(f"Command failed with exit code {process.returncode}")
        sys.exit(1)

def increment_version():
    pubspec_path = "pubspec.yaml"
    if not os.path.exists(pubspec_path):
        print("Error: pubspec.yaml not found in current directory.")
        sys.exit(1)
        
    with open(pubspec_path, "r") as f:
        content = f.read()
        
    match = re.search(r"^version:\s*([0-9\.]+)\+(\d+)", content, re.MULTILINE)
    if not match:
        print("Error: Could not parse version and build number from pubspec.yaml")
        sys.exit(1)
        
    base_version = match.group(1)
    build_number = int(match.group(2))
    new_build_number = build_number + 1
    new_version = f"{base_version}+{new_build_number}"
    
    # Replace the version line in pubspec.yaml
    new_content = re.sub(
        r"^version:\s*[^\s#]+",
        f"version: {new_version}",
        content,
        flags=re.MULTILINE
    )
    
    with open(pubspec_path, "w") as f:
        f.write(new_content)
        
    print(f"Incremented version in pubspec.yaml: {base_version}+{build_number} -> {new_version}")
    return new_version

def upload_apk(apk_path, version, server_url):
    print(f"Uploading {apk_path} (version: {version}) to {server_url}...")
    
    # Boundary for multipart form data
    boundary = '----WebKitFormBoundary7MA4YWxkTrZu0gW'
    
    # Prepare body
    with open(apk_path, 'rb') as f:
        file_content = f.read()
        
    parts = []
    parts.append(f'--{boundary}'.encode('utf-8'))
    parts.append(b'Content-Disposition: form-data; name="file"; filename="app-release.apk"')
    parts.append(b'Content-Type: application/vnd.android.package-archive')
    parts.append(b'')
    parts.append(file_content)
    parts.append(f'--{boundary}--'.encode('utf-8'))
    
    body = b'\r\n'.join(parts)
    
    # Build request url
    params = urllib.parse.urlencode({'version': version})
    url = f"{server_url}/upload_apk?{params}"
    
    req = urllib.request.Request(url, data=body, method='POST')
    req.add_header('Content-Type', f'multipart/form-data; boundary={boundary}')
    req.add_header('Content-Length', str(len(body)))
    
    try:
        with urllib.request.urlopen(req) as response:
            res_body = response.read().decode('utf-8')
            print(f"Upload Response: {res_body}")
    except Exception as e:
        print(f"Error uploading APK: {e}")
        if hasattr(e, 'read'):
            print(e.read().decode('utf-8'))
        sys.exit(1)

def trigger_update(server_url):
    url = f"{server_url}/update"
    print(f"Triggering update command via {url}...")
    req = urllib.request.Request(url, method='POST')
    try:
        with urllib.request.urlopen(req) as response:
            res_body = response.read().decode('utf-8')
            print(f"Update Trigger Response: {res_body}")
    except Exception as e:
        print(f"Error triggering update: {e}")
        if hasattr(e, 'read'):
            print(e.read().decode('utf-8'))
        sys.exit(1)

def main():
    server_url = "http://95.46.161.3:10555"
    
    # 1. Auto-increment build number
    print("Step 1: Incrementing build number in pubspec.yaml...")
    version = increment_version()
    
    # 2. Build APK
    print("Step 2: Building Release APK...")
    run_command("flutter build apk --release")
    
    # 3. Locate APK
    apk_path = os.path.join("build", "app", "outputs", "flutter-apk", "app-release.apk")
    if not os.path.exists(apk_path):
        # Try relative paths/alternative paths if any
        alternative_path = os.path.join("build", "app", "outputs", "apk", "release", "app-release.apk")
        if os.path.exists(alternative_path):
            apk_path = alternative_path
        else:
            print(f"Error: APK not found at {apk_path}")
            sys.exit(1)
            
    # 4. Upload APK
    print("Step 3: Uploading APK to backend server...")
    upload_apk(apk_path, version, server_url)
    
    # 5. Trigger update
    print("Step 4: Triggering update to connected phone...")
    trigger_update(server_url)
    
    print("All tasks completed successfully!")

if __name__ == "__main__":
    main()
