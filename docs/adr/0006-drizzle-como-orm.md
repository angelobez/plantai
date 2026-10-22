# Drizzle como ORM e ferramenta de migrations da API

A API usa o Drizzle (schema em TypeScript e migrations com o drizzle-kit) para falar com o Postgres. O Prisma é a escolha mais comum em projetos NestJS, mas ainda não tem tipo nativo para PostGIS: as colunas de localização viram `Unsupported("geography")` e toda consulta por distância precisaria de SQL cru, justamente o coração de "Mudas por perto". O Drizzle tem o tipo `geometry` do PostGIS, deixa as consultas espaciais tipadas, gera migrations em SQL legível para revisar no PR e é leve no cold start do Lambda ([ADR 0004](0004-api-no-aws-lambda-com-function-url.md)).

## Considered Options

- **Prisma:** mais conhecido e com boa documentação, mas o PostGIS fica fora do schema e fora da tipagem.
- **TypeORM:** tem suporte a PostGIS, mas está pouco cuidado e tem tipagem fraca para o TypeScript `strict` do projeto.

## Consequences

- O schema do banco é código TypeScript em `api/`, e as migrations geradas são versionadas e revisadas como qualquer outro arquivo.
- Trocar de ORM depois significa reescrever o schema, os repositórios e as consultas espaciais.
