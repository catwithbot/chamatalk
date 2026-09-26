<p align="center">
  <img src="./public/brand-assets/chamatalk_symbol1.png" width="96" alt="Símbolo do Chamatalk" />
</p>

<h1 align="center">Chamatalk</h1>

<p align="center">
  Plataforma de atendimento ao cliente e comunicação omnichannel, com código aberto e implantação própria.
</p>

<p align="center">
  <a href="https://github.com/catwithbot/chamatalk">Repositório</a> ·
  <a href="https://github.com/catwithbot/chamatalk/issues">Issues</a>
</p>

---

## Sobre o projeto

O Chamatalk centraliza as conversas da sua empresa em um único espaço de atendimento. A plataforma foi desenvolvida para equipes que precisam organizar mensagens, acompanhar clientes, automatizar rotinas e manter o controle da própria infraestrutura e dos dados.

O projeto pode ser executado em servidor próprio usando Docker, PostgreSQL e Redis. A arquitetura foi preparada para atender operações pequenas e crescer conforme a demanda.

## Principais recursos

### Atendimento omnichannel

- Caixa de entrada compartilhada para toda a equipe.
- Chat em tempo real para sites e aplicações.
- Atendimento por e-mail.
- Integrações com canais sociais e mensageria.
- Histórico completo das conversas e interações.

### Produtividade da equipe

- Distribuição automática de conversas entre atendentes.
- Notas internas e menções para colaboração.
- Respostas prontas para perguntas frequentes.
- Etiquetas, filtros e visualizações personalizadas.
- Atalhos de teclado e barra de comandos.
- Horários de atendimento e respostas automáticas.
- Equipes e regras de automação.

### Gestão de clientes

- Cadastro de contatos com histórico de interações.
- Segmentação de contatos.
- Campos personalizados.
- Formulários antes do início do atendimento.
- Campanhas para comunicação proativa.

### Base de conhecimento

- Criação de artigos, perguntas frequentes e guias.
- Portal de ajuda para autoatendimento dos clientes.
- Redução de dúvidas repetitivas para a equipe de suporte.

### Relatórios e acompanhamento

- Monitoramento das conversas em andamento.
- Relatórios por conversa, atendente, caixa de entrada, etiqueta e equipe.
- Indicadores de satisfação do cliente.
- Exportação de dados para análises externas.

### Integrações

- Integração com Slack.
- Integração com serviços de chatbot.
- Aplicações incorporadas no painel de atendimento.
- Integração com plataformas de comércio eletrônico.
- Tradução de mensagens em tempo real.
- Integração com ferramentas de gestão de tarefas.

## Tecnologias

- Ruby 3.4.4
- Ruby on Rails
- Vue.js
- Vite
- PostgreSQL 16 com suporte a vetores
- Redis
- Sidekiq
- Docker e Docker Compose

## Requisitos

Para executar o Chamatalk localmente, instale:

- Docker Engine
- Docker Compose
- Git

Para desenvolvimento sem Docker, também serão necessários Ruby, Node.js, pnpm, PostgreSQL e Redis.

## Execução com Docker

### Produção

1. Clone o repositório:

```bash
git clone git@github-chamatalk:catwithbot/chamatalk.git
cd chamatalk
```

2. Crie o arquivo de ambiente:

```bash
cp .env.example .env
```

3. Edite o `.env` e defina, no mínimo, uma chave segura para `SECRET_KEY_BASE`, a URL pública em `FRONTEND_URL` e a senha do PostgreSQL.

4. Inicie os serviços:

```bash
docker compose -f docker-compose.production.yaml up -d
```

A aplicação ficará disponível na porta `3000`. Para publicar o serviço na internet, use um proxy reverso com HTTPS, como Nginx, Caddy ou Traefik.

### Desenvolvimento

```bash
docker compose up -d
```

O ambiente de desenvolvimento utiliza:

- Aplicação web em `http://localhost:3000`
- Servidor Vite em `http://localhost:3036`
- Painel do MailHog em `http://localhost:8025`

## Variáveis de ambiente essenciais

| Variável | Finalidade |
| --- | --- |
| `SECRET_KEY_BASE` | Assinatura e segurança das sessões da aplicação. |
| `FRONTEND_URL` | URL pública usada pela aplicação e pelos e-mails. |
| `POSTGRES_HOST` | Endereço do banco PostgreSQL. |
| `POSTGRES_USERNAME` | Usuário do banco PostgreSQL. |
| `POSTGRES_PASSWORD` | Senha do banco PostgreSQL. |
| `REDIS_URL` | URL de conexão com o Redis. |
| `REDIS_PASSWORD` | Senha do Redis quando habilitada. |
| `ACTIVE_STORAGE_SERVICE` | Serviço usado para armazenar arquivos. |
| `MAILER_SENDER_EMAIL` | Remetente dos e-mails enviados pela aplicação. |

Consulte o arquivo `.env.example` para ver todas as opções disponíveis.

## Comandos úteis

Instalar dependências:

```bash
bundle install
pnpm install
```

Preparar o banco de dados:

```bash
bundle exec rails db:prepare
```

Iniciar o ambiente de desenvolvimento:

```bash
pnpm dev
```

Executar testes Ruby:

```bash
bundle exec rspec
```

Executar testes JavaScript:

```bash
pnpm test
```

Verificar o estilo do código:

```bash
bundle exec rubocop
pnpm eslint
```

## Estrutura dos serviços

O ambiente de produção é composto por:

- `rails`: aplicação web e API.
- `sidekiq`: processamento de tarefas em segundo plano.
- `postgres`: banco de dados principal.
- `redis`: filas, cache e comunicação entre processos.

Os dados persistentes são armazenados nos volumes do Docker definidos no arquivo de produção.

## Segurança

- Use valores fortes e exclusivos para as credenciais de produção.
- Habilite HTTPS antes de disponibilizar a aplicação publicamente.
- Restrinja as portas do PostgreSQL e Redis à rede interna do servidor.
- Faça backups regulares do banco de dados e dos arquivos enviados.
- Não publique arquivos `.env`, chaves privadas ou tokens no repositório.

Para relatar uma vulnerabilidade, consulte o arquivo [SECURITY.md](./SECURITY.md).

## Contribuindo

1. Crie uma branch para sua alteração.
2. Faça mudanças pequenas e objetivas.
3. Execute os testes e verificações de estilo aplicáveis.
4. Abra um pull request descrevendo o problema e a solução.

## Licença

O Chamatalk é distribuído sob a licença MIT. Consulte o arquivo [LICENSE](./LICENSE) para os termos completos.

---

Chamatalk — atendimento organizado, dados sob seu controle.
