// RNF2 T005 (DA-2, TAT-09; research R1 e R4): divide o pipeline de um vídeo em estágios, um por serviço de vídeo.
//
// Reproduz as regras de process_video em Tools/video/video_processor.py (commit 0523102, l. 286-369):
//  - extract_frames só pode ser a última ferramenta. Sozinha, é um estágio de extração sobre o original; com outras
//    ferramentas antes, essas são editadas primeiro sem pré-visualização (0-70 %) e a extração vem no fim (70-100 %);
//  - sem legendas, todas as ferramentas formam um único estágio de edição;
//  - com legendas, parte-se à volta de cada `subtitles`; se a lista começar por legendas há um estágio de edição vazio
//    antes (a base normaliza assim a entrada para MP4/H.264);
//  - a pré-visualização aplica-se só no último estágio de edição com `trim` ou `speed` (ou no primeiro, se não houver)
//    e no estágio de extração.
// Um pipeline inválido (extração fora do fim, repetida, ou ferramenta não suportada) fica num único estágio de edição
// com todas as ferramentas, para o serviço de edição falhar com o mesmo erro que a base.
const { VIDEO_TOOLS } = require('./video');

const EDIT = 'video_edit';
const SUBTITLES = 'video_subtitles';
const FRAMES = 'video_frames';

function isValid(tools) {
  if (tools.some((tool) => !VIDEO_TOOLS.includes(tool.procedure))) return false;
  const extractors = tools
    .map((tool, index) => (tool.procedure === 'extract_frames' ? index : -1))
    .filter((index) => index >= 0);
  return extractors.length === 0 || (extractors.length === 1 && extractors[0] === tools.length - 1);
}

// Estágios de edição e legendagem (sem extração), com as faixas de progresso da base.
function editAndSubtitleStages(tools, preview) {
  if (!tools.some((tool) => tool.procedure === 'subtitles')) {
    return [{ service: EDIT, tools, preview, progressRange: [0, 100] }];
  }

  // Mesma construção de process_video: null marca um estágio de legendagem.
  const groups = [];
  let pending = [];
  for (const tool of tools) {
    if (tool.procedure === 'subtitles') {
      if (pending.length > 0 || groups.length === 0) {
        groups.push(pending);
        pending = [];
      }
      groups.push(null);
    } else {
      pending.push(tool);
    }
  }
  if (pending.length > 0) groups.push(pending);

  let previewStage = 0;
  groups.forEach((group, index) => {
    if (group && group.some((tool) => tool.procedure === 'trim' || tool.procedure === 'speed')) {
      previewStage = index;
    }
  });

  // Na base: min(99, int((index + percent / 100) * 100 / len(stages))); o 100 chega no fim.
  const n = groups.length;
  const at = (value) => Math.min(99, Math.trunc((value * 100) / n));
  let subtitleIndex = 0;
  return groups.map((group, index) => {
    const progressRange = [at(index), at(index + 1)];
    if (group === null) {
      const tool = tools.filter((t) => t.procedure === 'subtitles')[subtitleIndex++];
      return { service: SUBTITLES, tools: [tool], preview: false, progressRange };
    }
    return { service: EDIT, tools: group, preview: preview && index === previewStage, progressRange };
  });
}

function planStages(tools, preview = false) {
  const list = Array.isArray(tools) ? tools : [];
  if (!isValid(list)) {
    return [{ service: EDIT, tools: list, preview, progressRange: [0, 100] }];
  }

  const last = list[list.length - 1];
  if (last && last.procedure === 'extract_frames') {
    if (list.length === 1) {
      return [{ service: FRAMES, tools: [last], preview, progressRange: [0, 100] }];
    }
    // A parte editada ocupa 0-70 % (int(pct * 0.7) na base) e nunca é pré-visualização.
    const edited = editAndSubtitleStages(list.slice(0, -1), false).map((stage) => ({
      ...stage,
      progressRange: stage.progressRange.map((value) => Math.trunc(value * 0.7)),
    }));
    return [...edited, { service: FRAMES, tools: [last], preview, progressRange: [70, 100] }];
  }

  return editAndSubtitleStages(list, preview);
}

module.exports = { planStages };
