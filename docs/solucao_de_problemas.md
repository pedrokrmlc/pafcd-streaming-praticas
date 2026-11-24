# Solução de problemas

### `RequestDisallowedByAzure` ou "região não permitida" ao criar a VM
A assinatura Azure for Students só permite algumas regiões, e a lista varia. O `criar_ambiente.sh` já tenta
descobrir as regiões permitidas e escolher uma sozinho. Se mesmo assim der erro, veja a lista e escolha à mão:
```bash
az policy assignment list --disable-scope-strict-match --query "[].{nome:displayName, parametros:parameters}" -o json
LOCATION=NOME_DA_REGIAO bash infra/criar_ambiente.sh SEU_IP
```
(Também aparece no Portal → *Policy* → *Assignments* → "Allowed resource deployment regions".)

### `QuotaExceeded` / tamanho de VM indisponível
```bash
az group delete -n rg-streaming --yes
SIZE=Standard_D2as_v5 bash infra/criar_ambiente.sh SEU_IP   # ou Standard_D2s_v5
```
Precisa ter **8 GB de RAM**. Com 4 GB (B2s) o Kafka e o Spark não cabem juntos.

### O navegador não abre o Jupyter / Kafka UI (fica carregando)
1. `bash infra/status.sh`: o ambiente já está "PRONTO"?
2. Seu IP mudou? Veja em https://api.ipify.org e rode `bash infra/liberar_ip.sh NOVO_IP`.
3. Use `http://` e não `https://`.
4. Redes de empresa ou da faculdade às vezes bloqueiam as portas 8888/8080/3000. Teste pelo 4G do celular.

### "Ainda montando..." por mais de 20 minutos
Veja o log da instalação:
```bash
bash infra/vm.sh "tail -40 /var/log/cloud-init-output.log"
```
Se o erro estiver no download do material (`curl` ou `git clone`), rode `bash infra/atualizar_material.sh` e depois refaça a montagem:
```bash
bash infra/vm.sh "cd /opt/streaming/ambiente && docker compose up -d --build"
```

### Um container caiu
```bash
bash infra/vm.sh "cd /opt/streaming/ambiente && docker compose ps -a"
bash infra/vm.sh "cd /opt/streaming/ambiente && docker compose logs --tail 50 kafka1"
bash infra/vm.sh "cd /opt/streaming/ambiente && docker compose up -d"
```

### Esqueci o token
`bash infra/mostrar_acesso.sh`

### O kernel do notebook morreu (memória)
Feche notebooks que não está usando (Running → Shut Down). Cada sessão Spark reserva ~1,5 GB.

### Quero começar do zero
```bash
bash infra/destruir.sh
bash infra/criar_ambiente.sh SEU_IP
```
