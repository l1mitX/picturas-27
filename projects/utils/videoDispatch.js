// RNF2 T025/T026 (DA-2, TAT-09; research R3, R4, R5): mensagens dos estágios de vídeo e encadeamento.
// Funções puras, sem RabbitMQ nem MongoDB, para se testarem sozinhas; o projects.js só as liga.
const path = require('path');

// Caminho de um ficheiro intermédio (R3): …/projects/<projeto>/stages/<token>/<imgId>-<índice>.mp4,
// na mesma pasta de projeto do destino final (out/ ou preview/).
function stagePath(finalUri, token, imgId, index) {
  const projectDir = path.posix.dirname(path.posix.dirname(finalUri));
  return `${projectDir}/stages/${token}/${imgId}-${index}.mp4`;
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

module.exports = { stagePath, stageMessage, firstStage, nextStage, nextMessageId };
