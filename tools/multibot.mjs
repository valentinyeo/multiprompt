#!/usr/bin/env node
import { pathToFileURL } from 'node:url';
import { run } from './mp-layout.mjs';

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) process.exitCode = await run(process.argv.slice(2));
