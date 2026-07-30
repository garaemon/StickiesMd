import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore -- plain JS module without type declarations
import { findElectronBinaryIssue } from '../../scripts/check-electron.mjs';

const RELATIVE_BINARY_PATH = 'Electron.app/Contents/MacOS/Electron';

describe('findElectronBinaryIssue', () => {
  let electronPackageDir: string;

  beforeEach(() => {
    electronPackageDir = mkdtempSync(join(tmpdir(), 'electron-check-'));
  });

  afterEach(() => {
    rmSync(electronPackageDir, { recursive: true, force: true });
  });

  it('should_return_issue_when_path_file_is_missing', () => {
    const issue = findElectronBinaryIssue(electronPackageDir);

    expect(issue).toContain('path.txt');
  });

  it('should_return_issue_when_binary_is_missing', () => {
    writeFileSync(join(electronPackageDir, 'path.txt'), RELATIVE_BINARY_PATH);

    const issue = findElectronBinaryIssue(electronPackageDir);

    expect(issue).toContain('binary');
  });

  it('should_return_null_when_binary_exists', () => {
    writeFileSync(join(electronPackageDir, 'path.txt'), RELATIVE_BINARY_PATH);
    const binaryPath = join(electronPackageDir, 'dist', RELATIVE_BINARY_PATH);
    mkdirSync(dirname(binaryPath), { recursive: true });
    writeFileSync(binaryPath, '');

    const issue = findElectronBinaryIssue(electronPackageDir);

    expect(issue).toBeNull();
  });
});
