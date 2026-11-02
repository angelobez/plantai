# Nenhum fornecedor de analytics ou diagnóstico recebe id de usuário

O app nunca manda ao Firebase (Google Analytics e Crashlytics), nem a outro fornecedor de analytics ou diagnóstico, nada que identifique o Usuário: nem o id interno, nem um hash dele, nem e-mail, nome ou telefone. Isso vale para `setUserId`, `setUserIdentifier`, propriedades de usuário, chaves customizadas e parâmetros de evento. O que chega lá são só os ids que o próprio SDK gera por instalação (id da instância do Analytics, UUID de instalação do Crashlytics), que o PlantAí não liga a nenhuma conta. Escolhemos assim para que a exclusão de conta (direito de eliminação, art. 18, VI, da LGPD) termine no nosso banco: sem id de usuário no fornecedor, não há o que pedir para ele apagar.

## Considered Options

- **Mandar um hash do id do Usuário e propagar a exclusão:** daria funis por pessoa e juntaria as falhas de um mesmo Usuário, mas obriga a exclusão de conta a chamar a API de exclusão de cada fornecedor e a provar que chamou.

## Consequences

- Os funis do Google Analytics são por instalação, não por pessoa. Quem troca de celular conta como outra pessoa.
- Para ligar um erro do app ao log da API, use o `request_id` ([Logs da API](https://github.com/angelobez/plantai/issues/77)), nunca o id do Usuário.
- Mandar id de usuário a qualquer fornecedor (inclusive Clarity ou Sentry, se forem adotados) exige rever este ADR, a política de privacidade, o formulário "Segurança dos dados" da Play e a exclusão de conta, que passaria a propagar a exclusão.
- Os ids por instalação ficam no Google pelo prazo de retenção de cada produto (14 meses no Analytics, 90 dias no Crashlytics), e a política de privacidade diz isso.
