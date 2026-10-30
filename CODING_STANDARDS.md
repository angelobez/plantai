# Padrões de código

Lido na revisão (`/code-review`). Lint, format e typecheck já são cobrados pelo pre-commit e pelo CI; aqui ficam as regras que nenhuma ferramenta cobra.

## Idioma dos textos
- Português do Brasil: o que o usuário lê no app (telas, mensagens de erro, e-mails) e o conteúdo de relatórios feitos para o Ângelo ler (ex.: motivos de descarte do catálogo).
- Todo o resto em inglês: identificadores, comentários, logs, saída de scripts e de CLI, `message` dos erros da API.

## API
- TypeScript `strict`; Zod em toda fronteira: requests, `.env`, respostas de serviços externos (Claude, Google, Resend).
- Conjunto fechado de valores (códigos de erro, status, propósitos) vira `enum` ou união literal com uma fonte única, não strings soltas repetidas.
- Fluxos de autenticação não revelam se uma conta existe: a resposta (status e corpo) é a mesma com ou sem conta, inclusive quando algo falha no meio, como o envio de e-mail. Falha de envio vai para o log, não para a resposta.
- Testes de integração com PostGIS real via Testcontainers; rota nova muda `api/openapi.json` (`npm run openapi:update`).
- Log não leva dado pessoal (localização, telefone, e-mail, código de login). Erro vai para o log por `messageOf()` / `stackOf()` (`api/src/errors/message-of.ts`); o lint barra `.message` e `.stack` só dentro de `this.logger.*(...)`, então confira também valores montados antes da chamada.
- O `Env` de um teste vem do `testEnv()` (`api/test/support/env.ts`), com overrides só do que o teste verifica. O único literal completo é o do `env.spec.ts`, que testa o parse. Variável nova muda um lugar só.

## App
- `flutter_lints` com `strict-casts`, `strict-inference` e `strict-raw-types`.
- Testes de unidade nos ViewModels e de widget nas telas principais.
- Códigos de erro vindos da API mapeados por um `enum` (`ApiErrorCode`), não comparando strings.
- Toda tela que depende da rede oferece "Tentar de novo" quando a chamada falha por falta de conexão.
