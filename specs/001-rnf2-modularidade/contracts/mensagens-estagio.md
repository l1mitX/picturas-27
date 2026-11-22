# Contrato: mensagens entre o `projects` e os serviços de vídeo

Interface interna (RabbitMQ). Mantém o envelope e as respostas da base (INV-002); só acrescenta campos de estágio.

## Pedido de estágio (`projects` → `video_edit_queue` | `video_subtitles_queue` | `video_frames_queue`)

```json
{
  "messageId": "request-<uuid> | preview-<uuid>",
  "timestamp": "<ISO 8601>",
  "procedure": "video_edit | video_subtitles | video_frames",
  "parameters": {
    "inputImageURI": "<caminho no volume image_data>",
    "outputImageURI": "<caminho do estágio, ou destino final se for o último>",
    "tools": [{ "procedure": "brightness", "params": { "brightness": 1.5 } }],
    "preview": false,
    "progress": { "user": "<id>", "projectId": "<id>", "imgId": "<id>", "range": [0, 100] },
    "stage": { "index": 0, "count": 1 },
    "sourceInfo": { "duration": 0.0, "fps": 0.0 }
  }
}
```

- `procedure` diferente do esperado pelo serviço → erro 2000 (`wrong_procedure`), como hoje.
- `tools` segue as regras do «Estágio» em `data-model.md`; ferramenta não suportada → 2002.
- `sourceInfo` só existe no estágio de extração precedido de edição (R5).
- `stage` serve para diagnóstico e para o serviço saber se é o último estágio (envia 100 % no fim).

## Resposta (serviço → `project_queue`)

Igual à base (`Tools/video/video.py:76-110`): sucesso com `output.imageURI`, `output.type` (`video`, `image` para a
folha de contactos, `frames` para a extração) e `video_info`; erro com `error.code` (2000–2005) e `error.msg`.
O `microservice` passa a identificar o serviço (e.g., `picturas-video-edit-ms`).

## Progresso (serviço → `ws_queue`)

Igual à base (`Tools/video/video.py:112-124`), com `percent` já convertido para a faixa do estágio (R4).
