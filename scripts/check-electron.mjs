// Preflight check for `npm run dev`.
// electron-vite fails with a cryptic "Error: Electron uninstall" when the
// Electron binary is missing (e.g. npm skipped Electron's postinstall
// script). This script detects that state and prints an actionable fix.
import { existsSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

/**
 * Checks whether the Electron binary referenced by the electron package is
 * present on disk.
 *
 * @param {string} electronPackageDir - Path to node_modules/electron.
 * @returns {string | null} A human-readable issue description, or null when
 * the binary is installed correctly.
 */
export function findElectronBinaryIssue(electronPackageDir) {
  const pathFile = join(electronPackageDir, 'path.txt');
  if (!existsSync(pathFile)) {
    return `path.txt is missing in ${electronPackageDir}`;
  }
  const relativeBinaryPath = readFileSync(pathFile, 'utf8').trim();
  const binaryPath = join(electronPackageDir, 'dist', relativeBinaryPath);
  if (!existsSync(binaryPath)) {
    return `Electron binary is missing at ${binaryPath}`;
  }
  return null;
}

function runCheck() {
  const projectRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
  const electronPackageDir = join(projectRoot, 'node_modules', 'electron');
  const issue = findElectronBinaryIssue(electronPackageDir);
  if (issue === null) {
    return;
  }
  console.error(
    [
      'Electron is not installed correctly:',
      `  ${issue}`,
      '',
      'This usually happens when npm install skips the Electron postinstall',
      'script that downloads the binary. To fix it, run:',
      '',
      '  node node_modules/electron/install.js',
      '',
    ].join('\n')
  );
  process.exit(1);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  runCheck();
}
