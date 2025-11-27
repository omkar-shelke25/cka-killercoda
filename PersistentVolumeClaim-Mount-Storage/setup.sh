#!/bin/bash
set -euo pipefail

# Create namespace
kubectl create ns nginx-cyperpunk

# Create the local storage directory on node01
ssh node01 "mkdir -p /mnt/disks/ssd1 && chmod 777 /mnt/disks/ssd1"

# Create directory structure for manifests
mkdir -p /src/nginx

# Create PersistentVolume manifest
cat <<'EOF' > /src/nginx/nginx-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nginx-pv
spec:
  capacity:
    storage: 700Mi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-path
  local:
    path: /mnt/disks/ssd1
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - node01
EOF

# Create Deployment manifest WITHOUT volumes/volumeMounts (student needs to add)
cat <<'EOF' > /src/nginx/nginx-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-scifi-portal
  namespace: nginx-cyperpunk
  labels:
    app: nginx-scifi
    tier: frontend
    project: scifi-portal
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-scifi
  template:
    metadata:
      labels:
        app: nginx-scifi
        tier: frontend
        project: scifi-portal
    spec:
      containers:
        - name: nginx-scifi
          image: nginx
          ports:
            - containerPort: 80
              name: nginx-server
EOF

# Create Service manifest
cat <<'EOF' > /src/nginx/nginx-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-scifi-portal-service
  namespace: nginx-cyperpunk
  labels:
    app: nginx-scifi
    tier: frontend
    project: scifi-portal
spec:
  type: NodePort
  selector:
    app: nginx-scifi
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30339
EOF

# Apply the PV and Service (these are already provided)
kubectl apply -f /src/nginx/nginx-pv.yaml
sleep 3

kubectl apply -f /src/nginx/nginx-deployment.yaml
kubectl apply -f /src/nginx/nginx-service.yaml


#!/bin/bash
set -euo pipefail

# Usage: ./create_index_on_node01.sh
# Requires: passwordless SSH access to node01 or ability to sudo on remote via your SSH user.

REMOTE="node01"
TARGET_DIR="/mnt/disks/ssd1"
TARGET_FILE="${TARGET_DIR}/index.html"

echo "Ensuring ${TARGET_DIR} exists on ${REMOTE}..."
ssh "${REMOTE}" "sudo mkdir -p '${TARGET_DIR}' && sudo chmod 755 '${TARGET_DIR}'"

echo "Writing index.html to ${REMOTE}:${TARGET_FILE} ..."
ssh "${REMOTE}" "sudo tee '${TARGET_FILE}' > /dev/null" <<'HTML'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>NGINX — Matrix Rain (Enhanced)</title>
<link href="https://fonts.googleapis.com/css2?family=Share+Tech+Mono&family=Orbitron:wght@400;700&display=swap" rel="stylesheet">
<style>
  :root{
    --bg:#00090a;
    --glow:#00ff7a;
    --accent: #64ffb5;
    --panel: rgba(0,0,0,0.36);
    --glass: rgba(255,255,255,0.02);
  }

  html,body{height:100%;margin:0;font-family:'Share Tech Mono', monospace, system-ui;background:linear-gradient(180deg,#00110b 0%,var(--bg) 60%);color:var(--glow);-webkit-font-smoothing:antialiased;-moz-osx-font-smoothing:grayscale;overflow:hidden}
  .app { position:relative; height:100vh; width:100%; display:flex; align-items:center; justify-content:center; gap:24px; padding:24px; box-sizing:border-box; }

  canvas { position:fixed; inset:0; width:100%; height:100%; display:block; z-index:0; }

  .card { position:relative; z-index:5; width:min(980px, 92%); color:var(--glow); text-align:center; border-radius:14px; padding:28px; background: linear-gradient(180deg, rgba(0,0,0,0.45), rgba(0,0,0,0.22)); border: 1px solid rgba(0,255,122,0.06); box-shadow: 0 12px 50px rgba(0,0,0,0.7), inset 0 0 30px rgba(0,255,122,0.02); backdrop-filter: blur(6px) saturate(120%); }

  .title-wrap { display:flex; align-items:center; justify-content:center; gap:18px; flex-wrap:wrap; }
  h1 { font-family: 'Orbitron', system-ui, sans-serif; margin:0; font-size: clamp(20px, 4.8vw, 54px); letter-spacing:6px; line-height:1; color:var(--glow); position:relative; text-transform:uppercase; padding:6px 12px; filter: drop-shadow(0 0 10px rgba(0,255,122,0.15)); }
  h1::before{ content: ""; position:absolute; inset:0; border-radius:8px; z-index:-1; box-shadow: 0 0 40px rgba(0,255,122,0.06), 0 0 90px rgba(0,255,122,0.03); opacity:0.6; transform:scale(1.02); transition:opacity .35s ease; }

  .glitch { position:relative; display:inline-block; }
  .glitch::after, .glitch::before{ content: attr(data-text); position:absolute; left:0; top:0; width:100%; clip-path: inset(0 0 0 0); opacity:0.85; }
  .glitch::before{ color:#7fffc2; transform:translate(-2px,-1px); mix-blend-mode: screen; animation:glitch-1 2.8s infinite linear; opacity:0.55 }
  .glitch::after { color:#00b36a; transform:translate(2px,1px); mix-blend-mode: screen; animation:glitch-2 3.6s infinite linear; opacity:0.55 }
  @keyframes glitch-1 { 0% { clip-path: inset(0 0 90% 0) } 30% { clip-path: inset(10% 0 10% 0)} 60% { clip-path: inset(50% 0 0 0)} 100% { clip-path: inset(0 0 0 0)}}
  @keyframes glitch-2 { 0% { clip-path: inset(90% 0 0 0) } 25% { clip-path: inset(40% 0 40% 0) } 65% { clip-path: inset(10% 0 70% 0) } 100% { clip-path: inset(0 0 0 0)}}

  .lead { margin:8px 0 0; color: rgba(100,255,175,0.95); font-size:clamp(12px,1.3vw,18px) }
  .chips { display:flex; gap:10px; justify-content:center; margin-top:16px; flex-wrap:wrap }
  .chip { background: linear-gradient(90deg, rgba(0,0,0,0.26), rgba(255,255,255,0.02)); border-radius:999px; padding:8px 14px; font-size:13px; border:1px solid rgba(0,255,122,0.06); color:#bfffe0; box-shadow: 0 6px 18px rgba(0,0,0,0.6); }

  .foot { margin-top:14px; font-size:12px; color: rgba(0,255,122,0.42) }

  .controls { display:flex; gap:8px; justify-content:center; margin-top:18px; align-items:center; flex-wrap:wrap }
  .range { -webkit-appearance:none; height:6px; background:linear-gradient(90deg,#052 0%, #032 100%); border-radius:999px; width:180px; }
  .btn { background: linear-gradient(90deg, rgba(0,0,0,0.22), rgba(255,255,255,0.02)); border:1px solid rgba(0,255,122,0.06); color:#bfffe0; padding:8px 12px; border-radius:8px; cursor:pointer; box-shadow: 0 6px 18px rgba(0,0,0,0.45); }
  .btn:active{ transform:translateY(1px) }

  .scanline { position:fixed; inset:0; background-image: linear-gradient(rgba(0,0,0,0) 92%, rgba(0,0,0,0.06) 100%); background-size:100% 4px; z-index:2; pointer-events:none; mix-blend-mode: overlay }
  .vignette { position:fixed; inset:0; pointer-events:none; z-index:3; background: radial-gradient(ellipse at center, rgba(0,0,0,0) 35%, rgba(0,0,0,0.6) 100%); mix-blend-mode:multiply }

  @media (max-width:420px){
    .card{ padding:16px; border-radius:10px }
    h1{ letter-spacing:4px; font-size:28px }
  }
</style>
</head>
<body>
<canvas id="rain" aria-hidden="true"></canvas>
<canvas id="sparks" aria-hidden="true"></canvas>

<div class="scanline" aria-hidden="true"></div>
<div class="vignette" aria-hidden="true"></div>

<div class="app" role="main" aria-label="Matrix splash">
  <div class="card" role="region" aria-labelledby="title">
    <div class="title-wrap">
      <h1 id="title" class="glitch" data-text="SYSTEM ONLINE">SYSTEM ONLINE</h1>
    </div>

    <p class="lead">Node: <strong id="node">k8s-node-01</strong> &nbsp; • &nbsp; Serving: <strong>/usr/share/nginx/html</strong></p>

    <div class="chips" aria-hidden="true">
      <div class="chip">Status: <strong>ACTIVE</strong></div>
      <div class="chip">Mode: <strong>Matrix Rain</strong></div>
      <div class="chip">Protocol: <strong>HTTP/1.1</strong></div>
    </div>

    <div class="controls" aria-hidden="true">
      <button class="btn" id="toggleBtn" title="Toggle animation (Esc)">Pause</button>
      <label style="font-size:13px;color:rgba(0,255,122,0.6)">Speed</label>
      <input id="speed" class="range" type="range" min="1" max="8" value="3" />
      <button class="btn" id="themeBtn" title="Toggle color hint">Alt Hue</button>
    </div>

    <div class="foot" aria-hidden="true">Press <kbd>Esc</kbd> to pause/resume. Built for NGINX + Kubernetes</div>
  </div>
</div>

<script>
(() => {
  const rainCanvas = document.getElementById('rain');
  const sparksCanvas = document.getElementById('sparks');
  const rainCtx = rainCanvas.getContext('2d', { alpha: true });
  const sparksCtx = sparksCanvas.getContext('2d', { alpha: true });

  let W, H;
  const baseFont = 18;
  let cols, drops;
  let running = true;
  let speedMultiplier = 1;
  let altHue = false;

  const charset = 'アイウエオカカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  const sparks = [];
  function resize() {
    W = rainCanvas.width = window.innerWidth;
    H = rainCanvas.height = window.innerHeight;
    sparksCanvas.width = W;
    sparksCanvas.height = H;
    rainCtx.textBaseline = 'top';
    rainCtx.font = `${baseFont}px monospace`;
    cols = Math.floor(W / (baseFont * 0.6));
    drops = new Array(cols).fill(0).map(() => Math.random() * H);
  }

  function drawRain() {
    rainCtx.fillStyle = 'rgba(0,8,0,0.12)';
    rainCtx.fillRect(0,0,W,H);

    rainCtx.shadowColor = altHue ? 'rgba(120,200,255,0.16)' : 'rgba(0,255,122,0.16)';
    rainCtx.shadowBlur = 12;

    for (let i=0;i<cols;i++){
      const x = i * (baseFont * 0.6);
      const y = drops[i] * (baseFont * 0.9);

      rainCtx.fillStyle = altHue ? 'rgba(200,240,255,0.95)' : 'rgba(180,255,200,0.95)';
      rainCtx.fillText(charset.charAt(Math.floor(Math.random()*charset.length)), x, y);

      rainCtx.fillStyle = altHue ? 'rgba(120,180,255,0.55)' : 'rgba(48,200,96,0.55)';
      rainCtx.fillText(charset.charAt(Math.floor(Math.random()*charset.length)), x, y - baseFont * 0.9);

      drops[i] += (0.9 + Math.random()*1.6) * (speedMultiplier);
      if (drops[i] * (baseFont * 0.9) > H && Math.random() > 0.975 / speedMultiplier) {
        drops[i] = 0;
        if (Math.random() > 0.7) spawnSparks(x + (baseFont*0.2), H - 30);
      }
    }

    rainCtx.globalCompositeOperation = 'source-over';
    const g = rainCtx.createRadialGradient(W/2, H/2, Math.min(W,H)/4, W/2, H/2, Math.max(W,H));
    g.addColorStop(0, 'rgba(0,0,0,0)');
    g.addColorStop(1, 'rgba(0,0,0,0.36)');
    rainCtx.fillStyle = g;
    rainCtx.fillRect(0,0,W,H);
  }

  function spawnSparks(x,y){
    const count = 6 + Math.floor(Math.random()*8);
    for (let i=0;i<count;i++){
      sparks.push({
        x: x + (Math.random()-0.5)*12,
        y: y + (Math.random()-0.5)*8,
        vx: (Math.random()-0.5) * 2.8,
        vy: -Math.random()*2.6 - 0.6,
        life: 30 + Math.random()*40,
        size: 1 + Math.random()*2
      });
    }
  }

  function drawSparks(){
    sparksCtx.clearRect(0,0,W,H);
    for (let i=sparks.length-1;i>=0;i--){
      const p = sparks[i];
      p.x += p.vx * (0.9 + speedMultiplier*0.2);
      p.y += p.vy;
      p.vy += 0.06;
      p.life--;
      const alpha = Math.max(0, p.life / 80);
      sparksCtx.globalAlpha = alpha;
      sparksCtx.fillStyle = altHue ? 'rgba(160,210,255,1)' : 'rgba(160,255,190,1)';
      sparksCtx.beginPath();
      sparksCtx.arc(p.x, p.y, p.size, 0, Math.PI*2);
      sparksCtx.fill();
      if (p.life <= 0) sparks.splice(i,1);
    }
    sparksCtx.globalAlpha = 1;
  }

  let raf = null;
  function loop(){
    if (running){
      drawRain();
      drawSparks();
    } else {
      rainCtx.fillStyle = 'rgba(0, 0, 0, 0.22)';
      rainCtx.fillRect(0,0,W,H);
    }
    raf = requestAnimationFrame(loop);
  }

  const toggleBtn = document.getElementById('toggleBtn');
  const speedRange = document.getElementById('speed');
  const themeBtn = document.getElementById('themeBtn');

  toggleBtn.addEventListener('click', () => {
    running = !running;
    toggleBtn.textContent = running ? 'Pause' : 'Resume';
  });

  speedRange.addEventListener('input', (e) => {
    const v = Number(e.target.value);
    speedMultiplier = 0.4 + (v / 3.5);
  });

  themeBtn.addEventListener('click', () => {
    altHue = !altHue;
    document.documentElement.style.setProperty('--glow', altHue ? '#7fe0ff' : '#00ff7a');
    themeBtn.textContent = altHue ? 'Default Hue' : 'Alt Hue';
  });

  window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      running = !running;
      toggleBtn.textContent = running ? 'Pause' : 'Resume';
    }
  });

  (function setNodeFromAttr(){
    const el = document.getElementById('node');
    if(!el) return;
    const attr = el.getAttribute('data-node');
    if(attr) el.textContent = attr;
  })();

  resize();
  loop();
  window.addEventListener('resize', () => { resize(); }, { passive:true });

})();
</script>
</body>
</html>
HTML

echo "Setting permissions on ${REMOTE}:${TARGET_FILE} ..."
ssh "${REMOTE}" "sudo chown root:root '${TARGET_FILE}' && sudo chmod 644 '${TARGET_FILE}'"

echo "Done. Verify with: ssh ${REMOTE} 'ls -l ${TARGET_FILE} && sudo cat ${TARGET_FILE} | head -n 5'"




echo "✅ Setup complete!"
echo ""
echo "📁 Available manifests in /src/nginx/:"
echo "   - nginx-pv.yaml (PersistentVolume - already applied)"
echo "   - nginx-deployment.yaml (needs volume mount configuration)"
echo "   - nginx-service.yaml (NodePort service - already applied)"
echo ""
echo "📋 Your task:"
echo "   1. Create a PVC manifest and bind it to the existing PV"
echo "   2. Update the deployment to mount the PVC"
echo "   3. Deploy the application"
