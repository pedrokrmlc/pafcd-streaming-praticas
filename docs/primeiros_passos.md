# Primeiros passos: seu ambiente na Azure

Você vai criar **uma máquina virtual só sua** na Azure, com tudo o que as aulas práticas usam:

- cluster **Apache Kafka** com 3 brokers;
- **Jupyter Lab** com Python, PySpark e as ferramentas de linha de comando do Kafka;
- **Kafka UI** para ver tópicos e mensagens no navegador;
- **Postgres** e **Grafana** (usados a partir da Aula 5).

Nada é instalado no seu computador: basta um navegador.

## 1. Ative o Azure for Students (uma vez só)

1. Acesse <https://azure.microsoft.com/free/students> e entre com o **e-mail institucional**.
2. Não precisa de cartão de crédito. Você ganha **US$ 100 de crédito**; o curso inteiro gasta em torno de US$ 10 a 15 se você desligar a VM ao final de cada aula.

## 2. Abra o Cloud Shell

1. Entre em <https://portal.azure.com>.
2. Clique no ícone **`>_`** na barra do topo → escolha **Bash**.
3. Na primeira vez ele pergunta sobre armazenamento: escolha **"Montar conta de armazenamento"** (*Mount storage account*),
   a assinatura *Azure for Students* e **"Criar uma conta de armazenamento"**. Assim a pasta do material
   fica guardada entre uma aula e outra. O custo é de centavos por mês.

> Se você escolher o modo sem armazenamento, a pasta some quando a sessão fecha: é só rodar o
> `git clone` do passo 3 de novo. A VM e seus notebooks **não** são afetados.

## 3. Baixe o material

No Cloud Shell:

```bash
git clone https://github.com/pedrokrmlc/pafcd-streaming-praticas.git streaming
cd streaming
```

## 4. Descubra seu IP

No navegador **do seu computador** (não no Cloud Shell), abra <https://api.ipify.org>. Anote o número, por exemplo `177.20.30.40`. Precisa ser o IPv4 (quatro números separados por ponto); sites que mostram um endereço longo com `:` estão mostrando o IPv6, que não serve.
Só esse IP vai conseguir acessar a sua VM.

## 5. Crie o ambiente

```bash
bash infra/criar_ambiente.sh 177.20.30.40      # use o SEU IP
```

Em 3 a 5 minutos o script mostra os endereços e um **token**. **Anote o token**: ele é a senha do Jupyter, da Kafka UI e do Grafana.

A VM ainda vai passar **de 8 a 12 minutos** montando o ambiente lá dentro. Acompanhe:

```bash
bash infra/status.sh       # repita até aparecer "AMBIENTE PRONTO"
```

## 6. Acesse

| Serviço | Endereço | Login |
|---|---|---|
| Jupyter Lab | `http://IP_DA_VM:8888/lab?token=TOKEN` | o token já vai no link |
| Kafka UI | `http://IP_DA_VM:8080` | `aluno` / token |
| Grafana | `http://IP_DA_VM:3000` | `admin` / token |
| Spark UI | `http://IP_DA_VM:4040` | (abre quando um notebook Spark estiver rodando) |

## Rotina de toda aula

```bash
[ -d streaming ] || git clone https://github.com/pedrokrmlc/pafcd-streaming-praticas.git streaming
cd streaming
bash infra/ligar.sh                # início da aula
bash infra/liberar_ip.sh SEU_IP    # só se você mudou de rede (casa ↔ faculdade)
...
bash infra/desligar.sh             # FIM DA AULA: não esqueça!
```

A VM também se desliga sozinha todo dia à meia-noite (horário de Brasília), por segurança.

## Comandos úteis

| Comando | Para quê |
|---|---|
| `bash infra/status.sh` | ver se está tudo de pé |
| `bash infra/mostrar_acesso.sh` | esqueci o token / os endereços |
| `bash infra/vm.sh "docker stop kafka2"` | roda um comando dentro da VM (usado no Lab 4 da Aula 3) |
| `git pull && bash infra/atualizar_material.sh` | baixa o material novo do professor para a VM (seus notebooks não são sobrescritos) |
| `bash infra/destruir.sh` | **fim da disciplina**: apaga tudo e encerra os custos |

Problemas? Veja `docs/solucao_de_problemas.md`.
