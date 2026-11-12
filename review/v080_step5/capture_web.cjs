// v0.8.0 5단계 확인 자료: 웹 빌드를 Playwright headless(Chromium)로 열어 찍는다 (맥에서 Godot 창을 띄우지 않음, CLAUDE.md).
// 서버: python3 -m http.server 8767 --directory build/web
// 실행: NODE_PATH=<playwright node_modules> FRAMES=<프레임 폴더> node review/v080_step5/capture_web.cjs <장면…>
// 장면: <보조 무기 id>_5 / <보조 무기 id>_evo (1280x720 = 출격 화면 2배, 5초 15장/초 GIF 프레임)
//       card_pc, card_phone (진화 카드 + 짝 스킬 카드), hud_pc, hud_phone (판 화면 진화 아이콘), museum_pc, museum_phone (전시관 진화 도감)
// ?fxtest 숨은 키(배포 전 삭제): Shift+0 촬영 모드, Alt+1~6 보조 무기 하나만 1→3→5단계, Alt+Shift+1~6 바로 진화(도감 기록), Shift+7 진화 카드 화면
const { chromium } = require("playwright");
const fs = require("fs");
const OUT = __dirname;
const URL = "http://localhost:8767/index.html?fxtest";
const SUBS = ["missile", "blackhole", "saw", "mine", "coil", "wave"];
const VP = { pc: { width: 1280, height: 720 }, phone: { width: 844, height: 390 } };
const SORTIE = { pc: [0.5, 0.70], phone: [0.505, 0.677] };
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

async function gif(browser, scene) {
  const { ctx, page } = await boot(browser, "pc");
  await sortie(page, "pc");
  const [id, mode] = scene.split("_");
  await key(page, "Shift+Digit0");
  await skipCards(page);
  await key(page, "Digit1");
  const n = SUBS.indexOf(id) + 1;
  if (mode === "evo") await key(page, `Alt+Shift+Digit${n}`); else await key(page, `Alt+Digit${n}`, 3);
  await sleep(4500);
  const dir = `${process.env.FRAMES}/${scene}`;
  fs.mkdirSync(dir, { recursive: true });
  const moves = ["ArrowRight", "ArrowDown", "ArrowLeft", "ArrowUp"];
  const moving = id === "mine" || id === "saw";
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
  console.log(scene, `프레임 ${got.length}장 → 75장`);
  await ctx.close();
}

async function card(browser, size) {
  const { ctx, page } = await boot(browser, size);
  await sortie(page, size);
  await skipCards(page);
  await key(page, "Shift+Digit7");
  await sleep(500);
  await page.screenshot({ path: `${OUT}/shots/card_merge_${size}.png` });  // 아이콘이 합쳐지는 중
  await sleep(3500);
  await page.screenshot({ path: `${OUT}/shots/card_${size}.png` });
  await key(page, "Digit1");  // 첫 칸을 고르면 진화든 아니든 화면이 닫힌다 → 판 화면 칸 아이콘
  await sleep(300);
  // 진화 카드가 아니었을 수도 있으니 Alt+Shift로 확실히 진화 + 한 칸 더 (보조 무기 2개)
  await key(page, "Alt+Shift+Digit1");
  await key(page, "Shift+Digit5");
  await sleep(1500);
  await page.screenshot({ path: `${OUT}/shots/hud_${size}.png` });
  await ctx.close();
}

// 전시관: 처음엔 못 만든 것만, 진화 3개를 만든 뒤(Alt+Shift) 다시 열어 만든 것 / 못 만든 것
async function museum(browser, size) {
  const mobile = size === "phone";
  const ctx = await browser.newContext({ viewport: VP[size], deviceScaleFactor: 1, isMobile: mobile, hasTouch: mobile });
  for (const step of ["none", "some"]) {
    const { page } = await boot(browser, size, ctx);
    if (step === "some") {
      await sortie(page, size);
      await skipCards(page);
      for (const n of [1, 3, 6]) await key(page, `Alt+Shift+Digit${n}`);
      await sleep(800);
      await page.goto(URL);
      await sleep(9000);
    }
    const at = JSON.parse(process.env.MUSEUM || "{}")[size];
    if (at) {
      if (mobile) await page.touchscreen.tap(at[0], at[1]); else await page.mouse.click(at[0], at[1]);
      await sleep(1500);
      const scroll = JSON.parse(process.env.SCROLL || "{}")[size];
      if (scroll) {  // 진화 줄까지 끌어 내리기
        for (let i = 0; i < 6; i++) {
          await page.mouse.move(scroll[0], scroll[1]); await page.mouse.down();
          await page.mouse.move(scroll[0], scroll[1] - 200, { steps: 12 }); await page.mouse.up();
          await sleep(400);
        }
        if (scroll[2]) { await page.mouse.click(scroll[2], scroll[3]); await sleep(400); }  // 진화 칸 하나 골라 설명 줄
      }
    }
    await page.screenshot({ path: `${OUT}/shots/museum_${step}_${size}.png` });
    await page.close();
  }
  await ctx.close();
}

(async () => {
  fs.mkdirSync(`${OUT}/shots`, { recursive: true });
  const browser = await chromium.launch({ headless: true, args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"], ...(process.env.CHROME ? { executablePath: process.env.CHROME } : {}) });
  for (const scene of process.argv.slice(2)) {
    if (scene.startsWith("card_")) await card(browser, scene.slice(5));
    else if (scene.startsWith("museum_")) await museum(browser, scene.slice(7));
    else if (scene.startsWith("base_")) { const { ctx, page } = await boot(browser, scene.slice(5)); await page.screenshot({ path: `${OUT}/shots/${scene}.png` }); await ctx.close(); }
    else await gif(browser, scene);
  }
  await browser.close();
  console.log("콘솔 오류", errors.length, errors.slice(0, 10));
})();
