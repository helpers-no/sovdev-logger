import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateUrlEnv, validateInstanceIdEnv, validateTokenEnv } from './env-checks.js';

test('validateUrlEnv: unset is not ok', () => {
  const result = validateUrlEnv(undefined);
  assert.equal(result.ok, false);
  assert.match(result.detail, /not set/);
});

test('validateUrlEnv: valid https URL is ok', () => {
  const result = validateUrlEnv('https://logs-prod-eu-west-0.grafana.net');
  assert.equal(result.ok, true);
});

test('validateUrlEnv: http (not https) is not ok', () => {
  const result = validateUrlEnv('http://example.com');
  assert.equal(result.ok, false);
  assert.match(result.detail, /not https/);
});

test('validateUrlEnv: garbage string is not ok', () => {
  const result = validateUrlEnv('not-a-url');
  assert.equal(result.ok, false);
  assert.match(result.detail, /not a valid URL/);
});

test('validateInstanceIdEnv: unset is not ok', () => {
  assert.equal(validateInstanceIdEnv(undefined).ok, false);
});

test('validateInstanceIdEnv: numeric string is ok', () => {
  const result = validateInstanceIdEnv('333665');
  assert.equal(result.ok, true);
});

test('validateInstanceIdEnv: non-numeric is not ok', () => {
  const result = validateInstanceIdEnv('abc123');
  assert.equal(result.ok, false);
  assert.match(result.detail, /not purely numeric/);
});

test('validateInstanceIdEnv: negative number is not ok (regex requires digits only)', () => {
  const result = validateInstanceIdEnv('-5');
  assert.equal(result.ok, false);
});

test('validateTokenEnv: unset is not ok', () => {
  assert.equal(validateTokenEnv(undefined).ok, false);
});

test('validateTokenEnv: too short is not ok', () => {
  const result = validateTokenEnv('short');
  assert.equal(result.ok, false);
  assert.match(result.detail, /suspiciously short/);
});

test('validateTokenEnv: long fake value without glc_ prefix is ok but warns', () => {
  const result = validateTokenEnv('fake_dummy_token_value_1234567890');
  assert.equal(result.ok, true);
  assert.match(result.detail, /missing the usual glc_ prefix/);
});

test('validateTokenEnv: long fake value with glc_ prefix is ok, no warning', () => {
  const result = validateTokenEnv('glc_fake_dummy_token_value_1234567890');
  assert.equal(result.ok, true);
  assert.match(result.detail, /has expected glc_ prefix/);
});
