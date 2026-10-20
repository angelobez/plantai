---
name: rodada
description: Rodada de alinhamento do mapa: junta as perguntas dos tickets de decisão num questionário e, depois de respondido, resolve os tickets sozinho.
disable-model-invocation: true
---

# Rodada de alinhamento

Um jeito assíncrono de andar pelo mapa do wayfinder (issue com label `wayfinder:map`, hoje a #1). Em vez de uma sessão de grilling por ticket, o Ângelo responde as perguntas de **todos** os tickets de decisão liberados de uma vez, e você resolve os tickets sem ele.

As respostas do questionário **são** a voz do humano. "ok" significa "aceito a recomendação mostrada". Só decida o que está respondido; o que ficar em branco espera a próxima rodada.

Referências (leia antes de começar):
- `~/.claude/skills/wayfinder/SKILL.md`: mapa, tickets, frontier, fog, out of scope e como registrar uma resolução
- `~/.claude/skills/grilling/SKILL.md`: como montar perguntas (frontier, uma recomendação por pergunta)
- `docs/agents/issue-tracker.md`, seção "Wayfinding operations": os comandos `gh` de cada operação

Comece pelo modo certo: se existe em `docs/rodadas/` um questionário com `status: aguardando` cujas respostas foram preenchidas, vá para **Processar**. Senão, vá para **Perguntar**.

## Perguntar

1. `git pull`. Carregue o mapa e calcule a frontier (tickets abertos, desbloqueados e sem assignee).
2. Separe a frontier por tipo:
   - `research`: dispare um subagente por ticket, em paralelo e com `isolation: "worktree"`, que chama a skill `research`, salva em `docs/research/<nome>.md` numa branch `research/<nome>`, faz push e comenta o resumo no ticket.
   - `grilling`: entram no questionário.
   - `prototype` e `task` com humano: liste no topo do questionário como "precisa de sessão ao vivo" ou como checklist para o Ângelo.
3. Atribua a `@me` cada ticket de grilling que entrar no questionário.
4. Para cada um, leia o corpo, os tickets fechados relacionados, o `CONTEXT.md`, os ADRs e as pesquisas que ele cita. Monte as perguntas com o método do grilling, indo o mais fundo que der sem resposta: cada pergunta tem opções, uma recomendação com o motivo e, quando a escolha abre caminhos, as perguntas de seguimento de cada opção ("Se escolher (b): ..."). Fatos você descobre sozinho; só decisões vão para o questionário.
5. Escreva `docs/rodadas/<AAAA-MM-DD>.md` no formato abaixo, faça commit e push.
6. Avise o Ângelo (use `PushNotification` se estiver disponível) com o link do arquivo no GitHub e pare.

Completo quando: todo ticket de grilling da frontier tem perguntas no arquivo, toda pesquisa da frontier foi disparada, e o arquivo está no GitHub.

### Formato do questionário

```markdown
---
status: aguardando
mapa: 1
---
# Rodada <data>

Responda na linha "Resposta:". `ok` aceita a recomendação. Pode editar direto no GitHub, até pelo celular.

## Precisa de sessão ao vivo
- [Título do ticket](link): por quê

## [Título do ticket](link)

**Q1. <título>**
<contexto curto e opções (a), (b), (c)>
Recomendação: <opção> — <motivo>
Se (b): <pergunta de seguimento>
Resposta:
```

## Processar

1. `git pull` e leia o questionário. Uma resposta em branco deixa o ticket sem decisão nesta rodada.
2. Para cada ticket com respostas, **um de cada vez** (todos mexem no mesmo mapa e no mesmo `CONTEXT.md`), dispare um subagente com contexto limpo. Entregue a ele: o número do ticket, as perguntas com as respostas, e a instrução de ler as três referências do topo e o `CONTEXT.md`. Ele deve:
   - verificar se as respostas resolvem o ticket por completo;
   - se resolvem: atualizar o `CONTEXT.md` (e criar ADR só quando a skill `domain-modeling` mandar), fazer commit e push, comentar a resolução no ticket e fechá-lo;
   - devolver: a frase-resumo da decisão, os tickets novos que a decisão tornou claros (título, tipo, pergunta, bloqueios), o que saiu do escopo, e as perguntas de seguimento se o ticket não fechou.
3. Com o retorno de cada subagente, atualize o mapa você mesmo: linha em "Decisions so far", tickets novos como sub-issues com os bloqueios, fog que virou ticket sai de "Not yet specified", e o que saiu do escopo vai para "Out of scope". Ticket que não fechou continua atribuído e leva as perguntas de seguimento para a próxima rodada.
4. Troque o `status` do questionário para `processado`, faça commit e push.
5. Se o mapa ainda tem tickets abertos, volte para **Perguntar** e já gere a próxima rodada. Se não tem, avise que o mapa terminou e que o próximo passo é `/to-spec`.

Completo quando: todo ticket respondido está fechado ou tem perguntas de seguimento registradas, o mapa reflete todas as decisões, e a próxima rodada foi gerada (ou o mapa terminou).
