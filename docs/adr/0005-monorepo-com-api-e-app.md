# API e app no mesmo repositório

A API NestJS fica em `api/` e o app Flutter em `app/`, no mesmo repositório. Para um projeto de uma pessoa só, um repositório mantém juntos o mapa, as issues, o glossário, os ADRs e o código das duas partes, e uma mudança no contrato da API entra num único PR junto com o app que a consome. O custo de misturar duas linguagens é contido no CI: cada parte só roda quando a pasta dela muda (filtro de `paths` no GitHub Actions).

## Considered Options

- **Dois repositórios (`plantai-api` e `plantai-app`):** CI e ferramentas de cada linguagem ficam isolados, mas as issues e a documentação se dividem, e uma mudança de contrato vira dois PRs coordenados.

## Consequences

- As ferramentas de cada linguagem ficam dentro da pasta dela (`package.json` em `api/`, `pubspec.yaml` em `app/`); a raiz guarda só o que é do projeto inteiro (docs, CI, hooks).
- Um workflow novo no CI precisa declarar os `paths` da parte que ele cobre, ou volta a rodar tudo em todo PR.
