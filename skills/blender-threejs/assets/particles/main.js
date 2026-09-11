import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { MeshSurfaceSampler } from 'three/addons/math/MeshSurfaceSampler.js';

const stage = document.querySelector('#stage');
const status = document.querySelector('#status');
const depth = document.querySelector('#depth');
const distance = document.querySelector('#distance');
const pauseButton = document.querySelector('#pause');
const shapeButtons = [...document.querySelectorAll('[data-shape]')];
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
const count = innerWidth < 740 ? 10000 : 18000;
document.querySelector('#count').textContent = `${count.toLocaleString()} 个粒子`;
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(44, 1, 0.1, 60);
camera.position.set(0, 1.2, 8.92);
let renderer;
try {
  renderer = new THREE.WebGLRenderer({ alpha: true, antialias: false, powerPreference: 'high-performance' });
} catch (error) {
  status.textContent = 'WebGL 不可用，请使用支持 WebGL 的浏览器重试。';
  document.querySelectorAll('button,input').forEach(element => { element.disabled = true; });
  throw error;
}
renderer.setPixelRatio(Math.min(devicePixelRatio, 1.8));
renderer.setClearColor(0x000000, 0);
stage.append(renderer.domElement);
const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.055;
controls.enablePan = false;
controls.enableZoom = false;
controls.minPolarAngle = 0.25;
controls.maxPolarAngle = Math.PI - 0.25;
controls.autoRotateSpeed = 0.25;
const timer = new THREE.Timer();
timer.connect(document);
let seed = 47021;
function random() {
  seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
  return seed / 4294967296;
}
const seeds = new Float32Array(count);
const arcs = new Float32Array(count * 3);
const forms = { sphere: new Float32Array(count * 3), ring: new Float32Array(count * 3), scatter: new Float32Array(count * 3) };
for (let i = 0; i < count; i++) {
  const j = i * 3, a = random() * Math.PI * 2, b = Math.acos(2 * random() - 1);
  const radius = 2.05 + (random() - 0.5) * 0.12;
  forms.sphere.set([radius * Math.sin(b) * Math.cos(a), radius * Math.cos(b), radius * Math.sin(b) * Math.sin(a)], j);
  const ringA = a, ringB = random() * Math.PI * 2;
  const tube = 0.48 * Math.sqrt(random());
  const ringR = 1.8 + tube * Math.cos(ringB);
  const x = ringR * Math.cos(ringA), y = tube * Math.sin(ringB), z = ringR * Math.sin(ringA);
  forms.ring.set([x, y * 0.77 - z * 0.64, y * 0.64 + z * 0.77], j);
  const spread = 2.8 + random() * 2.9;
  forms.scatter.set([spread * Math.sin(b) * Math.cos(a), spread * Math.cos(b) * 0.65, spread * Math.sin(b) * Math.sin(a)], j);
  seeds[i] = random();
  arcs.set([(random() - 0.5) * 2.4, (random() - 0.5) * 2.4, (random() - 0.5) * 2.4], j);
}
const geometry = new THREE.BufferGeometry();
geometry.setAttribute('position', new THREE.BufferAttribute(forms.sphere.slice(), 3));
geometry.setAttribute('target', new THREE.BufferAttribute(forms.sphere.slice(), 3));
geometry.setAttribute('aSeed', new THREE.BufferAttribute(seeds, 1));
geometry.setAttribute('aArc', new THREE.BufferAttribute(arcs, 3));
const uniforms = {
  uTime: { value: 0 }, uProgress: { value: 1 }, uDepth: { value: 0.55 },
  uFocus: { value: 9 }, uPixelRatio: { value: renderer.getPixelRatio() },
  uPointer: { value: new THREE.Vector3(100, 100, 100) }, uInfluence: { value: 0 },
};
const material = new THREE.ShaderMaterial({
  uniforms, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
  vertexShader: `
    attribute vec3 target; attribute float aSeed; attribute vec3 aArc;
    uniform float uTime, uProgress, uDepth, uFocus, uPixelRatio, uInfluence;
    uniform vec3 uPointer;
    varying vec3 vColor; varying float vAlpha, vBlur;
    void main() {
      float t = uProgress * uProgress * (3.0 - 2.0 * uProgress);
      float curve = sin(t * 3.14159265);
      vec3 p = mix(position, target, t) + curve * curve * aArc;
      float phase = aSeed * 62.83;
      p += vec3(sin(uTime*.34+phase), cos(uTime*.29+phase*1.3), sin(uTime*.24+phase*.7)) * .045;
      vec3 away = p - uPointer;
      float repel = exp(-dot(away,away) * 1.8) * uInfluence;
      p += normalize(away + vec3(.0001)) * repel * .4;
      vec4 view = modelViewMatrix * vec4(p,1.0);
      float d = max(.3, -view.z);
      float blur = min(1.0, abs(d-uFocus) / 2.6) * uDepth;
      float base = (1.4 + aSeed * 1.7) * uPixelRatio * 8.0 / d;
      float size = base + blur * 18.0 * uPixelRatio;
      gl_PointSize = clamp(size, 1.0, 54.0);
      gl_Position = projectionMatrix * view;
      float warmth = smoothstep(-1.5,1.5,p.x + p.y*.5 + sin(phase)*.4);
      vColor = mix(vec3(.20,.62,.68), vec3(1.0,.62,.29), warmth);
      vColor = mix(vColor, vec3(1.0,.88,.7), pow(aSeed, 8.0)*.6);
      vAlpha = (.55 + aSeed*.45) * pow(base / size, 1.15);
      vBlur = blur;
    }
  `,
  fragmentShader: `
    varying vec3 vColor; varying float vAlpha, vBlur;
    void main() {
      float r = length(gl_PointCoord - .5) * 2.0;
      if (r > 1.0) discard;
      float glow = exp(-r*r*mix(4.0,2.7,vBlur));
      float edge = 1.0 - smoothstep(.65,1.0,r);
      gl_FragColor = vec4(vColor * 1.35, glow * edge * vAlpha);
      #include <tonemapping_fragment>
      #include <colorspace_fragment>
    }
  `,
});
const points = new THREE.Points(geometry, material);
points.frustumCulled = false;
scene.add(points);

const dustGeometry = new THREE.BufferGeometry();
const dustPositions = new Float32Array(160 * 3);
for (let i = 0; i < 160; i++) dustPositions.set([(random()-.5)*18, (random()-.5)*12, (random()-.5)*16], i*3);
dustGeometry.setAttribute('position', new THREE.BufferAttribute(dustPositions, 3));
const dustMaterial = new THREE.ShaderMaterial({
  transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
  uniforms: { uTime: uniforms.uTime, uDepth: uniforms.uDepth, uFocus: uniforms.uFocus, uPixelRatio: uniforms.uPixelRatio },
  vertexShader: `uniform float uTime,uDepth,uFocus,uPixelRatio; varying float vOpacity;
    void main(){vec3 p=position;p.y+=sin(uTime*.1+p.x)*.25;vec4 v=modelViewMatrix*vec4(p,1.);float d=max(.5,-v.z);float blur=min(1.,abs(d-uFocus)/4.)*uDepth;gl_PointSize=(1.5+blur*19.)*uPixelRatio;gl_Position=projectionMatrix*v;vOpacity=(.06+blur*.05)*step(.5,-v.z);}`,
  fragmentShader: `varying float vOpacity;void main(){float r=length(gl_PointCoord-.5)*2.;if(r>1.)discard;gl_FragColor=vec4(.48,.67,.7,exp(-r*r*3.)*(1.-smoothstep(.7,1.,r))*vOpacity);}`,
});
scene.add(new THREE.Points(dustGeometry, dustMaterial));
let currentShape = 'sphere';
let paused = reducedMotion.matches;
let zoomGoal = null;
let disposed = false;
let sequence = 0;
const names = { sphere: '球体', ring: '环形', scatter: '散开', model: '模型' };
const position = geometry.attributes.position;
const target = geometry.attributes.target;
function setShape(shape) {
  if (!forms[shape]) return;
  const progress = uniforms.uProgress.value;
  const t = progress * progress * (3 - 2 * progress);
  const arc = Math.sin(t * Math.PI) ** 2;
  for (let i = 0; i < position.array.length; i++) position.array[i] += (target.array[i] - position.array[i]) * t + arcs[i] * arc;
  position.needsUpdate = true;
  target.array.set(forms[shape]); target.needsUpdate = true;
  uniforms.uProgress.value = reducedMotion.matches ? 1 : 0;
  currentShape = shape;
  shapeButtons.forEach(button => button.setAttribute('aria-pressed', String(button.dataset.shape === shape)));
  const keys = Object.keys(forms);
  document.querySelector('#shape-number').textContent = `${String(keys.indexOf(shape)+1).padStart(2,'0')} / ${String(keys.length).padStart(2,'0')}`;
  document.querySelector('#shape-name').textContent = names[shape];
  status.textContent = reducedMotion.matches ? `${names[shape]} · 已就绪` : paused ? '已暂停 · 播放后重组' : '粒子正在重组';
}
function reform() {
  const keys = Object.keys(forms);
  setShape(keys[(keys.indexOf(currentShape)+1)%keys.length]);
}
function updatePause() {
  pauseButton.textContent = paused ? '▷' : 'Ⅱ';
  pauseButton.setAttribute('aria-label', paused ? '播放动画' : '暂停动画');
  pauseButton.title = paused ? '播放动画' : '暂停动画';
  status.textContent = paused ? '动画已暂停' : uniforms.uProgress.value < 1 ? '粒子正在重组' : `${names[currentShape]} · 自由流动`;
}
const abort = new AbortController();
const events = { signal: abort.signal };
shapeButtons.forEach(button => button.addEventListener('click', () => setShape(button.dataset.shape), events));
document.querySelector('#reform').addEventListener('click', reform, events);
pauseButton.addEventListener('click', () => { paused = !paused; updatePause(); }, events);
depth.addEventListener('input', () => {
  uniforms.uDepth.value = Number(depth.value)/100;
  document.querySelector('#depth-value').textContent = `${depth.value}%`;
}, events);
distance.addEventListener('input', () => { zoomGoal = Number(distance.value); }, events);
renderer.domElement.addEventListener('wheel', event => {
  event.preventDefault();
  zoomGoal = THREE.MathUtils.clamp((zoomGoal ?? camera.position.length()) * Math.exp(event.deltaY*.001), 5, 16);
}, { passive: false, signal: abort.signal });
controls.addEventListener('start', () => { zoomGoal = null; });
const pointer = new THREE.Vector2();
const pointerWorld = new THREE.Vector3();
let pointerActive = false, pressed = null;
renderer.domElement.addEventListener('pointermove', event => {
  const rect = renderer.domElement.getBoundingClientRect();
  pointer.set((event.clientX-rect.left)/rect.width*2-1, -(event.clientY-rect.top)/rect.height*2+1);
  pointerActive = true;
}, events);
renderer.domElement.addEventListener('pointerleave', () => { pointerActive = false; }, events);
renderer.domElement.addEventListener('pointerdown', event => { pressed = { x:event.clientX, y:event.clientY }; }, events);
renderer.domElement.addEventListener('pointerup', event => {
  if (pressed && Math.hypot(event.clientX-pressed.x,event.clientY-pressed.y)<5) reform();
  pressed = null;
}, events);
renderer.domElement.addEventListener('pointercancel', () => { pressed = null; }, events);
reducedMotion.addEventListener('change', () => {
  if(reducedMotion.matches) { paused = true; uniforms.uProgress.value = 1; updatePause(); }
}, events);

function releaseModel(model) {
  const geometries = new Set(), materials = new Set(), textures = new Set(), images = new Set();
  model.traverse(object => {
    if (object.geometry) geometries.add(object.geometry);
    for (const m of (Array.isArray(object.material) ? object.material : object.material ? [object.material] : [])) {
      materials.add(m);
      for (const value of Object.values(m)) if (value?.isTexture) { textures.add(value); if(value.source.data) images.add(value.source.data); }
    }
  });
  geometries.forEach(g=>g.dispose()); materials.forEach(m=>m.dispose()); textures.forEach(t=>t.dispose()); images.forEach(image=>image.close?.());
}
function sampleModel(model) {
  model.updateMatrixWorld(true);
  const vertices = [];
  const v = new THREE.Vector3();
  model.traverse(object => {
    if(!object.isMesh) return;
    if(object.isSkinnedMesh || object.isInstancedMesh || object.morphTargetInfluences?.length) throw new Error('请载入普通静态网格 GLB；骨架、实例或形变动画暂不采样。');
    const attribute = object.geometry.attributes.position;
    const index = object.geometry.index;
    const n = index ? index.count : attribute.count;
    if(vertices.length+n*3>3000000) throw new Error('模型面数过多，请简化后再载入。');
    for(let i=0;i<n;i++) { v.fromBufferAttribute(attribute,index?index.getX(i):i).applyMatrix4(object.matrixWorld); vertices.push(v.x,v.y,v.z); }
  });
  if(!vertices.length || vertices.some(value=>!Number.isFinite(value))) throw new Error('GLB 没有可采样的有效网格。');
  const g = new THREE.BufferGeometry();
  const m = new THREE.MeshBasicMaterial();
  try {
    g.setAttribute('position',new THREE.Float32BufferAttribute(vertices,3));
    g.computeBoundingBox();
    const size=g.boundingBox.getSize(v).length();
    if(size<1e-6) throw new Error('模型尺寸无效。');
    g.center(); g.scale(5/size,5/size,5/size);
    const sampler = new MeshSurfaceSampler(new THREE.Mesh(g,m)).setRandomGenerator(random).build();
    const sampled = new Float32Array(count*3);
    for(let i=0;i<count;i++) { sampler.sample(v); if(!Number.isFinite(v.x+v.y+v.z)) throw new Error('模型表面无法采样。'); sampled.set(v.toArray(),i*3); }
    return sampled;
  } finally { g.dispose(); m.dispose(); }
}
const upload = document.querySelector('#upload');
const fileInput = document.querySelector('#file');
upload.addEventListener('click',()=>fileInput.click(),events);
fileInput.addEventListener('change',async()=>{
  const file = fileInput.files[0]; if(!file)return;
  const request = ++sequence;
  upload.disabled=true;status.textContent='正在读取模型';
  let gltf;
  try {
    if(file.size>50*1024*1024)throw new Error('请使用小于 50 MB 的 GLB。');
    const data=await file.arrayBuffer();
    if(data.byteLength<12 || new DataView(data).getUint32(0,true)!==0x46546c67)throw new Error('文件不是有效 GLB，请重新选择。');
    const manager=new THREE.LoadingManager();
    manager.setURLModifier(url=>{if(!url.startsWith('blob:')&&!url.startsWith('data:'))throw new Error('请导出内嵌资源的 GLB。');return url;});
    gltf=await new GLTFLoader(manager).parseAsync(data,'');
    if(disposed || request!==sequence)return;
    forms.model=sampleModel(gltf.scene);
    document.querySelector('[data-shape=model]').hidden=false;
    setShape('model');
  } catch(error) { if(!disposed && request===sequence)status.textContent=error.message; }
  finally {
    if(gltf) for(const model of gltf.scenes)releaseModel(model);
    if(!disposed && request===sequence) {upload.disabled=false;fileInput.value='';}
  }
},events);
function resize() {
  const width=stage.clientWidth,height=stage.clientHeight;
  renderer.setSize(width,height);camera.aspect=width/height;
  camera.clearViewOffset();
  if(width>740) camera.setViewOffset(width,height,-width*.135,0,width,height);
  else camera.setViewOffset(width,height,0,-height*.055,width,height);
  camera.updateProjectionMatrix();
}
const observer=new ResizeObserver(resize);observer.observe(stage);resize();updatePause();
renderer.setAnimationLoop(()=>{
  timer.update();const delta=Math.min(timer.getDelta(),.05);
  if(!paused) {
    uniforms.uTime.value+=delta;
    const previous=uniforms.uProgress.value;
    uniforms.uProgress.value=Math.min(1,previous+delta/2.8);
    if(previous<1 && uniforms.uProgress.value===1)status.textContent=`${names[currentShape]} · 自由流动`;
  }
  if(zoomGoal!==null){
    const radius=THREE.MathUtils.damp(camera.position.length(),zoomGoal,5,delta);
    camera.position.setLength(radius);
    if(Math.abs(radius-zoomGoal)<.003){camera.position.setLength(zoomGoal);zoomGoal=null;}
  }
  controls.autoRotate=!paused && !reducedMotion.matches;
  controls.update(delta);
  uniforms.uFocus.value=camera.position.length();
  distance.value=uniforms.uFocus.value.toFixed(1);document.querySelector('#distance-value').textContent=distance.value;
  uniforms.uInfluence.value=THREE.MathUtils.damp(uniforms.uInfluence.value,pointerActive?1:0,4,delta);
  if(pointerActive){
    pointerWorld.set(pointer.x,pointer.y,.5).unproject(camera).sub(camera.position).normalize();
    const normal=camera.position.clone().normalize();
    const length=-camera.position.dot(normal)/pointerWorld.dot(normal);
    uniforms.uPointer.value.copy(pointerWorld.multiplyScalar(length).add(camera.position));
  }
  renderer.render(scene,camera);
  // 公开只读场景状态，用于观察真实渲染与验证交互。
  stage.dataset.shape=currentShape;stage.dataset.progress=uniforms.uProgress.value.toFixed(3);stage.dataset.time=uniforms.uTime.value.toFixed(3);
  stage.dataset.distance=uniforms.uFocus.value.toFixed(3);stage.dataset.depth=String(uniforms.uDepth.value);
  stage.dataset.camera=camera.position.toArray().map(value=>value.toFixed(3)).join(',');
  stage.dataset.particles=String(count);stage.dataset.drawCalls=String(renderer.info.render.calls);stage.dataset.geometries=String(renderer.info.memory.geometries);
});
window.addEventListener('pagehide',()=>{
  disposed=true;sequence++;abort.abort();renderer.setAnimationLoop(null);observer.disconnect();controls.dispose();timer.dispose();geometry.dispose();material.dispose();dustGeometry.dispose();dustMaterial.dispose();renderer.dispose();
},{once:true});
