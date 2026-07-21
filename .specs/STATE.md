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

### AD-008
- **Decision**: O bootstrap suportará somente MariaDB 10.11; MySQL continua tecnicamente compatível com o conector do TFS, mas não faz parte da matriz validada.
- **Reason**: Uma única implementação de banco reduz divergência entre Docker no desenvolvimento e o serviço nativo da VPS.
- **Trade-off**: Trocar para Oracle MySQL exigirá uma feature própria para adaptar instalação, imagem e gates operacionais.
- **Scope**: Banco de desenvolvimento, instalação nativa, documentação e testes.
- **Date**: 2026-07-21
- **Status**: active

### AD-009
- **Decision**: O release nativo manterá um `config.lua` imutável que carrega `/etc/otserv/config.lua`; a unidade não usará `--config`.
- **Reason**: No TFS 1.6, o parser reconhece `--config`, mas o `ConfigManager` redefine o caminho para `config.lua` durante o carregamento.
- **Trade-off**: Cada release precisa incluir o pequeno loader Lua além do binário, chave e datapack.
- **Scope**: Bundle `systemd`, instalador nativo e layout dos releases.
- **Date**: 2026-07-21
- **Status**: active

### AD-010
- **Decision**: O instalador nativo receberá um arquivo de ambiente real, preservará configuração e segredos existentes e ativará releases imutáveis por troca atômica de symlink.
- **Reason**: Reexecuções e falhas de compilação não podem substituir credenciais, dados ou o binário ativo da VPS.
- **Trade-off**: Credenciais existentes incompatíveis precisam ser corrigidas explicitamente pelo operador; o instalador não redefine senhas nem remove releases antigos.
- **Scope**: Instalação nativa, inicialização do MariaDB e publicação de releases na VPS.
- **Date**: 2026-07-21
- **Status**: active

## Handoff

- **Feature**: Bootstrap Open Tibia Server / `.specs/features/bootstrap-open-tibia-server`
- **Phase / Task**: Execute — T9 completa; T10 próxima
- **Completed**: T1 `e31cc663`; T2 `2d0bd363`; T3 `b831bd7`; T4 `351e40e`; T5 `63e1127`; T6 `3de35bb`; T7 `742d630`; T8 `ea2b346`; T9 aprovada com 16/16 contratos
- **In-progress** (file:line): `.specs/features/bootstrap-open-tibia-server/tasks.md:421`
- **Next step**: adicionar o smoke test nativo da VPS com rollback verificável
- **Blockers**: deploy nativo futuro requer terminal/SSH
- **Uncommitted files**: nenhum após o commit atômico da T9
- **Branch**: `main`
