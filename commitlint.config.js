// Conventional Commits enforcement — aligné avec skill `/commit` du cookbook.
// Wire via lefthook.yml (commit-msg hook).
//
// Types autorisés cf .claude/commands/commit.md :
//   feat, fix, refactor, perf, docs, test, chore, style, ci, build
//
// Subject rules :
//   ≤ 50 chars (§14 spirit — concis)
//   pas de point final
//   impératif présent ("add" pas "added" ni "adds")

export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat',
        'fix',
        'refactor',
        'perf',
        'docs',
        'test',
        'chore',
        'style',
        'ci',
        'build',
        'revert',
      ],
    ],
    'subject-case': [2, 'never', ['upper-case', 'pascal-case', 'sentence-case', 'start-case']],
    'subject-empty': [2, 'never'],
    'subject-full-stop': [2, 'never', '.'],
    'subject-max-length': [2, 'always', 72],
    'header-max-length': [2, 'always', 100],
    'body-leading-blank': [1, 'always'],
    'footer-leading-blank': [1, 'always'],
    'scope-case': [2, 'always', 'lower-case'],
  },
};
