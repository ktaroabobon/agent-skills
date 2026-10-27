import { expect, test } from 'claude-code/testing'
import type { EngineInterface, On, PromptComposeInput } from 'claude-code'

const POLICY_ID = 'delegate-sessions:policy'

const BASE: PromptComposeInput = {
  model: 'claude-opus-5-5',
  promptModel: 'claude-opus-5-5',
  surfaces: ['desktop'],
  tools: [],
  outputStyle: null,
  traits: [],
}

// Nothing sits beneath the plugin: these hooks stand for the engine, with an
// in-memory store and a prompt of one engine section.
function engine(on: On) {
  const store = new Map<string, unknown>()
  on('store.get', (_, e) => ({ value: store.get(e.key) }))
  on('store.set', (_, e) => {
    store.set(e.key, e.value)
    return { value: undefined }
  })
  on('command.register', () => ({ value: { command: 'delegate' } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('prompt.compose', () => ({
    sections: [{ id: 'intro', text: 'engine', scope: 'shared' as const }],
  }))
}

async function ids($: EngineInterface, input: Partial<PromptComposeInput> = {}) {
  return (await $.prompt.compose({ ...BASE, ...input })).sections.map(s => s.id)
}

test('the policy is appended last in the desktop app', async ($, on) => {
  engine(on)
  expect(await ids($)).toEqual(['intro', POLICY_ID])
})

test('the policy is appended where start_session is offered outside the desktop', async ($, on) => {
  engine(on)
  expect(
    await ids($, { surfaces: ['terminal'], tools: ['mcp__ccd_session__start_session'] }),
  ).toEqual(['intro', POLICY_ID])
})

test('the policy is left out where no session can be started', async ($, on) => {
  engine(on)
  expect(await ids($, { surfaces: ['terminal'] })).toEqual(['intro'])
})

test('/delegate off drops the policy and /delegate on restores it', async ($, on) => {
  engine(on)
  await $.session.start({ cwd: '/', surface: 'desktop', isInteractive: true })

  const off = await $.command.run({ command: 'delegate', args: 'off' })
  expect(off.text).toContain('off')
  expect(await ids($)).toEqual(['intro'])
  expect((await $.command.run({ command: 'delegate', args: '' })).text).toContain(': off')

  await $.command.run({ command: 'delegate', args: 'on' })
  expect(await ids($)).toEqual(['intro', POLICY_ID])
  expect((await $.command.run({ command: 'delegate', args: 'status' })).text).toContain(': on')
})
