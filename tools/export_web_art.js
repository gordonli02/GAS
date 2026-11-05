// Exports art and synthesized sounds from the web build, using its own code.
//   node tools/export_web_art.js
// Starts a local page at http://localhost:8765/ ; open it in a browser (headless Edge cannot run
// OfflineAudioContext). The page posts its results back and this script writes:
//   packs/core/art/<tier>.png, <tier>_large.png   tier symbols (transparent, square)
//   assets/audio/sfx_*.wav                         the web build's synthesized sounds
//   tests/fixtures/web_ref/*.png                   reference ticket faces for visual comparison
'use strict';
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');
const lines = fs.readFileSync(path.join(root, 'reference/last-sale-source.html'), 'utf8').split('\n');
const grab = (from, to) => { // 1-based inclusive line numbers located by their text
  const a = lines.findIndex(l => l.startsWith(from));
  let b = a; while (!lines[b].startsWith(to)) b++;
  return lines.slice(a, b + 1).join('\n');
};
const html = fs.readFileSync(path.join(root, 'reference/last-sale-source.html'), 'utf8');
const rngStart = html.indexOf('window.PullTabRNG=');
const rngCode = html.slice(rngStart, html.indexOf('</script>', rngStart));
const art = grab("const OUT='#17202a';", 'function drawJarCover') + '\n' + grab('  const W=612,H=372;c.setTransform', '}');
const synth = grab('function noise(', 'function tone(') + '\n' + grab('const sfx={', '};');
const fontUrl = f => '/fonts/' + f;

const page = `<!doctype html><meta charset="utf-8">
<style>
@font-face{font-family:"Alfa Slab One";src:url("${fontUrl('alfa-slab-one-latin-400-normal.woff2')}")}
@font-face{font-family:"Oswald";font-weight:400;src:url("${fontUrl('oswald-latin-400-normal.woff2')}")}
@font-face{font-family:"Oswald";font-weight:600;src:url("${fontUrl('oswald-latin-600-normal.woff2')}")}
@font-face{font-family:"VT323";src:url("${fontUrl('vt323-latin-400-normal.woff2')}")}
</style>
<pre id="out">pending</pre>
<script>
${rngCode}
const F={slab:'"Alfa Slab One",Impact,Georgia,serif',cond:'"Oswald","Arial Narrow",Arial,sans-serif',lcd:'"VT323","Courier New",monospace'};
const WORDS=window.PullTabRNG.WORDS, FORMS=window.PullTabRNG.FORMS;
${art}
let ac=null,noiseBuf=null,muted=false;const bus=()=>ac.destination;
${synth}
const canvas=(w,h,draw)=>{const cv=document.createElement('canvas');cv.width=w;cv.height=h;draw(cv.getContext('2d'));return cv.toDataURL('image/png')};
function wav(buf){const d=buf.getChannelData(0),n=d.length,b=new ArrayBuffer(44+n*2),v=new DataView(b),s=(o,t)=>{for(let i=0;i<t.length;i++)v.setUint8(o+i,t.charCodeAt(i))};
  s(0,'RIFF');v.setUint32(4,36+n*2,true);s(8,'WAVE');s(12,'fmt ');v.setUint32(16,16,true);v.setUint16(20,1,true);v.setUint16(22,1,true);v.setUint32(24,buf.sampleRate,true);v.setUint32(28,buf.sampleRate*2,true);v.setUint16(32,2,true);v.setUint16(34,16,true);s(36,'data');v.setUint32(40,n*2,true);
  for(let i=0;i<n;i++)v.setInt16(44+i*2,Math.max(-1,Math.min(1,d[i]))*32767,true);
  let bin='';const u=new Uint8Array(b);for(let i=0;i<u.length;i++)bin+=String.fromCharCode(u[i]);return 'data:audio/wav;base64,'+btoa(bin)}
async function render(dur,play){const rate=44100;ac=new OfflineAudioContext(1,Math.ceil(rate*dur),rate);
  noiseBuf=ac.createBuffer(1,rate*.4,rate);const d=noiseBuf.getChannelData(0);for(let i=0;i<d.length;i++)d[i]=Math.random()*2-1;
  play();return wav(await ac.startRendering())}
(async()=>{
  const stage=t=>document.getElementById('out').textContent='stage '+t;stage('fonts');
  await Promise.all(['40px "Alfa Slab One"','600 20px "Oswald"','400 20px "Oswald"','24px "VT323"'].map(f=>document.fonts.load(f)));
  stage('symbols');const out={symbols:{},sounds:{},ref:{}};
  for(const key in SYMBOLS)for(const[suffix,ref,px]of[['',50,512],['_large',112,1024]]){
    // The square image spans ±1.2 s; strokes keep the thickness they have at the reference size.
    out.symbols[key+suffix]=canvas(px,px,c=>{const k=px/(2.4*ref);c.scale(k,k);SYMBOLS[key](c,1.2*ref,1.2*ref,ref)});
  }
  stage('sounds');out.sounds.deal=await render(.25,()=>sfx.slide());
  out.sounds.flip=await render(.3,()=>sfx.swish());
  out.sounds.toss=await render(.25,()=>sfx.drop());
  out.sounds.pop=await render(.2,()=>sfx.pop());
  for(const n of[2,3,5,8])out.sounds['win_'+n]=await render(.3+n*.075,()=>sfx.win(n===8?50:n===5?10:n===3?5:1));
  stage('refs');const t={no:1,tier:-1,prize:0,winRow:2,serial:'K482910',rows:[[3,1,4,1],[5,9,2],[6,5,3,5]],marks:[[2,7,1,8],[2,8,1],[8,2,8,4]],verify:null};
  const tw={...t,tier:0,prize:500,verify:'123456'};
  for(const f of FORMS){
    out.ref[f.id+'_front']=canvas(f.kind==='jar'?640:420,f.kind==='jar'?400:600,c=>drawTicketFront(c,f,f.tiers,'K482910'));
    const rows=f.kind==='windows'?[[3,1,4,1],[5,9,2],[6,5,3,5],[2,7,1],[8,2,8,4]]:t.rows;
    const marks=f.kind==='windows'?[[1,2,3,4],[5,6,7],[8,9,0,1],[2,3,4],[5,6,7,8]]:t.marks;
    out.ref[f.id+'_inside_lose']=canvas(f.kind==='jar'?640:420,f.kind==='jar'?400:600,c=>drawInterior(c,f,{...t,rows,marks}));
    out.ref[f.id+'_inside_win']=canvas(f.kind==='jar'?640:420,f.kind==='jar'?400:600,c=>drawInterior(c,f,{...tw,rows,marks}));
  }
  out.ref.flap=canvas(400,572,drawFlap);
  out.ref.tab_3=canvas(400,111,c=>drawTab(c,3));
  out.ref.jar_cover=canvas(372,612,c=>drawJarCover(c,612));
  stage('sending');const r=await fetch('/result',{method:'POST',body:JSON.stringify(out)});
  stage(r.ok?'done, files written':'save failed');
})().catch(e=>{document.getElementById('out').textContent='ERROR '+e.stack});
</script>`;

const save = (dir, name, url) => { fs.mkdirSync(dir, { recursive: true }); fs.writeFileSync(path.join(dir, name), Buffer.from(url.split(',')[1], 'base64')); };
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
      for (const k in out.symbols) save(path.join(root, 'packs/core/art'), k + '.png', out.symbols[k]);
      for (const k in out.sounds) save(path.join(root, 'assets/audio'), 'sfx_' + k + '.wav', out.sounds[k]);
      for (const k in out.ref) save(path.join(root, 'tests/fixtures/web_ref'), k + '.png', out.ref[k]);
      console.log('symbols', Object.keys(out.symbols).length, 'sounds', Object.keys(out.sounds).join(' '), 'refs', Object.keys(out.ref).length);
      res.end('ok');
      server.close();
    });
    return;
  }
  res.statusCode = 404; res.end();
});
server.listen(8765, '127.0.0.1', () => console.log('open http://localhost:8765/'));
