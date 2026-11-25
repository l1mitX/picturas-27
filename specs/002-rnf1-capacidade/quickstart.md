# Guia de validação: RNF1 — Capacidade e elasticidade do processamento de vídeo

Cenários para provar que a *spec* está cumprida. Mesma máquina e mesmos parâmetros da base e de `apos-rnf2`
(constituição, princípio IV).

## Pré-requisitos

- RNF2 concluído e medido (`docs/fase2/medicoes/resultados/apos-rnf2/`).
- Parâmetros da política de réplicas e limites de memória decididos pela equipa (`research.md`, R3 e R9) e registados
  em `docs/fase2/medicoes/README.md` antes de medir.
- `docker compose up -d --build`, com o projeto Compose `picturas`.

## 1. Preservação (SC-005)

1. Testes de todos os serviços e do `projects` (comandos da T028 do RNF2) → todos passam.
2. `regressao_hashes.py imagem apos-rnf1` e `video apos-rnf1` → *hashes* iguais à base.

## 2. Réplicas e disponibilidade (SC-006, H-01 a H-05, H-10)

1. **H-01/H-02**: `docker compose up -d --scale video_edit=2`; dois trabalhos do mesmo projeto em simultâneo e duas
   pré-visualizações do mesmo vídeo → sem erros, resultados corretos.
2. **H-03**: apagar o volume `whisper_models`; arrancar 2 réplicas de legendagem e pedir duas legendagens → o modelo é
   descarregado uma vez e as duas terminam.
3. **H-10**: com uma legendagem em curso, `docker stop` da réplica → o vídeo termina nessa réplica antes de ela sair;
   nenhum vídeo recomeça noutra (registos dos *workers*).
4. **Bloqueio**: `docker pause` de uma réplica a meio de um estágio → ao fim de ~2 intervalos de *heartbeat* (60 s por
   omissão, ~2 min), a mensagem passa para outra réplica.
5. **H-05**: cancelar um pipeline com várias réplicas ativas → nada é registado.
6. **H-04**: legendagem do vídeo Premium mais longo permitido (600 s), sozinha e com 2 em paralelo → duração medida
   abaixo do `consumer_timeout`, sem reentrega.

## 3. Capacidade e elasticidade (SC-001 a SC-004, SC-007)

1. `carga_rnf1.py apos-rnf1 paralelo` → M6 (p95 ≤ 30 s alvo; ≥ 2 em simultâneo mínimo).
2. `carga_rnf1.py apos-rnf1 m1`, `isolado` e `m2` → M1 não pior do que `apos-rnf2`; isolado ≤ 19,6 s.
3. `elasticidade_m4.py apos-rnf1` → M4 (≤ 30 s alvo; ≤ 60 s mínimo) e regresso ao mínimo.
4. Durante 1–3: `docker inspect` de cada contentor de vídeo → nenhum com `OOMKilled: true`.

## Registo

- **2026-11-25**: no ramo `fase2`, com RNF2 integrado, os testes passam: `projects/tests` 68/68; `video_edit`
  38/38; `video_subtitles` 21/21; `video_frames` 42/42 (101 testes de vídeo). Contudo,
  `docs/fase2/medicoes/resultados/apos-rnf2/` ainda não existe. Por isso, o ponto de partida está testado, mas a
  medição obrigatória do RNF2 não está completa e a T001 permanece pendente; não iniciar as medições `apos-rnf1`
  até os resultados `apos-rnf2` serem recolhidos conforme o quickstart do RNF2.

Resultados em `docs/fase2/medicoes/resultados/apos-rnf1/`. O ganho do RNF1 é a diferença entre `apos-rnf2` e
`apos-rnf1`. Hipóteses H-01 a H-05 e H-10 atualizam o Exercício 6, Bloco 1; desvios face à DA-1 vão para o relatório
(cap. 8).
