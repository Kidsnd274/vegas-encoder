// B0 fixtures are authored from the read-only mockup model, not Windows facts.
// No FFmpeg execution, network request, or production compiler lives here.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const checkOnly = process.argv.includes('--check');
const writeFile = (file, text) => {
  if (checkOnly) {
    if (fs.readFileSync(file,'utf8').replace(/\r\n/g,'\n') !== text) throw new Error(`Stale B0 fixture: ${path.relative(root,file)}`);
  } else {
    fs.mkdirSync(path.dirname(file),{recursive:true});
    fs.writeFileSync(file,text);
  }
};
const context = vm.createContext({});
context.window = context;
for (const name of ['avoptions.js', 'model.js']) {
  vm.runInContext(fs.readFileSync(path.join(root, 'docs/product/design/shared', name), 'utf8'), context);
}
const ve = context.VE;
// Fixture annotations only: the product compiler will emit these facts in B2.
// No additional edited-state fixtures or Dart domain implementation are added.
const annotateTokens = (tokens, res) => {
  const fields = {
    video: {'-c:v':'video.encoder', '-preset':'video.speed', '-tune':'video.tune',
      '-crf':'video.quality', '-cq':'video.quality', '-global_quality':'video.quality',
      '-rc':'video.mode', '-qp':'video.qp', '-profile:v':'video.profile',
      '-pix_fmt':res.mode === 'profile' ? 'video.profile' : 'video.depth',
      '-g':res.mode === 'lossless' ? 'video.mode' : 'video.gopSec',
      '-color_primaries':'video.color', '-color_trc':'video.color', '-colorspace':'video.color', '-color_range':'video.color',
      '-tag:v':'video.encoder', '-vendor':'video.encoder', '-level':'video.mode', '-slices':'video.mode', '-slicecrc':'video.mode',
      '-b:v':['cq','crf'].includes(res.mode) ? 'video.mode' : 'video.bitrateK',
      '-minrate':'video.bitrateK', '-maxrate':res.mode === 'cbr' ? 'video.bitrateK' : 'video.maxrateK',
      '-bufsize':res.mode === 'cbr' ? 'video.bitrateK' : 'video.maxrateK', '-multipass':'video.multipass'},
    audio: {'-c:a':'audio[0].encoder', '-b:a':'audio[0].bitrateK',
      '-vbr':res.amode === 'bitrate' ? 'audio[0].mode' : 'audio[0].vbr',
      '-compression_level':'audio[0].level', '-ar':'audio[0].sampleRate', '-ac':'audio[0].channels'},
    mux: {'-movflags':'container.faststart', '-f':'container.format'},
  };
  let field = null, stream = 'video';
  return tokens.map((token, i) => {
    if (token.role === 'video' || token.role === 'audio') stream = token.role;
    if (token.role === 'extra') field = stream === 'video' ? 'video.extra' : 'audio[0].extra';
    else if (!fields[token.role]) field = null;
    else if (token.text.startsWith('-')) {
      field = fields[token.role][token.text];
      if (!field) throw new Error(`Unannotated fixture option ${token.text}`);
    } else if (i === 0 || tokens[i-1].role !== token.role) throw new Error('Orphan fixture value');
    return {...token, field};
  });
};
// Authored sample facts, not Windows probes. Audio formats are encoder-side
// FFmpeg sample formats; bits are useful precision, not storage/packet bitrate.
const authoredSignals = {
  'yt-h264': ['yuv420p',8,'4:2:0',true,'fltp',32,true],
  'yt-hevc-nv': ['p010le',10,'4:2:0',false,'fltp',32,true],
  'av1-small': ['yuv420p10le',10,'4:2:0',true,'flt',32,false],
  'prores-hq': ['yuv422p10le',10,'4:2:2',true,'s32',24,true],
  'dnxhr-hq': ['yuv422p',8,'4:2:2',true,'s16',16,true],
  'ffv1-master': ['yuv420p10le',10,'4:2:0',true,'flt',32,false],
};
const signalFacts = (recipe, ctx) => {
  if (ctx.video.pixfmt !== 'p010le' || ctx.audio?.sampleFmt !== 'f32le') throw new Error('New media needs authored signal facts');
  const [pixfmt,depth,chroma,convertVideo,sampleFmt,bits,convertAudio] = authoredSignals[recipe.id];
  return {
    video: recipe.video.enabled ? {inputFormat:'p010le',outputFormat:pixfmt,inputBits:10,outputBits:depth,
      inputChroma:'4:2:0',outputChroma:chroma,chromaChanged:chroma !== '4:2:0',conversion:convertVideo,
      containerSupport:ve.compat.video[ve.videoEncoders[recipe.video.encoder].family][recipe.container.format]} : null,
    audio: recipe.audio[0].enabled ? [{inputFormat:'flt',outputFormat:sampleFmt,inputBits:32,outputBits:bits,
      inputChroma:null,outputChroma:null,chromaChanged:null,conversion:convertAudio,
      containerSupport:ve.compat.audio[ve.audioEncoders[recipe.audio[0].encoder].family][recipe.container.format]}] : [],
  };
};
const mapIssue = (issue, tokens = []) => {
  const text = issue.text;
  const id = /banding/.test(text) ? 'V-DEPTH-DOWN' : /interpolated/.test(text) ? 'V-CHROMA-UP'
    : /Fast start/.test(text) ? 'V-FASTSTART' : /Runs on/.test(text) ? 'V-HARDWARE'
    : /test encode/.test(text) ? 'V-ENC-FAILED' : /isn’t in/.test(text) ? 'V-ENC-MISSING'
    : /can’t hold.*video|in .*works in FFmpeg/.test(text) ? 'V-CONTAINER-VIDEO'
    : /can’t hold.*audio|audio in .*muxes/.test(text) ? 'V-CONTAINER-AUDIO' : 'V-DESIGN';
  let field = issue.field ?? '';
  if (field.startsWith('audio.')) field = field.replace('audio.','audio[0].');
  if (field === 'video.gop') field = 'video.gopSec';
  if (field === 'container') field = id === 'V-FASTSTART' ? 'container.faststart' : 'container.format';
  const stream = id === 'V-CONTAINER-VIDEO' ? 'video' : id === 'V-CONTAINER-AUDIO' ? 'audio[0]' : null;
  const tokenIndices = tokens.flatMap((token, i) => token.field === field ||
    (stream && token.field === `${stream}.encoder`) ? [i] : []);
  return { id, level: issue.level, field, message: text, params: stream ? {stream} : {}, fix: issue.fix ?? null, tokenIndices };
};
const issueNotice = { id: 'V-UNTESTED', level: 'info', field: '', message: 'B0 design fixture. Not tested with VEGAS yet.', params: {}, fix: null, tokenIndices:[] };
const cleanRecipe = (r) => {
  const copy = JSON.parse(JSON.stringify(r));
  for (const key of ['revision', 'updated', 'builtin', 'favorite']) delete copy[key];
  delete copy.video.options;
  delete copy.audio.options;
  copy.audio = [copy.audio];
  copy.extensions = {};
  return copy;
};
const presets = ve.library.filter((r) => r.builtin);
const paths = {
  ffmpeg: 'ffmpeg',
  videoPipe: '\\\\.\\pipe\\vegas-encoder-0000-video',
  audioPipe: '\\\\.\\pipe\\vegas-encoder-0000-audio',
  project: 'Sample project',
};
const makeFixture = (r, ctx = ve.sampleContext) => {
  const recipe = cleanRecipe(r);
  const compiled = ve.compile(r, ctx);
  const res = compiled.resolved;
  const tokens = annotateTokens(compiled.tokens, res);
  const output = tokens.at(-1).text;
  const advancedTemplate = ['{inputs}', ve.commandText(tokens.filter((x) => !['exe', 'global', 'input', 'output'].includes(x.role))), '{output}'].join('\n');
  const est = ve.estimate(r, { ...ctx, durationSec: 60 });
  const perMinute = est.bytes;
  return {
    recipe,
    preset: { vepreset: 1, revision: r.revision, favorite: r.favorite, pinned: false, builtin: true,
      updatedAt: '2026-10-12T01:12:00Z', origin: null,
      requires: { encoders: [r.video.encoder, r.audio.encoder], minFFmpegVersion: null }, recipe },
    media: { video: ctx.video, audio: ctx.audio, durationSec: null },
    paths: { ...paths, videoPipe: `\\\\.\\pipe\\vegas-encoder-${ctx.pipeId}-video`, audioPipe: `\\\\.\\pipe\\vegas-encoder-${ctx.pipeId}-audio`, project: ctx.project?.replace(/\.veg$/, '') ?? paths.project, output },
    normalize: { recipe, issues: [] },
    compile: { executable: 'ffmpeg', argv: tokens.slice(1).map((x) => x.text), display: tokens,
      commandLine: ve.commandText(tokens), advancedTemplate,
      resolved: { videoEncoder: res.enc.id, audioEncoder: res.aenc.id, videoMode: res.mode, audioMode: res.amode,
        quality: res.quality ?? null, speed: res.speed ?? null, profile: res.profile ?? null, depth: res.depth, pixfmt: res.pixfmt },
      signalPath: signalFacts(recipe, ctx),
      issues: [...ve.validate(r, 'gyan-8.1', ctx).map((issue) => mapIssue(issue, tokens)), issueNotice], summary: ve.summary(r) },
    validations: Object.fromEntries(ve.installations.map((inst) => [inst.id, [...ve.validate(r, inst.id, ctx).map((issue) => mapIssue(issue)), issueNotice]])),
    compileIssues: Object.fromEntries(ve.installations.map((inst) => [inst.id, [...ve.validate(r, inst.id, ctx).map((issue) => mapIssue(issue, tokens)), issueNotice]])),
    estimate: { available: true, approx: est.approx, videoKbps: est.videoKbps, audioKbps: est.audioKbps,
      bytesPerMinute: perMinute, totalBytes: null, minBytesPerMinute: est.approx ? perMinute * .6 : null,
      maxBytesPerMinute: est.approx ? perMinute * 1.6 : null,
      explanation: 'Design fixture: size depends on how busy the footage is.' },
  };
};
const fixtures = presets.map((r) => makeFixture(r));
const profiles = { profiles: 1, provenance: 'B0: model.js; design-time Linux FFmpeg 8.1.3; NOT Windows-qualified',
  video: Object.values(ve.videoEncoders), audio: Object.values(ve.audioEncoders), containers: Object.values(ve.containers),
  compatibility: ve.compat, rateModes: ve.rateModes,
  videoOrder: { groups: ve.videoOrder }, audioOrder: { groups: ve.audioOrder } };
const installations = ve.installations.map((inst, n) => {
  const hash = String(n + 1).repeat(64); // Deliberately synthetic; isFixture is mandatory.
  return { id: inst.id, label: inst.label, path: inst.path, ffprobePath: inst.path.replace(/ffmpeg.exe$/, 'ffprobe.exe'),
    version: inst.version, build: inst.build, source: ['winget', 'manual', 'path'][n], license: inst.license,
    identity: { sha256: hash, key: 'b0-fixture-' + inst.id, size: 100000000, mtime: '2026-10-12T00:00:00Z', libraries: {} },
    probedAt: ['2026-10-12T01:12:00Z', '2026-10-09T01:12:00Z', '2026-10-05T01:12:00Z'][n],
    probeMs: inst.probeMs, counts: inst.counts, availability: inst.availability, isFixture: true };
});
const templateTexts = fixtures.map((f) => f.compile.advancedTemplate);
const lint = Object.fromEntries(templateTexts.map((text) => [text, ve.lint(text).map((x) => ({
  id: 'L-DESIGN', level: x.level, start: x.start, end: x.end, message: x.text, params: {}, fix: null,
}))]));
lint[''] = [{ id: 'L-INPUTS', level: 'error', start: 0, end: 0, message: 'Add {inputs}.', params: {} },
  { id: 'L-OUTPUT', level: 'error', start: 0, end: 0, message: 'Add {output}.', params: {} }];
const complete = Object.fromEntries(presets.map((r) => {
  const text = `ffmpeg {inputs} -c:v ${r.video.encoder} -preset `;
  const c = ve.complete(text, text.length);
  return [`${text.length}:${text}`, { kind: c.kind, of: c.of ?? null, start: text.length, end: text.length,
    items: c.items.map((x) => ({ value: x.value, description: x.desc ?? '', type: x.type ?? null,
      defaultValue: x.def ?? null, source: x.source ?? null, availability: null })) }];
}));
const details = Object.fromEntries(Object.entries(context.VE_AVOPTIONS.encoders).map(([name, enc]) => [name, {
  name, kind: ve.audioEncoders[name] ? 'audio' : 'video',
  pixelFormats: enc.pixfmts ?? [], sampleFormats: enc.samplefmts ?? [], sampleRates: (enc.samplerates ?? []).map(Number),
  options: enc.options.map((o) => ({ name: o.name, aliases: o.aliases ?? [], type: o.type,
    description: o.desc, min: o.min ?? null, max: o.max ?? null, defaultValue: o.default ?? null,
    constants: (o.consts ?? []).map((c) => ({ name: c.name, value: c.value ?? null, description: c.desc ?? '' })) })),
}]));
const session = ve.templateSession();
const popupFixture = makeFixture(session.recipe, ve.vegas);
popupFixture.media.durationSec = ve.vegas.durationSec;
lint[popupFixture.compile.advancedTemplate] = ve.lint(popupFixture.compile.advancedTemplate).map((x) => ({
  id:'L-DESIGN',level:x.level,start:x.start,end:x.end,message:x.text,params:{},fix:null,
}));
const canonical = (value) => JSON.stringify((function sort(v) {
  if (Array.isArray(v)) return v.map(sort);
  if (v && typeof v === 'object') return Object.fromEntries(Object.keys(v).sort().map((k) => [k,sort(v[k])]));
  return v;
})(value));
const payloads = {}, decodedPayloads = {}, diffs = {};
for (const f of [...fixtures,popupFixture]) {
  const snapshot = {recipe:f.recipe,origin:null,vegasPrefs:f.recipe.vegas,writtenBy:'0.1.0-b0-fake',extensions:{}};
  const data = Buffer.from(canonical(snapshot),'utf8');
  let crc = 0xffffffff;
  for (const byte of data) { crc ^= byte; for(let n=0;n<8;n++) crc=(crc>>>1)^((crc&1)?0xedb88320:0); }
  const header = Buffer.alloc(32);
  header.write('VEnc'); header.writeUInt16LE(1,4); header.writeUInt32LE(data.length,8);
  header.writeUInt32LE((crc^0xffffffff)>>>0,12); header.writeUInt32LE(1,16);
  const encoded = Buffer.concat([header,data]).toString('base64');
  payloads[canonical(snapshot)] = encoded;
  decodedPayloads[encoded] = {snapshot,migrated:false,issues:[]};
  diffs[canonical(f.recipe)+'\n'+canonical(f.recipe)] = [];
}
const bundle = { fixtures, additionalFixtures: [popupFixture], profiles, installations, details, lint, complete, payloads, decodedPayloads, diffs };
const dest = path.join(root, 'schema/fixtures/b0');
writeFile(path.join(dest, 'core-and-services.json'), JSON.stringify(bundle, null, 2) + '\n');
writeFile(path.join(root, 'packages/ve_core/lib/src/fixture_data.dart'), `// Generated by scripts/Generate-B0Fixtures.mjs. DESIGN FIXTURES ONLY.\nconst String b0FixtureJson = r'''${JSON.stringify(bundle,null,2)}''';\n`);
console.log(`Generated ${fixtures.length} built-in fixtures and ${installations.length} illustrative installations.`);

const states = ['starting', 'encoding', 'finishing', 'verifying', 'done', 'failed', 'cancelled'];
const live = states.map((state, n) => {
  const terminal = ['done','failed','cancelled'].includes(state);
  const framesDone = state === 'starting' ? 0 : state === 'encoding' ? 7400 : state === 'cancelled' ? 3250 : 22873;
  return { live: 1, jobId: 'b0-render', hostHwnd:'123456', sequence: n + 1, updatedAt: `2026-10-12T06:22:0${n}Z`, state,
    framesDone, framesTotal: 22873, encodeFps: state === 'starting' ? null : 61.8,
    speed: state === 'starting' ? null : 2.06, bitrateKbps: state === 'starting' ? null : 30700,
    bytesWritten: state === 'starting' ? 0 : state === 'done' ? 2930000000 : 1230000000,
    elapsedSec: n === 0 ? 0 : 243 + n, etaSec: terminal ? null : state === 'encoding' ? 250 : null,
    estimatedFinalBytes: state === 'encoding' ? 2930000000 : null,
    outputPath: ve.vegas.output, templateName: ve.vegas.templateName, encoderSummary: 'libx264 + aac',
    message: state === 'failed' ? 'FFmpeg exited with code 1. Partial file removed.' : state === 'cancelled' ? 'Cancelled in VEGAS. Partial file removed.' : '',
    ffmpegExitCode: state === 'done' ? 0 : state === 'failed' ? 1 : null };
});
const liveDir = path.join(dest, 'live');
live.forEach((s) => writeFile(path.join(liveDir, s.state + '.live.json'), JSON.stringify(s,null,2) + '\n'));
const request = { protocol: 1, sessionId: 'b0-edit-session', templateName: session.templateName,
  recipe: cleanRecipe(session.recipe), origin: {presetId:session.origin.id, revision:session.origin.revision,name:session.origin.name},
  baseRecipe:cleanRecipe(session.base), context: { hostVersion:'2026.0.3.189',project:ve.vegas.project,
    media:{video:ve.vegas.video,audio:ve.vegas.audio,durationSec:ve.vegas.durationSec}},
  ownerHwnd:'123456',dllVersion:'0.1.0-b0-fixture',coreVersion:'0.1.0-b0-fake' };
const jobs = ve.history.map((h) => {
  const f = fixtures.find((f) => h.encoder.startsWith(f.recipe.video.encoder)) ?? fixtures[0];
  const source = JSON.parse(JSON.stringify(presets.find((r) => r.id === f.recipe.id)));
  if (h.status === 'failed') source.video.extra = '-preset 14';
  const jobRecipe = cleanRecipe(source);
  const jobContext = {...ve.vegas,project:h.project,durationSec:h.durationSec,pipeId:h.id,
    output:h.output.replace(/(\.[A-Za-z0-9]+)$/,`.ve-partial-${h.id}$1`)};
  const argv = ve.compile(source,jobContext).tokens.slice(1).map((t) => t.text);
  return { job:1,id:h.id,startedAt:'2026-10-12T06:00:00Z',endedAt:'2026-10-12T06:22:00Z',project:h.project,
    templateName:h.template,outputPath:h.output,status:h.status,recipe:jobRecipe,origin:{presetId:f.recipe.id,revision:f.preset.revision,name:f.recipe.name},
    recipeSha256:createHash('sha256').update(canonical(jobRecipe)).digest('hex'),media:{video:jobContext.video,audio:jobContext.audio,durationSec:h.durationSec},
    ffmpeg:installations[0],argv,elapsedSec:h.elapsedSec,sizeBytes:h.sizeBytes,avgFps:h.avgFps,
    ffmpegExitCode:h.exit,hresult:h.status === 'succeeded' ? '0x00000000' : h.status === 'cancelled' ? '0x8004E017' : '0x80004005',
    message:h.note ?? '',stderrTail:h.log ?? '',verification:{state:h.status === 'succeeded' ? 'passed' : 'skipped',message:'B0 illustrative record',expectedCodecs:[],actualCodecs:[],ffprobeVersion:null},
    timings:{},published:h.status === 'succeeded',retainedPartialPath:null };
});
const machine = {machine:1,revision:0,installations,defaultFFmpegId:'gyan-8.1',progressWindow:true,keepOnTop:false,verifyOutput:true,theme:'system',
  uiState:{desktopWindowBounds:{x:-1280,y:80,width:1200,height:800},desktopMaximized:false,lastSizeLengthText:'10:00'}};
const serviceBundle = {live,request,jobs,machine};
for (const [name,value] of Object.entries({request,machine,'result-apply':{protocol:1,sessionId:request.sessionId,action:'apply',recipe:request.recipe,origin:request.origin},'result-cancel':{protocol:1,sessionId:request.sessionId,action:'cancel'}})) {
  writeFile(path.join(dest,name+'.json'),JSON.stringify(value,null,2)+'\n');
}
jobs.forEach((job) => writeFile(path.join(dest,job.id+'.json'),JSON.stringify(job,null,2)+'\n'));
const index = jobs.map((job) => ({index:1,id:job.id,recordFile:job.id+'.json',startedAt:job.startedAt,status:job.status,templateName:job.templateName,outputPath:job.outputPath}));
writeFile(path.join(dest,'jobs.jsonl'),index.map((j) => JSON.stringify(j)).join('\n')+'\n');
writeFile(path.join(root,'packages/ve_services/lib/src/service_fixture_data.dart'),`// Generated by scripts/Generate-B0Fixtures.mjs. DESIGN FIXTURES ONLY.\nconst String b0ServiceFixtureJson = r'''${JSON.stringify(serviceBundle,null,2)}''';\n`);
