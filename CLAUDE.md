# PlantAí

App de plantas: identificar pela foto, dicas de cuidado com IA e doação de mudas entre vizinhos. Projeto de portfólio do Ângelo, com MVP no ar até 15/11/2026.

## Idioma
- Conversa, issues, glossário e ADRs: português do Brasil
- Código, nomes de commits e README: inglês

## Como o projeto é planejado
- O caminho até o MVP é um mapa do wayfinder: a issue com o label `wayfinder:map`, com os tickets como sub-issues e o vínculo "blocked by" entre eles.
- Para continuar o planejamento: `/wayfinder` passando o mapa. Um ticket por sessão.
- Planejar, não fazer: até o mapa terminar, a saída de cada ticket é uma decisão, não código.

## Onde as coisas ficam
- `CONTEXT.md`: glossário do domínio, sem detalhes de implementação
- `docs/adr/`: decisões difíceis de reverter
- `docs/research/`: resultados das pesquisas, um arquivo por ticket

## Decisões já tomadas
- Objetivo: portfólio primeiro, MVP enxuto até 15/11/2026
- App em Flutter; API própria em NestJS + PostgreSQL/PostGIS
- MVP: login, identificação por foto, dicas de cuidado geradas pelo Claude, anúncio de doação de muda, lista de mudas por perto, botão "tenho interesse" que abre o WhatsApp
- Repositório público; segredos só em `.env`
