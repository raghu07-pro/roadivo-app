const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const root = path.resolve(__dirname, '../..');
const swift = fs.readFileSync(path.join(root, 'App/CarBrowserInputScript.swift'), 'utf8');
const source = swift.match(/static let source = #"""\n([\s\S]*?)\n    """#/)[1];
const html = `<!doctype html><style>input,textarea,button{display:block;margin:14px;padding:12px}</style>
<form id="form" role="search"><input id="query" type="search" name="q" aria-label="Search">
<input id="other" type="text" name="name"><textarea id="note"></textarea><button>Go</button></form>
<input id="password" type="password"><input id="card" autocomplete="cc-number">
<input id="code" autocomplete="one-time-code"><input id="readonly" readonly><input id="disabled" disabled>
<output id="result"></output><script>
globalThis.events=[]; document.addEventListener('input',e=>events.push(['input',e.target.id]));
document.addEventListener('change',e=>events.push(['change',e.target.id]));
document.querySelector('form').addEventListener('submit',e=>{e.preventDefault();
document.querySelector('output').textContent=document.querySelector('#query').value;events.push(['submit']);});
</script>`;

async function isolated(session, frameId) {
  const { executionContextId } = await session.send('Page.createIsolatedWorld', {
    frameId, worldName: 'PlayCarTVCarInput'
  });
  async function evaluate(expression) {
    const result = await session.send('Runtime.evaluate', {
      expression, contextId: executionContextId, returnByValue: true, awaitPromise: true
    });
    if (result.exceptionDetails) throw new Error(result.exceptionDetails.text);
    return result.result.value;
  }
  await evaluate(`globalThis.messages=[];globalThis.webkit={messageHandlers:{playcartvCarInput:{
    postMessage(message){messages.push(message);}}}};${source}`);
  return {
    evaluate,
    messages: () => evaluate('messages'),
    edits: () => evaluate('messages.filter(m=>m.kind==="edit")'),
    apply: (request, text, submit = true) => evaluate(`playcartvCarInput.apply(
      ${JSON.stringify(request.documentID)},${JSON.stringify(request.requestID)},${JSON.stringify(text)},${submit})`)
  };
}

(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'],
    executablePath: process.env.PLAYCARTV_CHROMIUM_PATH });
  const page = await browser.newPage();
  const session = await page.context().newCDPSession(page);
  let tests = 0;
  async function test(name, run) { await run(); tests += 1; console.log(`PASS ${name}`); }
  try {
    await page.setContent(html);
    const { frameTree } = await session.send('Page.getFrameTree');
    const bridge = await isolated(session, frameTree.frame.id);
    await test('isolated bridge is ready and invisible to website JavaScript', async () => {
      assert.equal((await bridge.messages())[0].kind, 'ready');
      assert.equal(await page.evaluate(() => typeof globalThis.playcartvCarInput), 'undefined');
    });
    await test('trusted field click opens the editor request without reading the field value', async () => {
      await page.locator('#query').click();
      const [request] = await bridge.edits();
      assert.equal(request.label, 'Search'); assert.equal(request.search, true);
      assert.equal('value' in request, false);
      assert.equal((await bridge.messages()).some(m => m.kind === 'pointer'), true);
    });
    await test('Unicode and code-like text update the field, fire input/change, and submit its form', async () => {
      const request = (await bridge.edits()).at(-1);
      const text = 'music & తెలుగు " \' ` ${test} <script>nothing()</script>';
      assert.equal(await bridge.apply(request, text), true);
      assert.equal(await page.locator('#query').inputValue(), text);
      assert.equal(await page.locator('#result').textContent(), text);
      assert.deepEqual(await page.evaluate(() => events), [['input','query'],['change','query'],['submit']]);
      assert.equal(await bridge.apply(request, 'replay'), false);
    });
    await test('website-generated clicks cannot open a native editor', async () => {
      const count = (await bridge.edits()).length;
      await page.locator('#query').evaluate(el => el.click());
      assert.equal((await bridge.edits()).length, count);
    });
    await test('a newer field selection rejects an older editor result', async () => {
      await page.locator('#query').click(); const old = (await bridge.edits()).at(-1);
      await page.locator('#other').click(); const current = (await bridge.edits()).at(-1);
      assert.equal(await bridge.apply(old, 'wrong'), false);
      assert.equal(await bridge.apply(current, 'name', false), true);
      assert.equal(await page.locator('#other').inputValue(), 'name');
    });
    await test('password, card, one-time code, readonly and disabled fields are excluded', async () => {
      const count = (await bridge.edits()).length;
      for (const id of ['password','card','code','readonly','disabled']) {
        const box = await page.locator('#'+id).boundingBox();
        await page.mouse.click(box.x + 8, box.y + 8);
      }
      assert.equal((await bridge.edits()).length, count);
    });
    await test('a field removed before completion is rejected', async () => {
      await page.locator('#other').click(); const request = (await bridge.edits()).at(-1);
      await page.locator('#other').evaluate(el => el.remove());
      assert.equal(await bridge.apply(request, 'stale', false), false);
    });
    await test('textarea editing and length bounds do not submit the enclosing form', async () => {
      await page.locator('#note').click(); const request = (await bridge.edits()).at(-1);
      assert.equal(request.search, false);
      assert.equal(await bridge.apply(request, 'x'.repeat(4097), false), false);
      assert.equal(await bridge.apply(request, 'a\nb', false), true);
      assert.equal(await page.locator('#note').inputValue(), 'a\nb');
      assert.equal((await page.evaluate(() => events.filter(e=>e[0]==='submit'))).length, 1);
    });
    await test('an iframe edits and submits inside its original frame only', async () => {
      await page.route('https://frame.test/**', route => route.fulfill({ body: html, contentType: 'text/html' }));
      await page.evaluate(() => {
        const frame=document.createElement('iframe');frame.src='https://frame.test/';
        frame.style='width:700px;height:500px';document.body.prepend(frame);
      });
      await page.frameLocator('iframe').locator('#query').waitFor();
      const tree = (await session.send('Page.getFrameTree')).frameTree;
      const child = tree.childFrames.find(f=>f.frame.url==='https://frame.test/');
      const frameBridge = await isolated(session, child.frame.id);
      await page.frameLocator('iframe').locator('#query').click();
      const request = (await frameBridge.edits()).at(-1);
      assert.equal(await frameBridge.apply(request, 'iframe query'), true);
      assert.equal(await page.frameLocator('iframe').locator('#result').textContent(), 'iframe query');
      assert.notEqual(await page.locator('#query').inputValue(), 'iframe query');
    });
    await test('navigation replaces the document token and rejects a previous request', async () => {
      await page.locator('#query').click(); const request = (await bridge.edits()).at(-1);
      await page.setContent(html);
      const current = await isolated(session, frameTree.frame.id);
      assert.equal(await current.apply(request, 'stale navigation'), false);
    });
    console.log(`${tests} browser input integration checks passed (Chromium; not CarPlay or WebKit).`);
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
