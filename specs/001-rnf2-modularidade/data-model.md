# Modelo de dados (fase 1): RNF2 — Modularidade do processamento de vídeo

Não há entidades novas na base de dados. O que muda é a forma como um trabalho de vídeo é repartido.

## Trabalho de vídeo (inalterado)

Um vídeo de um projeto com a sua lista ordenada de ferramentas (`videoPipeline(project, imgId)`), criado no *Apply* ou
na pré-visualização. Guarda-se como hoje num `Process` do `projects` (`user_id`, `project_id`, `img_id`, `msg_id`,
`og_img_uri`, `new_img_uri`, `token`, `cancelToken`, `runner_id`).

## Estágio (novo, só em memória e nas mensagens)

| Campo | Significado | Regras |
|---|---|---|
| `service` | `video_edit`, `video_subtitles` ou `video_frames` | Determina a fila (R9) |
| `tools` | Ferramentas que este estágio executa, por ordem | `video_subtitles` tem exatamente `[subtitles]`; `video_frames` tem exatamente `[extract_frames]`; `video_edit` tem só ferramentas suportadas (pode ser vazio, R1-3) |
| `preview` | Se este estágio aplica a regra da pré-visualização | No máximo um estágio de edição e o de extração (R1-4) |
| `progressRange` | `[início, fim]` em percentagem | Faixas contíguas, crescentes, de 0 a 100 (R4) |
| `input` / `output` | Caminhos no volume `image_data` | Entrada do estágio *i+1* = saída do estágio *i*; o último escreve no destino final (R3) |

**Transições** (por trabalho de vídeo, controladas pelo `projects`):

```
planeado → estágio 0 enviado → resposta 0 (sucesso) → estágio 1 enviado → … → último estágio (sucesso) → resultado registado → pasta stages/<token>/ apagada
                    └─ resposta com erro em qualquer estágio → erro enviado ao utilizador → pasta apagada
                    └─ token cancelado ao receber uma resposta → nada é registado nem enviado → pasta apagada
```

O `Process` do `projects` passa a ter `cur_pos` = índice do estágio em curso (hoje é o índice da ferramenta de imagem),
e guarda o plano de estágios do trabalho, para o encadeamento não depender de recalcular o plano. Como o `Process` é um
esquema Mongoose (`projects/models/process.js`), o plano exige um campo novo, opcional (e.g., `stages`), senão é
descartado ao gravar.

## Módulo de efeitos

Um ficheiro por efeito em `Tools/effects/` (`brightness`, `contrast`, `saturation`, `rotate`, `resize`,
`binarization`, `cut`, `border`), cada um com uma função PIL pura `(imagem, parâmetros…) → imagem`, com os nomes de
parâmetros atuais. Usado por uma ferramenta de imagem (o seu efeito) e pelo serviço de edição (os oito).
