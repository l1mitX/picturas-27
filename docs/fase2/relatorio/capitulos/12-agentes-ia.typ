#import "../template.typ": *

= Utilização de IA

#orientacao[
  *Origem:* Exercício 6, Bloco 2, secção 7, e Exercício 7, secção 6.

  Obrigatório: documentar as ferramentas, os modelos e as _skills_ utilizadas, enumerar as tarefas apoiadas e comprovar a
  validação realizada pela equipa, tanto na análise e na escrita como no código e nas medições. A equipa é responsável
  por todo o conteúdo entregue, incluindo o gerado por IA.

  Valoriza-se evidência concreta (_commits_, ficheiros de configuração dos agentes) e reflexão crítica: o que a IA
  fez bem, onde errou, como o erro foi detetado e o que foi rejeitado e porquê. Não basta dizer que a IA foi usada; é preciso mostrar
  que o resultado foi verificado.
]

A melhoria dos dois requisitos não funcionais seguiu o mesmo fluxo de _Spec-Driven Development_ da fase anterior,
apoiado pelo GitHub Spec Kit. A equipa escolheu os requisitos, as táticas e as decisões arquiteturais (capítulos 2 a
8), e só depois a IA gerou, a partir dessas decisões, a especificação, o plano e a lista de tarefas de cada requisito,
em `specs/001-rnf2-modularidade/` (RNF2, DA-2) e `specs/002-rnf1-capacidade/` (RNF1, DA-1). O código foi escrito
tarefa a tarefa a partir desses artefactos, e cada tarefa foi revista por um membro da equipa antes do _commit_. A IA
apoiou também a análise da base, os _scripts_ de medição e a revisão do relatório, sempre com verificação da equipa
no código e nos ficheiros de resultados.

== Ferramentas, modelos e configuração

#tabela(
  colunas: (3.5cm, 1fr),
  [Ferramenta / modelo], [Configuração e utilização (_skills_, instruções de projeto, MCP, …)],

  [GitHub Spec Kit \ (v1.2.0)],
  [Inicializado em `.specify/` com a integração `copilot` (`.specify/integration.json`, `4368d1f`). Modelos de documento
   em `.specify/templates/` e _scripts_ de apoio em `.specify/scripts/`. Constituição da fase 2 em
   `.specify/memory/constitution.md` (v1.0.0, `3dde194`), com cinco princípios: só _refactoring_, preservação funcional
   verificável, decisões primeiro e código depois, medir antes e depois da mesma forma, e coerência com o padrão global.],

  [GitHub Copilot],
  [_Skills_ do Spec Kit em `.github/skills/speckit-*/SKILL.md`: `constitution`, `specify`, `clarify`, `checklist`,
   `plan`, `tasks`, `analyze`, `implement`, `converge` e `taskstoissues`.],

  [Claude Code \ (Claude Opus 5.5)],
  [Assistente de código no VS Code e no terminal, com acesso ao repositório. Seguiu o `AGENTS.md` da base (orientações
   para agentes) e as regras da equipa em `docs/fase2/medicoes/README.md`, secção «Antes de medir».],
)

== Tarefas apoiadas e validação

#tab([Tarefas apoiadas por IA e validação],
  tabela(
    colunas: (2.6cm, 2.4cm, 2.4cm, 2.8cm, 2.8cm),
    tamanho: 8.5pt,
    [Ferramenta / modelo / _skill_], [Tarefa apoiada (capítulo)], [O que foi aceite], [O que foi rejeitado e porquê], [Como foi validado pela equipa],

    [Copilot \ `speckit-constitution`],
    [Constituição da fase 2 (transversal)],
    [Os cinco princípios: só _refactoring_, preservação, decisões primeiro, medição e coerência com o padrão global],
    [—],
    [Lida e aceite pela equipa antes de gerar as _specs_ (`3dde194`)],

    [Copilot \ `speckit-specify`, `speckit-checklist`, `speckit-plan`, `speckit-tasks`, `speckit-analyze`],
    [Especificação, plano, contratos e tarefas do RNF2 e do RNF1 (caps. 8 e 10)],
    [Os artefactos em `specs/001-rnf2-modularidade/` e `specs/002-rnf1-capacidade/`, depois de corrigidos],
    [As inconsistências apontadas pelo `speckit-analyze` (no RNF2: C1, C2, F1, F2, E1 e E2), corrigidas antes da
     implementação],
    [Revisão contra as decisões do cap. 8 (`b78db27`, `cf95814`)],

    [Claude Code \ (Claude Opus 5.5)],
    [Rascunho do diagnóstico, das evidências, das hipóteses e da matriz (caps. 2 a 4)],
    [A estrutura, as evidências depois de conferidas e a unificação dos IDs dos planos iniciais, que colidiam (E1–E7)],
    [—],
    [Cada evidência foi conferida no _commit_ `0523102` da base, no ficheiro e nas linhas citadas (`ae18ea0`,
     `6fcc10c`)],

    [Claude Code],
    [Cenários, candidatos e escolha da medida principal do CAND-1 (caps. 5 e 6)],
    [Os cenários e a quantificação, com os valores copiados dos ficheiros de medição],
    [A proposta de mudar a medida principal do M6 para o M1. A equipa manteve o M6, porque o ganho do M1 vem sobretudo
     do CAND-2],
    [Valores conferidos em `resultados/base/*_resumo.json`; leitura do REQ-VID-EDIT-009 corrigida depois de
     confrontada com o documento do PL1-G4 (`cff765c`, `c04e091`)],

    [Claude Code],
    [Táticas, decisões, vistas e plano de medição (caps. 7 a 10)],
    [As táticas e as duas decisões],
    [A primeira proposta punha os efeitos partilhados em `Tools/utils`, o que reconstruiria 16 serviços a cada mudança
     (EV-28). Ficaram em `Tools/effects/`, um ficheiro por efeito],
    [Evidências conferidas no código; vistas revistas depois da implementação, na T029 do RNF1 (`c056ca2`,
     `eafe0ba`, `db5507b`)],

    [Claude Code],
    [Planos dos RNF, _scripts_ de medição e _baseline_ (cap. 10)],
    [Os _scripts_ `carga_rnf1.py`, `rnf2_estaticas.py`, `regressao_hashes.py` e `elasticidade_m4.py`],
    [Linhas de atribuição a IA nas mensagens de _commit_, que a equipa não pediu. Ficaram em `cd4c12d`, `af910b4` e
     `98be376` e foram retiradas a partir daí],
    [Testes do `elasticidade_m4.py` em `docs/fase2/medicoes/tests`; os outros _scripts_ conferidos nas corridas de
     teste (`98be376`); medições oficiais corridas por um membro da equipa na máquina de referência],

    [GitHub Copilot \ (agente)],
    [Implementação do RNF2: base comum dos serviços de vídeo e serviço de edição, T006 a T021 (cap. 10)],
    [O código e os testes das tarefas],
    [—],
    [Testes do serviço de edição, regressão por _hashes_ e verificação manual na interface (T040); revisão antes do
     _commit_ (`a18bda4`, `ac1e8c1`)],

    [Claude Code],
    [Implementação do RNF1: T009 a T013, T018, T020 e T026 (cap. 10)],
    [O código e os testes das tarefas],
    [—],
    [Testes automáticos (51 do `video_autoscaler`, testes de réplicas nos serviços), uso da aplicação e revisão antes
     de cada _commit_ (`b391ec7`, `b6519d7`, `d21df69`, `a15b9e5`, `db819e2`, `853947e`)],

  ),
)

== Análise crítica

=== O que correu bem

Tomar as decisões antes de gerar código, como exige o terceiro princípio da constituição, deu bons resultados. Como a
IA gerava as _specs_ a partir de táticas e decisões já aceites, as listas de tarefas ficaram alinhadas com o
capítulo 8, e cada alteração pode ser seguida até à decisão, à tática e ao teste. A IA foi especialmente útil em três
coisas: organizar muito material com rastreabilidade, ligando evidências, hipóteses, cenários, táticas e decisões por
identificadores; escrever e testar código repetitivo, como os testes de concorrência, o `video_autoscaler` e os
_scripts_ de medição; e confrontar o texto com o código e com os dados, quando isso lhe era pedido explicitamente. As
duas listas de tarefas foram seguidas até ao fim e estão todas marcadas como feitas.

=== Onde a IA errou e como foi detetado

- *Propostas de decisão rejeitadas.* A IA propôs mudar a medida principal do CAND-1 do M6 para o M1; a equipa manteve
  o M6, porque o ganho do M1 vem sobretudo do CAND-2. A primeira proposta para os efeitos partilhados punha-os em
  `Tools/utils`, o que reconstruiria 16 serviços a cada mudança (EV-28); ficaram em `Tools/effects/`, um ficheiro por
  efeito. *Deteção:* revisão das propostas pela equipa contra as medições de base e o `docker-compose.yaml`.
- *Afirmações que não batiam com o código.* Na revisão final do relatório, uma contagem de serviços estava errada (15
  em vez de 16, EV-28), uma célula dizia que o `video_tool` só falava com o RabbitMQ, quando também descarrega o modelo
  de legendas da internet, e uma hipótese aparecia como refutada quando os dados a confirmavam (H-06). *Deteção:*
  conferência de cada afirmação no código da base e nos ficheiros de resultados.
- *Causas erradas para comportamentos observados.* Nas verificações manuais, a IA atribuiu a um defeito do código um
  atraso que, afinal, era uma réplica ainda a legendar um vídeo de 600 s. Também apresentou duas vezes uma causa errada
  para um conflito de versão no _Apply_. *Deteção:* a equipa não aceitou as explicações sem prova; no caso do _Apply_,
  a causa só foi encontrada com a prova recolhida nas ferramentas de programador do _browser_.

=== Práticas adotadas para validar o resultado

- *Especificação:* constituição, _specs_ e listas de tarefas lidas e aceites pela equipa antes da implementação;
  inconsistências encontradas pelo `speckit-analyze` corrigidas antes de começar.
- *Código:* testes automáticos nos serviços de vídeo e no `video_autoscaler`, regressão por _hashes_
  (`regressao_hashes.py`) para provar a preservação funcional, verificações manuais na interface e revisão de cada
  tarefa antes do _commit_, feito sempre por um membro da equipa.
- *Relatório:* nenhuma afirmação entra sem ser conferida no código da base, no código entregue ou nos ficheiros de
  resultados; uma explicação da IA é tratada como hipótese até haver prova; cada capítulo é revisto no PDF, e não só no
  código.
- *Decisões:* as decisões de fundo, como a escolha dos requisitos, a medida principal e os valores-alvo, foram sempre
  da equipa.

=== Limitações e melhorias

- *Cobertura dos testes.* O _frontend_ continua sem testes automáticos: o encadeamento dos estágios, as
  pré-visualizações e o cancelamento foram verificados manualmente na interface (T040). Uma regressão na interface tem
  mais probabilidade de passar despercebida.
- *Limitações da validação funcional.* Os testes e a regressão por _hashes_ provam que o comportamento se mantém, mas
  não avaliam a segurança nem a facilidade de manutenção do código gerado. As medições foram feitas numa única máquina
  de referência e cobrem apenas parte dos riscos de desempenho (capítulo 10). Propõe-se complementar estas
  verificações com revisão de código nos _pull requests_.
- *Explicações plausíveis mas erradas.* Os erros mais caros não foram de código, mas de diagnóstico: a IA dá causas
  convincentes sem prova. Propõe-se pedir sempre, junto com a explicação, o registo ou a medição que a confirma.
