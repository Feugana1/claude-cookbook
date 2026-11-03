#!/usr/bin/env node
/**
 * F-AUDIT-P2-2 — file size ratchet.
 *
 * Enforces the CLAUDE.md §14 file-size limits on controllers, services and
 * Edge templates. Limits :
 *   - app/controllers/**.ts     : 300 lines
 *   - app/services/**.ts        : 400 lines
 *   - resources/views/**.edge   : 800 lines
 *
 * Ratchet mode : files already over the limit at baseline time are
 * grandfathered in `scripts/file-size-baseline.json`. They can only SHRINK
 * — if a file grows above its baseline entry, CI fails. New files must
 * respect the canonical limits.
 *
 * Usage :
 *   node scripts/check-file-sizes.js                 # check, exit non-zero on violation
 *   node scripts/check-file-sizes.js --baseline      # regenerate baseline (commit with the file)
 */

import { readFileSync, writeFileSync, statSync } from 'node:fs'
import { readdir } from 'node:fs/promises'
import { join, relative } from 'node:path'

const PROJECT_ROOT = process.cwd()
const BASELINE_PATH = join(PROJECT_ROOT, 'scripts', 'file-size-baseline.json')

const LIMITS = {
  controller: { pattern: 'app/controllers', ext: '.ts', max: 300 },
  service: { pattern: 'app/services', ext: '.ts', max: 400 },
  template: { pattern: 'resources/views', ext: '.edge', max: 800 },
}

async function walk(dir) {
  const out = []
  let entries
  try {
    entries = await readdir(dir, { withFileTypes: true })
  } catch {
    return out
  }
  for (const entry of entries) {
    const full = join(dir, entry.name)
    if (entry.isDirectory()) {
      out.push(...(await walk(full)))
    } else {
      out.push(full)
    }
  }
  return out
}

function countLines(file) {
  const content = readFileSync(file, 'utf-8')
  return content.split('\n').length
}

function relPath(file) {
  return relative(PROJECT_ROOT, file).replace(/\\/g, '/')
}

function classify(file) {
  const rel = relPath(file)
  for (const [kind, cfg] of Object.entries(LIMITS)) {
    if (rel.startsWith(cfg.pattern) && rel.endsWith(cfg.ext)) {
      return { kind, max: cfg.max }
    }
  }
  return null
}

async function collectAllFiles() {
  const targets = [
    join(PROJECT_ROOT, 'app', 'controllers'),
    join(PROJECT_ROOT, 'app', 'services'),
    join(PROJECT_ROOT, 'resources', 'views'),
  ]
  const all = []
  for (const target of targets) {
    try {
      statSync(target)
    } catch {
      continue
    }
    const files = await walk(target)
    for (const file of files) {
      const cls = classify(file)
      if (cls) {
        all.push({ path: relPath(file), lines: countLines(file), ...cls })
      }
    }
  }
  return all
}

function loadBaseline() {
  try {
    return JSON.parse(readFileSync(BASELINE_PATH, 'utf-8'))
  } catch {
    return {}
  }
}

function writeBaseline(baseline) {
  const sorted = Object.fromEntries(
    Object.entries(baseline).sort(([a], [b]) => a.localeCompare(b))
  )
  writeFileSync(BASELINE_PATH, JSON.stringify(sorted, null, 2) + '\n', 'utf-8')
}

async function regenerateBaseline() {
  const files = await collectAllFiles()
  const baseline = {}
  for (const f of files) {
    if (f.lines > f.max) {
      baseline[f.path] = f.lines
    }
  }
  writeBaseline(baseline)
  console.log(`Baseline regenerated with ${Object.keys(baseline).length} grandfathered files.`)
  console.log(`Saved to ${relPath(BASELINE_PATH)}`)
}

async function runCheck() {
  const files = await collectAllFiles()
  const baseline = loadBaseline()

  const newViolators = []
  const regressions = []
  const shrunk = []

  for (const f of files) {
    const baselineMax = baseline[f.path]
    if (baselineMax !== undefined) {
      if (f.lines > baselineMax) {
        regressions.push({ ...f, baselineMax })
      } else if (f.lines < baselineMax) {
        shrunk.push({ ...f, baselineMax })
      }
    } else {
      if (f.lines > f.max) {
        newViolators.push(f)
      }
    }
  }

  console.log('\n═══ File size ratchet (CLAUDE.md §14) ═══')
  console.log(`Grandfathered in baseline : ${Object.keys(baseline).length} files`)
  console.log(`Files scanned              : ${files.length}`)

  if (shrunk.length > 0) {
    console.log(`\n✓ ${shrunk.length} baseline file(s) shrunk (ratchet progression):`)
    for (const f of shrunk.slice(0, 10)) {
      console.log(`  ${f.path}  ${f.baselineMax} → ${f.lines}`)
    }
    if (shrunk.length > 10) {
      console.log(`  ... and ${shrunk.length - 10} more`)
    }
    console.log(
      `  → run \`node scripts/check-file-sizes.js --baseline\` to tighten the baseline`
    )
  }

  let failed = false

  if (newViolators.length > 0) {
    failed = true
    console.error(`\n✗ ${newViolators.length} new file(s) over the limit:`)
    for (const f of newViolators) {
      console.error(`  ${f.path}  ${f.lines} lines (limit: ${f.max} for ${f.kind})`)
    }
  }

  if (regressions.length > 0) {
    failed = true
    console.error(`\n✗ ${regressions.length} baseline file(s) grew above their grandfathered size:`)
    for (const f of regressions) {
      console.error(`  ${f.path}  ${f.baselineMax} → ${f.lines} (regression)`)
    }
  }

  if (!failed) {
    console.log('\n✓ All files within their size budget.\n')
    process.exit(0)
  } else {
    console.error(
      '\nFix the violations above, or refactor/split the offending files. ' +
        'Limits are defined in CLAUDE.md §14 (controllers 300, services 400, templates 800).'
    )
    process.exit(1)
  }
}

const mode = process.argv[2]
if (mode === '--baseline') {
  regenerateBaseline().catch((err) => {
    console.error('Failed to regenerate baseline:', err)
    process.exit(1)
  })
} else {
  runCheck().catch((err) => {
    console.error('File size check failed:', err)
    process.exit(1)
  })
}
