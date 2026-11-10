// 웹 빌드 확인 (v0.7.0 밸런스 적용): 콘솔 오류, 출격 화면 FPS (PC 1280x720, 폰 844x390 터치, 각각 CPU 4배 느림 포함).
// 서버는 따로 띄움 (build/web을 http://localhost:8765/). 실행: NODE_PATH=<playwright가 있는 node_modules> node web_check.cjs <출력 폴더>
// 기지에서 출격 버튼(SORTIE 좌표)을 누르고, 워프 연출을 건너뛴 뒤 25초 동안 원을 그리며 움직이면서 FPS를 잰다.
const { chromium } = require("playwright");
const OUT = (process.argv[2] || __dirname) + "/";
const URL = "http://localhost:8765/index.html";
const CASES = [
  { name: "pc", vp: { width: 1280, height: 720 }, slow: 1 },
  { name: "pc_cpu4x", vp: { width: 1280, height: 720 }, slow: 4 },
  { name: "phone", vp: { width: 844, height: 390 }, slow: 1, mobile: true },
  { name: "phone_cpu4x", vp: { width: 844, height: 390 }, slow: 4, mobile: true },
];
const SORTIE = { pc: [640, 507], phone: [422, 275] };  // 첫 화면 캡처로 확인한 출격 버튼 자리
async function fps(page, ms) {
  return page.evaluate((ms) => new Promise((ok) => {
    let n = 0; const t0 = performance.now();
    const f = () => { n++; if (performance.now() - t0 < ms) requestAnimationFrame(f); else ok(n * 1000 / (performance.now() - t0)); };
    requestAnimationFrame(f);
  }), ms);
}
(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROME });
  const lines = [];
  let errors = 0;
  for (const c of CASES) {
    const ctx = await browser.newContext({ viewport: c.vp, deviceScaleFactor: c.mobile ? 3 : 1, isMobile: !!c.mobile, hasTouch: !!c.mobile });
    const page = await ctx.newPage();
    const log = [];
    page.on("console", (m) => { if (m.type() === "error") log.push("console.error: " + m.text()); });
    page.on("pageerror", (e) => log.push("pageerror: " + e.message));
    const cdp = await ctx.newCDPSession(page);
    await page.goto(URL);
    await page.waitForTimeout(9000);
    await page.screenshot({ path: OUT + c.name + "_base.png" });
    const at = SORTIE[c.mobile ? "phone" : "pc"];
    if (c.mobile) await page.touchscreen.tap(...at); else await page.mouse.click(...at);
    await page.waitForTimeout(12000);  // 이륙·워프 연출 (처음 출격은 건너뛰기 없음)
    if (c.slow > 1) await cdp.send("Emulation.setCPUThrottlingRate", { rate: c.slow });
    // 키보드로 원을 그리며 움직인다 (폰은 화면 터치 없이 키보드: FPS만 잼)
    const keys = ["KeyD", "KeyS", "KeyA", "KeyW"];
    let k = 0;
    const mover = setInterval(async () => { try { await page.keyboard.up(keys[k % 4]); k++; await page.keyboard.down(keys[k % 4]); await page.keyboard.press("Digit1"); } catch (e) {} }, 1500);  // 레벨업 카드는 1번으로 골라 계속 진행
    await page.keyboard.down(keys[0]);
    const run = await fps(page, 25000);
    clearInterval(mover);
    await page.screenshot({ path: OUT + c.name + "_run.png" });
    errors += log.length;
    lines.push(`${c.name}: 출격 ${run.toFixed(1)}fps, 콘솔 오류 ${log.length}` + (log.length ? "\n  " + log.join("\n  ") : ""));
    await ctx.close();
  }
  await browser.close();
  const text = lines.join("\n") + `\n전체 콘솔 오류: ${errors}\n`;
  require("fs").writeFileSync(OUT + "web_result.txt", text);
  console.log(text);
  process.exit(errors ? 1 : 0);
})();
