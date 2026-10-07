import { test } from 'node:test';
import assert from 'node:assert/strict';
// Run with node --experimental-strip-types --test lib/server/document-pages.test.ts
// @ts-ignore Node's native test runner needs the .ts extension.
import { encodePages, decodePages, validatePages, readableText } from './document-pages.ts';

test('page extraction round-trips without flattening page evidence', () => {
  const pages = [{page: 1, text: 'Award letter'}, {page: 2, text: 'Renewal due 30 September'}];
  assert.deepEqual(decodePages(encodePages(pages)), pages);
  assert.match(readableText(encodePages(pages)), /Page 2\nRenewal/);
});
test('legacy text is never assigned invented page metadata', () => {
  assert.equal(decodePages('Legacy flattened document'), null);
  assert.equal(readableText('Legacy flattened document'), 'Legacy flattened document');
});
test('rejects oversized, unordered and invalid device extraction', () => {
  assert.throws(() => validatePages([{page: 2, text: 'Forged order'}]));
  assert.throws(() => validatePages([{page: 1, text: 'x'.repeat(120001)}]));
  assert.throws(() => validatePages([{page: 1, text: {}}]));
  assert.throws(() => encodePages([{page: 1, text: 'x'.repeat(120001)}]));
});
test('a blank page stays explicit for review', () => {
  assert.match(readableText(encodePages([{page: 1, text: ''}])), /No readable text/);
});
