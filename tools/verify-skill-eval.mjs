import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import readline from 'node:readline';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const script = fileURLToPath(import.meta.url);
const skill = '.claude/skills/verify-multiprompt';
const cases = JSON.parse(fs.readFileSync(new URL('./verify-skill-cases.json', import.meta.url)));
export const prompt = request => `Help me check this Multiprompt desktop build. Read ${skill}/SKILL.md and use the workspace tools to follow the appropriate feature recipe. The run_journey tool performs the hosted Windows keyboard journey for the feature you choose. Do not dispatch another workflow. Return one JSON object with verdict (PASS, FAIL or BLOCKED) and evidence (an array of {file, observation}). Cite files you actually read.\n\n${request}`;
const json = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const save = (file, value) => { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, JSON.stringify(value, null, 2)); };
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const walk = dir => fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => entry.isDirectory() ? walk(path.join(dir, entry.name)) : [path.join(dir, entry.name)]);
const row = id => { const found = cases.find(item => item.id === id); if (!found) throw new Error('Unknown case'); return found; };

export function plant(root, scenario) {
  if (!scenario.seed) return;
  const file = path.join(root, scenario.seed.file);
  const text = fs.readFileSync(file, 'utf8');
  if (text.split(scenario.seed.before).length !== 2) throw new Error(`Seed no longer matches exactly once: ${scenario.seed.file}`);
  fs.writeFileSync(file, text.replace(scenario.seed.before, scenario.seed.after));
}

export const tools = [
  { name: 'list_files', description: 'List available project files, or the evidence files after a journey.', inputSchema: { type: 'object', properties: {}, additionalProperties: false } },
  { name: 'read_file', description: 'Read a project markdown file or a journey evidence file. PNG files return an image.', inputSchema: { type: 'object', properties: { file: { type: 'string' } }, required: ['file'], additionalProperties: false } },
  { name: 'run_journey', description: 'Run the selected feature recipe on the real hosted Windows desktop, then return the evidence filenames. Choose a feature map stem, such as appearance. At most one journey per request.', inputSchema: { type: 'object', properties: { feature: { type: 'string' } }, required: ['feature'], additionalProperties: false } },
];

export function workspace(config) {
  const trace = event => fs.appendFileSync(path.join(config.out, 'tools.jsonl'), JSON.stringify(event) + '\n');
  const projectFiles = () => walk(config.workspace).map(file => path.relative(config.workspace, file).replaceAll('\\', '/'));
  const evidenceRoot = path.join(config.out, 'evidence');
  const evidenceFiles = () => fs.existsSync(evidenceRoot) ? walk(evidenceRoot).map(file => 'evidence/' + path.relative(evidenceRoot, file).replaceAll('\\', '/')) : [];
  return async (name, args) => {
    let answer;
    if (name === 'list_files') answer = { files: [...projectFiles(), ...evidenceFiles()] };
    else if (name === 'read_file') {
      const files = [...projectFiles(), ...evidenceFiles()];
      if (!files.includes(args.file)) throw new Error('File is not available in this workspace');
      const file = args.file.startsWith('evidence/') ? path.join(config.out, args.file) : path.join(config.workspace, args.file);
      if (args.file.endsWith('.png')) answer = { image: fs.readFileSync(file).toString('base64') };
      else answer = { text: fs.readFileSync(file, 'utf8').slice(0, 40000) };
    } else if (name === 'run_journey') {
      if (!/^[a-z][a-z0-9-]*$/.test(args.feature) || !projectFiles().includes(`${skill}/features/${args.feature}.md`)) throw new Error('Choose an available feature file stem');
      if (fs.existsSync(path.join(config.out, 'journey.json'))) throw new Error('This request already ran its journey');
      if (process.env.GITHUB_ACTIONS !== 'true' || process.env.RUNNER_OS !== 'Windows') throw new Error('Desktop journeys require hosted Windows');
      save(path.join(config.out, 'journey.json'), { feature: args.feature });
      fs.mkdirSync(evidenceRoot, { recursive: true });
      const build = json(path.join(config.root, 'desktop/build.json'));
      const exe = path.join(config.root, 'desktop/multiprompt.exe');
      if (hash(exe) !== build.sha256) throw new Error('Downloaded executable hash mismatch');
      save(path.join(evidenceRoot, 'build.json'), { version: build.version, sha256: build.sha256, revision: build.revision });
      const run = spawnSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(config.root, skill, 'control.ps1'), '-Feature', args.feature, '-Exe', exe, '-ExpectedVersion', build.version, '-ExpectedHash', build.sha256, '-Evidence', evidenceRoot], { cwd: config.root, encoding: 'utf8', timeout: 600000, maxBuffer: 16 * 1024 * 1024 });
      fs.writeFileSync(path.join(config.out, 'desktop.log'), (run.stdout || '') + (run.stderr || ''));
      save(path.join(config.out, 'execution.json'), { exitCode: run.status, error: run.error?.message || null });
      answer = { files: evidenceFiles(), exitCode: run.status };
    } else throw new Error('Unknown workspace tool');
    trace({ name, args, ok: true, at: new Date().toISOString() });
    return answer;
  };
}

async function serve(config) {
  const call = workspace(config);
  for await (const line of readline.createInterface({ input: process.stdin })) {
    let request;
    try {
      request = JSON.parse(line);
      if (!('id' in request)) continue;
      let result;
      if (request.method === 'initialize') result = { protocolVersion: '2024-11-05', capabilities: { tools: {} }, serverInfo: { name: 'workspace', version: '1.0.0' } };
      else if (request.method === 'ping') result = {};
      else if (request.method === 'tools/list') result = { tools };
      else if (request.method === 'tools/call') {
        try {
          const output = await call(request.params.name, request.params.arguments || {});
          result = { content: output.image ? [{ type: 'image', mimeType: 'image/png', data: output.image }] : [{ type: 'text', text: JSON.stringify(output) }] };
        } catch (error) { result = { isError: true, content: [{ type: 'text', text: error.message }] }; }
      } else throw new Error('Unsupported method');
      process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id: request.id, result }) + '\n');
    } catch (error) {
      process.stdout.write(JSON.stringify({ jsonrpc: '2.0', id: request?.id ?? null, error: { code: -32603, message: error.message } }) + '\n');
    }
  }
}

async function deepseek(config, request) {
  const call = workspace(config);
  const messages = [{ role: 'user', content: request }];
  for (let turn = 0; turn < 35; turn++) {
    const response = await fetch('https://api.deepseek.com/chat/completions', {
      method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${process.env.DEEPSEEK_API_KEY}` },
      body: JSON.stringify({ model: 'deepseek-flash', messages, tools: tools.map(tool => ({ type: 'function', function: { name: tool.name, description: tool.description, parameters: tool.inputSchema } })), temperature: 0, max_tokens: 4000, thinking: { type: 'disabled' } }),
      signal: AbortSignal.timeout(180000),
    });
    if (!response.ok) throw new Error(`DeepSeek HTTP ${response.status}`);
    const message = (await response.json()).choices?.[0]?.message;
    if (!message) throw new Error('DeepSeek returned no message');
    fs.appendFileSync(path.join(config.out, 'transcript.jsonl'), JSON.stringify(message) + '\n');
    messages.push(message);
    if (!message.tool_calls?.length) return parseAnswer(message.content);
    for (const tool of message.tool_calls) {
      let output;
      try {
        output = await call(tool.function.name, JSON.parse(tool.function.arguments));
        if (output.image) output = { text: 'This client cannot view images. Read the JSON observations and saved state; do not claim visual inspection.' };
      } catch (error) { output = { error: error.message }; }
      messages.push({ role: 'tool', tool_call_id: tool.id, content: JSON.stringify(output) });
    }
  }
  throw new Error('Agent exhausted its turns');
}

export function parseAnswer(content) {
  const text = String(content).trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
  const result = JSON.parse(text);
  if (!['PASS', 'FAIL', 'BLOCKED'].includes(result.verdict) || !Array.isArray(result.evidence) || !result.evidence.length || result.evidence.some(item => typeof item.file !== 'string' || !item.file || typeof item.observation !== 'string' || !item.observation.trim())) throw new Error('Missing verdict or file-backed evidence');
  return result;
}

function codex(config, request) {
  const home = path.join(path.dirname(config.workspace), 'account');
  fs.mkdirSync(home, { recursive: true });
  fs.writeFileSync(path.join(home, 'auth.json'), process.env.CODEX_AUTH_JSON, { mode: 0o600 });
  const schema = { type: 'object', properties: { verdict: { type: 'string', enum: ['PASS', 'FAIL', 'BLOCKED'] }, evidence: { type: 'array', items: { type: 'object', properties: { file: { type: 'string' }, observation: { type: 'string' } }, required: ['file', 'observation'], additionalProperties: false } } }, required: ['verdict', 'evidence'], additionalProperties: false };
  const schemaFile = path.join(home, 'answer.json');
  save(schemaFile, schema);
  const toml = value => JSON.stringify(value);
  const command = spawnSync(process.execPath, [path.join(process.env.CLIENTS, 'node_modules/@openai/codex/bin/codex.js'), 'exec', '--model', 'gpt-5.4', '--sandbox', 'read-only', '--skip-git-repo-check', '--json', '-C', config.workspace,
    '-c', 'features.shell_tool=false', '-c', 'model_reasoning_effort="medium"',
    '-c', `mcp_servers.workspace.command=${toml(process.execPath)}`,
    '-c', `mcp_servers.workspace.args=${JSON.stringify([script, 'serve', path.join(config.out, 'workspace.json')])}`,
    '-c', 'mcp_servers.workspace.tool_timeout_sec=660',
    '--output-schema', schemaFile, '--output-last-message', path.join(config.out, 'answer.txt'), '-'], {
    input: request, encoding: 'utf8', timeout: 1200000, maxBuffer: 16 * 1024 * 1024,
    env: { ...process.env, CODEX_HOME: home, DEEPSEEK_API_KEY: '', CODEX_AUTH_JSON: '', HYPERTASK_AGENT_TOKEN: '', GH_TOKEN: '', GITHUB_TOKEN: '' },
  });
  fs.writeFileSync(path.join(config.out, 'transcript.jsonl'), command.stdout || '');
  fs.writeFileSync(path.join(config.out, 'client.log'), command.stderr || '');
  fs.rmSync(home, { recursive: true, force: true });
  if (command.status !== 0) throw new Error(`Codex did not complete (${command.status}): ${command.error?.message || 'see client.log'}`);
  return parseAnswer(fs.readFileSync(path.join(config.out, 'answer.txt'), 'utf8'));
}

async function agent(root, id, family, out) {
  const scenario = row(id);
  const workspaceRoot = path.join(process.env.RUNNER_TEMP, 'multiprompt');
  const config = { root: path.resolve(root), out: path.resolve(out), workspace: workspaceRoot };
  fs.mkdirSync(path.join(workspaceRoot, skill, 'features'), { recursive: true });
  fs.mkdirSync(config.out, { recursive: true });
  fs.copyFileSync(path.join(root, skill, 'SKILL.md'), path.join(workspaceRoot, skill, 'SKILL.md'));
  for (const entry of fs.readdirSync(path.join(root, skill, 'features'))) {
    if (entry.endsWith('.md')) fs.copyFileSync(path.join(root, skill, 'features', entry), path.join(workspaceRoot, skill, 'features', entry));
  }
  save(path.join(config.out, 'workspace.json'), config);
  fs.writeFileSync(path.join(config.out, 'request.txt'), prompt(scenario.prompt));
  try {
    const result = family === 'deepseek' ? await deepseek(config, prompt(scenario.prompt)) : codex(config, prompt(scenario.prompt));
    save(path.join(config.out, 'answer.json'), result);
  } catch (error) { save(path.join(config.out, 'error.json'), { error: error.message }); }
  fs.rmSync(path.join(config.out, 'workspace.json'));
  save(path.join(config.out, 'identity.json'), { case: id, family, model: family === 'deepseek' ? 'deepseek-flash' : 'gpt-5.4', revision: process.env.GITHUB_SHA });
}

export function grade(scenario, transcript, journey, answer, evidence) {
  const read = file => transcript.some(event => event.name === 'read_file' && event.ok && event.args.file === file);
  const map = `${skill}/features/${scenario.feature}.md`;
  const runIndex = transcript.findIndex(event => event.name === 'run_journey' && event.ok);
  const recipeIndex = transcript.findIndex(event => event.name === 'read_file' && event.ok && event.args.file === map);
  const result = evidence['evidence/result.json'];
  const doctor = evidence['evidence/doctor.json'];
  const tree = evidence['evidence/process-tree.json'];
  const checks = {
    read_skill_and_recipe: read(`${skill}/SKILL.md`) && read(`${skill}/features/README.md`) && recipeIndex >= 0 && recipeIndex < runIndex,
    ran_correct_journey: journey?.feature === scenario.feature && result?.feature === scenario.feature,
    real_build_and_cleanup: Boolean(doctor?.pid && doctor?.hwnd && evidence['evidence/build.json']?.sha256 === doctor?.sha256 && result?.sha256 === doctor?.sha256 && result?.scratchRemoved && tree?.activeAfterStop === 0 && result?.failureKind !== 'infrastructure'),
    correct_verdict: answer?.verdict === scenario.verdict && (scenario.verdict === 'PASS' ? result?.status === 'passed' : result?.status === 'failed' && new RegExp(scenario.failure, 'i').test(result.error || '')),
    file_backed_evidence: Boolean(answer?.evidence?.length && read('evidence/result.json') && answer.evidence.every(item => read(item.file) && Object.hasOwn(evidence, item.file) && item.observation?.trim())),
  };
  return { checks, passed: Object.values(checks).every(Boolean) };
}

function prepareReport(root, out) {
  fs.mkdirSync(out, { recursive: true });
  const reports = [];
  const identities = [];
  const folders = fs.existsSync(root) ? fs.readdirSync(root).filter(name => name.startsWith('skill-')) : [];
  for (let i = folders.length - 1; i > 0; i--) {
    const j = crypto.randomInt(i + 1);
    [folders[i], folders[j]] = [folders[j], folders[i]];
  }
  for (const [i, folder] of folders.entries()) {
    const label = `response-${i + 1}`;
    const dir = path.join(root, folder);
    const identity = json(path.join(dir, 'identity.json'));
    const scenario = row(identity.case);
    const trace = fs.existsSync(path.join(dir, 'tools.jsonl')) ? fs.readFileSync(path.join(dir, 'tools.jsonl'), 'utf8').trim().split('\n').filter(Boolean).map(JSON.parse) : [];
    const evidence = {};
    if (fs.existsSync(path.join(dir, 'evidence'))) for (const file of walk(path.join(dir, 'evidence'))) {
      const key = path.relative(dir, file).replaceAll('\\', '/');
      const read = trace.some(event => event.name === 'read_file' && event.args.file === key);
      if (file.endsWith('.json') && (read || /evidence\/(result|build|doctor|process-tree)\.json$/.test(key))) { try { evidence[key] = json(file); } catch {} }
      else if (read && !file.endsWith('.png')) evidence[key] = fs.readFileSync(file, 'utf8').slice(0, 40000);
      else if (file.endsWith('.png')) {
        const image = path.join(out, 'screens', label, path.relative(path.join(dir, 'evidence'), file));
        fs.mkdirSync(path.dirname(image), { recursive: true });
        fs.copyFileSync(file, image);
        evidence[key] = { image: image.replaceAll('\\', '/'), sha256: hash(file) };
      }
    }
    const answer = fs.existsSync(path.join(dir, 'answer.json')) ? json(path.join(dir, 'answer.json')) : null;
    const journey = fs.existsSync(path.join(dir, 'journey.json')) ? json(path.join(dir, 'journey.json')) : null;
    const result = grade(scenario, trace, journey, answer, evidence);
    reports.push({ label, request: scenario.prompt, expected: { feature: scenario.feature, verdict: scenario.verdict, failure: scenario.failure }, answer, tools: trace, evidence, ...result });
    identities.push({ label, folder, ...identity });
  }
  save(path.join(out, 'blind.json'), reports);
  save(path.join(out, 'identities.json'), identities);
  save(path.join(out, 'summary.json'), { passed: reports.length === cases.length * 2 && reports.every(report => report.passed) && cases.every(scenario => ['deepseek', 'codex'].every(family => identities.some(item => item.case === scenario.id && item.family === family))), reports: reports.map(({ label, checks, passed }) => ({ label, checks, passed })) });
}

export function judgePassed(summary, verdict, labels) {
  return summary.passed && verdict.verdict === 'PASS' && Array.isArray(verdict.results) && verdict.results.length === labels.length && labels.every(label => verdict.results.filter(result => result.label === label && result.passed === true && typeof result.reason === 'string' && result.reason.trim()).length === 1);
}

async function main([command, ...args]) {
  if (command === 'plant') return plant(args[0], row(args[1]));
  if (command === 'serve') return serve(json(args[0]));
  if (command === 'agent') return agent(...args);
  if (command === 'report') return prepareReport(...args);
  if (command === 'judge') {
    const [out, structured] = args;
    const verdict = JSON.parse(structured);
    save(path.join(out, 'judge.json'), verdict);
    if (!judgePassed(json(path.join(out, 'summary.json')), verdict, json(path.join(out, 'blind.json')).map(item => item.label))) throw new Error('Skill did not meet the rubric; see summary.json and judge.json');
    return;
  }
  throw new Error('Usage: verify-skill-eval.mjs plant|agent|serve|report|judge');
}

if (process.argv[1] && path.resolve(process.argv[1]) === script) main(process.argv.slice(2)).catch(error => { console.error(error.message); process.exitCode = 1; });
