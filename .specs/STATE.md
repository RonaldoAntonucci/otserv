# STATE

## Decisions

### AD-001
- **Decision**: O TFS usará a versão estável `v1.6` e o protocolo 13.10 como baseline inicial.
- **Reason**: A versão possui release estável e compatibilidade declarada pelo OTClient escolhido.
- **Trade-off**: Funcionalidades posteriores da branch `master` não entram automaticamente.
- **Scope**: Servidor, cliente, datapacks e assets compatíveis.
- **Date**: 2026-07-21
- **Status**: active

### AD-002
- **Decision**: Todo serviço do projeto será construído e executado por Docker; o host macOS não receberá dependências de runtime do TFS ou banco.
- **Reason**: O mesmo fluxo precisa funcionar no macOS de desenvolvimento e na VPS Ubuntu.
- **Trade-off**: Builds e depuração dependem do Docker e podem consumir mais recursos localmente.
- **Scope**: Desenvolvimento local, CI e VPS.
- **Date**: 2026-07-21
- **Status**: superseded by AD-005

### AD-003
- **Decision**: O banco inicial será MariaDB com volume Docker persistente e segredos fornecidos fora do Git.
- **Reason**: É compatível com o schema MySQL do TFS e permite ambiente reproduzível.
- **Trade-off**: A operação passa a depender do ciclo de vida do Compose e dos volumes.
- **Scope**: Persistência do servidor e ambientes locais/remotos.
- **Date**: 2026-07-21
- **Status**: superseded by AD-006

### AD-004
- **Decision**: A primeira inicialização utilizará o datapack oficial incluído no TFS; a escolha de um datapack completo será tratada como feature posterior.
- **Reason**: Isola falhas de compilação/configuração de incompatibilidades introduzidas por conteúdo de terceiros.
- **Trade-off**: O primeiro mundo é apenas um ambiente técnico de validação, não o conteúdo final do servidor.
- **Scope**: Bootstrap e smoke test inicial.
- **Date**: 2026-07-21
- **Status**: active

### AD-005
- **Decision**: Docker será obrigatório apenas no desenvolvimento macOS; na VPS Ubuntu, TFS e banco rodarão como serviços nativos.
- **Reason**: O usuário quer isolamento local sem adicionar a camada Docker à operação da VPS.
- **Trade-off**: Desenvolvimento e produção terão empacotamentos diferentes e exigirão gates de paridade explícitos.
- **Scope**: Desenvolvimento local e deploy na VPS.
- **Date**: 2026-07-21
- **Status**: active

### AD-006
- **Decision**: MariaDB usará container e volume persistente no desenvolvimento, mas instalação e armazenamento nativos na VPS.
- **Reason**: Mantém o macOS limpo e segue o modelo operacional nativo escolhido para produção.
- **Trade-off**: Inicialização, persistência e healthcheck precisam ser validados separadamente nos dois ambientes.
- **Scope**: Banco de desenvolvimento e produção.
- **Date**: 2026-07-21
- **Status**: active

### AD-007
- **Decision**: O projeto usará três repositórios públicos: `otserv` para orquestração e os forks verdadeiros `forgottenserver` e `otclient`.
- **Reason**: Preserva o vínculo com os upstreams e separa infraestrutura das modificações de servidor e cliente.
- **Trade-off**: O projeto precisa manter revisões e integração entre três repositórios.
- **Scope**: Organização do código e releases.
- **Date**: 2026-07-21
- **Status**: active

## Handoff

- **Feature**: Bootstrap Open Tibia Server / `.specs/features/bootstrap-open-tibia-server`
- **Phase / Task**: Execute — T1 em gate final
- **Completed**: Specify, Design, plano de tarefas, estratégia de testes e ferramentas aprovados; artefatos da T1 preparados
- **In-progress** (file:line): `.specs/features/bootstrap-open-tibia-server/tasks.md:79`
- **Next step**: criar e publicar o commit atômico da T1, validar cinco assertivas e iniciar T2
- **Blockers**: deploy nativo futuro requer terminal/SSH; MCP Hostinger não executa comandos no sistema operacional
- **Uncommitted files**: `.specs/STATE.md`, `.specs/features/bootstrap-open-tibia-server/spec.md`, `.specs/features/bootstrap-open-tibia-server/context.md`, `.specs/features/bootstrap-open-tibia-server/design.md`, `.specs/features/bootstrap-open-tibia-server/tasks.md`
- **Branch**: `main`
