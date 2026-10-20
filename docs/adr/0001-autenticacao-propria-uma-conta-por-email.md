# Autenticação própria na API, com Google e e-mail/senha e uma conta por e-mail

A API NestJS cuida sozinha da autenticação, sem Firebase Auth nem outro provedor de identidade. Ela valida o ID token do Google ou a senha (argon2id) e emite um JWT próprio. O access token dura 15 minutos e o refresh token é rotativo, guardado no banco e revogável. Escolhemos assim para manter o Usuário no nosso Postgres, não colocar um terceiro serviço na stack só por causa do login e mostrar autenticação de ponta a ponta no portfólio.

Cada e-mail corresponde a um único Usuário, que pode entrar pelos dois métodos. Quem entra pelo Google com o e-mail de uma conta que já existe cai nessa mesma conta. Isso só acontece se o Google confirmar o e-mail: `email_verified` verdadeiro, e o e-mail é `@gmail.com` ou o token traz o claim `hd`. Se a conta existente ainda não confirmou o e-mail pelo código, o Google assume a conta e a senha pendente é apagada. Isso impede que alguém cadastre o e-mail da vítima antes dela e continue com acesso pela senha.

## Considered Options

- **Firebase Auth:** menos código, mas acrescenta um serviço e deixa a identidade do Usuário fora do nosso banco.
- **Só Google:** era o caminho mais curto, mas foi descartado porque a pessoa quer poder entrar também com e-mail e senha.
- **Login por telefone com código (SMS/WhatsApp):** confirmaria o número do WhatsApp, mas cada mensagem é cobrada.

## Consequences

- Cadastro e recuperação de senha mandam um código de 6 dígitos por e-mail. Para isso é preciso um provedor de e-mail transacional (Resend) e um domínio próprio verificado.
- Trocar o e-mail da conta não entra no MVP, porque mexe na regra de juntar contas.
- No Android, o Google Sign-In depende do `applicationId` e do SHA-1 da chave que assina o APK. Os dois precisam estar fixados antes do primeiro login pelo Google.
