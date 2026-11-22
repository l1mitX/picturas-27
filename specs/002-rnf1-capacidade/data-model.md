# Modelo de dados (fase 1): RNF1 — Capacidade e elasticidade do processamento de vídeo

Sem entidades novas na base de dados. Há configuração nova e estados novos das réplicas.

## Política de réplicas (configuração do `video_autoscaler`, uma por serviço de vídeo)

| Campo | Significado | Regras |
|---|---|---|
| `service` | `video_edit`, `video_subtitles` ou `video_frames` | Nome do serviço no `docker-compose.yaml` |
| `queue` | Fila do serviço | A do RNF2 (`video_edit_queue`, …) |
| `min` | Réplicas mínimas | ≥ 1 (há sempre quem consuma) |
| `max` | Réplicas máximas | ≥ `min`; com os limites de memória, cabe na máquina de medição (R9) |
| `per_replica` | Mensagens pendentes por réplica | ≥ 1 |
| `poll_s` | Intervalo de consulta (s) | > 0 |
| `cooldown_s` | Espera antes de retirar réplicas (s) | ≥ 0 |

Valores por omissão: **[PROPOSTA]** em `research.md`, R3; decididos pela equipa antes da medição `apos-rnf1`.

## Réplica (estado de cada *worker* de vídeo)

```
a aguardar ──(recebe mensagem)──▶ a processar ──(estágio termina, ack)──▶ a aguardar
     │                                  │
     └──(SIGTERM)──▶ parada            └──(SIGTERM)──▶ a parar ──(estágio termina, ack)──▶ parada
```

- Em «a parar», a réplica já não aceita mensagens novas (consumo cancelado), mas termina e confirma a que tem (R4).
- O *heartbeat* continua ativo em todos os estados (R5); se a réplica bloquear, o broker fecha a ligação e a mensagem
  sem `ack` volta à fila.

## Evento do `video_autoscaler` (registo, para o M4)

`{ "ts": "<ISO 8601>", "service": "...", "pending": n, "current": n, "target": n, "action": "up|down|hold" }`, uma
linha JSON por decisão (R10).
