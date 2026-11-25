# RNF1 T003 — Decisão: parâmetros das réplicas e limites de memória

> **Decidido a 2026-11-25 pela pessoa E** (responsável pelo RNF1), que aceitou a proposta da IA sem alterações; ver
> «Decisão», no fim. As tabelas e as secções seguintes mantêm a proposta e as razões tal como foram apresentadas (partem
> do `research.md` do RNF1, R3 e R9, revistos com os dados da base e da medição `apos-rnf2` de 25/11). A decisão está
> registada no `docs/fase2/medicoes/README.md` e não muda depois de ver os resultados da `apos-rnf1` (constituição,
> princípio IV).

## O que é preciso decidir (em linguagem simples)

O `video_autoscaler` olha para as filas de vídeo e decide quantas cópias («réplicas») de cada serviço devem estar a
correr. O número de cópias muda sozinho; o que a equipa decide são as regras e os limites dentro dos quais ele decide:

| # | Parâmetro | Pergunta | [PROPOSTA] | Porquê |
|---|---|---|---|---|
| 1 | Edição: mínimo–máximo | Quantas cópias da edição, no mínimo e no máximo? | **1–4** | O cenário principal (M6) são 4 edições ao mesmo tempo: com 4 cópias, todas correm em paralelo. Na base, uma edição usou ~2,5 CPUs em média (pico 3,75); 4 juntas dão ~10 dos 12 CPUs. O mínimo aceitável do relatório é 2 em paralelo. As cópias da edição também resolvem o M1: na `apos-rnf2` o curto ainda espera ~100 s na fila da edição, atrás do passo de edição com que a legendagem começa (recodifica o vídeo de 177 s); com 2 ou mais cópias deixa de esperar. |
| 2 | Legendagem: mínimo–máximo | E da legendagem? | **1–1** | Nenhum cenário medido ganha com mais cópias da legendagem: o M6 não tem legendagem, e no M1 e no M2 o que atrasa os curtos é a fila da edição (linha 1), não a da legendagem. Cada legendagem gasta até 1 451 MiB (`apos-rnf2`) e muito CPU (Faster-Whisper), que disputaria os 12 CPUs com as edições. A memória já não é o impedimento (duas juntas ~2,9 GiB dos 7,7 GiB), por isso a opção (a), máximo 2, também é viável (ver abaixo). Fica configurável: numa máquina maior sobe-se o máximo. |
| 3 | Extração: mínimo–máximo | E da extração de fotogramas? | **1–2** | É leve e não entra nos cenários medidos; 2 chega para não bloquear. |
| 4 | Trabalhos por réplica | Quantos trabalhos à espera justificam mais uma cópia? | **1** | Os trabalhos são longos (10 s a 5 min): um trabalho à espera já justifica uma cópia nova (até ao máximo). |
| 5 | Intervalo de consulta | De quanto em quanto tempo o autoscaler olha para as filas? | **5 s** | A consulta à API do RabbitMQ é barata, e o alvo do M4 é acrescentar cópias em ≤ 30 s: 5 s de consulta deixa o resto para o contentor arrancar. |
| 6 | Espera antes de descer | Quanto tempo a fila tem de estar mais vazia antes de tirar cópias? | **60 s** | Evita estar sempre a subir e a descer quando os pedidos chegam com pequenos intervalos (o `research.md` propunha 30 s). Se a equipa decidir 60 s, atualizar também o valor por defeito (30 s) no contrato do autoscaler e no R3 do `research.md`. |
| 7 | Limite de memória da legendagem | Quanta memória pode usar cada cópia? | **1,6 GiB** | Máximo medido na `apos-rnf2`: 1 451 MiB (M1), mais ~10 % (1 596 MiB). Os 2 506 MiB da base eram do serviço único, que fazia edição e legendagem juntas. |
| 8 | Limite de memória da edição | Idem | **2,1 GiB** | Máximo medido na `apos-rnf2`: 1 888 MiB (M2; 1 886 MiB no M1), mais ~10 % (2 077 MiB). O pico é do passo de edição que recodifica o vídeo longo antes da legendagem; uma edição curta fica nos ~680–780 MiB. **Atenção:** a proposta anterior (1,75 GiB = 1 792 MiB) ficava abaixo do medido e o Docker matava a edição a meio do trabalho. |
| 9 | Limite de memória da extração | Idem | **512 MiB** | A `apos-rnf2` só a viu parada (16 MiB): nenhum cenário medido usa a extração. É um teto folgado para não a matar; confirmar com uma extração de 100 fotogramas do vídeo de 1080p (`docker stats`) antes de fixar. |

Os valores 1–6 vão para as variáveis de ambiente do `video_autoscaler`
(`specs/002-rnf1-capacidade/contracts/autoscaler-e-workers.md`):

```
SCALE_VIDEO_EDIT=video_edit_queue:1:4:1
SCALE_VIDEO_SUBTITLES=video_subtitles_queue:1:1:1
SCALE_VIDEO_FRAMES=video_frames_queue:1:2:1
POLL_SECONDS=5
COOLDOWN_SECONDS=60
```

Os valores 7–9 vão para o `docker-compose.yaml` (`deploy.resources.limits.memory`, T013).

## Memória: confirma-se que cabe?

A máquina de medição dá **7,7 GiB** ao Docker. Com a proposta, o pior caso (tudo no máximo ao mesmo tempo) é:

- legendagem: 1 × 1,6 GiB = **1,6 GiB** no limite (1 451 MiB medidos)
- edição: 4 × 2,1 GiB = **8,4 GiB** no limite. Na prática depende do vídeo:
  - 4 edições curtas (o M6): ~0,7–0,8 GiB cada, **~3 GiB** ao todo;
  - 4 edições de vídeos longos ao mesmo tempo (e.g., 4 pessoas a pedir legendas de vídeos de 3 min, cujo 1.º passo é
    uma edição): ~1,9 GiB cada, **~7,5 GiB**, quase todos os 7,7 GiB. Nenhum cenário medido faz isto.
- extração: 2 × 512 MiB = **1 GiB** no limite (16 MiB medidos, parada)
- resto da aplicação (bases de dados, RabbitMQ, SeaweedFS, serviços Node, ferramentas de imagem): **por medir**

Os limites são tetos, não memória reservada: a soma dos tetos (~11 GiB) passa dos 7,7 GiB, mas o uso real nos
cenários medidos fica muito abaixo. O caso de risco é o de vários vídeos longos na edição ao mesmo tempo; se a equipa o
achar provável, baixa-se o máximo da edição para 3 (o M6 passa a ter um trabalho à espera). Para confirmar que o uso
real cabe, falta saber quanta memória gasta o resto da aplicação: correr `docker stats --no-stream` com a aplicação
ligada e um M6 a correr (o `carga_rnf1.py` só mede os serviços de vídeo, e a `apos-rnf2` não registou o resto).

Opções que a equipa considerou para a legendagem:
- **(a)** máximo 2: com os números da `apos-rnf2` são ~3,2 GiB no limite (~2,9 GiB medidos), o que já cabe com as
  edições curtas do M6; o risco de faltar memória fica só para o caso dos vídeos longos acima (nenhum cenário medido
  junta 2 legendagens e 4 edições);
- **(b)** máximo 1 — **[PROPOSTA]**, a mais segura nesta máquina e suficiente para os cenários medidos (linha 2);
- **(c)** máximo 2 na legendagem e máximo 3 na edição (o M6 tem 4 trabalhos, por isso um ficaria à espera).

## Como começa cada repetição do M6: cópias «frias» ou «quentes»

- **Frias:** cada repetição começa só com o mínimo (1 cópia de edição). O autoscaler vê a fila e sobe as cópias; esse
  tempo (até 5 s de consulta + arranque do contentor) entra no tempo de cada trabalho.
- **Quentes:** as cópias já estão subidas quando chegam os 4 pedidos.

**[PROPOSTA] Frias como medição oficial do M6**, porque:
1. é o que um utilizador encontra na prática: depois de um período sem pedidos, as cópias já desceram ao mínimo;
2. começa no mesmo estado da base (um único *worker* de edição a correr), por isso a comparação `apos-rnf2` →
   `apos-rnf1` é justa;
3. é a opção conservadora: não melhora os resultados à custa de cópias já subidas (isso seria o mesmo que ter mínimo 4).

Quentes pode correr-se como **medição complementar** (pasta separada, como a T015), para separar o ganho de capacidade
(quentes) do custo da elasticidade (diferença entre frias e quentes). O tempo de subida em si já é medido no M4.

**Atenção ao alvo.** O alvo do M6 no relatório é p95 ≤ 30 s, fixado a partir da base de 18/11 (portátil na bateria).
Com a máquina de 25/11 (ligada à tomada) o M6 já fica nos 21,8 s sem réplicas, por isso o relatório propõe avaliar o
CAND-1 pela meta equivalente **p95 ≤ 11 s** (cap. 6, **[PROPOSTA]**, por decidir).
Com 11 s, o custo de arrancar cópias pesa muito: na `apos-rnf2` um trabalho sozinho demora ~5,9 s, e com frias os
trabalhos 2 a 4 esperam até 5 s de consulta mais o arranque do contentor (por medir, é o M4) antes de começarem.
Estimativa grosseira (da IA, não medida): o último trabalho acaba perto de 5 + arranque + 6–8 s, ou seja, é provável
passar dos 11 s com frias mesmo melhorando muito face aos 21,8 s da `apos-rnf2`. Com quentes deve cumprir.

Se com frias o M6 falhar o alvo mas cumprir com quentes, isso é um resultado honesto a relatar: o custo de arrancar
cópias, que se baixa com mínimo 2 na edição (gasta mais memória parada; uma cópia a trabalhar chegou a ~0,7 GiB, parada gasta menos, por medir). A equipa deve escolher
frias ou quentes **sabendo isto**, antes de medir.

**Consequência para o *script*:** hoje o `carga_rnf1.py` corre as repetições seguidas, sem pausa. Com a espera de 60 s,
só a 1.ª repetição seria fria e as outras quentes. Para medir frias é preciso acrescentar uma pausa entre repetições
maior do que a espera antes de descer mais a paragem ordenada (e.g., `--pausa 120`), ou esperar que o autoscaler volte
ao mínimo. Na base a pausa não muda nada (havia um único *worker*), por isso o método continua comparável.

## Ordem sugerida

1. ~~Medir a carga `apos-rnf2`~~ — feito a 25/11 (deu os valores das linhas 7–8 acima).
2. Antes da reunião (opcional, ~10 min, não é medição oficial): `docker stats --no-stream` com a aplicação ligada e um
   M6 a correr (memória do resto da aplicação) e uma extração de 100 fotogramas (confirma a linha 9).
3. Reunião curta da equipa: decidir as linhas 1–9, a opção (a), (b) ou (c), frias ou quentes, e o alvo do M6 (30 s
   ou o equivalente de 11 s).
4. Registar a decisão no `docs/fase2/medicoes/README.md` e marcar a T003 no `specs/002-rnf1-capacidade/tasks.md`.

A T003 tem de estar fechada antes da T013 (limites no `docker-compose.yaml`), da T020 (serviço `video_autoscaler`) e
de qualquer medição `apos-rnf1`.

## Alternativa considerada e não seguida: parâmetros que se ajustam sozinhos

O autoscaler podia, antes de subir uma cópia, ver a memória livre e só subir se coubesse, em vez de um máximo fixo.
Não se segue agora porque: sai do plano (R3 e R9 pedem valores fixos); a constituição pede parâmetros fixados antes de
medir, e valores que mudam sozinhos tornam os resultados difíceis de repetir e de comparar; é mais código e mais risco
perto da entrega. Fica para o relatório como trabalho futuro.

## Decisão

Decidido pela pessoa E a 2026-11-25, a partir da **[PROPOSTA da IA]** (sem reunião da equipa).

| # | Parâmetro | Valor decidido |
|---|---|---|
| 1 | Edição mín–máx | 1–4 |
| 2 | Legendagem mín–máx | 1–1 |
| 3 | Extração mín–máx | 1–2 |
| 4 | Trabalhos por réplica | 1 |
| 5 | Intervalo de consulta | 5 s |
| 6 | Espera antes de descer | 60 s |
| 7 | Memória da legendagem | 1,6 GiB |
| 8 | Memória da edição | 2,1 GiB |
| 9 | Memória da extração | 512 MiB (confirmar com uma extração de 100 fotogramas antes da T013; se passar de ~465 MiB, subir para o medido + ~10 % e registar porquê) |
| — | Opção para a legendagem | (b), máximo 1 |
| — | M6 oficial | Frias; quentes como medição complementar, em pasta separada, para saber o custo de arrancar cópias |
| — | Alvo do M6 | p95 ≤ 11 s (meta equivalente do cap. 6); os 30 s ficam na tabela do relatório |

Decidido por: pessoa E · Data: 2026-11-25
