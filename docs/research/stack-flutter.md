# Pesquisa: stack Flutter para o MVP

Ticket: [#6](https://github.com/angelobez/plantai/issues/6). Pesquisado em 20/10/2026.

> **Decisão (20/10/2026, ver a [resolução no ticket](https://github.com/angelobez/plantai/issues/6)).** Fica a recomendação da pesquisa: MVVM da doc oficial (View → ViewModel → Repository abstrato → Service) com `provider` + `ChangeNotifier` e `go_router`. Riverpod pode entrar numa refatoração depois do MVP. "Mudas por perto" é **só lista**, ordenada pela distância calculada na API, sem SDK de mapa. Bibliotecas: `image_picker`, `dio`, `geolocator` (aproximada), `flutter_secure_storage`, `url_launcher` com `https://wa.me/` e `google_sign_in`. O login já foi decidido em [Método de login](https://github.com/angelobez/plantai/issues/3) (ADR 0001). **Distribuição:** vídeo/GIF da demo no README para recrutadores, e uma conta Limited distribution gratuita (até 20 aparelhos) no Android Developer Console para os testadores reais. O APK sai com `flutter build apk --split-per-abi`, assinado, num GitHub Release. Conta Full (US$ 25) só se alguém pedir. Antes de depender disso, um APK de teste vai ser instalado num celular real. **`applicationId`: `dev.angelobez.plantai`**, que não depende do domínio do app (ADR 0003).

**Pergunta:** quais bibliotecas e padrões usar no app Flutter do MVP, para alguém vindo de TypeScript/NestJS e novo em Dart (estado, câmera/galeria, upload, lista ou mapa por distância, HTTP, autenticação, WhatsApp), e como gerar e distribuir o APK sem Play Store.

**Critérios:** simples, popular, mantido, publicado por quem é dono do assunto (de preferência `flutter.dev` ou `dart.dev`) e fácil para o Claude Code gerar e revisar. Android primeiro.

Os números do pub.dev (versão, data, likes, downloads em 30 dias, publisher) vieram da API pública `https://pub.dev/api/packages/<nome>` e `/score` em 2026-10-20.

---

## 1. Base: Flutter e Dart

- Flutter estável atual: **3.47.7** (2026-10-08), com **Dart 3.13.5** ([releases_linux.json](https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json)). Vários pacotes abaixo já exigem Flutter >= 3.44 ou 3.47, então instale o estável atual e não uma versão antiga.
- Instalação no Linux pelo caminho recomendado: pacotes `curl git unzip xz-utils zip libglu1-mesa`, VS Code com a extensão Flutter, e o comando *Flutter: New Project* → *Download SDK* ([Quick start](https://docs.flutter.dev/install/quick)). Para Android, siga também o [Target Android setup](https://docs.flutter.dev/platform-integration/android/setup) (Android Studio/SDK e `flutter doctor --android-licenses`). Depois, rode `flutter doctor`.
- Para quem vem de TS: o antigo guia "JS to Dart" do dart.dev hoje redireciona para [dart.dev/learn](https://dart.dev/learn). Os melhores pontos de partida são o [Dart tutorial](https://dart.dev/learn/tutorial) e o [DartPad](https://dartpad.dev) para testar rápido. Os pontos que mais confundem no começo são *null safety* sound, `Future`/`async` no lugar de `Promise`, e classes com construtores nomeados (`User.fromJson`).

## 2. Arquitetura e gerenciamento de estado

A doc oficial [Architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations) é a referência mais segura. Ela diz:

- **Strongly recommend:** separar camada de UI e de dados, usar o padrão *repository* (com classe abstrata) e *services*, fluxo de dados unidirecional, modelos imutáveis, injeção de dependência e nada de lógica nos widgets.
- **DI:** "We recommend you use the provider package to handle dependency injection."
- **Estado (Conditional):** `ChangeNotifier`/`Listenable` (do próprio SDK) nos ViewModels. A doc também diz que a escolha "ultimately comes down to personal preference".
- **Navegação (Recommend):** `go_router`, "the preferred way to write 90% of Flutter applications".
- O app de exemplo oficial que aplica tudo isso é o *Compass app* (flutter/samples).

Esse desenho (View → ViewModel → Repository → Service) é parecido com Controller → Service → Repository do NestJS, e o `provider` faz o papel do container de DI.

| Pacote | Versão | Publicado | Publisher | Likes | Downloads/30d |
|---|---|---|---|---|---|
| `provider` | 6.1.5+1 | 2025-08-19 | dash-overflow.net | 11.009 | 1,1 mi |
| `flutter_riverpod` | 3.4.3 | 2026-09-03 | dash-overflow.net | 2.915 | 3,8 mi |
| `flutter_bloc` | 9.1.1 | 2025-05-02 | bloclibrary.dev | 8.085 | 2,2 mi |
| `go_router` | 18.1.0 | 2026-10-14 | flutter.dev | 5.793 | 4,8 mi |

**Opções:**

- **`provider` + `ChangeNotifier` (recomendado).** É o que a doc oficial usa, tem a menor API para aprender e não usa geração de código. O pacote está maduro e mudou pouco (última versão em 2025-08). Isso indica estabilidade, não abandono.
- **Riverpod 3.** É o mais baixado hoje e foi feito pelo mesmo autor do `provider`. Tem mais recursos (cache e estado assíncrono com `AsyncValue`), mas também mais conceitos. A geração de código é opcional ([getting started](https://riverpod.dev/docs/introduction/getting_started)). Vale a pena se o app crescer, mas para um MVP de poucas semanas é mais coisa para aprender.
- **Bloc.** É sólido, mas exige muito código repetitivo (eventos e estados). Não compensa num MVP solo.

## 3. Foto: câmera e galeria

- **`image_picker` 1.2.4** (flutter.dev, 2026-10-06). Faz câmera e galeria numa chamada só: `pickImage(source: ImageSource.camera | ImageSource.gallery, maxWidth:, maxHeight:, imageQuality:)` ([API](https://pub.dev/documentation/image_picker/latest/image_picker/ImagePicker/pickImage.html)).
  - No Android, "No configuration required". No Android 13+, ele usa o *Android Photo Picker* ([README](https://pub.dev/packages/image_picker)).
  - Cuidado: o Android pode matar a Activity enquanto a câmera está aberta. Chame `ImagePicker.retrieveLostData()` ao iniciar o app para recuperar a foto.
  - Use `maxWidth: 1600` (por exemplo) e `imageQuality: ~80` para reduzir a foto **antes** do upload. Isso economiza dados móveis e o custo da API de identificação. Em geral dispensa o `flutter_image_compress`.
- O pacote `camera` (0.12.1) só faz sentido para um preview de câmera customizado dentro do app. O MVP não precisa disso.

## 4. Cliente HTTP e upload

| Pacote | Versão | Publicado | Publisher | Downloads/30d |
|---|---|---|---|---|
| `dio` | 5.11.1 | 2026-09-04 | flutter.cn | 5,0 mi |
| `http` | 1.6.0 | 2025-11-10 | dart.dev | 13,4 mi |

- **Recomendo o `dio`.** Ele parece com o axios: instância única com `baseUrl` e timeouts, *interceptors* para incluir `Authorization: Bearer` e tratar 401, e upload multipart com `FormData.fromMap({'file': await MultipartFile.fromFile(path)})` ([README](https://pub.dev/packages/dio)).
- O `http` (dart.dev) é mais simples e oficial, mas não tem interceptors. Você acabaria escrevendo um wrapper.
- O upload da foto pode ir direto para a API NestJS como `multipart/form-data` (com `FileInterceptor` no lado do Nest). Onde a imagem fica guardada depende do ticket de hospedagem (#7).
- JSON: no começo, `fromJson`/`toJson` escritos à mão bastam. A doc oficial cita `freezed`/`json_serializable` para modelos imutáveis, mas avisa que eles deixam o build mais lento. Fica opcional.

## 5. Localização e "mudas por perto"

- **`geolocator` 14.1.2** (Baseflow, 2026-10-19). Fluxo: `isLocationServiceEnabled()` → `checkPermission()`/`requestPermission()` → `getCurrentPosition()`. No Android 12+, peça `ACCESS_COARSE_LOCATION` e `ACCESS_FINE_LOCATION` juntas, porque o usuário pode conceder só a aproximada ([README](https://pub.dev/packages/geolocator)). Para este app, a localização **aproximada já basta**, e isso também ajuda na privacidade (#4).
- **Lista por distância em vez de mapa (recomendado).** A API (PostGIS) devolve as mudas ordenadas por distância, e o app mostra "a 1,2 km". Não precisa de SDK de mapa, chave de API nem tiles. Se precisar calcular no cliente, use `Geolocator.distanceBetween(...)`.
- **Se quiser mapa depois:**
  - `flutter_map` 8.3.2 (fleaflet.dev) não pede chave. Com os tiles públicos do OSM, a [política de uso](https://operations.osmfoundation.org/policies/tiles/) exige atribuição visível e um User-Agent próprio (`userAgentPackageName`, conforme a [doc do flutter_map](https://docs.fleaflet.dev/layers/tile-layer)). O serviço é "best-effort", sem garantia.
  - `google_maps_flutter` 2.19.0 (flutter.dev) exige chave do Google Cloud com o *Maps SDK for Android* ativado ([README](https://pub.dev/packages/google_maps_flutter)). É mais configuração e tem risco de cobrança.
- Para mostrar o bairro a partir das coordenadas, existe o `geocoding` 5.0.0. No MVP dá para pedir o bairro em texto no anúncio.

## 6. Autenticação

O método de login é decidido no ticket #3. Do lado do app, as peças são estas:

- **Token da própria API (JWT do NestJS):** guarde o token com **`flutter_secure_storage` 11.2.0** (5,3 mi downloads/30d) e injete-o num interceptor do `dio`. Não use `shared_preferences` para token, porque ele não é criptografado. Ele serve para preferências comuns.
- **Login com Google:** `google_sign_in` 7.2.0 (flutter.dev). A API v7 mudou: `GoogleSignIn.instance.initialize(serverClientId: ...)` e depois `authenticate()` ([README](https://pub.dev/packages/google_sign_in)). Precisa de um OAuth client no Google Cloud com o SHA-1 da chave de assinatura (setup em [google_sign_in_android](https://pub.dev/packages/google_sign_in_android#integration)). O token vai para a API, que o valida e emite o próprio JWT.
- **Firebase Auth** (`firebase_auth` 7.0.0) ou **Supabase** (`supabase_flutter` 2.18.3) resolvem login completo, mas trazem um segundo backend junto com o NestJS. Só valem se o #3 decidir delegar o login.
- `go_router` tem `redirect` para mandar o usuário não logado à tela de login.

## 7. "Tenho interesse" → WhatsApp

- **`url_launcher` 6.3.3** (flutter.dev).
- Link oficial do WhatsApp: `https://wa.me/<número>?text=<mensagem URL-encoded>`. O número vai em formato internacional completo, sem `+`, sem zeros à esquerda, sem parênteses e sem traços ([WhatsApp Help Center: click to chat](https://faq.whatsapp.com/general/chats/how-to-use-click-to-chat/)). Exemplo: `5511987654321`.
- Em Dart: `launchUrl(Uri.https('wa.me', '/$numero', {'text': 'Oi! Tenho interesse na muda de ...'}), mode: LaunchMode.externalApplication)`. O `Uri.https` já faz o encoding.
- O README recomenda chamar `launchUrl` direto e tratar a falha, em vez de depender de `canLaunchUrl`. No Android 11+, `canLaunchUrl` retorna `false` sem um bloco `<queries>` no manifest ([README](https://pub.dev/packages/url_launcher)).
- Como é `https`, o link funciona mesmo sem WhatsApp instalado: abre no navegador.

## 8. Gerar e distribuir o APK sem Play Store

**Build** ([Build and release an Android app](https://docs.flutter.dev/deployment/android)):

1. Crie a chave de upload: `keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -storetype JKS -keysize 2048 -validity 10000 -alias upload`.
2. Crie `android/key.properties` (senhas, alias, caminho) e o `signingConfigs { create("release") ... }` em `android/app/build.gradle.kts`. **Nunca versione o `.jks` nem o `key.properties`.** O repositório é público, então os dois entram no `.gitignore`.
3. Gere com `flutter build apk --split-per-abi`. A saída fica em `build/app/outputs/flutter-apk/`. Na prática, distribua o `app-arm64-v8a-release.apk`. A doc diz que, fora da Play Store, "an APK might be your only option".
4. Hospede o APK num **GitHub Release** do repositório e coloque o link no README. Dá para automatizar isso depois com GitHub Actions.

**Atenção: Android developer verification no Brasil.** A [página oficial](https://developer.android.com/developer-verification) diz que, desde **30/09/2026**, há proteções para usuários no **Brasil**, Indonésia, Singapura e Tailândia em aparelhos certificados com Android 7+. A [página de limited distribution](https://developer.android.com/developer-verification/guides/limited-distribution) diz: "Any package names not registered by this date will no longer be installable on certified Android devices in those regions." Na prática, um APK de pacote não registrado **não instala no celular de um recrutador brasileiro** pelo fluxo normal. Os caminhos possíveis, segundo o [FAQ](https://developer.android.com/developer-verification/guides/faq):

| Caminho | Custo | Alcance | Observação |
|---|---|---|---|
| `adb install` / `flutter install` | grátis | só os seus aparelhos | "Apps installed using ADB won't require verification." Serve para desenvolver e para a demo ao vivo. |
| Conta **Limited distribution** no Android Developer Console | grátis, sem documento | até **20 aparelhos** autorizados | Cada aparelho entra por QR code ou link, com consentimento no dispositivo. Exige conta Google com 2FA e perfil de pagamentos. Pensada para estudantes e hobbyistas. |
| Conta **Full distribution** no Android Developer Console | US$ 25 + documento de identidade | qualquer pessoa | O APK no GitHub Release instala normalmente. |
| "Advanced flow" do usuário | grátis | qualquer pessoa paciente | O usuário liga o modo desenvolvedor, faz um setup único e espera 1 dia. Não dá para pedir isso a um recrutador. |

Em qualquer caso, **guarde bem a chave de assinatura**: "If you lose your signing key you won't be able to register your packages." Defina o `applicationId` definitivo (ex.: `dev.angelobez.plantai`) logo no começo, porque é ele que fica registrado.

Não confirmei na prática como cada caminho se comporta. A página principal fala em "participating stores", e a de limited distribution fala em qualquer pacote não registrado. Vale testar instalando um APK de teste num celular real antes de depender de um caminho.

---

## Recomendação

| Necessidade | Escolha |
|---|---|
| Arquitetura | MVVM da doc oficial: View → ViewModel (`ChangeNotifier`) → Repository (abstrato) → Service |
| DI e estado | `provider` + `ChangeNotifier` |
| Navegação | `go_router` (com `redirect` para login) |
| Foto | `image_picker` com `maxWidth`/`imageQuality` para reduzir antes do envio |
| HTTP e upload | `dio` (instância única, interceptor de auth, `FormData` multipart) |
| Localização | `geolocator`, localização aproximada |
| "Por perto" | **lista** ordenada por distância calculada na API (PostGIS), sem mapa no MVP |
| Token | `flutter_secure_storage` |
| WhatsApp | `url_launcher` + `https://wa.me/<número>?text=...` |
| APK | `flutter build apk --split-per-abi`, assinado, publicado em GitHub Release, mais um vídeo de demo no README |

São 7 dependências diretas, todas populares e atualizadas em 2025 ou 2026, e 4 delas publicadas pelo próprio `flutter.dev`. O Claude Code conhece bem todas.

## Perguntas para você decidir

1. **Estado:** fico com `provider` + `ChangeNotifier` (o oficial, menos coisa para aprender) ou quer aprender Riverpod, que é mais "de mercado" e conta pontos no portfólio?
2. **Mapa:** o MVP fica só com lista por distância, ou o mapa é importante para a demo? Se for, `flutter_map` + OSM ou Google Maps?
3. **Distribuição no Brasil:** paga US$ 25 + identidade para ter uma conta Full no Android Developer Console (APK instalável por qualquer pessoa), usa a conta Limited gratuita (20 aparelhos), ou a demo para recrutadores fica em **vídeo/GIF no README** + `adb` ao vivo?
4. **Login (#3):** JWT próprio do NestJS, Google Sign-In validado pela API, ou um provedor externo (Firebase/Supabase)? Isso decide o pacote de auth.
5. **`applicationId`:** qual domínio reverso usar (ex.: `dev.angelobez.plantai`)? Ele é difícil de mudar depois de registrado.
