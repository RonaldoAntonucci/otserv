# Desenvolvimento com Docker no macOS

## Regra do ambiente local

Docker Desktop é a única dependência de execução do desenvolvimento no macOS. Compilador, CMake, bibliotecas do TFS, Lua, MariaDB e qualquer outro runtime do projeto existem somente nas imagens e containers Docker; nenhum deles deve ser instalado diretamente no host.

Git é usado no host apenas para obter os repositórios. Ele não executa nem compila o projeto; SSH é necessário somente para administrar a VPS.

## Pré-requisitos

- Docker Desktop ativo, com Docker Compose v2.
- Git para clonar os três repositórios públicos.
- Portas TCP `7171` e `7172` livres no host.

Não use Homebrew, MacPorts ou outro gerenciador do macOS para instalar dependências do TFS.

## Preparar o checkout

```sh
git clone --recurse-submodules https://github.com/RonaldoAntonucci/otserv.git
cd otserv
cp env/development.env.example env/development.env
```

Edite `env/development.env` e substitua `CHANGE_ME_LOCAL_PASSWORD` por uma senha local. O arquivo real é ignorado pelo Git; nunca versione ou compartilhe seu conteúdo.

Valide a configuração antes de subir a stack usando a imagem de testes fixada:

```sh
docker build --file docker/test.Dockerfile --tag otserv-test:local .
docker run --rm --volume "$PWD:/workspace:ro" --workdir /workspace otserv-test:local sh scripts/validate-config.sh development env/development.env
```

## Subir e observar a stack

```sh
docker compose --env-file env/development.env up --detach --build
docker compose --env-file env/development.env ps
docker compose --env-file env/development.env logs --follow tfs
```

O Compose cria somente `db` e `tfs`. MariaDB usa o volume nomeado `db_data`, não publica a porta `3306`, e precisa ficar saudável antes do TFS. O servidor publica `7171` (login/status) e `7172` (jogo).

Comandos operacionais comuns:

```sh
docker compose --env-file env/development.env restart db tfs
docker compose --env-file env/development.env logs --tail 200 db tfs
docker compose --env-file env/development.env down
```

`down` preserva o volume e os dados. `docker compose ... down --volumes` apaga o banco local e só deve ser usado quando a intenção explícita for recriar o ambiente do zero.

## Gates de desenvolvimento

```sh
make test-static
make test-dev
make verify
```

`make test-static` executa 70 contratos dentro da imagem de testes. `make test-dev` compila a imagem `linux/amd64` fixada e executa 24 integrações em projetos/volumes Docker isolados. `make verify` executa os dois gates, totalizando 94 verificações locais.

Os testes de desenvolvimento limpam somente seus próprios projetos e volumes isolados. O volume normal criado pelos comandos acima não é removido.

## Diagnóstico

```sh
docker compose --env-file env/development.env config
docker compose --env-file env/development.env ps --all
docker compose --env-file env/development.env logs --tail 300 db tfs
```

Se o banco não ficar saudável, confirme os valores obrigatórios no arquivo real de ambiente. Se o TFS encerrar, procure erros de schema, mapa ou scripts no log. Corrija a causa e repita `make verify`; não marque uma imagem como pronta quando o gate falhar.
