# Plano de implementação: RNF2 — Modularidade do processamento de vídeo

**Pasta**: `specs/001-rnf2-modularidade` (ramo `fase2`) | **Data**: 2026-11-22 | **Spec**: [spec.md](spec.md)

**Entrada**: `spec.md` desta pasta; DA-2 (Exercício 7, secção 3); constituição v1.0.0.

## Resumo

Dividir o `video_tool` em três serviços por tipo de trabalho (edição, legendagem, extração), cada um com a sua fila e
o seu Dockerfile (TAT-07); passar o encadeamento dos estágios para o `projects`, com um planeador puro que reproduz as
regras atuais de `process_video` (TAT-09, R1); e extrair os 8 efeitos para `Tools/effects/`, um ficheiro por efeito,
usado pelas ferramentas de imagem e pelo serviço de edição (TAT-08, R8). O comportamento visto pelo utilizador fica
igual (INV-001 a INV-005), o que se prova com *hashes* iguais aos da base e com os testes existentes e novos.

## Contexto técnico

**Linguagem/versão**: Python 3.11 (*workers*, `python:3.11-slim`); Node.js (serviço `projects`, Express).

**Dependências principais**: `pika` 1.3.2, `pillow` 11.0.0, ffmpeg/ffprobe (apt), `faster-whisper` 1.2.1 (só
legendagem); `amqplib`/Mongoose no `projects`.

**Armazenamento**: volume partilhado `image_data` para entradas, saídas e ficheiros intermédios dos estágios (R3);
MongoDB do `projects` para os `Process`, com um campo novo opcional para o plano de estágios (`projects/models/process.js`; o Mongoose descarta campos fora do esquema).

**Testes**: `pytest` por serviço de vídeo; `node --test` no `projects`; `regressao_hashes.py` e `rnf2_estaticas.py`
(`docs/fase2/medicoes/`).

**Plataforma**: Docker Compose (Docker Desktop/WSL2 na máquina de medição); RabbitMQ 4.0.5.

**Tipo de projeto**: serviços *web* e *workers* assíncronos (microserviços com filas).

**Objetivos de desempenho**: não piorar o trabalho isolado (p95 ≤ 19,6 s, mínimo); o M1 é observado (SC-008).

**Restrições**: só *refactoring* (princípio I); saídas iguais bit a bit (princípio II); sem novas plataformas.

**Âmbito**: 3 serviços novos e 1 pasta partilhada nova, 8 ferramentas de imagem tocadas, `projects` (planeador,
encadeamento, limpeza), `docker-compose.yaml`, `rabbitMQ/definitions.json`.

## Verificação da constituição

*Antes da fase 0 e de novo depois da fase 1.*

| Princípio | Verificação | Estado |
|---|---|---|
| I. Só refactoring | Contrato de mensagens e códigos mantidos (`contracts/mensagens-estagio.md`); interfaces HTTP e UI inalteradas (INV-005) | ✅ |
| II. Preservação verificável | *Hashes* da base com o executor local que segue o mesmo plano que o `projects` (R2, R7); testes repartidos sem perder casos; testes novos para H-08 | ✅ (depende de R2) |
| III. Decisões primeiro | Cada estrutura cita a sua TAT; nomes de serviços e filas da DA-2; R1–R10 detalham sem alterar a DA-2 | ✅ |
| IV. Medir da mesma forma | `quickstart.md` usa os *scripts* e parâmetros da base; N3 com imagens do mesmo dia; R10 para a deteção estática | ✅ |
| V. Coerência e simplicidade | `projects` continua dono do cancelamento, quota e registo (INV-003); efeitos fora de `Tools/utils` (R8); código comum dos *workers* em `Tools/video_common/`, não copiado pelas imagens (R6) | ✅ |

Sem violações; a tabela «Acompanhamento da complexidade» fica vazia.

## Estrutura do projeto

### Documentação (esta feature)

```text
specs/001-rnf2-modularidade/
├── spec.md
├── plan.md              # este ficheiro
├── research.md          # fase 0 (R1–R10)
├── data-model.md        # fase 1
├── quickstart.md        # fase 1 (validação)
├── contracts/
│   └── mensagens-estagio.md
└── tasks.md             # fase 2 (/speckit-tasks; não criado por este passo)
```

### Código (raiz do repositório)

```text
Tools/
├── effects/                       # NOVO (TAT-08, R8): um ficheiro por efeito
│   ├── brightness.py  contrast.py  saturation.py  rotate.py
│   └── resize.py      binarization.py  cut.py  border.py
├── video_common/                  # NOVO (R6): worker base, probe, códigos 2000–2005, local_pipeline.py (só testes, R7)
├── video_edit/                    # NOVO (TAT-07): efeitos por fotograma, corte, velocidade; Dockerfile sem faster-whisper
│   └── tests/
├── video_subtitles/               # NOVO (TAT-07): Faster-Whisper e fontes; único com o volume whisper_models
│   └── tests/
├── video_frames/                  # NOVO (TAT-07): extração de fotogramas e folha de contactos
│   └── tests/
├── video/                         # RETIRADO no fim (o código passa para os três serviços)
├── brightness/ contrast/ saturation/ rotate/ resize/ binarization/ cut/ border/
│                                  # ALTERADOS: usam Tools/effects/<efeito>.py; Dockerfile copia só esse ficheiro
└── utils/                         # INALTERADO (EV-28: não acrescentar nada aqui)

projects/
├── utils/videoStages.js           # NOVO (R1): planStages(tools, preview) → estágios
├── models/process.js              # ALTERADO: campo opcional com o plano de estágios
├── utils/project_msg.js           # ALTERADO (R9): três filas novas, sem video_queue
├── routes/projects.js             # ALTERADO: envia o 1.º estágio; encadeia os seguintes na resposta; limpa stages/<token>/
└── tests/
    ├── fixtures/video_stage_plans.json   # NOVO (R2): casos partilhados com Python
    └── videoStages.test.js               # NOVO

rabbitMQ/definitions.json          # ALTERADO (R9)
docker-compose.yaml                # ALTERADO: três serviços em vez de video_tool
docs/fase2/medicoes/regressao_hashes.py   # ALTERADO só na chamada (R7)
```

**Decisão de estrutura**: segue a convenção da base (uma pasta por serviço em `Tools/`, um Dockerfile por pasta, a
construção a partir de `Tools/`). As pastas novas partilhadas (`effects`, `video_common`) ficam ao lado de `utils`,
mas cada Dockerfile copia só o que usa.

## Ordem sugerida (para o `/speckit-tasks`)

1. Ficheiro de casos (R2, com todos os pipelines dos testes Python e do `regressao_hashes.py`) e planeador (R1) com testes, sem tocar nos serviços: prova o comportamento esperado.
2. `Tools/effects/` e as 8 ferramentas de imagem; `regressao_hashes.py imagem` igual à base.
3. `Tools/video_common/` e os três serviços (código movido de `Tools/video/`), com o executor local; testes repartidos
   e `regressao_hashes.py video` igual à base.
4. `projects` (esquema do `Process`, filas, envio do 1.º estágio, encadeamento, limpeza) e
   `docker-compose.yaml`/`definitions.json`; retirar `Tools/video/` e a `video_queue`.
5. Teste novo de cancelamento a meio (H-08) e verificação manual do `quickstart.md`.
6. Medição `apos-rnf2` completa (constituição, princípio IV).

## Acompanhamento da complexidade

*Sem violações da constituição.*
