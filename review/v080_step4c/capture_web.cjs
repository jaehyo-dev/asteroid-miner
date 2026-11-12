// v0.8.0 4c단계 확인 자료 (4b 도구 복사): 웹 빌드를 Playwright headless(Chromium)로 열어 찍는다 (맥에서 Godot 창을 띄우지 않음, CLAUDE.md).
// 서버는 따로 띄움: python3 -m http.server 8766 --directory build/web
// 실행: NODE_PATH=<playwright가 있는 node_modules> FRAMES=<프레임 폴더> node review/v080_step4c/capture_web.cjs <장면…>
// 장면: <보조 무기 id>_<1|3|5> (펄스 연사포 + 그 보조 무기 하나, GIF 프레임 4초 15장/초, 1280x720 = 출격 화면 2배)
//       perf (폰 844x390, 5단계 보조 무기 3개: 채굴 펄스·기뢰·유도 미사일, 10초 동안 화면 프레임 수 + 표시 글자 캡처 3장)
// 장면 만들기는 ?fxtest 숨은 키: 숫자 1 펄스 연사포, Alt+1~6 보조 무기 하나만(누를 때마다 1→3→5단계), Shift+1~6 보조 무기 1단계 올리기,
// Shift+0 촬영 모드(체력 유지·가까이 운석·해파리 채움·레벨업 멈춤, 구석에 FPS·효과 수) (배포 전 삭제)
const { chromium } = require("playwright");
const fs = require("fs");
const OUT = __dirname;
const URL = "http://localhost:8766/index.html?fxtest";
const SUBS = ["missile", "blackhole", "saw", "mine", "coil", "wave"];
const VP = { pc: { width: 1280, height: 720 }, phone: { width: 844, height: 390 } };
const SORTIE = { pc: [0.5, 0.70], phone: [0.505, 0.677] };  // 기지 화면 출격 버튼 (4단계에서 확인한 자리)

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const errors = [];

async function open(browser, size) {
  const mobile = size === "phone";
  const ctx = await browser.newContext({ viewport: VP[size], deviceScaleFactor: 1, isMobile: mobile, hasTouch: mobile });
  const page = await ctx.newPage();
  page.on("console", (m) => { if (m.type() === "error") errors.push(`${size}: ${m.text()}`); });
  page.on("pageerror", (e) => errors.push(`${size}: ${e.message}`));
  await page.goto(URL);
  await sleep(9000);
  const at = SORTIE[size];
  const [x, y] = [at[0] * VP[size].width, at[1] * VP[size].height];
  if (mobile) await page.touchscreen.tap(x, y); else await page.mouse.click(x, y);
  await sleep(6000);
  await page.mouse.click(5, 5).catch(() => {});  // 워프 연출 넘기기
  await sleep(1500);
  return { ctx, page };
}

async function key(page, k, times = 1) {
  for (let i = 0; i < times; i++) { await page.keyboard.press(k); await sleep(120); }
}

// 출격 직후 이미 쌓인 레벨업 카드가 뜨면 S(건너뛰기)로 닫는다. 카드가 없으면 S는 잠깐 아래로 움직일 뿐
async function skipCards(page) {
  for (let i = 0; i < 2; i++) { await sleep(1500); await key(page, "KeyS"); }
  await sleep(2000);
}

async function gif(browser, scene) {
  const { ctx, page } = await open(browser, "pc");
  const [id, stage] = scene.split("_");
  await key(page, "Shift+Digit0");  // 촬영 모드 먼저 (경험치가 멈춰 레벨업 카드가 끼어들지 않게)
  await skipCards(page);
  await key(page, "Digit1");  // 펄스 연사포
  await key(page, `Alt+Digit${SUBS.indexOf(id) + 1}`, { 1: 1, 3: 2, 5: 3 }[stage]);
  await sleep(4000);
  const dir = `${process.env.FRAMES}/${scene}`;
  fs.mkdirSync(dir, { recursive: true });
  const moves = ["ArrowRight", "ArrowDown", "ArrowLeft", "ArrowUp"];
  const moving = id === "mine" || id === "saw";
  // 실제 시간 프레임: CDP screencast로 받은 프레임에서 1/15초마다 가장 가까운 것을 고른다
  const cdp = await ctx.newCDPSession(page);
  const got = [];
  cdp.on("Page.screencastFrame", (f) => {
    got.push({ t: f.metadata.timestamp, data: f.data });
    cdp.send("Page.screencastFrameAck", { sessionId: f.sessionId }).catch(() => {});
  });
  await cdp.send("Page.startScreencast", { format: "png", everyNthFrame: 1 });
  const t0 = Date.now();
  let held = null;
  while (Date.now() - t0 < 4600) {
    if (moving) {
      const m = moves[Math.floor((Date.now() - t0) / 500) % 4];
      if (m !== held) { if (held) await page.keyboard.up(held); await page.keyboard.down(m); held = m; }
    }
    await sleep(30);
  }
  await cdp.send("Page.stopScreencast");
  if (held) await page.keyboard.up(held);
  const start = got[0].t + 0.3;
  for (let i = 0; i < 60; i++) {
    const want = start + i / 15;
    let best = got[0];
    for (const g of got) if (Math.abs(g.t - want) < Math.abs(best.t - want)) best = g;
    fs.writeFileSync(`${dir}/${String(i).padStart(3, "0")}.png`, Buffer.from(best.data, "base64"));
  }
  console.log(scene, `받은 프레임 ${got.length}장 / ${(got[got.length - 1].t - got[0].t).toFixed(1)}초 → 60장`);
  await ctx.close();
}

async function perf(browser) {
  const { ctx, page } = await open(browser, "phone");
  await key(page, "Shift+Digit0");
  await skipCards(page);
  await key(page, "Digit1");
  for (const id of ["wave", "mine", "missile"]) await key(page, `Shift+Digit${SUBS.indexOf(id) + 1}`, 5);
  await sleep(4000);
  fs.mkdirSync(`${OUT}/perf`, { recursive: true });
  const moves = ["ArrowRight", "ArrowDown", "ArrowLeft", "ArrowUp"];
  // 브라우저 화면 프레임 수 (Godot 웹은 requestAnimationFrame마다 한 프레임). 기뢰가 깔리게 움직이며 잰다
  const counting = page.evaluate(() => new Promise((done) => {
    const ts = []; const t0 = performance.now();
    const tick = (t) => { ts.push(t); if (t - t0 < 10000) requestAnimationFrame(tick); else done(ts); };
    requestAnimationFrame(tick);
  }));
  for (let i = 0; i < 20; i++) {
    const m = moves[i % 4];
    await page.keyboard.down(m); await sleep(500); await page.keyboard.up(m);
    if (i % 7 === 6) await page.screenshot({ path: `${OUT}/perf/phone_${i}.png` });
  }
  const ts = await counting;
  const gaps = ts.slice(1).map((t, i) => t - ts[i]).sort((a, b) => a - b);
  const result = { frames: ts.length, seconds: (ts[ts.length - 1] - ts[0]) / 1000, fps: (ts.length - 1) / ((ts[ts.length - 1] - ts[0]) / 1000),
    median_ms: gaps[Math.floor(gaps.length / 2)], p95_ms: gaps[Math.floor(gaps.length * 0.95)], max_ms: gaps[gaps.length - 1] };
  fs.writeFileSync(`${OUT}/perf/result.json`, JSON.stringify(result, null, 1));
  console.log("perf", JSON.stringify(result));
  await ctx.close();
}

(async () => {
  const browser = await chromium.launch({ headless: true, ...(process.env.CHROME ? { executablePath: process.env.CHROME } : {}) });
  for (const scene of process.argv.slice(2)) {
    if (scene === "perf") await perf(browser); else await gif(browser, scene);
  }
  await browser.close();
  console.log(errors.length ? "콘솔 오류:\n" + errors.join("\n") : "콘솔 오류 0");
  process.exit(errors.length ? 1 : 0);
})();
