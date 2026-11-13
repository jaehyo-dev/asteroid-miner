// v0.8.0 5d단계 확인 자료 (5c 스크립트에서 GIF 장면만 남김): 웹 빌드를 Playwright headless(Chromium)로 열어 찍는다 (맥에서 Godot 창을 띄우지 않음, CLAUDE.md).
// 서버: python3 -m http.server 8768 --directory build/web
// 실행: CHROME=<chrome> NODE_PATH=<playwright node_modules> FRAMES=<프레임 폴더> node review/v080_step5d/capture_web.cjs wave_5 wave_r1 wave_r2 wave_r3
// 장면: wave_5 채굴 펄스 5단계, wave_r<n> 공명 파쇄 후보 n (1280x720 = 출격 화면 2배, 6초 15장/초, 촬영 모드 + Shift+F 바깥 운석밭으로 운석이 촘촘한 같은 장면)
// ?fxtest 숨은 키(배포 전 삭제): Shift+0 촬영 모드, Shift+F 바깥 운석밭, Alt+6 채굴 펄스 1→3→5단계, Alt+Shift+6 바로 진화, R 공명 파쇄 후보 바꾸기
const { chromium } = require("playwright");
const fs = require("fs");
const URL = "http://localhost:8768/index.html?fxtest";
const VP = { width: 1280, height: 720 };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const errors = [];

async function key(page, k, times = 1) {
  for (let i = 0; i < times; i++) { await page.keyboard.press(k); await sleep(150); }
}

async function gif(browser, scene) {
  const ctx = await browser.newContext({ viewport: VP, deviceScaleFactor: 1 });
  const page = await ctx.newPage();
  page.on("console", (m) => { if (m.type() === "error") errors.push(`${scene}: ${m.text()}`); });
  page.on("pageerror", (e) => errors.push(`${scene}: ${e.message}`));
  await page.goto(URL);
  await sleep(9000);
  await page.mouse.click(0.5 * VP.width, 0.70 * VP.height);  // 출격
  await sleep(6000);
  await page.mouse.click(5, 5).catch(() => {});
  await sleep(1500);
  await key(page, "Shift+Digit0");
  await key(page, "Shift+KeyF");
  for (let i = 0; i < 2; i++) { await sleep(1500); await key(page, "KeyS"); }  // 첫 레벨업 카드 건너뛰기
  await sleep(1500);
  await key(page, "Digit1");
  if (scene === "wave_5") await key(page, "Alt+Digit6", 3);
  else { await key(page, "Alt+Shift+Digit6"); await key(page, "KeyR", Number(scene.slice(-1)) - 1); }
  await sleep(4500);
  const dir = `${process.env.FRAMES}/${scene}`;
  fs.mkdirSync(dir, { recursive: true });
  const cdp = await ctx.newCDPSession(page);
  const got = [];
  cdp.on("Page.screencastFrame", (f) => {
    got.push({ t: f.metadata.timestamp, data: f.data });
    cdp.send("Page.screencastFrameAck", { sessionId: f.sessionId }).catch(() => {});
  });
  await cdp.send("Page.startScreencast", { format: "png", everyNthFrame: 1 });
  await sleep(6600);
  await cdp.send("Page.stopScreencast");
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

(async () => {
  const browser = await chromium.launch({ headless: true, args: ["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"], ...(process.env.CHROME ? { executablePath: process.env.CHROME } : {}) });
  for (const scene of process.argv.slice(2)) await gif(browser, scene);
  await browser.close();
  console.log("콘솔 오류", errors.length, errors.slice(0, 10));
})();
