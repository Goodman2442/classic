#!/usr/bin/env node
// Снимает страницу на трёх ширинах, в светлой и тёмной теме.
//
//   node shot.mjs <url|путь-к-html> [выходная-папка] [--themes light,dark] [--full]
//
// По умолчанию снимается первый экран: именно его разглядывают при критике,
// и он влезает в модель целиком. Флаг --full добавляет снимок всей страницы —
// для проверки ритма секций, но у длинных страниц он выходит в десятки тысяч
// пикселей и детали на нём уже не читаются.
//
// Печатает пути к снимкам — по одному на строку, чтобы агент мог их прочитать.

import { existsSync } from "node:fs";
import { mkdir } from "node:fs/promises";
import { pathToFileURL } from "node:url";
import { execSync } from "node:child_process";
import { createRequire } from "node:module";

const VIEWPORTS = [
  { name: "mobile", width: 390, height: 844 },
  { name: "tablet", width: 834, height: 1112 },
  { name: "desktop", width: 1440, height: 900 },
];

// Playwright может лежать локально или глобально — пробуем оба пути,
// прежде чем сдаваться.
function loadPlaywright() {
  const require = createRequire(import.meta.url);
  try {
    return require("playwright");
  } catch {}
  try {
    const globalRoot = execSync("npm root -g", { encoding: "utf8" }).trim();
    return createRequire(globalRoot + "/").call(null, "playwright");
  } catch {}
  try {
    const globalRoot = execSync("npm root -g", { encoding: "utf8" }).trim();
    return require(globalRoot + "/playwright");
  } catch {}
  console.error(
    "Playwright не найден. Поставьте его: npm i -g playwright\n" +
      "Браузеры: npx playwright install chromium",
  );
  process.exit(1);
}

const [, , target, outDirArg, ...rest] = process.argv;
if (!target) {
  console.error("Укажите URL или путь к html-файлу.");
  process.exit(2);
}

const themesArg = rest.find((a) => a.startsWith("--themes="));
const themes = themesArg ? themesArg.split("=")[1].split(",") : ["light", "dark"];
const wantFull = rest.includes("--full");
const outDir = outDirArg && !outDirArg.startsWith("--") ? outDirArg : "shots";

const url = /^https?:\/\//.test(target)
  ? target
  : existsSync(target)
    ? pathToFileURL(target).href
    : (() => {
        console.error(`Не найдено: ${target}`);
        process.exit(2);
      })();

const { chromium } = loadPlaywright();
await mkdir(outDir, { recursive: true });

// Предпочитаем сборку Chromium от Playwright: она зафиксирована по версии и
// совпадает с той, что стоит в облачных сессиях, поэтому снимки одинаковы
// везде. Если её не скачивали, откатываемся на установленный Google Chrome —
// он запускается во временном профиле, так что расширения и куки на снимок
// всё равно не влияют.
async function launch() {
  try {
    return await chromium.launch();
  } catch (e) {
    for (const channel of ["chrome", "msedge"]) {
      try {
        const b = await chromium.launch({ channel });
        console.error(`Chromium от Playwright не найден, снимаю через ${channel}.`);
        return b;
      } catch {}
    }
    console.error(
      "Не удалось запустить браузер. Поставьте сборку Playwright:\n" +
        "  npx playwright install chromium\n" +
        "либо убедитесь, что установлен Google Chrome.\n\n" +
        String(e.message || e),
    );
    process.exit(1);
  }
}

const browser = await launch();
const written = [];

for (const theme of themes) {
  for (const vp of VIEWPORTS) {
    const context = await browser.newContext({
      viewport: { width: vp.width, height: vp.height },
      colorScheme: theme,
      deviceScaleFactor: 2,
      reducedMotion: "no-preference",
    });
    const page = await context.newPage();
    const errors = [];
    page.on("console", (m) => m.type() === "error" && errors.push(m.text()));
    page.on("pageerror", (e) => errors.push(String(e)));

    await page.goto(url, { waitUntil: "networkidle", timeout: 30000 });
    // Дать шрифтам и входным анимациям осесть, иначе снимок ловит середину перехода.
    await page.evaluate(() => document.fonts?.ready);
    await page.waitForTimeout(400);

    // Горизонтальный скролл на body — частая поломка, которую на глаз
    // по снимку не всегда видно.
    const overflow = await page.evaluate(
      () => document.documentElement.scrollWidth > window.innerWidth + 1,
    );

    const file = `${outDir}/${theme}-${vp.name}.png`;
    await page.screenshot({ path: file, fullPage: false });
    written.push({ file, overflow, errors });

    if (wantFull) {
      const height = await page.evaluate(() => document.body.scrollHeight);
      const fullFile = `${outDir}/${theme}-${vp.name}-full.png`;
      await page.screenshot({ path: fullFile, fullPage: true });
      written.push({
        file: fullFile,
        overflow: false,
        errors: [],
        tall: height > 8000 ? height : 0,
      });
    }

    await context.close();
  }
}

await browser.close();

for (const w of written) {
  const flags = [];
  if (w.overflow) flags.push("ГОРИЗОНТАЛЬНЫЙ СКРОЛЛ");
  if (w.errors.length) flags.push(`ОШИБОК В КОНСОЛИ: ${w.errors.length}`);
  if (w.tall) flags.push(`высота ${w.tall}px, детали на снимке не читаются`);
  console.log(w.file + (flags.length ? "  <- " + flags.join(", ") : ""));
}
for (const w of written) {
  for (const e of w.errors.slice(0, 3)) console.log(`  [${w.file}] ${e}`);
}
