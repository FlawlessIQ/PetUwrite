const test = require('node:test')
const assert = require('node:assert/strict')
const { PAGES } = require('./pages')

test('the confirm page changes nothing on GET — it offers a POST button', () => {
  const html = PAGES.confirm('abc')
  assert.match(html, /<form method="post">/)
  assert.match(html, /name="t" value="abc"/)
})

test('a token cannot inject markup', () => {
  assert.doesNotMatch(PAGES.confirm('"><script>x</script>'), /<script>x/)
})
