# Veylor V0.2

Aplicativo de comunicação em desenvolvimento para Windows, Linux, Android e iOS.

## Incluído na V0.2
- DMs por nome de usuário com consultas autorizadas no backend.
- Notificações em tempo real autenticadas por WebSocket. REST permanece a fonte de verdade e há consulta de segurança a cada 30 s.
- Criação de canais de texto e voz por proprietário/moderador.
- Gestão básica de membros: proprietário concede/remove moderador; moderadores podem remover membros comuns.
- Sessão salva em armazenamento seguro nativo pelo pacote flutter_secure_storage.
- Migração de schema SQLite não destrutiva a partir da V0.1.

## Não implementado
- Streaming, voz e vídeo ainda não operacionais; LiveKit aguarda o cliente da V0.3.
- WebSocket distribui sinais de atualização, **não** payload de mensagens; dados só pela API autorizada.
- Não há presença persistente, typing indicators, moderação avançada, bloqueios de usuário ou uploads.
- Testes de carga, TLS, hardening, publicação e builds assinados ainda não foram concluídos.

## API
Node 22.13+:
```bash
cd apps/server
npm install
npm start
```

## Cliente
Flutter SDK mais ferramentas de cada destino:
```bash
cd apps/client
flutter create --project-name veylor --platforms=windows,linux,android,ios .
flutter pub get
flutter run -d windows --dart-define=VEYLOR_API_URL=http://127.0.0.1:8080
```
No Linux use `-d linux`. No Android/iOS configure endereço HTTPS acessível pelo dispositivo; o host local do seu PC não corresponde a 127.0.0.1 do celular. Windows requer Visual Studio Build Tools; Linux com flutter_secure_storage pode exigir pacote libsecret-1-dev e dependências de desktop; iOS requer Mac/Xcode, assinatura e permissões nativas.

**Segurança:** backend local para desenvolvimento. Sessões são armazenadas em Secure Storage no cliente, não em texto simples. Para disponibilização pública ainda faltam infraestrutura HTTPS/WSS, rate limit distribuído, controle de abuso e monitoramento. Mantenha LIVEKIT_API_SECRET somente no servidor.

Veja [arquitetura](docs/ARCHITECTURE.md).
