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
const os = require("os");
// WSL은 headless면 WebGL이 소프트웨어(SwiftShader/llvmpipe)라, 창을 띄우고 d3d12로 GPU를 쓴다. 측정 중 창을 가리지 말 것.
// WSL에서는 CHROME에 headless shell이 아닌 정식 Chromium을 주거나 비워 둔다.
const wsl = process.platform === "linux" && /microsoft/i.test(os.release());
const launchOpts = wsl
  ? {
      executablePath: process.env.CHROME,
      headless: false,
      args: ["--ignore-gpu-blocklist", "--enable-gpu", "--use-angle=gl"],
      env: { ...process.env, GALLIUM_DRIVER: "d3d12" },
    }
  : { executablePath: process.env.CHROME };
(async () => {
  const browser = await chromium.launch(launchOpts);
  const rows = [];
  let errors = 0;
  for (const scene of ["early", "late"]) {
    for (const c of CASES) {
      for (const [ver, port] of VERSIONS) {
        const load = os.loadavg()[0].toFixed(2); // uptime 출력 형식이 맥·리눅스가 달라 os로 읽음
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
        // 맥·데스크탑 결과를 구분하려고 WebGL 렌더러 이름을 같이 남김
        const renderer = await page.evaluate(() => {
          const gl = document.createElement("canvas").getContext("webgl2");
          const ext = gl && gl.getExtension("WEBGL_debug_renderer_info");
          return ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : "알 수 없음";
        });
        for (let i = 0; i < 120 && !perf; i++) await page.waitForTimeout(1000);
        await page.screenshot({ path: `${OUT}${scene}_${c.name}_${ver}.png` });
        errors += log.length;
        rows.push({ scene, case: c.name, ver, load, renderer, ...(perf || { fps: "시간 초과" }), errors: log.length });
        console.log(JSON.stringify(rows[rows.length - 1]) + (log.length ? "\n  " + log.join("\n  ") : ""));
        await ctx.close();
      }
    }
  }
  await browser.close();
  require("fs").writeFileSync(OUT + "perf_web.json", JSON.stringify(rows, null, 1));
  process.exit(errors ? 1 : 0);
})();
