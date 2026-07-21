# VPS Ubuntu nativa

## Contrato suportado

O instalador suporta somente Ubuntu 24.04 LTS `amd64`, executado como root. Ele instala MariaDB 10.11 e as dependências de build, compila o TFS fixado com um job, publica releases imutáveis em `/opt/otserv/releases`, habilita/inicia `tfs.service` e só declara prontidão depois de confirmar que o serviço está ativo.

Docker não é usado na VPS. O acesso autorizado por SSH é obrigatório: o painel/MCP da Hostinger permite inspecionar e controlar a máquina, mas não substitui o terminal root necessário para instalar e validar o runtime.

## Checkout e ambiente secreto

```sh
git clone --recurse-submodules https://github.com/RonaldoAntonucci/otserv.git /root/otserv
cd /root/otserv
git submodule status
sudo install -d -o root -g root -m 0700 /root/otserv-secrets
sudo install -o root -g root -m 0600 deploy/vps/otserv.env.example /root/otserv-secrets/otserv.env
sudoedit /root/otserv-secrets/otserv.env
```

Substitua todos os placeholders. `MYSQL_HOST` deve permanecer `127.0.0.1`; `TFS_IP` deve conter o endereço público ou domínio do servidor. O instalador rejeita arquivo com sufixo `.example`, placeholder ou valor obrigatório ausente. Os comandos acima também mantêm a fonte secreta restrita; depois da primeira instalação, o instalador exige que `/etc/otserv/otserv.env` continue `root:root` e `0600`.

## Instalar e validar

```sh
cd /root/otserv
sudo deploy/vps/install.sh /root/otserv-secrets/otserv.env
sudo mariadb forgottenserver --execute="INSERT INTO server_config (config, value) VALUES ('bootstrap_persistence_marker', 'vps-bootstrap-v1') ON DUPLICATE KEY UPDATE value = 'vps-bootstrap-v1';"
sudo make test-vps
```

O `INSERT` idempotente cria o marcador exigido pelo primeiro smoke sem expor a credencial da aplicação. Depois disso, o smoke é estritamente somente leitura. Consulte a [evidência validada](vps-validation.md) para a prova de preservação.

Nenhum `systemctl start` adicional é necessário entre o instalador e o smoke. Se o TFS não ficar ativo, o instalador termina com erro e não imprime a mensagem de prontidão.

Abra somente as portas do protocolo e mantenha MariaDB sem regra pública:

```sh
sudo ufw allow 7171/tcp comment 'OTServ login'
sudo ufw allow 7172/tcp comment 'OTServ game'
sudo ufw status numbered
```

Se houver um firewall adicional no painel da hospedagem, ele também precisa permitir TCP `7171` e `7172`. Nunca publique `3306`.

## Estado, logs e restart

```sh
sudo systemctl status mariadb tfs
sudo journalctl --unit=tfs.service --boot --no-pager
sudo journalctl --unit=tfs.service --follow
sudo ss -ltn
```

Reinicie banco e servidor em conjunto e repita o gate:

```sh
sudo systemctl restart mariadb tfs
sudo make test-vps
```

O resultado aprovado é `14 passed, 0 failed`: MariaDB ativo apenas em loopback, schema e marcador presentes, TFS ativo, portas ouvindo, datapack carregado e nenhum erro fatal no journal do boot atual.

## Atualização idempotente

Escolha e revise primeiro um commit do repositório de orquestração. Então:

```sh
cd /root/otserv
git fetch origin
OTSERV_COMMIT='substitua-pelo-commit-completo-aprovado'
git checkout "$OTSERV_COMMIT"
git submodule sync --recursive
git submodule update --init --recursive
sudo deploy/vps/install.sh /root/otserv-secrets/otserv.env
sudo make test-vps
```

O instalador preserva `/etc/otserv/otserv.env`, o schema, os dados e o release ativo se a compilação falhar. Ele não redefine a senha de um banco existente e não remove releases antigos.

## Rollback de release

Liste os releases e escolha uma revisão completa já validada:

```sh
sudo ls -1 /opt/otserv/releases
TFS_REVISION='substitua-pela-revisao-completa-validada'
sudo test -x "/opt/otserv/releases/$TFS_REVISION/tfs"
sudo test -r "/opt/otserv/releases/$TFS_REVISION/REVISION"
sudo test ! -e /opt/otserv/current.new
sudo ln -s "/opt/otserv/releases/$TFS_REVISION" /opt/otserv/current.new
sudo mv -Tf /opt/otserv/current.new /opt/otserv/current
sudo systemctl restart tfs
sudo make test-vps
```

A troca do symlink é atômica e não altera MariaDB. Se o gate falhar, recolha `systemctl status` e o journal antes de tentar outra revisão.

## Preservação e recuperação

- Não remova `/var/lib/mysql`, `/etc/otserv` ou `/opt/otserv/releases` durante atualização/diagnóstico.
- Não substitua manualmente `/etc/otserv/otserv.env`; o instalador preserva o arquivo real já instalado.
- Não copie credenciais para comandos, logs, issues ou Git.
- Backup e disaster recovery automatizados ainda estão fora do escopo. Configure-os antes de aceitar dados reais de jogadores.
- Se `tfs.service` falhar, confira primeiro `journalctl`, a disponibilidade local do MariaDB e a revisão apontada por `/opt/otserv/current`.

O registro sanitizado da primeira instalação, reinstalação, restart e exposição de rede está em [Native VPS Bootstrap Validation](vps-validation.md).
