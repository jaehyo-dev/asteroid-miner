// 두 웹 빌드(직전 커밋 / 지금)를 같은 장면·같은 시드로 번갈아 잰다. 각 조합 1번씩.
// 실행: CHROME=<chrome-headless-shell> NODE_PATH=<playwright node_modules> node perf_web.cjs <출력 폴더> before=8791 after=8792
const { chromium } = require("playwright");
const OUT = process.argv[2] + "/";
const VERSIONS = process.argv.slice(3).map((a) => a.split("="));
const CASES = [
  { name: "pc", vp: { width: 1280, height: 720 }, slow: 1 },
  { name: "pc_cpu4x", vp: { width: 1280, height: 720 }, slow: 4 },
  { name: "phone", vp: { width: 844, height: 390 }, slow: 1, mobile: true },
];
const { execSync } = require("child_process");
(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROME });
  const rows = [];
  let errors = 0;
  for (const scene of ["early", "late"]) {
    for (const c of CASES) {
      for (const [ver, port] of VERSIONS) {
        const load = execSync("uptime").toString().split("averages: ")[1].split(" ")[0];
        const ctx = await browser.newContext({ viewport: c.vp, deviceScaleFactor: c.mobile ? 3 : 1, isMobile: !!c.mobile, hasTouch: !!c.mobile });
        const page = await ctx.newPage();
        const log = [];
        let perf = null;
        page.on("console", (m) => {
          if (m.type() === "error") log.push(m.text());
          if (m.text().startsWith("PERF:")) perf = JSON.parse(m.text().slice(5));
        });
        page.on("pageerror", (e) => log.push("pageerror: " + e.message));
        const cdp = await ctx.newCDPSession(page);
        if (c.slow > 1) await cdp.send("Emulation.setCPUThrottlingRate", { rate: c.slow });
        await page.goto(`http://localhost:${port}/index.html?scene=${scene}`);
        for (let i = 0; i < 120 && !perf; i++) await page.waitForTimeout(1000);
        await page.screenshot({ path: `${OUT}${scene}_${c.name}_${ver}.png` });
        errors += log.length;
        rows.push({ scene, case: c.name, ver, load, ...(perf || { fps: "시간 초과" }), errors: log.length });
        console.log(JSON.stringify(rows[rows.length - 1]) + (log.length ? "\n  " + log.join("\n  ") : ""));
        await ctx.close();
      }
    }
  }
  await browser.close();
  require("fs").writeFileSync(OUT + "perf_web.json", JSON.stringify(rows, null, 1));
  process.exit(errors ? 1 : 0);
})();
