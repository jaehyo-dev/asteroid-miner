// v0.8.0 4단계 확인 자료: 웹 빌드를 Playwright headless(Chromium)로 열어 찍는다 (맥에서 Godot 창을 띄우지 않음, CLAUDE.md).
// 서버는 따로 띄움: python3 -m http.server 8765 --directory build/web
// 실행: NODE_PATH=<playwright가 있는 node_modules> node review/v080_step4/capture_web.cjs <장면…>
// 장면: <보조 무기 id>_1 / _5 (펄스 연사포 + 그 보조 무기, GIF 프레임), rail_fast (레일건, 빠르게 사각형으로 돌며, GIF 프레임),
//       cards_new_<pc|phone>, cards_full_<pc|phone>, hud_<pc|phone>, research_<pc|phone> (캡처 1장)
// GIF 프레임: 1280x720(출격 화면 2배), 5초 15장/초 → frames/<장면>/ → python3 review/v080_step4/make_gifs.py <frames>
// 장면 만들기는 ?fxtest 숨은 키: 숫자 1~5 무기, Shift+1~6 보조 무기 얻기·1단계, Shift+0 촬영 모드(체력 유지·가까이 적 채움), Shift+9 레벨업 (배포 전 삭제)
const { chromium } = require("playwright");
const fs = require("fs");
const OUT = __dirname;
const URL = "http://localhost:8765/index.html?fxtest";
const SUBS = ["missile", "blackhole", "saw", "mine", "coil", "wave"];
const VP = { pc: { width: 1280, height: 720 }, phone: { width: 844, height: 390 } };
// 기지 화면에서 출격 버튼 위치 (화면 비율, 첫 캡처에서 확인)
const SORTIE = { pc: [0.5, 0.70], phone: [0.505, 0.677] };
// 연구소 건물, 무기 가지 "보조 무기 해금" 칸 (화면 비율, 첫 캡처에서 확인)
const RESEARCH = { pc: [0.266, 0.28], phone: [0.33, 0.18] };
const CELL = { pc: [0.544, 0.625], phone: [0.564, 0.436] };

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
  return { ctx, page };
}

async function tap(page, size, at) {
  const [x, y] = [at[0] * VP[size].width, at[1] * VP[size].height];
  if (size === "phone") await page.touchscreen.tap(x, y); else await page.mouse.click(x, y);
}

// 기지 → 출격 → 워프 연출이 끝날 때까지
async function sortie(page, size) {
  await tap(page, size, SORTIE[size]);
  await sleep(6000);
  await page.mouse.click(5, 5).catch(() => {});  // 첫 출격 연출이 길면 눌러 넘긴다 (두 번째부터 넘길 수 있음)
  await sleep(1500);
}

async function key(page, k, times = 1) {
  for (let i = 0; i < times; i++) { await page.keyboard.press(k); await sleep(80); }
}

async function gif(browser, scene) {
  const { ctx, page } = await open(browser, "pc");
  await sortie(page, "pc");
  if (scene === "rail_fast") {
    await key(page, "Digit3");
  } else {
    const [id, stage] = scene.split("_");
    await key(page, `Shift+Digit${SUBS.indexOf(id) + 1}`, Number(stage));
  }
  await key(page, "Shift+Digit0");  // 촬영 모드
  await sleep(4000);
  const dir = `${process.env.FRAMES}/${scene}`;
  fs.mkdirSync(dir, { recursive: true });
  const moves = ["ArrowRight", "ArrowDown", "ArrowLeft", "ArrowUp"];
  const moving = scene === "rail_fast" || scene.startsWith("mine") || scene.startsWith("saw");
  // 실제 시간 프레임: CDP 화면 중계(screencast)로 렌더된 프레임을 시각과 함께 받아, 5초 동안 1/15초마다 가장 가까운 프레임을 고른다
  // (page.screenshot은 한 장에 0.1~0.2초 걸려 GIF가 빨리 감기처럼 됨)
  const cdp = await ctx.newCDPSession(page);
  const got = [];
  cdp.on("Page.screencastFrame", (f) => {
    got.push({ t: f.metadata.timestamp, data: f.data });
    cdp.send("Page.screencastFrameAck", { sessionId: f.sessionId }).catch(() => {});
  });
  await cdp.send("Page.startScreencast", { format: "png", everyNthFrame: 1 });
  const t0 = Date.now();
  let held = null;
  while (Date.now() - t0 < 5600) {
    if (moving) {
      const m = moves[Math.floor((Date.now() - t0) / 600) % 4];
      if (m !== held) { if (held) await page.keyboard.up(held); await page.keyboard.down(m); held = m; }
    }
    await sleep(30);
  }
  await cdp.send("Page.stopScreencast");
  if (held) await page.keyboard.up(held);
  const start = got[0].t + 0.3;
  for (let i = 0; i < 75; i++) {
    const want = start + i / 15;
    let best = got[0];
    for (const g of got) if (Math.abs(g.t - want) < Math.abs(best.t - want)) best = g;
    fs.writeFileSync(`${dir}/${String(i).padStart(3, "0")}.png`, Buffer.from(best.data, "base64"));
  }
  const span = got[got.length - 1].t - got[0].t;
  console.log(scene, `받은 프레임 ${got.length}장 / ${span.toFixed(1)}초 → 75장`);
  await ctx.close();
}

async function shot(browser, scene) {
  const size = scene.endsWith("_phone") ? "phone" : "pc";
  const kind = scene.replace(/_(pc|phone)$/, "");
  const { ctx, page } = await open(browser, size);
  if (kind === "research") {
    await tap(page, size, RESEARCH[size]);  // 연구소 건물
    await sleep(2500);
    if (CELL[size]) { await tap(page, size, CELL[size]); await sleep(1500); }  // 보조 무기 해금 칸
  } else {
    await sortie(page, size);
    if (kind === "cards_full") {
      await key(page, "Shift+Digit1"); await key(page, "Shift+Digit3", 2); await key(page, "Shift+Digit5");
    } else if (kind === "hud") {
      await key(page, "Shift+Digit1"); await key(page, "Shift+Digit2", 3); await key(page, "Shift+Digit6", 5);
      await key(page, "Shift+Digit0");
      await sleep(3000);
    }
    if (kind.startsWith("cards")) {
      await key(page, "Shift+Digit9");
      await sleep(2500);
      await page.mouse.click(VP[size].width / 2, 8);  // 카드 펼치기 연출 넘기기 (빈 곳)
      await sleep(1500);
    }
  }
  await page.screenshot({ path: `${OUT}/ui/${scene}.png` });
  console.log(scene, "찍음");
  await ctx.close();
}

(async () => {
  fs.mkdirSync(`${OUT}/ui`, { recursive: true });
  const browser = await chromium.launch({ headless: true, ...(process.env.CHROME ? { executablePath: process.env.CHROME } : {}) });
  for (const scene of process.argv.slice(2)) {
    if (/_(pc|phone)$/.test(scene)) await shot(browser, scene); else await gif(browser, scene);
  }
  await browser.close();
  console.log(errors.length ? "콘솔 오류:\n" + errors.join("\n") : "콘솔 오류 0");
  process.exit(errors.length ? 1 : 0);
})();
