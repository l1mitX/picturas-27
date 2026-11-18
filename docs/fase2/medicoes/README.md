# Medições da Fase 2

> **Estado (2026-11-18, pausa):** baseline do RNF2 (estáticas, N3, regressão) concluída. Script de carga
> `carga_rnf1.py` escrito e testado no cenário `isolado` (curto sozinho: 13,8 s). Ronda de teste do M1
> interrompida; uma legendagem do vídeo de 177 s demora pelo menos 2 min. **Falta decidir** as repetições
> (proposta mínima: isolado 5, M1 5, M2 só N=4 com 3; sem referência `--scale 2`) e correr a baseline do RNF1.
> A pasta `resultados/teste/` é só de teste do script: não é baseline.

Scripts e resultados das medições dos dois RNF. Os scripts são os mesmos em todos os momentos de medição
(base, após RNF2, após RNF1); só muda a etiqueta da pasta de resultados.

| Script | Para quê | RNF |
|---|---|---|
| `rnf2_estaticas.py` | N1 (duplicação imagem/vídeo), N2 (impacto de mudança, cenários C1–C3), N4 (tamanho e complexidade) | RNF2 |
| `regressao_hashes.py` | Referência de preservação funcional: *hash* das saídas das ferramentas de imagem e de 9 pipelines de vídeo | RNF1 e RNF2 |
| (a criar) script de carga | M1–M5 | RNF1 (e N5 do RNF2) |

Comandos exatos no cabeçalho de cada script. Resultados em `resultados/<etiqueta>/`.

## Ambiente da baseline (2026-11-18)

| Item | Valor |
|---|---|
| Commit | `0523102` (sem alterações ao código; só `docs/` acrescentado) |
| Máquina | AMD Ryzen 5 5600H, 15,9 GB RAM, Windows 11 Home |
| Docker | Docker Desktop, Engine 29.8.0, Compose 5.5.1, WSL2 (kernel 6.18.58.1) |
| Recursos dados ao Docker | 12 CPUs, 7,7 GiB de RAM |
| Arranque | `docker compose up -d --build` (ver nota abaixo) |

> **Nota sobre o arranque.** Na primeira tentativa, `docker compose up -d` (sem `--build`) reaproveitou imagens
> antigas com o mesmo nome de projeto (`picturas-*`), construídas a 21–22/10/2026 a partir do código da Fase 1
> da equipa, e não da base. Detetado porque os testes dentro do contentor `projects` não eram os do repositório.
> A aplicação foi reconstruída com `--build` antes de qualquer medição. **Usar sempre `--build`** nas medições.

## Resultados da baseline (`resultados/base/`)

### Testes existentes

| Conjunto | Comando | Resultado |
|---|---|---|
| `projects/tests` (3 ficheiros) | `docker compose exec -T projects sh -c "node --test tests/*.test.js"` | 8 testes, 8 passam |
| `Tools/video/tests` (3 ficheiros) | `docker compose run --rm --no-deps -T video_tool sh -c "pip install -q pytest && python -m pytest -q -p no:cacheprovider tests"` | 74 testes, 74 passam (169 s) |

### RNF2 — métricas estáticas (`rnf2_estaticas.json`)

| Métrica | Base |
|---|---|
| N1 — efeitos com duas implementações (imagem e vídeo) | **8** (brightness, contrast, saturation, rotate, resize, binarization, cut, border); 18 linhas copiadas em `Tools/video/effects.py` |
| N2 — C1 (mudar o filtro de brilho) | 2 ficheiros; reconstruir `brightness_tool` e `video_tool`; reimplanta os 3 tipos de trabalho de vídeo |
| N2 — C2 (atualizar o Faster-Whisper) | 2 ficheiros; reconstruir `video_tool`; reimplanta os 3 tipos de trabalho de vídeo |
| N2 — C3 (mudar a amostragem de fotogramas) | 1 ficheiro; reconstruir `video_tool`; reimplanta os 3 tipos de trabalho de vídeo |
| N4 — serviços de vídeo | 1 (`video`) |
| N4 — SLOC Python do vídeo | 601 (maior: `video_processor.py`, 264) |
| N4 — complexidade ciclomática máxima | 22 (`process_video`); `extract_frames` 14; `callback` 11 |
| N4 — orquestrador `projects/routes/projects.js` | 2733 linhas; 16 com ramificação imagem/vídeo (`isVideo`/`media_type`) |

### RNF2 — N3 (imagem Docker do vídeo)

| Item | Base |
|---|---|
| Tamanho da imagem `picturas-video_tool` | 1,69 GB (1 692 188 439 B) |
| Maiores camadas | `apt-get` ffmpeg + fontes (incl. CJK das legendas): 597 MB; `pip install` com `faster-whisper`: 457 MB |
| Tempo de build sem cache | 240 s (`docker compose build --no-cache video_tool`, 1 medição, sem outra carga na máquina) |

> O `apt-get` do Dockerfile não fixa versões: a imagem reconstruída sem cache ficou com 1 707 624 420 B (contra
> 1 692 188 439 B da construída a 10/11). Comparar tamanhos só entre imagens construídas no mesmo dia, ou
> comparar o tamanho das camadas próprias (as que vêm do `pip install` e do `COPY`).

### Referência de regressão (`regressao_imagem.json`, `regressao_video.json`)

- Imagem: 8 ferramentas sobre uma imagem de entrada determinística (gerada pelo script). Concluído.
- Vídeo: 9 pipelines (V1–V8 e a pré-visualização V1p) sobre `samples/video/`, cobrindo filtros, corte, velocidade,
  extração (sozinha e depois de edições) e legendas. Concluído.
- **Determinismo verificado:** a referência de vídeo foi gerada duas vezes (`base/` e `base-repeticao/`) e os
  *hashes* são iguais nos 9 casos, incluindo as legendas (Faster-Whisper em CPU). A comparação depois do
  refactoring é, por isso, válida.
