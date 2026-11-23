// RNF2 T004 (R1, R2): o planeador de estágios reproduz a divisão do process_video da base.
// Os planos esperados estão em fixtures/video_stage_plans.json (partilhado com o local_pipeline dos testes Python).
const test = require('node:test');
const assert = require('node:assert/strict');
const { planStages } = require('../utils/videoStages');
const { casos } = require('./fixtures/video_stage_plans.json');

for (const caso of casos) {
  test(`planStages: ${caso.nome} (${caso.origem})`, () => {
    assert.deepEqual(planStages(caso.tools, caso.preview), caso.estagios);
  });
}

test('planStages não altera a lista de ferramentas recebida', () => {
  const tools = [{ procedure: 'brightness', params: { brightness: 1.5 } }, { procedure: 'subtitles', params: {} }];
  const copia = JSON.parse(JSON.stringify(tools));
  planStages(tools, false);
  assert.deepEqual(tools, copia);
});

test('planStages trata a ausência de ferramentas como um estágio de edição vazio', () => {
  assert.deepEqual(planStages(undefined, false), [
    { service: 'video_edit', tools: [], preview: false, progressRange: [0, 100] },
  ]);
});
