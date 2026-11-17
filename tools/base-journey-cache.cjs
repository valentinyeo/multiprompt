const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { execFileSync } = require('node:child_process');
const { journeyMatrix } = require('./verify-features.cjs');
const { describeRun, runOutcome } = require('./pr-verifier.cjs');

function cacheName(variant, harness) {
  if (!/^[a-z][a-z0-9-]*$/.test(variant.feature) || !/^[0-9a-f]{40}$/.test(variant['app-revision']) || !/^[0-9a-f]{64}$/.test(harness) ||
      ![96, 120, 144].includes(variant['caption-dpi']) || !['light', 'dark'].includes(variant['caption-browser-theme'])) throw new Error('Invalid base cache identity');
  return `base-v1-${variant.feature}-${variant['app-revision']}-${harness}-${variant['caption-dpi']}-${variant['caption-browser-theme']}`;
}

function evidenceName(variant) {
  const suffix = ['title-bar', 'window-controls', 'bot-photo'].includes(variant.feature) ? `-${variant['caption-dpi']}-${variant['caption-browser-theme']}` : '';
  return `verify-${variant.feature}-${variant['app-revision']}${suffix}`;
}

function harnessVersion(revision = 'HEAD', workflowRevision = revision, cwd = process.cwd(), workflowFile) {
  const git = args => execFileSync('git', args, { cwd, encoding: 'utf8' });
  const catalogs = new Set(['app_state.zig', 'command_palette.zig', 'sidebar.zig', 'shortcuts.zig', 'notify_ports.zig', 'changelog.zig']);
  const files = git(['ls-tree', '-r', revision, '--', '.claude/skills/verify-multiprompt', 'tools', 'assets', 'extension', 'service', 'shared', 'src', 'build.zig', 'build.zig.zon'])
    .split('\n').filter(line => {
      const file = line.split('\t')[1] || '';
      if (file.startsWith('tools/') && /(?:\.test\.[cm]?js$|\/(?:test_[^/]+|[^/]+[_-]test)\.py$|\.md$)/.test(file)) return false;
      return !/^src\/[^/]+\.zig$/.test(file) || catalogs.has(path.posix.basename(file));
    }).join('\n');
  const workflow = workflowFile ? fs.readFileSync(workflowFile, 'utf8') : git(['show', `${workflowRevision}:.github/workflows/verify.yml`]);
  if (!files || !workflow) throw new Error('Cannot identify runtime harness');
  return createHash('sha256').update(`base-cache-v1\n${files}\n${workflow}`).digest('hex');
}

function readJson(directory, name) {
  return JSON.parse(fs.readFileSync(path.join(directory, name), 'utf8').replace(/^\uFEFF/, ''));
}

function completeEvidence(directory, options) {
  if (options.variant.feature === 'tmux-binding') return false;
  try {
    cacheName(options.variant, options.harness);
    const result = readJson(directory, 'result.json');
    const build = readJson(directory, 'build.json');
    const doctor = readJson(directory, 'doctor.json');
    const run = describeRun(directory, evidenceName(options.variant));
    return ['passed', 'failed'].includes(result.status) && runOutcome(run) !== 'blocked' && run.screenshots.length > 0 &&
      !!result.cleanup && !/pending|unavailable|failed|error|lost|timeout|timed out/i.test(result.cleanup) &&
      doctor && typeof doctor === 'object' && build.revision === options.variant['app-revision'] && build.embeddedRevision === build.revision &&
      /^[0-9a-f]{40}$/.test(build.harnessRevision) && /^[0-9a-f]{64}$/.test(build.sha256);
  } catch { return false; }
}

function validEvidence(directory, options) {
  try {
    const manifest = readJson(directory, 'base-cache.json');
    return manifest.key === cacheName(options.variant, options.harness) && manifest.repo === options.repo &&
      String(manifest.runId) === String(options.runId) && completeEvidence(directory, options);
  } catch { return false; }
}

function stamp(directory, options) {
  fs.rmSync(path.join(directory, 'base-cache.json'), { force: true });
  if (!completeEvidence(directory, options)) return false;
  fs.writeFileSync(path.join(directory, 'base-cache.json'), JSON.stringify({ key: cacheName(options.variant, options.harness), repo: options.repo, runId: String(options.runId) }, null, 2));
  return true;
}

function api(endpoint) {
  return JSON.parse(execFileSync('gh', ['api', endpoint], { encoding: 'utf8', maxBuffer: 8 * 1024 * 1024 }));
}

function extract(repo, artifact, target) {
  const archive = `${target}.zip`;
  const fd = fs.openSync(archive, 'w');
  try {
    execFileSync('gh', ['api', `repos/${repo}/actions/artifacts/${artifact.id}/zip`], { stdio: ['ignore', fd, 'inherit'] });
  } finally { fs.closeSync(fd); }
  try {
    execFileSync('unzip', ['-q', archive, '-d', target], { stdio: 'inherit' });
  } finally { fs.rmSync(archive, { force: true }); }
}

function restore(options, directory) {
  const { repo, base, harness, features } = options;
  if (!Array.isArray(features) || new Set(features).size !== features.length) throw new Error('Expected unique journey names');
  for (const variant of journeyMatrix(features, base)) cacheName(variant, harness);
  fs.mkdirSync(directory, { recursive: true });
  const report = { base, harness, features: [], reused: [], beforeJobs: journeyMatrix(features, base).length, afterJobs: 0, sources: [] };
  const runs = new Map();
  for (const feature of features) {
    for (const variant of journeyMatrix([feature], base)) fs.rmSync(path.join(directory, evidenceName(variant)), { recursive: true, force: true });
    const scratch = fs.mkdtempSync(path.join(directory, '.restore-'));
    const restored = [];
    try {
      for (const variant of journeyMatrix([feature], base)) {
        const name = cacheName(variant, harness);
        let artifacts;
        try {
          artifacts = api(`repos/${repo}/actions/artifacts?name=${encodeURIComponent(name)}&per_page=100`).artifacts;
        } catch (error) {
          process.stderr.write(`Base cache lookup missed for ${feature}: ${error.message}\n`);
          break;
        }
        let hit = false;
        for (const artifact of artifacts.filter(item => item.name === name && !item.expired && item.workflow_run?.id && String(item.workflow_run.id) !== String(options.runId)).sort((a, b) => b.id - a.id)) {
          const target = path.join(scratch, evidenceName(variant));
          try {
            const id = artifact.workflow_run.id;
            if (!runs.has(id)) runs.set(id, api(`repos/${repo}/actions/runs/${id}`));
            const run = runs.get(id);
            if (run.repository?.full_name !== repo || run.head_repository?.full_name !== repo ||
                !['pull_request', 'workflow_dispatch', 'push'].includes(run.event) ||
                !['.github/workflows/pr-verifier.yml', '.github/workflows/verify.yml'].includes(run.path)) continue;
            extract(repo, artifact, target);
            if (!validEvidence(target, { variant, harness, repo, runId: id })) continue;
            restored.push({ directory: target, artifactId: artifact.id, runId: id });
            hit = true;
            break;
          } catch (error) {
            process.stderr.write(`Base cache artifact ${artifact.id} rejected: ${error.message}\n`);
          } finally {
            if (!hit) fs.rmSync(target, { recursive: true, force: true });
          }
        }
        if (!hit) break;
      }
      if (restored.length === journeyMatrix([feature], base).length) {
        report.reused.push(feature);
        for (const item of restored) {
          const target = path.join(directory, path.basename(item.directory));
          fs.rmSync(target, { recursive: true, force: true });
          fs.renameSync(item.directory, target);
          report.sources.push({ feature, artifactId: item.artifactId, runId: item.runId });
        }
      } else report.features.push(feature);
    } finally { fs.rmSync(scratch, { recursive: true, force: true }); }
  }
  report.afterJobs = journeyMatrix(report.features, base).length;
  fs.writeFileSync(path.join(directory, 'reuse.json'), JSON.stringify(report, null, 2));
  return report;
}

function main([command, directory], env) {
  if (command === 'restore') {
    const harness = env.HARNESS_VERSION || harnessVersion('HEAD', 'HEAD', process.cwd(), env.WORKFLOW_FILE);
    const report = restore({ repo: env.REPO, base: env.BASE_SHA, harness, features: JSON.parse(env.FEATURES), runId: env.RUN_ID }, directory);
    const line = `features=${JSON.stringify(report.features)}\nharness_version=${harness}\n`;
    if (env.GITHUB_OUTPUT) fs.appendFileSync(env.GITHUB_OUTPUT, line);
    process.stdout.write(line);
    const summary = `Base reuse: ${report.reused.length} journeys reused; ${report.beforeJobs} -> ${report.afterJobs} Windows journey jobs.\n`;
    process.stdout.write(summary);
    if (env.GITHUB_STEP_SUMMARY) fs.appendFileSync(env.GITHUB_STEP_SUMMARY, summary);
  } else if (command === 'stamp') {
    const variant = JSON.parse(env.VARIANT);
    if (stamp(directory, { variant, harness: env.HARNESS_VERSION, repo: env.REPO, runId: env.RUN_ID })) {
      const line = `name=${cacheName(variant, env.HARNESS_VERSION)}\n`;
      process.stdout.write(line);
      if (env.GITHUB_OUTPUT) fs.appendFileSync(env.GITHUB_OUTPUT, line);
    }
  } else throw new Error('Usage: base-journey-cache.cjs restore|stamp <evidence directory>');
}

module.exports = { cacheName, evidenceName, harnessVersion, validEvidence, stamp, restore };
if (require.main === module) {
  try { main(process.argv.slice(2), process.env); } catch (error) { console.error(error.message); process.exitCode = 1; }
}
