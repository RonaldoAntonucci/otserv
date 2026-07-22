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

### AD-011
- **Decision**: O smoke nativo será somente leitura, exigirá o marcador `bootstrap_persistence_marker=vps-bootstrap-v1` criado no procedimento e reportará 14 verificações operacionais sem imprimir segredos.
- **Reason**: A mesma execução precisa validar persistência antes e depois de restart/reinstalação sem alterar o estado que pretende comprovar.
- **Trade-off**: A primeira validação remota exige criar explicitamente o marcador após a instalação inicial.
- **Scope**: Gate nativo `make test-vps` e coleta de evidências da VPS.
- **Date**: 2026-07-21
- **Status**: active

### AD-012
- **Decision**: Releases nativos serão publicados como `root:otserv`, com leitura/execução para o grupo de serviço e nenhum acesso para outros usuários.
- **Reason**: Diretórios criados por staging restritivo precisam continuar imutáveis para o serviço, mas o usuário `otserv` deve conseguir atravessar e ler todo o bundle.
- **Trade-off**: Operadores fora de `root` ou do grupo `otserv` não inspecionam diretamente o release.
- **Scope**: Instalador nativo e permissões de `/opt/otserv/releases/<commit>`.
- **Date**: 2026-07-21
- **Status**: active

### AD-013
- **Decision**: O OTClient Windows x64 será compilado nativamente em uma máquina Windows pelo fluxo MSVC/vcpkg já mantido no fork; o macOS ficará restrito à instalação persistente e ao UAT no CrossOver, sem receber dependências de build do projeto.
- **Reason**: O fork já possui preset e CI nativos para Windows, enquanto o cross-build Docker/MinGW no Apple Silicon exigiria trabalho adicional de portabilidade e uma matriz de dependências ainda não validada.
- **Trade-off**: A compilação passa a depender de uma máquina Windows preparada e os artefatos precisarão ser transferidos para o macOS antes da validação no CrossOver.
- **Scope**: Build e empacotamento do cliente, preparação do ambiente Windows e UAT local no CrossOver.
- **Date**: 2026-07-21
- **Status**: active

## Handoff

- **Feature**: Windows-built OTClient and First VPS Connection / `.specs/features/dockerized-otclient-vps-connection`
- **Phase / Task**: build pausado entre Specify e Design; slice independente `OTC-PROV` concluído e verificado
- **Completed**: pivô Windows em AD-013 e guia de retomada preservados; slice de identidade ativado em `995e689`; provisionador transacional em `38ba490`; contratos reforçados em `1895531`; segredo ignorado `env/client-test.env` criado com modo `0600`; VPS contém exatamente uma conta `otserv-smoke` e um personagem ativo `Docker Scout`; primeira execução `created`, segunda `noop`; gate Docker pós-fix com 84/84 contratos; Verifier PASS em 11/11 critérios e sensor P0 com 8/8 mutações mortas
- **In-progress** (file:line): nenhuma implementação em andamento; `.specs/features/dockerized-otclient-vps-connection/validation.md:1` registra o PASS independente do slice; a estratégia histórica de build em `spec.md:1` continua marcada para revisão
- **Next step**: na máquina Windows, clonar com submódulos, validar os pré-requisitos do fork e revisar/reaprovar a especificação substituindo o fluxo Docker/MinGW pelo preset nativo `windows-release`; somente então iniciar Design e retomar build, instalação persistente no CrossOver e primeira conexão
- **Blockers**: ambiente Windows ainda não preparado; a estratégia anterior de build permanece sem autorização para implementação; nenhum blocker restante no slice de identidade
- **Uncommitted files**: nenhum após o commit deste handoff
- **Branch**: `main`
