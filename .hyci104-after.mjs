#!/usr/bin/env node
import { execFileSync } from 'node:child_process';

const repo = 'valentinyeo/multiprompt';
const gh = (...args) => execFileSync('gh', args, { encoding: 'utf8', maxBuffer: 1 << 28 });
const api = path => JSON.parse(gh('api', path));
const minutes = job => (new Date(job.completed_at) - new Date(job.started_at)) / 60000;
const jobsOf = run => api(`repos/${repo}/actions/runs/${run.id}/jobs?per_page=100`).jobs;
const speedOf = jobs => jobs.find(job => job.name === 'switch-performance');

const runs = api(`repos/${repo}/actions/workflows/test.yml/runs?per_page=25&event=push&branch=master`).workflow_runs;
const save = runs.find(run => run.conclusion === 'success' && run.head_branch === 'master');
if (!save) throw new Error('no successful master push run of Tests yet');
const saveSpeed = speedOf(jobsOf(save));
if (!saveSpeed || saveSpeed.conclusion !== 'success') throw new Error(`master push speed job on run ${save.id} did not pass, so nothing was saved`);
console.log(`master push run ${save.id} ${save.head_sha.slice(0, 8)}: speed job ${minutes(saveSpeed).toFixed(1)} min, cache saved`);

const later = api(`repos/${repo}/actions/workflows/test.yml/runs?per_page=25`).workflow_runs
  .filter(run => ['pull_request', 'workflow_dispatch'].includes(run.event))
  .filter(run => new Date(run.created_at) > new Date(save.updated_at))
  .sort((a, b) => new Date(a.created_at) - new Date(b.created_at));
const warm = later.find(run => speedOf(jobsOf(run))?.status === 'completed');
if (!warm) throw new Error(`no warm pull request or manual Tests run has finished its speed job after master run ${save.id}`);
const warmSpeed = speedOf(jobsOf(warm));
if (warmSpeed.conclusion !== 'success') throw new Error(`warm speed job on run ${warm.id} is ${warmSpeed.conclusion}`);

const restore = (api(`repos/${repo}/actions/jobs/${warmSpeed.id}`).steps || []).find(step => /Restore Zig/.test(step.name));
const log = gh('api', `repos/${repo}/actions/jobs/${warmSpeed.id}/logs`);
const hit = /Cache restored from key: .*-zig-0\.16\.0-speed-/.test(log);
console.log(`warm run ${warm.id} ${warm.event} on ${warm.head_branch}: speed job ${minutes(warmSpeed).toFixed(1)} min, ${warmSpeed.conclusion}, restore step ${restore?.conclusion}, cache ${hit ? 'restored' : 'missed'}`);

if (!hit) throw new Error('the warm run did not restore the shared speed cache');
if (minutes(warmSpeed) > 7) throw new Error(`speed job still ${minutes(warmSpeed).toFixed(1)} min, over the 7 minute target`);
console.log('speed-job-faster-and-cache-restored');
