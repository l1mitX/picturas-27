<!--
Sync Impact Report
- Versão: (modelo) → 1.0.0 (primeira ratificação, Fase 2)
- Princípios: I. Só refactoring · II. Preservação funcional verificável · III. Decisões primeiro, código depois ·
  IV. Medir antes e depois, da mesma forma · V. Coerência com o padrão global e simplicidade
- Secções acrescentadas: Restrições da Fase 2 · Fluxo de trabalho · Governação
- Modelos a rever: .specify/templates/spec-template.md (requisitos funcionais → invariantes) ⚠ ver nota em "Fluxo de trabalho"
- Pendentes: nenhum
-->

# Constituição do PictuRAS — Fase 2 (melhoria de RNF por refactoring)

Aplica-se a todo o código, configuração e documentação produzidos na Fase 2, por pessoas e por assistentes de IA.
A base é a solução PL1-G4 no *commit* `0523102` (`picturas-um/picturas-27`). As decisões arquiteturais estão nos
exercícios da equipa (`docs/fase2/exercicios/`) e no relatório (`docs/fase2/relatorio/`).

## Princípios

### I. Só refactoring

A Fase 2 melhora dois requisitos não funcionais sem acrescentar funcionalidades. O utilizador tem de obter os mesmos
resultados, com a mesma interface e as mesmas regras (quotas, cancelamento, limites por perfil). Qualquer alteração que
o utilizador veja é classe B e tem de estar justificada numa decisão; funcionalidade nova (classe C) é rejeitada.
O contrato das mensagens entre serviços (`messageId`, `timestamp`, `procedure`, `parameters`) e os códigos de erro
2000–2005 mantêm-se.

### II. Preservação funcional verificável (inegociável)

Nenhuma alteração está concluída sem prova de que o comportamento se mantém:

- `docs/fase2/medicoes/regressao_hashes.py` dá *hashes* **iguais** aos da base (`resultados/base/`), para as
  ferramentas de imagem e para os 9 pipelines de vídeo (H-07);
- os testes existentes passam: `projects/tests` (8 na base) e os de `Tools/video/tests` (74 na base), adaptados aos
  novos serviços sem perder casos;
- cada risco identificado nas decisões tem um teste novo: cancelamento com várias réplicas (H-05), cancelamento com o
  pipeline repartido (H-08), retirar réplicas a meio de um trabalho (H-10).

### III. Decisões primeiro, código depois

O código realiza as decisões DA-1 e DA-2 do Exercício 7; não as substitui.

- Cada *spec*, plano e tarefa cita os IDs de que parte (`QS-nn`, `CAND-n`, `DA-n`, `TAT-nn`, `H-nn`, `EV-nn`) em vez
  de copiar o texto. Os IDs nunca se reutilizam nem se renumeram.
- Se o código tiver de se afastar de uma decisão, regista-se o desvio e porquê no campo «Desvios face à decisão» da
  DA (relatório, cap. 8), e a vista «depois» (`docs/fase2/relatorio/images/vista_depois.puml`) é atualizada.
- Hipóteses (`H-nn`) confirmadas ou refutadas durante a implementação atualizam o estado no Exercício 6, Bloco 1.

### IV. Medir antes e depois, da mesma forma

- Três momentos, sempre com o mesmo método: `base`, `apos-rnf2`, `apos-rnf1` (`docs/fase2/medicoes/README.md`,
  «Antes de medir»). O ganho de cada RNF mede-se entre momentos consecutivos.
- Mesma máquina, mesmos recursos do Docker, arranque com `docker compose up -d --build`, mesmos parâmetros dos
  *scripts*. Imagens Docker só se comparam se forem construídas no mesmo dia (N3).
- Os valores-alvo e mínimos já estão fixados (relatório, Tabela 18) e não se mudam depois de ver os resultados.
  Nunca se inventam valores: o que não foi medido fica por medir.

### V. Coerência com o padrão global e simplicidade

- O vídeo passa a seguir o padrão global: um serviço por unidade de trabalho, com fila própria, encadeado pelo
  `projects`, que continua a ser o único dono do cancelamento, da quota e do registo dos resultados.
- O módulo de efeitos partilhado fica em `Tools/effects/`, com um ficheiro por efeito, e **não** em `Tools/utils`
  (EV-28): cada ferramenta de imagem copia só o seu ficheiro.
- Escolhe-se a solução mais simples que cumpre a decisão; peças novas (e.g., o `video_autoscaler`) têm de estar
  previstas numa DA.

## Restrições da Fase 2

- Ordem de implementação: primeiro o RNF2 (DA-2: serviços por tipo de trabalho e efeitos partilhados), depois o RNF1
  (DA-1 + TAT-13: réplicas, ajuste automático, paragem ordenada e *heartbeat*). A DA-2 é pré-requisito da DA-1.
- Plataforma: Docker Compose, RabbitMQ 4.0.5, *workers* Python com `pika`, serviços Node. Não se introduzem outras
  plataformas de execução (e.g., Kubernetes).
- Prazo de entrega: 2026-11-27.

## Fluxo de trabalho

- Fluxo curto do Spec Kit: `specify → plan → tasks → implement`; o `clarify` só se uma decisão estiver mesmo em aberto.
  `analyze` antes de dar uma *spec* por concluída, para apanhar desvios face às DA.
- Nas *specs*, os «requisitos funcionais» do modelo escrevem-se como **invariantes** (o que tem de ficar igual), e os
  critérios de sucesso são as medidas do cenário (`QS-nn`) com os valores-alvo e mínimos da Tabela 18.
- Os assistentes de IA propõem alterações; um membro da equipa revê-as e faz o *commit*. As mensagens de *commit*
  citam os IDs das decisões que realizam (e.g., «DA-2, TAT-08: …»), para preencher o campo «Implementação» das DA.
- Documentação em português europeu.

## Governação

Esta constituição prevalece sobre outras práticas durante a Fase 2. Alterações exigem acordo da equipa, uma linha no
relatório de impacto acima e a subida da versão (MAJOR: princípio retirado ou redefinido; MINOR: princípio ou secção
nova; PATCH: clarificação). Cada *spec* e cada revisão verificam o cumprimento dos princípios I a V.

**Versão**: 1.0.0 | **Ratificada**: 2026-11-22 | **Última alteração**: 2026-11-22
