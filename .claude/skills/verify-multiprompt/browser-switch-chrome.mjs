import { createRequire } from 'node:module';
import path from 'node:path';

const require = createRequire(path.join(process.env.VERIFY_BROWSER_MODULE, 'package.json'));
console.log(require('puppeteer').executablePath());
