// 웹 빌드 확인: 콘솔 오류, 기지·연구소 FPS (PC, PC CPU 4배 느림, 폰 844x390 터치). 서버는 따로 띄움 (http://localhost:8765/).
// 실행: NODE_PATH=<playwright가 있는 node_modules> node review/v070_fix_impl/check/web_check.cjs
const { chromium } = require("playwright");
const OUT = __dirname + "/web/";
const URL = "http://localhost:8765/index.html";
const CASES = [
  { name: "pc", vp: { width: 1280, height: 720 }, slow: 1, research: [340, 200] },
  { name: "pc_cpu4x", vp: { width: 1280, height: 720 }, slow: 4, research: [340, 200] },
  { name: "phone", vp: { width: 844, height: 390 }, slow: 1, mobile: true, research: [273, 90] },
  { name: "phone_cpu4x", vp: { width: 844, height: 390 }, slow: 4, mobile: true, research: [273, 90] },
];
async function fps(page, ms) {
  return page.evaluate((ms) => new Promise((ok) => {
    let n = 0; const t0 = performance.now();
    const f = () => { n++; if (performance.now() - t0 < ms) requestAnimationFrame(f); else ok(n * 1000 / (performance.now() - t0)); };
    requestAnimationFrame(f);
  }), ms);
}
(async () => {
  const browser = await chromium.launch(process.env.CHROME ? { executablePath: process.env.CHROME } : {});
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
    if (c.slow > 1) await cdp.send("Emulation.setCPUThrottlingRate", { rate: c.slow });
    await page.waitForTimeout(1000);
    const base = await fps(page, 5000);
    await page.screenshot({ path: OUT + c.name + "_base.png" });
    if (c.mobile) await page.touchscreen.tap(...c.research); else await page.mouse.click(...c.research);
    await page.waitForTimeout(1500);
    const research = await fps(page, 5000);
    await page.screenshot({ path: OUT + c.name + "_research.png" });
    errors += log.length;
    lines.push(`${c.name}: 기지 ${base.toFixed(1)}fps, 연구소 ${research.toFixed(1)}fps, 콘솔 오류 ${log.length}` + (log.length ? "\n  " + log.join("\n  ") : ""));
    await ctx.close();
  }
  await browser.close();
  const text = lines.join("\n") + `\n전체 콘솔 오류: ${errors}\n`;
  require("fs").writeFileSync(OUT + "result.txt", text);
  console.log(text);
  process.exit(errors ? 1 : 0);
})();
