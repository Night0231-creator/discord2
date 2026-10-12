# Veylor 2.0

Novo aplicativo de comunicação para Windows, Linux, Android e iOS, com interface inspirada na organização dos chats por servidores e objetivo futuro de streaming 4K/60 FPS.

## MVP v0.1
- Flutter: cadastro/login, lista de servidores, canais de texto/voz, criação de servidores, convites e mensagens.
- Node.js 22 + SQLite: API autenticada, autorização por participação no servidor, sessões, convites e mensagens.
- Chat atualizado por polling a cada 3 segundos.
- Emissão autorizada de JWT de acesso a LiveKit em canais de voz (quando configurado).
- **Voz/vídeo e captura de tela AINDA NÃO funcionam. 4K/60 FPS é meta futura.**

## Iniciar a API
Requer Node.js 22.13+:
```bash
cd apps/server
node server.mjs
```
API em http://127.0.0.1:8080. Para teste: `node --test apps/server/test/*.test.mjs` na raiz do repositório.

## Iniciar app Flutter
Instale o Flutter, Android SDK e ferramentas nativas desejadas.
```bash
cd apps/client
flutter create --project-name veylor --platforms=windows,linux,android,ios .
flutter pub get
flutter run -d windows --dart-define=VEYLOR_API_URL=http://127.0.0.1:8080
```
Use `-d linux` no Linux. No Android/iOS configure uma URL de API acessível ao aparelho com HTTPS. O endereço 127.0.0.1 aponta para o próprio aparelho; no emulador Android use o IP de host do emulador e configure políticas de tráfego cleartext somente em builds de desenvolvimento.

iOS requer macOS e Xcode para compilação e assinatura. A pasta de código Flutter está pronta, mas os projetos nativos são gerados por `flutter create` (Flutter SDK não disponível no ambiente de edição).

## Segurança
Repositório privado. Não distribua este MVP publicamente antes de configurar TLS, armazenamento seguro de tokens do cliente, rate limit distribuído, monitoramento, recuperação de conta e testes de autorização. O token do cliente fica em memória, sem persistência de sessão. Variáveis LIVEKIT_API_KEY, LIVEKIT_API_SECRET e LIVEKIT_URL ficam apenas no backend.
