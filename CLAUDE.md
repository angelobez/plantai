# PlantAí

App de plantas: identificar pela foto, dicas de cuidado com IA e doação de mudas entre vizinhos. Projeto de portfólio do Ângelo, com MVP no ar até 15/11/2026.

## Idioma
- Conversa, issues, glossário e ADRs: português do Brasil
- Código, nomes de commits e README: inglês

## Como o projeto é planejado
- O caminho até o MVP é um mapa do wayfinder: a issue com o label `wayfinder:map`, com os tickets como sub-issues e o vínculo "blocked by" entre eles.
- Para continuar o planejamento: `/rodada` (questionário assíncrono com vários tickets de uma vez) ou `/proximo` (um ticket numa conversa ao vivo). Entre um ticket e outro, `/clear`.
- Planejar, não fazer: até o mapa terminar, a saída de cada ticket é uma decisão, não código.

## Workflow de desenvolvimento
Vale depois que o mapa terminar.
- Monorepo: `api/` (NestJS) e `app/` (Flutter); ver `docs/adr/0005-monorepo-com-api-e-app.md`.
- Fluxo: `/to-spec` → `/to-tickets` → `/implement` por ticket (TDD + `/code-review`), `/clear` entre tickets e `/retro` no fim de cada sessão de código.
- Cada ticket numa branch com PR; a `main` só recebe PR com CI verde (sem exigir aprovação).
- API: TypeScript `strict`, Zod nas fronteiras (requests, `.env`, resposta do Claude), ESLint + Prettier, Jest, integração com PostGIS real via Testcontainers.
- App: `flutter_lints` com `strict-casts`, `strict-inference` e `strict-raw-types`, `dart format`, testes de unidade nos ViewModels e de widget nas telas principais.
- Pre-commit (Husky + lint-staged): só format e lint nos arquivos alterados. Typecheck e testes rodam no CI, em todo PR, só na parte cuja pasta mudou.
- Deploy: merge na `main` publica a API no Lambda (GitHub Actions com OIDC, sem chave da AWS no GitHub); tag `v*` gera o APK assinado no GitHub Release.
- `git push` comum é liberado; `push --force`, `reset --hard`, `clean` e `branch -D` ficam bloqueados (`git-guardrails`).

## Onde as coisas ficam
- `CONTEXT.md`: glossário do domínio, sem detalhes de implementação
- `docs/adr/`: decisões difíceis de reverter
- `docs/research/`: resultados das pesquisas, um arquivo por ticket

## Decisões já tomadas
- Objetivo: portfólio primeiro, MVP enxuto até 15/11/2026
- App em Flutter; API própria em NestJS + PostgreSQL/PostGIS
- MVP: login, identificação por foto, dicas de cuidado geradas pelo Claude, Meu jardim simples, anúncio de doação de muda, lista de mudas por perto, botão "tenho interesse" que abre o WhatsApp
- Repositório público; segredos só em `.env`

## Agent skills

### Issue tracker

Issues no GitHub (`angelobez/plantai`), via `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Os cinco labels padrão: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` e `docs/adr/` na raiz. See `docs/agents/domain.md`.
