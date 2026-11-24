// RNF2 T025/T026 (DA-2, TAT-09; research R3, R4, R5): mensagens dos estágios de vídeo e encadeamento.
// Funções puras, sem RabbitMQ nem MongoDB, para se testarem sozinhas; o projects.js só as liga.
const fs = require('fs');
const path = require('path');

// Pasta dos ficheiros intermédios de uma execução (R3): …/projects/<projeto>/stages/<token>,
// na mesma pasta de projeto do destino final (out/ ou preview/).
function stageDir(finalUri, token) {
  const projectDir = path.posix.dirname(path.posix.dirname(finalUri));
  return `${projectDir}/stages/${token}`;
}

// Caminho de um ficheiro intermédio (R3): …/projects/<projeto>/stages/<token>/<imgId>-<índice>.mp4.
function stagePath(finalUri, token, imgId, index) {
  return `${stageDir(finalUri, token)}/${imgId}-${index}.mp4`;
}

// Mensagem do estágio `index` (contrato em specs/001-rnf2-modularidade/contracts/mensagens-estagio.md).
// O último estágio escreve no destino final; os outros num ficheiro intermédio.
function stageMessage({ stages, index, inputUri, finalUri, token, imgId, progress, sourceInfo }) {
  const stage = stages[index];
  const last = index === stages.length - 1;
  const params = {
    tools: stage.tools,
    preview: stage.preview,
    progress: { ...progress, range: stage.progressRange },
    stage: { index, count: stages.length },
  };
  if (sourceInfo && stage.service === 'video_frames') params.sourceInfo = sourceInfo;
  return {
    toolName: stage.service,
    inputUri,
    outputUri: last ? finalUri : stagePath(finalUri, token, imgId, index),
    params,
  };
}

// Primeiro estágio de um trabalho de vídeo (no Apply e na pré-visualização).
function firstStage({ stages, inputUri, finalUri, token, imgId, progress }) {
  return stageMessage({ stages, index: 0, inputUri, finalUri, token, imgId, progress });
}

// Estágio seguinte, a partir da resposta de sucesso do estágio em curso; null se não houver (fim da cadeia).
// `process` é o Process guardado (stages, cur_pos, new_img_uri, token, img_id, runner_id, user_id, project_id).
function nextStage(process, response) {
  const stages = Array.isArray(process.stages) ? process.stages : [];
  const next = (process.cur_pos || 0) + 1;
  if (stages.length === 0 || next >= stages.length) return null;
  const imgId = String(process.img_id);
  return {
    curPos: next,
    ...stageMessage({
      stages,
      index: next,
      inputUri: response.output.imageURI,
      finalUri: process.new_img_uri,
      token: process.token || 0,
      imgId,
      progress: {
        user: String(process.runner_id || process.user_id),
        projectId: String(process.project_id),
        imgId,
      },
      // R5: a extração usa a informação do vídeo editado, não um probe novo.
      sourceInfo: response.metadata && response.metadata.video,
    }),
  };
}

// Mantém o prefixo que o projects usa para distinguir pré-visualizações de execuções.
function nextMessageId(currentMsgId, uuid) {
  return /preview/.test(currentMsgId) ? `preview-${uuid}` : `request-${uuid}`;
}

// RNF2 T037–T039 (H-08): o que fazer com a resposta de um estágio de vídeo.
//   'error'  → o erro segue para o cliente com o mesmo código, como na base; o pipeline acaba
//   'ignore' → a execução foi cancelada (o activeToken mudou): nada é enviado nem registado; o pipeline acaba
//   'next'   → envia o estágio seguinte (`next`)
//   'last'   → trata o resultado como na base (pré-visualização, ficheiro ou fotogramas); o pipeline acaba
// `ends` diz se os ficheiros intermédios deste vídeo já podem ser apagados.
function stageReplyAction(process, response, activeToken) {
  if (response.status === 'error') return { action: 'error', next: null, ends: true, error: response.error };
  if ((activeToken || 0) !== (process.token || 0)) return { action: 'ignore', next: null, ends: true };
  const next = nextStage(process, response);
  return next ? { action: 'next', next, ends: false } : { action: 'last', next: null, ends: true };
}

// RNF2 T039 (R3): apaga os ficheiros intermédios de um vídeo no fim do seu pipeline (sucesso, erro ou cancelamento),
// e a pasta stages/<token>/ quando fica vazia. Só toca nos ficheiros <imgId>-<índice>.mp4 deste vídeo: os outros
// vídeos da mesma execução podem ainda estar a meio. `root` é a pasta a partir da qual os URIs são resolvidos.
// Nunca lança erro: uma falha na limpeza não pode afetar o resultado do utilizador.
function removeStageFiles(root, finalUri, token, imgId) {
  const dir = path.resolve(root, stageDir(finalUri, token || 0));
  try {
    const mine = new RegExp(`^${String(imgId).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}-\\d+\\.mp4$`);
    for (const name of fs.readdirSync(dir)) {
      if (mine.test(name)) fs.rmSync(path.join(dir, name), { force: true });
    }
    if (fs.readdirSync(dir).length === 0) fs.rmdirSync(dir);
  } catch (err) {
    if (err.code !== 'ENOENT') console.log(`[STAGES] cleanup failed for ${dir}: ${err.message}`);
  }
}

// Um ficheiro intermédio tem sempre a forma …/stages/<token>/<imgId>-<índice>.mp4 (stagePath).
function isStageUri(uri) {
  const s = String(uri || '');
  return !s.split('/').includes('..') && /\/stages\/\d+\/[^/]+-\d+\.mp4$/.test(s);
}

// RNF2 T037/T039: o cancelamento apaga os Process em curso, por isso a resposta de um estágio que acaba depois
// já não encontra o seu Process. Se essa resposta trouxer um ficheiro intermédio, apaga-o (e a pasta, se vazia).
function removeStageOutput(root, uri) {
  if (!isStageUri(uri)) return;
  const file = path.resolve(root, uri);
  try {
    fs.rmSync(file, { force: true });
    const dir = path.dirname(file);
    if (fs.readdirSync(dir).length === 0) fs.rmdirSync(dir);
  } catch (err) {
    if (err.code !== 'ENOENT') console.log(`[STAGES] cleanup failed for ${file}: ${err.message}`);
  }
}

module.exports = {
  stageDir, stagePath, stageMessage, firstStage, nextStage, nextMessageId, stageReplyAction, removeStageFiles,
  isStageUri, removeStageOutput,
};
