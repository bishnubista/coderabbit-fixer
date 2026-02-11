#!/usr/bin/env bun
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

function candidateRoots(metaUrl) {
  const here = dirname(fileURLToPath(metaUrl));
  return [
    resolve(here, "../.."),
    join(process.env.HOME ?? "", ".local", "share", "coderabbit-fixer"),
  ];
}

export function main(metaUrl) {
  const commandName = basename(fileURLToPath(metaUrl));

  let target = "";
  for (const root of candidateRoots(metaUrl)) {
    const candidate = join(root, "runtime", "bash", commandName);
    if (existsSync(candidate)) {
      target = candidate;
      break;
    }
  }

  if (!target) {
    console.error(`ERROR: Could not locate bash implementation for '${commandName}'.`);
    process.exit(1);
  }

  const result = spawnSync(target, process.argv.slice(2), { stdio: "inherit" });
  if (result.error) {
    console.error(`ERROR: ${result.error.message}`);
    process.exit(1);
  }
  process.exit(result.status ?? 1);
}
