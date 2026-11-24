// RNF2 T015 e T016: envio e encadeamento dos estágios de vídeo, e pré-visualização por estágios.
const test = require('node:test');
const assert = require('node:assert/strict');
const { planStages } = require('../utils/videoStages');
const { stagePath, firstStage, nextStage, nextMessageId } = require('../utils/videoDispatch');

const S = { procedure: 'subtitles', params: {} };
const B = { procedure: 'brightness', params: { brightness: 1.5 } };
const T = { procedure: 'trim', params: { start: 1, end: 3 } };
const X = { procedure: 'extract_frames', params: { mode: 'count', count: 4, format: 'png' } };

const FINAL = './images/users/u1/projects/p1/out/video.mp4';
const ORIGINAL = './images/users/u1/projects/p1/src/video.mp4';
const PROGRESS = { user: 'r1', projectId: 'p1', imgId: 'i1' };

function processFor(stages, curPos, finalUri = FINAL) {
  return { stages, cur_pos: curPos, new_img_uri: finalUri, token: 7, img_id: 'i1', runner_id: 'r1', user_id: 'u1', project_id: 'p1' };
}

test('os ficheiros intermédios ficam em stages/<token>/ na pasta do projeto', () => {
  assert.equal(stagePath(FINAL, 7, 'i1', 0), './images/users/u1/projects/p1/stages/7/i1-0.mp4');
  assert.equal(stagePath('./images/users/u1/projects/p1/preview/video.mp4', 7, 'i1', 2),
    './images/users/u1/projects/p1/stages/7/i1-2.mp4');
});

test('um pipeline de um só estágio escreve logo no destino final', () => {
  const stages = planStages([B], false);
  const first = firstStage({ stages, inputUri: ORIGINAL, finalUri: FINAL, token: 7, imgId: 'i1', progress: PROGRESS });
  assert.equal(first.toolName, 'video_edit');
  assert.equal(first.inputUri, ORIGINAL);
  assert.equal(first.outputUri, FINAL);
  assert.deepEqual(first.params, {
    tools: [B], preview: false, progress: { ...PROGRESS, range: [0, 100] }, stage: { index: 0, count: 1 },
  });
  assert.equal(nextStage(processFor(stages, 0), { output: { imageURI: FINAL } }), null);
});

test('encadeamento: cada resposta de sucesso envia o estágio seguinte, até ao último', () => {
  const stages = planStages([B, S, X], false); // edição → legendagem → extração
  const first = firstStage({ stages, inputUri: ORIGINAL, finalUri: FINAL, token: 7, imgId: 'i1', progress: PROGRESS });
  assert.equal(first.toolName, 'video_edit');
  assert.equal(first.outputUri, './images/users/u1/projects/p1/stages/7/i1-0.mp4');

  const second = nextStage(processFor(stages, 0), { output: { imageURI: first.outputUri } });
  assert.equal(second.curPos, 1);
  assert.equal(second.toolName, 'video_subtitles');
  assert.equal(second.inputUri, first.outputUri);
  assert.equal(second.outputUri, './images/users/u1/projects/p1/stages/7/i1-1.mp4');
  assert.deepEqual(second.params.progress, { ...PROGRESS, range: [35, 69] });
  assert.equal(second.params.sourceInfo, undefined);

  const info = { duration: 9.96, fps: 25, frames: 249 };
  const third = nextStage(processFor(stages, 1), { output: { imageURI: second.outputUri }, metadata: { video: info } });
  assert.equal(third.curPos, 2);
  assert.equal(third.toolName, 'video_frames');
  assert.equal(third.outputUri, FINAL);
  assert.deepEqual(third.params.sourceInfo, info); // R5
  assert.deepEqual(third.params.stage, { index: 2, count: 3 });

  assert.equal(nextStage(processFor(stages, 2), { output: { imageURI: FINAL } }), null);
});

test('um Process sem plano (imagens, ou trabalhos antigos) não encadeia estágios', () => {
  assert.equal(nextStage({ cur_pos: 0, new_img_uri: FINAL }, { output: { imageURI: FINAL } }), null);
  assert.equal(nextStage({ stages: [], cur_pos: 0, new_img_uri: FINAL }, { output: { imageURI: FINAL } }), null);
});

test('pré-visualização: só o estágio previsto pelo plano recebe preview e os IDs mantêm o prefixo', () => {
  const stages = planStages([S, T, S], true); // edição vazia → legendas → edição [trim] (preview) → legendas
  const preview = './images/users/u1/projects/p1/preview/video.mp4';
  const first = firstStage({ stages, inputUri: ORIGINAL, finalUri: preview, token: 7, imgId: 'i1', progress: PROGRESS });
  assert.equal(first.params.preview, false);

  const flags = [first.params.preview];
  let current = first;
  for (let pos = 0; pos < stages.length - 1; pos++) {
    current = nextStage(processFor(stages, pos, preview), { output: { imageURI: current.outputUri } });
    flags.push(current.params.preview);
  }
  assert.deepEqual(flags, [false, false, true, false]);
  assert.equal(current.outputUri, preview);

  assert.equal(nextMessageId('preview-abc', 'xyz'), 'preview-xyz');
  assert.equal(nextMessageId('request-abc', 'xyz'), 'request-xyz');
});
