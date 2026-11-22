# Plano de implementação: RNF1 — Capacidade e elasticidade do processamento de vídeo

**Pasta**: `specs/002-rnf1-capacidade` (ramo `fase2`) | **Data**: 2026-11-22 | **Spec**: [spec.md](spec.md)

**Entrada**: `spec.md` desta pasta; DA-1 e TAT-13 (Exercício 7, secção 3); constituição v1.0.0; RNF2 concluído
(`specs/001-rnf2-modularidade`).

## Resumo

Permitir várias réplicas de cada serviço de vídeo a consumir a mesma fila (TAT-01); acrescentar um serviço
`video_autoscaler` que ajusta as réplicas pelo tamanho de cada fila, através do Compose (TAT-02, R1–R3); e tornar a
entrada e saída de réplicas segura: paragem ordenada com `SIGTERM` e *heartbeat* ativo com o processamento numa *thread*
separada (TAT-13, R4, R5). Fecham-se também os riscos das hipóteses H-02 a H-04 (temporários, Whisper,
`consumer_timeout`) e põem-se limites de memória (R6–R9).

## Contexto técnico

**Linguagem/versão**: Python 3.11 (*workers* e `video_autoscaler`).

**Dependências principais**: `pika` 1.3.2 (com `add_callback_threadsafe`); cliente Docker + *plugin* Compose no
`video_autoscaler`; `requests` para a API de gestão do RabbitMQ.

**Armazenamento**: volume `image_data` (inalterado); volume `whisper_models` partilhado pelas réplicas de legendagem.

**Testes**: `pytest` nos serviços de vídeo (paragem ordenada, *thread* de trabalho) e no `video_autoscaler` (política
de réplicas, função pura); verificações com contentores reais em `quickstart.md`, secção 2.

**Plataforma**: Docker Compose (Docker Desktop/WSL2), RabbitMQ 4.0.5 com a API de gestão (porta 15672).

**Tipo de projeto**: *workers* assíncronos e um serviço de controlo.

**Objetivos de desempenho**: M6 p95 ≤ 30 s (alvo); M4 ≤ 30 s (alvo); isolado e M1 sem piorar.

**Restrições**: só *refactoring*; *hashes* iguais; memória total ≤ 7,7 GiB na máquina de medição; sem outras plataformas.

**Âmbito**: `Tools/video_common/worker.py`, `Tools/video_subtitles/subtitles.py`, `Tools/video_edit/video_processor.py`
(nome do `.part`), serviço novo `Tools/video_autoscaler/`, `docker-compose.yaml`, `rabbitMQ/rabbitmq.conf`, *script*
novo `docs/fase2/medicoes/elasticidade_m4.py`.

## Verificação da constituição

| Princípio | Verificação | Estado |
|---|---|---|
| I. Só refactoring | Nenhuma mudança visível além do tempo de espera; contrato do RNF2 inalterado (INV-002) | ✅ |
| II. Preservação verificável | *Hashes* com uma e várias réplicas; testes novos para H-01 a H-05 e H-10 (RE-008) | ✅ |
| III. Decisões primeiro | `video_autoscaler` previsto na DA-1; paragem ordenada e *heartbeat* na TAT-13; parâmetros como **[PROPOSTA]** até a equipa decidir | ✅ |
| IV. Medir da mesma forma | `carga_rnf1.py` com os parâmetros da base; M4 com *script* novo e 5 repetições; ganho entre `apos-rnf2` e `apos-rnf1` | ✅ |
| V. Coerência e simplicidade | Escala pelo Compose, sem outra plataforma (R1); `projects` intacto; *socket* do Docker só no `video_autoscaler` | ✅ (o *socket* é um custo de segurança aceite na DA-1) |

Sem violações.

## Estrutura do projeto

### Documentação (esta feature)

```text
specs/002-rnf1-capacidade/
├── spec.md
├── checklists/requirements.md
├── plan.md              # este ficheiro
├── research.md          # fase 0 (R1–R10)
├── data-model.md        # fase 1
├── quickstart.md        # fase 1
├── contracts/
│   └── autoscaler-e-workers.md
└── tasks.md             # fase 2 (/speckit-tasks)
```

### Código (raiz do repositório)

```text
Tools/
├── video_common/worker.py          # ALTERADO (TAT-13): thread de trabalho, heartbeat ativo, SIGTERM, registo da 1.ª mensagem
├── video_edit/video_processor.py   # ALTERADO (R7): .part com nome único
├── video_subtitles/subtitles.py    # ALTERADO (R8): lock de ficheiro na primeira carga do modelo
└── video_autoscaler/               # NOVO (TAT-02): autoscaler.py, policy.py (função pura), Dockerfile, requirements.txt, tests/

docker-compose.yaml                 # ALTERADO: video_autoscaler; stop_grace_period e limites de memória nos serviços de vídeo
rabbitMQ/rabbitmq.conf              # ALTERADO (R6): consumer_timeout
docs/fase2/medicoes/elasticidade_m4.py   # NOVO (R10)
docs/fase2/medicoes/README.md       # ALTERADO: parâmetros da política e limites registados antes de medir
```

**Decisão de estrutura**: o `video_autoscaler` segue a convenção de `Tools/` (uma pasta por serviço com o seu
Dockerfile); a política de réplicas fica num módulo puro (`policy.py`) para se testar sem Docker nem RabbitMQ.

## Ordem sugerida (para o `/speckit-tasks`)

1. Paragem ordenada e *heartbeat* no `worker.py`, com testes (é o pré-requisito das réplicas, TAT-13).
2. Riscos das réplicas: `.part` único, *lock* do Whisper, `consumer_timeout`; verificar H-01 a H-04 com `--scale` manual.
3. Política de réplicas (`policy.py`) com testes, e o `video_autoscaler`.
4. `docker-compose.yaml` (autoscaler, `stop_grace_period`, limites de memória) e decisão dos parâmetros.
5. *Script* do M4 e medição `apos-rnf1`.

## Acompanhamento da complexidade

*Sem violações da constituição.*
