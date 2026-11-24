// RNF2 T037 e T038 (H-08): cancelamento e erro a meio de um pipeline de vídeo, e limpeza dos ficheiros intermédios.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { planStages } = require('../utils/videoStages');
const {
  stagePath, stageReplyAction, removeStageFiles, isStageUri, removeStageOutput,
} = require('../utils/videoDispatch');

const S = { procedure: 'subtitles', params: {} };
const B = { procedure: 'brightness', params: { brightness: 1.5 } };
const X = { procedure: 'extract_frames', params: { mode: 'count', count: 4, format: 'png' } };
const FINAL = './images/users/u1/projects/p1/out/video.mp4';

function processFor(stages, curPos, token = 7) {
  return { stages, cur_pos: curPos, new_img_uri: FINAL, token, img_id: 'i1', runner_id: 'r1', user_id: 'u1', project_id: 'p1' };
}
const ok = (uri) => ({ status: 'success', output: { type: 'video', imageURI: uri }, metadata: { video: { duration: 4 } } });
const failed = (code) => ({ status: 'error', error: { code, msg: 'boom' } });

// ------------------------------------------------------------------ T037: cancelamento entre estágios
test('cancelar entre dois estágios: a resposta do estágio i não envia o estágio i+1 e acaba o pipeline', () => {
  const stages = planStages([B, S, X], false); // edição → legendagem → extração
  // o utilizador cancelou durante o estágio 0: o activeToken passou de 7 para 8
  const reply = stageReplyAction(processFor(stages, 0, 7), ok(stagePath(FINAL, 7, 'i1', 0)), 8);
  assert.equal(reply.action, 'ignore');
  assert.equal(reply.next, null); // nada é enviado
  assert.equal(reply.ends, true); // os ficheiros intermédios são apagados
});

test('cancelar também ignora a resposta do último estágio (nada é registado nem chega ao cliente)', () => {
  const stages = planStages([B, S], false);
  const reply = stageReplyAction(processFor(stages, 1, 7), ok(FINAL), 8);
  assert.deepEqual(reply, { action: 'ignore', next: null, ends: true });
});

test('sem cancelamento, a resposta de um estágio intermédio envia o seguinte e não acaba o pipeline', () => {
  const stages = planStages([B, S, X], false);
  const reply = stageReplyAction(processFor(stages, 0, 7), ok(stagePath(FINAL, 7, 'i1', 0)), 7);
  assert.equal(reply.action, 'next');
  assert.equal(reply.next.toolName, 'video_subtitles');
  assert.equal(reply.ends, false);
});

test('sem cancelamento, a resposta do último estágio é tratada como o resultado e acaba o pipeline', () => {
  const stages = planStages([B, S], false);
  assert.deepEqual(stageReplyAction(processFor(stages, 1, 7), ok(FINAL), 7), { action: 'last', next: null, ends: true });
});

// ------------------------------------------------------------------ T038: erro num estágio intermédio
for (const code of [2000, 2001, 2002, 2003, 2004, 2005]) {
  test(`erro ${code} num estágio intermédio: o pipeline não continua e o erro segue com o mesmo código`, () => {
    const stages = planStages([B, S, X], false);
    const reply = stageReplyAction(processFor(stages, 1, 7), failed(code), 7);
    assert.equal(reply.action, 'error');
    assert.equal(reply.next, null);
    assert.equal(reply.ends, true);
    assert.equal(reply.error.code, code);
  });
}

test('um erro de um pipeline já cancelado continua a ser um erro (como na base)', () => {
  const stages = planStages([B, S], false);
  assert.equal(stageReplyAction(processFor(stages, 0, 7), failed(2003), 8).action, 'error');
});

// ------------------------------------------------------------------ T039: limpeza de stages/<token>/
function tmpRoot() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'picturas-stages-'));
}
function touch(root, uri) {
  const file = path.resolve(root, uri);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, 'x');
  return file;
}

test('no fim do pipeline apaga os ficheiros intermédios do vídeo e a pasta stages/<token>/ vazia', () => {
  const root = tmpRoot();
  const files = [0, 1].map((i) => touch(root, stagePath(FINAL, 7, 'i1', i)));
  removeStageFiles(root, FINAL, 7, 'i1');
  files.forEach((f) => assert.equal(fs.existsSync(f), false));
  assert.equal(fs.existsSync(path.dirname(files[0])), false);
  assert.equal(fs.existsSync(path.resolve(root, './images/users/u1/projects/p1')), true); // o resto fica
});

test('não apaga os ficheiros de outro vídeo da mesma execução nem os de outra execução', () => {
  const root = tmpRoot();
  const mine = touch(root, stagePath(FINAL, 7, 'i1', 0));
  const otherVideo = touch(root, stagePath(FINAL, 7, 'i2', 0));
  const otherRun = touch(root, stagePath(FINAL, 8, 'i1', 0));
  const similarId = touch(root, stagePath(FINAL, 7, 'i10', 0)); // 'i1' é prefixo de 'i10'
  removeStageFiles(root, FINAL, 7, 'i1');
  assert.equal(fs.existsSync(mine), false);
  assert.equal(fs.existsSync(otherVideo), true);
  assert.equal(fs.existsSync(otherRun), true);
  assert.equal(fs.existsSync(similarId), true);
});

test('sem ficheiros intermédios (pipeline de um só estágio) não faz nada nem lança erro', () => {
  const root = tmpRoot();
  assert.doesNotThrow(() => removeStageFiles(root, FINAL, 7, 'i1'));
});

// ------------------------------------------------------------------ T037/T039: estágio que acaba depois do cancelamento
// O cancelamento apaga os Process em curso; a resposta que chega depois já não tem Process, mas o ficheiro
// intermédio que o estágio escreveu tem de ser apagado na mesma.
test('reconhece os ficheiros intermédios e só esses', () => {
  assert.equal(isStageUri(stagePath(FINAL, 7, 'i1', 0)), true);
  assert.equal(isStageUri(FINAL), false);
  assert.equal(isStageUri('./images/users/u1/projects/p1/preview/video.mp4'), false);
  assert.equal(isStageUri('./images/users/u1/projects/p1/stages/7/../../out/video.mp4'), false);
  assert.equal(isStageUri(undefined), false);
});

test('a saída de um estágio que acabou depois do cancelamento é apagada, com a pasta se ficar vazia', () => {
  const root = tmpRoot();
  const late = touch(root, stagePath(FINAL, 7, 'i1', 0));
  removeStageOutput(root, stagePath(FINAL, 7, 'i1', 0));
  assert.equal(fs.existsSync(late), false);
  assert.equal(fs.existsSync(path.dirname(late)), false);
});

test('não apaga nada que não seja um ficheiro intermédio', () => {
  const root = tmpRoot();
  const final = touch(root, FINAL);
  removeStageOutput(root, FINAL);
  assert.equal(fs.existsSync(final), true);
  const other = touch(root, stagePath(FINAL, 7, 'i2', 0));
  removeStageOutput(root, stagePath(FINAL, 7, 'i1', 0)); // já não existe: não lança erro
  assert.equal(fs.existsSync(other), true);
});
