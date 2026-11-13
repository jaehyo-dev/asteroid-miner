// v0.8.0 5c단계 확인 자료 (5b 스크립트에서 톱날 움직임 일정·카드 고르기만 바꿈): 웹 빌드를 Playwright headless(Chromium)로 열어 찍는다 (맥에서 Godot 창을 띄우지 않음, CLAUDE.md).
// 서버: python3 -m http.server 8768 --directory build/web
// 실행: CHROME=<chrome-headless-shell> NODE_PATH=<playwright node_modules> FRAMES=<프레임 폴더> node review/v080_step5c/capture_web.cjs <장면…>
// 장면: <보조 무기 id>_5 / <보조 무기 id>_evo (1280x720 = 출격 화면 2배, 6초 15장/초 GIF 프레임, 촬영 모드: 운석·해파리 채움, 레벨업 멈춤)
//       cards_pc, cards_phone (진화 카드 6장 + 짝 스킬 카드 6장: Shift+7을 누를 때마다 다음 보조 무기)
//       museum_pc, museum_phone (전시관을 맨 위 → 가운데 → 맨 아래로 끌어 내리며)
// ?fxtest 숨은 키(배포 전 삭제): Shift+0 촬영 모드, Shift+F 바깥 운석밭, Alt+1~6 보조 무기 하나만 1→3→5단계, Alt+Shift+1~6 바로 진화(도감 기록), Shift+7 진화 카드 화면
const { chromium } = require("playwright");
const fs = require("fs");
const OUT = __dirname;
const URL = "http://localhost:8768/index.html?fxtest";
const SUBS = ["missile", "blackhole", "saw", "mine", "coil", "wave"];
const VP = { pc: { width: 1280, height: 720 }, phone: { width: 844, height: 390 } };
const SORTIE = { pc: [0.5, 0.70], phone: [0.505, 0.677] };
const MUSEUM = { pc: [940, 350], phone: [568, 190] };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const errors = [];

async function boot(browser, size, ctxIn) {
  const mobile = size === "phone";
  const ctx = ctxIn || await browser.newContext({ viewport: VP[size], deviceScaleFactor: 1, isMobile: mobile, hasTouch: mobile });
  const page = await ctx.newPage();
  page.on("console", (m) => { if (m.type() === "error") errors.push(`${size}: ${m.text()}`); });
  page.on("pageerror", (e) => errors.push(`${size}: ${e.message}`));
  await page.goto(URL);
  await sleep(9000);
  return { ctx, page };
}

async function sortie(page, size) {
  const at = SORTIE[size];
  const [x, y] = [at[0] * VP[size].width, at[1] * VP[size].height];
  if (size === "phone") await page.touchscreen.tap(x, y); else await page.mouse.click(x, y);
  await sleep(6000);
  await page.mouse.click(5, 5).catch(() => {});
  await sleep(1500);
}

async function key(page, k, times = 1) {
  for (let i = 0; i < times; i++) { await page.keyboard.press(k); await sleep(150); }
}

async function skipCards(page) {
  for (let i = 0; i < 2; i++) { await sleep(1500); await key(page, "KeyS"); }
  await sleep(1500);
}

// 움직임 일정 [시작 ms, 키(null = 멈춤)]: 톱날은 직진 중 첫 퍼짐(약 0.7초) → 멈춘 채 둘째 퍼짐(약 4.7초), 기뢰는 네모로 돌며 기뢰 줄을 깐다
const PLAN = {
  saw: [[0, "ArrowRight"], [2600, null]],
  mine: [[0, "ArrowRight"], [1300, "ArrowDown"], [1900, "ArrowLeft"], [3200, "ArrowUp"], [3800, "ArrowRight"], [5100, "ArrowDown"]],
};

async function gif(browser, scene) {
  const { ctx, page } = await boot(browser, "pc");
  await sortie(page, "pc");
  const [id, mode] = scene.split("_");
  await key(page, "Shift+Digit0");
  if (id === "wave" || id === "blackhole") await key(page, "Shift+KeyF");  // 공명 연쇄·움직이는 블랙홀이 보이게 바깥에도 운석
  await skipCards(page);
  await key(page, "Digit1");
  const n = SUBS.indexOf(id) + 1;
  if (mode === "evo") await key(page, `Alt+Shift+Digit${n}`); else await key(page, `Alt+Digit${n}`, 3);
  await sleep(id === "saw" ? 3300 : 4500);  // 톱날: 진화 4초 뒤 첫 퍼짐이 촬영 0.7초쯤(직진 중), 둘째가 4.7초쯤(멈춤)에 오게
  const dir = `${process.env.FRAMES}/${scene}`;
  fs.mkdirSync(dir, { recursive: true });
  const cdp = await ctx.newCDPSession(page);
  const got = [];
  cdp.on("Page.screencastFrame", (f) => {
    got.push({ t: f.metadata.timestamp, data: f.data });
    cdp.send("Page.screencastFrameAck", { sessionId: f.sessionId }).catch(() => {});
  });
  await cdp.send("Page.startScreencast", { format: "png", everyNthFrame: 1 });
  const t0 = Date.now();
  let held = null;
  const plan = PLAN[id] || [];
  while (Date.now() - t0 < 6600) {
    const now = Date.now() - t0;
    let want = null;
    for (const [at, k] of plan) if (now >= at) want = k;
    if (want !== held) { if (held) await page.keyboard.up(held); if (want) await page.keyboard.down(want); held = want; }
    await sleep(30);
  }
  await cdp.send("Page.stopScreencast");
  if (held) await page.keyboard.up(held);
  const start = got[0].t + 0.3;
  for (let i = 0; i < 90; i++) {
    const want = start + i / 15;
    let best = got[0];
    for (const g of got) if (Math.abs(g.t - want) < Math.abs(best.t - want)) best = g;
    fs.writeFileSync(`${dir}/${String(i).padStart(3, "0")}.png`, Buffer.from(best.data, "base64"));
  }
  console.log(scene, `프레임 ${got.length}장 → 90장`);
  await ctx.close();
}

// 진화 카드 6장 + 짝 스킬 카드 6장: Shift+7마다 다음 보조 무기의 진화 카드 화면(옆 칸에 짝 스킬 카드)
async function cards(browser, size) {
  const { ctx, page } = await boot(browser, size);
  await sortie(page, size);
  await skipCards(page);
  fs.mkdirSync(`${OUT}/shots`, { recursive: true });
  for (const id of SUBS) {
    await key(page, "Shift+Digit7");
    await sleep(4000);  // 합쳐지는 등장이 끝날 때까지
    await page.screenshot({ path: `${OUT}/shots/card_${id}_${size}.png` });
    await key(page, "KeyS");  // 건너뛰기로 닫는다
    await sleep(1500);
  }
  await ctx.close();
}

// 전시관: 진화 3개(연쇄 폭격·회전 충각·공명 파쇄)를 만든 뒤 열어 맨 위 → 가운데 → 맨 아래
async function museum(browser, size) {
  const mobile = size === "phone";
  const ctx = await browser.newContext({ viewport: VP[size], deviceScaleFactor: 1, isMobile: mobile, hasTouch: mobile });
  const { page } = await boot(browser, size, ctx);
  await sortie(page, size);
  await skipCards(page);
  for (const n of [1, 3, 6]) await key(page, `Alt+Shift+Digit${n}`);
  await sleep(800);
  await page.goto(URL);
  await sleep(9000);
  const at = MUSEUM[size];
  if (mobile) await page.touchscreen.tap(at[0], at[1]); else await page.mouse.click(at[0], at[1]);
  await sleep(1500);
  const [x, y] = mobile ? [422, 250] : [640, 450];
  const shot = async (name) => { await sleep(400); await page.screenshot({ path: `${OUT}/shots/museum_${name}_${size}.png` }); };
  await shot("top");
  const drag = async (dy) => {
    await page.mouse.move(x, y); await page.mouse.down();
    await page.mouse.move(x, y - dy, { steps: 12 }); await page.mouse.up();
    await sleep(300);
  };
  // 반 칸 넘게씩 끌어 한 줄씩 내리며(손을 떼면 줄 맨 위에 멈춤) 멈출 때마다 확인용 프레임도 남긴다 (맨 위 → 맨 아래)
  fs.mkdirSync(`${process.env.FRAMES}/museum_${size}`, { recursive: true });
  for (let i = 0; i < 8; i++) {
    await drag(110);
    await page.screenshot({ path: `${process.env.FRAMES}/museum_${size}/${String(i).padStart(2, "0")}.png` });
    if (i === 1) await shot("middle");
  }
  await shot("bottom");
  await ctx.close();
}

(async () => {
  fs.mkdirSync(`${OUT}/shots`, { recursive: true });
  const browser = await chromium.launch({ headless: true, args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"], ...(process.env.CHROME ? { executablePath: process.env.CHROME } : {}) });
  for (const scene of process.argv.slice(2)) {
    if (scene.startsWith("cards_")) await cards(browser, scene.slice(6));
    else if (scene.startsWith("museum_")) await museum(browser, scene.slice(7));
    else await gif(browser, scene);
  }
  await browser.close();
  console.log("콘솔 오류", errors.length, errors.slice(0, 10));
})();
