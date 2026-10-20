import { readFileSync } from 'node:fs';

const home = readFileSync(new URL('./dist/index.html', import.meta.url), 'utf8');
const needed = ['domainId: "b3508753-68db-46ba-92e0-6fd816681e3f"', 'src="https://api.endlesstesting.ai/api/sdk.js"'];
const missing = needed.filter((s) => !home.includes(s));

if (missing.length) {
  console.error(`multiprompt.dev homepage lost the Endless Testing snippet: ${missing.join(', ')}`);
  process.exit(1);
}
console.log('Endless Testing snippet is on the homepage.');
