#!/usr/bin/env node
// Run directly or with: node --test tests/bootstrap.test.cjs
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { test } = require('node:test');
const { Script } = require('node:vm');

const root = join(__dirname, '..');
const terraform = readFileSync(join(root, 'lambda.tf'), 'utf8');
const variables = readFileSync(join(root, 'variables.tf'), 'utf8');
const match = terraform.match(/^  bootstrap_code = <<-EOF\r?\n([\s\S]*?)^EOF\r?$/m);
assert.ok(match, 'Extract the exact bootstrap_code heredoc from lambda.tf');
const template = match[1];

test('project_name validation keeps interpolation safe in JavaScript and HTML', () => {
  assert.match(variables, /variable "project_name"\s*\{[\s\S]*?condition\s*=\s*can\(regex\("\^\[a-z0-9-\]\{3,20\}\$", var\.project_name\)\)/);
});

for (const projectName of ['abc', 'my-app-123', 'a'.repeat(20), '---']) {
  test(`rendered bootstrap parses and serves HTML and health JSON: ${projectName}`, async () => {
    assert.match(projectName, /^[a-z0-9-]{3,20}$/);
    // Only the template syntax used here is supported. One pass preserves
    // Terraform's escaped $${...} as literal ${...}, never interpolating it again.
    const rendered = template.replace(/\$\$\{|%%\{|\$\{([^}]*)\}|%\{/g, (token, expression) => {
      if (token === '$${') return '${';
      if (token === '%%{') return '%{';
      assert.equal(expression, 'var.project_name', `Unsupported Terraform template token: ${token}`);
      return projectName;
    });
    const script = new Script(rendered, { filename: 'bootstrap/index.js' });
    const exports = {};
    script.runInNewContext({ exports });
    assert.equal(typeof exports.handler, 'function');

    for (const event of [{ rawPath: '/' }, { path: '/' }, {}]) {
      const response = await exports.handler(event, {});
      assert.equal(response.statusCode, 200);
      assert.equal(response.headers['Content-Type'], 'text/html');
      assert.equal(response.headers['Cache-Control'], 'public, max-age=60, stale-while-revalidate=300');
      assert.ok(response.body.includes(`<title>${projectName}</title>`));
      assert.ok(response.body.includes(`<h1>${projectName}</h1>`));
      assert.ok(!response.body.includes('${'));
    }

    for (const event of [{ rawPath: '/api/health' }, { path: '/api/health' }]) {
      const response = await exports.handler(event, {});
      assert.equal(response.statusCode, 200);
      assert.equal(response.headers['Content-Type'], 'application/json');
      assert.equal(response.headers['Cache-Control'], 'no-store');
      const body = JSON.parse(response.body);
      assert.equal(body.status, 'bootstrap');
      assert.equal(body.message, 'Lambda initialized - awaiting application deployment');
      assert.equal(body.swr_enabled, true);
      assert.equal(new Date(body.timestamp).toISOString(), body.timestamp);
    }
  });
}
