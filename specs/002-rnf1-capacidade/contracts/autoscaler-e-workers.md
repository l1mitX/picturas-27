# Contrato: `video_autoscaler` e *workers* de vídeo

Interfaces internas. As mensagens entre o `projects` e os serviços de vídeo são as do RNF2
(`specs/001-rnf2-modularidade/contracts/mensagens-estagio.md`) e não mudam.

## Configuração do `video_autoscaler` (variáveis de ambiente)

| Variável | Exemplo | Significado |
|---|---|---|
| `COMPOSE_PROJECT_NAME` | `picturas` | Projeto Compose a ajustar (tem de ser o do arranque, R1) |
| `RABBITMQ_API` | `http://rabbitmq:15672` | API de gestão do RabbitMQ (R2) |
| `RABBITMQ_USERNAME`, `RABBITMQ_PASSWORD` | — | As mesmas credenciais dos outros serviços |
| `SCALE_<SERVIÇO>` | `video_edit_queue:1:4:1` | `fila:mínimo:máximo:por_réplica` para cada serviço de vídeo |
| `POLL_SECONDS`, `COOLDOWN_SECONDS` | `5`, `30` | Intervalo de consulta e espera antes de descer (R3) |

Montagens: `/var/run/docker.sock` e o `docker-compose.yaml` (só leitura). É o único serviço com acesso ao *socket*.

## Saída do `video_autoscaler`

Uma linha JSON por decisão no *log* do contentor (formato em `data-model.md`, «Evento»), para o M4 (R10).

## *Workers* de vídeo

- **Sinal de paragem**: `SIGTERM` → paragem ordenada (R4). O `stop_grace_period` do serviço tem de ser maior do que o
  seu estágio mais longo.
- **Ligação ao RabbitMQ**: *heartbeat* ativo (valor por omissão do broker); `prefetch_count=1`; `ack` manual no fim do
  estágio, publicado a partir da *thread* da ligação (R5).
- **Registo**: uma linha com data e hora quando consome a primeira mensagem depois de arrancar (R10).
