// Exports the room textures (the web build's canvas textures) using the web build's own code.
//   node tools/export_room_art.js
// Starts a local page at http://localhost:8765/ ; open it in a browser. The page runs the room
// builders with a stand-in THREE (only the canvas drawing is real) and posts the textures back:
//   assets/rooms/<name>.png
'use strict';
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const lines = fs.readFileSync(path.join(root, 'reference/last-sale-source.html'), 'utf8').split('\n');
const grab = (from, to) => {
  const a = lines.findIndex(l => l.startsWith(from));
  let b = a; while (!lines[b].startsWith(to)) b++;
  return lines.slice(a, b + 1).join('\n');
};
const html = lines.join('\n');
const rngStart = html.indexOf('window.PullTabRNG=');
const rngCode = html.slice(rngStart, html.indexOf('</script>', rngStart));
const txt = lines.find(l => l.startsWith('function txt('));
// From the construction kit to the end of buildBingo (the line before the light rig).
const kitFrom = lines.findIndex(l => l.startsWith('const mats=new Map();'));
const kitTo = lines.findIndex(l => l.startsWith('const rig={'));
const kit = lines.slice(kitFrom, kitTo).join('\n');

// canvasTexture calls in the order the builders make them.
const NAMES = {
  diner: ['diner_formica', 'diner_tiles', 'diner_dusk', 'diner_neon', 'diner_juke'],
  bar: ['bar_wood', 'bar_planks', 'bar_neon', 'phone_keys', 'phone_screen'],
  bingo: ['bingo_laminate', 'bingo_board', 'bingo_sheet', 'pig_tag'],
};

const page = `<!doctype html><meta charset="utf-8">
<style>
@font-face{font-family:"Alfa Slab One";src:url("/fonts/alfa-slab-one-latin-400-normal.woff2")}
@font-face{font-family:"Oswald";font-weight:400;src:url("/fonts/oswald-latin-400-normal.woff2")}
@font-face{font-family:"Oswald";font-weight:600;src:url("/fonts/oswald-latin-600-normal.woff2")}
@font-face{font-family:"VT323";src:url("/fonts/vt323-latin-400-normal.woff2")}
</style>
<pre id="out">pending</pre>
<script>
${rngCode}
const F={slab:'"Alfa Slab One",Impact,Georgia,serif',cond:'"Oswald","Arial Narrow",Arial,sans-serif',lcd:'"VT323","Courier New",monospace'};
${txt}
// A stand-in for three.js: every property, call and constructor gives another stand-in.
const stub=new Proxy(function(){},{get:(t,k)=>k===Symbol.toPrimitive?()=>0:k==='clone'?()=>stub:stub,apply:()=>stub,construct:()=>stub,set:()=>true});
const THREE=stub;
let shots=[];
function canvasTexture(w,h,draw,opts={}){const cv=document.createElement('canvas');cv.width=w;cv.height=h;draw(cv.getContext('2d'),w,h);shots.push({url:cv.toDataURL('image/png'),w,h,repeat:opts.repeat||null});return stub}
${kit}
const NAMES=${JSON.stringify(NAMES)};
(async()=>{
  await Promise.all(['40px "Alfa Slab One"','600 20px "Oswald"','400 20px "Oswald"','24px "VT323"'].map(f=>document.fonts.load(f)));
  const out={};
  for(const id in NAMES){
    shots=[];scenes[id].build(stub);
    if(shots.length!==NAMES[id].length)throw new Error(id+': '+shots.length+' textures, expected '+NAMES[id].length);
    shots.forEach((s,i)=>out[NAMES[id][i]]=s);
  }
  const r=await fetch('/result',{method:'POST',body:JSON.stringify(out)});
  document.getElementById('out').textContent=r.ok?'done, files written':'save failed';
})().catch(e=>{document.getElementById('out').textContent='ERROR '+e.stack});
</script>`;

const server = require('http').createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/') { res.setHeader('content-type', 'text/html; charset=utf-8'); res.end(page); return; }
  if (req.method === 'GET' && req.url.startsWith('/fonts/')) {
    const f = path.join(root, 'assets/fonts', path.basename(req.url));
    if (fs.existsSync(f)) { res.setHeader('content-type', 'font/woff2'); res.end(fs.readFileSync(f)); return; }
  }
  if (req.method === 'POST' && req.url === '/result') {
    const chunks = [];
    req.on('data', c => chunks.push(c));
    req.on('end', () => {
      const out = JSON.parse(Buffer.concat(chunks).toString());
      const dir = path.join(root, 'assets/rooms');
      fs.mkdirSync(dir, { recursive: true });
      for (const k in out) {
        fs.writeFileSync(path.join(dir, k + '.png'), Buffer.from(out[k].url.split(',')[1], 'base64'));
        console.log(k, out[k].w + 'x' + out[k].h, out[k].repeat ? 'repeat ' + out[k].repeat.join('x') : '');
      }
      res.end('ok');
      server.close();
    });
    return;
  }
  res.statusCode = 404; res.end();
});
server.listen(8765, '127.0.0.1', () => console.log('open http://localhost:8765/'));
