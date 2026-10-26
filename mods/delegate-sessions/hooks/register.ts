import type { Register } from 'claude-code'

// Off is stored, on is the default: a missing key means the policy applies.
const ENABLED_KEY = 'enabled'
const START_SESSION = 'mcp__ccd_session__start_session'

// Written without counts, sizes or model ids on purpose: the judgement rests on
// what the work is, and the model ids come from the environment section the
// engine already keeps current, so nothing here goes stale.
const POLICY = `# Delegating to child sessions (delegate-sessions mod)

The user prefers that self-contained work runs in child sessions rather than in this one. Within the rules of "Starting other sessions", lean toward delegating:

- When a request contains a task of its own (it ends in its own change, branch, PR or document, and a short brief can describe it), offer or propose a session for it instead of doing it inline. When unsure whether a piece is a task of its own or part of the current one, prefer the session if the brief would not mostly retell this conversation.
- When a request bundles several independent tasks, give each its own session and keep here only the one that depends most on this conversation.
- Keep here what that section keeps here: questions, reads, single edits, the fix for what this session just diagnosed, and verification of this session's own work.

Pick the child's model and effort from the nature of the work, and set them on every start_session call with context "fresh" (a "fork" inherits yours):

- Mechanical or fully specified work (applying a decided change, renames, formatting, dependency bumps, collecting or listing facts, read-only searches): the Sonnet model id from the environment section, effort "low" or "medium". Use the Haiku id only for pure lookups that need no judgement.
- Ordinary implementation with clear requirements and an obvious approach: the Sonnet id, effort "high".
- Work that needs judgement (design choices, ambiguous requirements, debugging an unknown cause, security-sensitive or hard-to-reverse changes, writing for other people to read): omit model and effort so the child inherits yours.

In the line you write before each start_session call, state the model and effort you chose and the reason in a few words, so the user can correct the choice.`

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'delegate',
      description: 'Turn the child-session delegation policy on or off (on | off | status)',
    })

    return next(e)
  })

  on('command.run', { command: 'delegate' }, async ($, e) => {
    const arg = e.args.trim().toLowerCase()
    if (arg === 'on' || arg === 'off') {
      await $.store.set(ENABLED_KEY, arg === 'on')

      return { text: `delegate-sessions: ${arg} (from the next request)` }
    }
    const isEnabled = (await $.store.get(ENABLED_KEY)) !== false

    return { text: `delegate-sessions: ${isEnabled ? 'on' : 'off'} (usage: /delegate on | off)` }
  })

  on('prompt.compose', async ($, e, next) => {
    const composed = await next(e)
    // start_session exists only in the desktop app, where it may be deferred and
    // so missing from `e.tools`; the desktop surface stands in for it then.
    const canStartSessions = e.tools.includes(START_SESSION) || e.surfaces.includes('desktop')
    if (!canStartSessions || e.traits.includes('analysis')) return composed
    if ((await $.store.get(ENABLED_KEY)) === false) return composed

    return {
      sections: [
        ...composed.sections,
        { id: 'delegate-sessions:policy', text: POLICY, scope: 'session' },
      ],
    }
  })
}
