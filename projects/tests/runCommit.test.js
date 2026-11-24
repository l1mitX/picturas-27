// Erro herdado da base, que o RNF2 torna mais provável: a pré-visualização regista um Process com o token da
// execução em curso (activeToken). Se o Apply acabasse com uma pré-visualização a meio, a contagem de trabalhos
// por acabar nunca chegava a 0 e a execução nunca era confirmada (o utilizador não via os resultados).
const test = require('node:test');
const assert = require('node:assert/strict');

function withProcessModel(docs, fn) {
  const modelPath = require.resolve('../models/process');
  const controllerPath = require.resolve('../controllers/process');
  const originalModel = require.cache[modelPath];
  const originalController = require.cache[controllerPath];
  const matches = (doc, filter) => Object.entries(filter).every(([key, value]) => {
    if (value && value.$not instanceof RegExp) return !value.$not.test(doc[key]);
    return doc[key] === value;
  });
  require.cache[modelPath] = { id: modelPath, filename: modelPath, loaded: true, exports: {
    countDocuments(filter) {
      return { exec: async () => docs.filter((doc) => matches(doc, filter)).length };
    },
  }};
  delete require.cache[controllerPath];
  return Promise.resolve(fn(require('../controllers/process'))).finally(() => {
    if (originalModel) require.cache[modelPath] = originalModel; else delete require.cache[modelPath];
    if (originalController) require.cache[controllerPath] = originalController; else delete require.cache[controllerPath];
  });
}

test('uma pré-visualização a meio não impede a confirmação da execução com o mesmo token', async () => {
  const docs = [{ project_id: 'p1', token: 1, msg_id: 'preview-abc' }];
  await withProcessModel(docs, async (Process) => {
    assert.equal(await Process.countByProjectAndToken('p1', 1), 0);
  });
});

test('os trabalhos da execução que ainda faltam continuam a contar', async () => {
  const docs = [
    { project_id: 'p1', token: 1, msg_id: 'request-a' },
    { project_id: 'p1', token: 1, msg_id: 'preview-b' },
    { project_id: 'p1', token: 2, msg_id: 'request-c' },
    { project_id: 'p2', token: 1, msg_id: 'request-d' },
  ];
  await withProcessModel(docs, async (Process) => {
    assert.equal(await Process.countByProjectAndToken('p1', 1), 1);
  });
});
