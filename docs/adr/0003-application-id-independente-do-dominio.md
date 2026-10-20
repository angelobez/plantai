# O `applicationId` do app Android é `dev.angelobez.plantai`, sem depender do domínio do PlantAí

O app Android usa o `applicationId` `dev.angelobez.plantai`, no domínio reverso do autor, e não um derivado do domínio do produto, como `br.com.plantai`. O domínio `plantai.com.br`, que parecia livre, está registrado por terceiro (venceu em 18/08/2026 e está suspenso), e o domínio do produto ficou para outro ticket. O `applicationId` não exige ser dono do domínio, mas precisa ser fixado antes do primeiro APK. Por isso ele não deve esperar a escolha do domínio.

## Considered Options

- **`br.com.plantai` (ou o reverso de outro domínio do produto):** é o padrão mais comum, mas amarraria o app a um domínio que ainda não temos e talvez nunca tenhamos.

## Consequences

- O `applicationId` fica registrado no Android Developer Console (verificação de desenvolvedor, conta Limited distribution) e no OAuth client do Google Sign-In, junto com o SHA-1 da chave de assinatura. Trocar depois exige registrar o pacote de novo, criar outro OAuth client e reinstalar o app em cada aparelho. Não troque só porque o domínio do produto mudou.
- Se a chave de assinatura se perder, o pacote não pode ser registrado de novo. A chave fica fora do repositório.
