# Bootstrap Open Tibia Server Specification

## Problem Statement

O projeto ainda não possui repositórios próprios, ambiente reproduzível ou uma instância funcional do The Forgotten Server. Precisamos estabelecer uma base rastreável que compile o TFS 1.6 em Docker no macOS, compile e opere nativamente no Ubuntu da VPS, inicialize o banco e carregue um datapack compatível.

## Goals

- [x] Criar a estrutura GitHub do projeto preservando os forks dos dois upstreams.
- [x] Compilar o TFS `v1.6` em Docker no desenvolvimento e nativamente na VPS para protocolo 13.10.
- [x] Inicializar MariaDB e o schema do TFS de forma persistente em ambos os ambientes.
- [x] Subir o servidor com o datapack oficial e comprovar que está pronto para receber conexões.
- [x] Preparar o fork do OTClient compatível para a próxima etapa de conexão.

## Out of Scope

| Feature | Reason |
| --- | --- |
| Compilar e distribuir o OTClient desktop | Será uma feature própria após o servidor estar estável |
| Datapack global/real map definitivo | A escolha exige auditoria de compatibilidade, origem e licença |
| Website, criação pública de contas e loja | Não são necessários para validar o servidor |
| Domínio, TLS, CDN e updater do cliente | Dependem do produto e da distribuição futura |
| Customizações de gameplay, mapa ou UI | Primeiro precisamos de uma baseline executável |
| Backup automatizado e disaster recovery | Serão definidos antes de dados reais entrarem em produção |

---

## Assumptions & Open Questions

| Assumption / decision | Chosen default | Rationale | Confirmed? |
| --- | --- | --- | --- |
| Protocolo e versão | TFS `v1.6`, protocolo 13.10 | Release estável e compatível com o OTClient escolhido | yes |
| Ambiente local | Docker Desktop no macOS | O usuário definiu Docker como regra permanente | yes |
| Ambiente remoto | VPS `1826871`, Ubuntu 24.04 LTS, 1 vCPU, 4 GB RAM e 50 GB | Instância ativa encontrada pelo MCP da Hostinger | yes |
| Banco | MariaDB em container no desenvolvimento e nativo na VPS | Isolamento local e operação nativa remota | yes |
| Primeiro datapack | Conteúdo oficial incluído no TFS | Reduz variáveis durante o bootstrap | yes |
| Organização GitHub | `RonaldoAntonucci/otserv` para orquestração + forks `forgottenserver` e `otclient` | Forks verdadeiros preservam nomes e vínculo com upstream; infraestrutura fica no repo do projeto | yes |
| Visibilidade dos repositórios | Público, acompanhando os upstreams open source | Facilita atribuição e colaboração; segredos permanecem fora do Git | yes |

**Open questions:** none — all surfaced decisions are resolved or explicitly bounded by the deployment-access limitation.

---

## User Stories

### P1: Estrutura de código-fonte do projeto ⭐ MVP

**User Story**: Como mantenedor, quero os upstreams preservados em forks e uma camada própria de orquestração para que possamos atualizar código e infraestrutura sem perder rastreabilidade.

**Why P1**: Todo build e deploy posterior depende de fontes controladas pelo projeto.

**Acceptance Criteria**:

1. WHEN a estrutura GitHub for criada THEN o sistema SHALL possuir forks autenticados de `otland/forgottenserver` e `opentibiabr/otclient` na conta `RonaldoAntonucci`.
2. WHEN o repositório `otserv` for criado THEN ele SHALL conter somente configuração, automação, documentação e referências fixadas aos forks, sem segredos.
3. WHEN as origens Git forem inspecionadas THEN cada fork SHALL identificar seu upstream oficial e a revisão baseline SHALL ser rastreável.

**Independent Test**: Consultar os três repositórios e verificar owner, relação de fork, upstream e revisões fixadas.

---

### P1: Build reproduzível do TFS ⭐ MVP

**User Story**: Como desenvolvedor, quero compilar o TFS em Docker no macOS e nativamente no Ubuntu para validar a mesma revisão nos dois ambientes sem instalar dependências no Mac.

**Why P1**: É a primeira prova técnica do projeto.

**Acceptance Criteria**:

1. WHEN o build Docker for executado a partir de um checkout limpo THEN ele SHALL produzir um binário TFS executável a partir da tag `v1.6` sem usar bibliotecas instaladas no host.
2. WHEN o build nativo for executado no Ubuntu 24.04 THEN ele SHALL produzir um binário TFS a partir do mesmo commit `098641981400f8ff89959f427f0e8718d9dd22e2` usado no desenvolvimento.
3. WHEN uma dependência ou etapa de compilação falhar THEN o build SHALL terminar com código diferente de zero e não publicar uma imagem marcada como pronta.
4. WHEN uma revisão upstream mudar THEN o build SHALL continuar usando a revisão fixada até uma atualização explícita do projeto.

**Independent Test**: Construir a imagem em checkout limpo e executar o build nativo em Ubuntu 24.04, registrando revisão, binários e códigos de saída.

---

### P1: Banco e inicialização do servidor ⭐ MVP

**User Story**: Como operador, quero iniciar MariaDB e TFS via Compose no desenvolvimento e como serviços nativos na VPS para manter dados persistentes e configuração segura.

**Why P1**: Um binário compilado sem banco e mundo carregado ainda não é um servidor utilizável.

**Acceptance Criteria**:

1. WHEN o volume de desenvolvimento estiver vazio THEN o Compose SHALL criar o banco e importar `schema.sql` exatamente uma vez.
2. WHEN o banco nativo da VPS ainda não possuir o schema THEN o instalador SHALL importá-lo uma vez e não destruir dados em reexecuções.
3. WHEN MariaDB ainda não estiver saudável THEN o TFS SHALL aguardar no Compose e o serviço nativo SHALL falhar sem declarar prontidão.
4. WHEN credenciais forem necessárias THEN elas SHALL vir de arquivos/variáveis não versionados e MariaDB SHALL escutar somente em interface local ou rede privada.

**Independent Test**: Em cada ambiente, inicializar o banco, inserir um marcador, reiniciar serviços e confirmar a persistência sem reimportação destrutiva.

---

### P1: Datapack e servidor pronto ⭐ MVP

**User Story**: Como mantenedor, quero iniciar o TFS com um datapack conhecido e compatível para separar problemas de infraestrutura de problemas de conteúdo.

**Why P1**: Confirma que build, banco, configuração e conteúdo funcionam em conjunto.

**Acceptance Criteria**:

1. WHEN o TFS iniciar com o datapack oficial THEN ele SHALL carregar mapa, itens, monstros, NPCs e scripts sem erro fatal.
2. WHEN a inicialização terminar THEN o container de desenvolvimento ou serviço `systemd` da VPS SHALL permanecer ativo e as portas configuradas SHALL estar ouvindo.
3. WHEN mapa ou arquivo obrigatório estiver ausente/incompatível THEN o processo SHALL falhar sem declarar prontidão e o log SHALL identificar a causa.
4. WHEN o operador executar o comando documentado de logs THEN ele SHALL obter logs pelo Compose no desenvolvimento e pelo journal na VPS.

**Independent Test**: Subir a stack do zero, aguardar healthchecks e validar processo, porta e ausência de erro fatal nos logs.

---

### P2: Fork do cliente preparado

**User Story**: Como desenvolvedor do cliente, quero um fork compatível e fixado para implementar a conexão assim que a baseline do servidor estiver validada.

**Why P2**: O cliente é necessário ao produto, mas sua compilação desktop não deve bloquear o bootstrap do servidor.

**Acceptance Criteria**:

1. WHEN o fork do OTClient for inspecionado THEN ele SHALL apontar para uma revisão cuja documentação declara compatibilidade com TFS 1.6/protocolo 13.10.
2. WHEN a próxima feature de cliente iniciar THEN ela SHALL conseguir consumir endereço e protocolo por configuração, sem valores secretos no código.

**Independent Test**: Verificar fork, revisão fixada e matriz de compatibilidade documentada.

---

## Edge Cases and Implicit-Requirement Sweep

| Dimension | Requirement or explicit N/A |
| --- | --- |
| Input validation & bounds | Variáveis obrigatórias, portas, caminhos e usuários de serviço SHALL ser validados antes da inicialização; valores ausentes falham com mensagem clara. |
| Failure / partial-failure states | Build, migração ou carga de datapack incompletos SHALL resultar em estado não saudável, sem falsa prontidão. |
| Idempotency / retry / duplicate handling | Builds, `compose up/down` e instalador nativo SHALL ser repetíveis; o schema SHALL inicializar somente quando ausente. |
| Auth boundaries & rate limits | Segredos SHALL ficar fora do Git; MariaDB SHALL ser acessível somente pela rede Docker local ou loopback na VPS. Rate limit é N/A porque não há API HTTP nesta feature. |
| Concurrency / ordering | MariaDB saudável SHALL preceder TFS nos dois ambientes; duas inicializações não SHALL executar importação concorrente do schema. |
| Data lifecycle / expiry | Volume local e diretórios nativos da VPS SHALL sobreviver a reinícios; retenção e backup são N/A porque dados reais ainda não fazem parte desta feature. |
| Observability | Logs e estado SHALL estar disponíveis via Compose local e `systemd`/journal na VPS. Métricas/tracing são N/A no bootstrap. |
| External-dependency failure | Falhas ao obter fontes/imagens/dependências SHALL encerrar a etapa com código não zero; revisões SHALL ser fixadas. |
| State-transition integrity | O ambiente só SHALL transicionar para pronto depois de banco saudável, schema presente, datapack carregado e portas do TFS ouvindo. |

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
| --- | --- | --- | --- |
| BOOT-01 | P1: Estrutura de código-fonte | Execute | Complete |
| BOOT-02 | P1: Build reproduzível | Execute | Complete |
| BOOT-03 | P1: Banco e inicialização | Execute | Complete |
| BOOT-04 | P1: Datapack e servidor pronto | Execute | Complete |
| BOOT-05 | P2: Fork do cliente preparado | Execute | Complete |
| BOOT-06 | Edge cases: validação e falhas | Execute | Complete |
| BOOT-07 | Edge cases: segurança e persistência | Execute | Complete |
| BOOT-08 | Edge cases: observabilidade e prontidão | Execute | Complete |

**Coverage:** 8 total, 8 mapped to tasks, 0 unmapped.

---

## Success Criteria

- [x] Três repositórios existem na conta GitHub e nenhuma credencial foi versionada.
- [x] O build Docker do TFS `v1.6` conclui em checkout limpo.
- [x] MariaDB e TFS ficam saudáveis via Docker Compose local e serviços nativos na VPS, com persistência após restart.
- [x] O TFS carrega o datapack oficial e mantém as portas configuradas disponíveis.
- [x] O procedimento Docker é repetível no macOS e o instalador nativo é idempotente no Ubuntu 24.04.
