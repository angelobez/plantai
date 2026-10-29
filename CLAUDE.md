# PlantAí

App de plantas: identificar pela foto, dicas de cuidado com IA e doação de mudas entre vizinhos. Projeto de portfólio do Ângelo, com o MVP funcionando no celular dele até 15/11/2026.

## Idioma
- Conversa, issues, glossário e ADRs: português do Brasil
- Código, nomes de commits e README: inglês

## Workflow de desenvolvimento
- Monorepo: `api/` (NestJS) e `app/` (Flutter); ver `docs/adr/0005-monorepo-com-api-e-app.md`.
- Fluxo: `/to-spec` → `/to-tickets` → `/implement` por ticket (TDD + `/code-review`), `/clear` entre tickets e `/retro` no fim de cada sessão de código. Planejamento de decisões em aberto: `/rodada` ou `/proximo` (mapa: issue com o label `wayfinder:map`).
- Cada ticket numa branch com PR; a `main` só recebe PR com CI verde (sem exigir aprovação).
- Padrões de código, cobrados na revisão: `CODING_STANDARDS.md`.
- Testar no celular: `npm run dev:phone` na raiz, no terminal do Ângelo (fora do Claude Code). Log da API, com os códigos de e-mail, em `api/logs/dev.log`.
- Pre-commit (Husky + lint-staged): só format e lint nos arquivos alterados. Typecheck e testes rodam no CI, em todo PR, só na parte cuja pasta mudou.
- Deploy: merge na `main` publica a API no Lambda (GitHub Actions com OIDC, sem chave da AWS no GitHub); tag `v*` gera o APK assinado no GitHub Release. Fica para a fase 2; até 15/11 a API roda no notebook e a tag `v0.N` só marca o fim da entrega.
- `git push` comum é liberado; `push --force`, `reset --hard`, `clean` e `branch -D` ficam bloqueados (`git-guardrails`).

## Onde as coisas ficam
- `CONTEXT.md`: glossário do domínio, sem detalhes de implementação
- `docs/adr/`: decisões difíceis de reverter
- `docs/research/`: resultados das pesquisas, um arquivo por ticket

## Decisões já tomadas
- Objetivo: portfólio primeiro, MVP enxuto funcionando no celular do Ângelo até 15/11/2026; abrir para outras pessoas é a fase 2, sem data (ver [Plano de entregas até 15/11](https://github.com/angelobez/plantai/issues/11))
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
