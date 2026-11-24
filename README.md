# Processamento de Streamings: ambiente prático na Azure

Material das aulas práticas da disciplina. Cada aluno sobe **a própria VM** na assinatura
*Azure for Students*, e tudo roda lá dentro em Docker. O aluno só precisa de um navegador.

```
 Navegador do aluno ──(só o IP dele)──►  VM Azure (Ubuntu, 2 vCPU / 8 GB)
                                          ├─ kafka1 · kafka2 · kafka3   (Kafka 4.0, KRaft)
                                          ├─ kafka-ui        :8080
                                          ├─ jupyter + spark :8888 / :4040
                                          ├─ postgres
                                          └─ grafana         :3000
 Azure Cloud Shell ── scripts infra/*.sh (criar, ligar, desligar, comandos na VM sem SSH)
```

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `infra/` | scripts para rodar no **Azure Cloud Shell** (criar, ligar, desligar, destruir a VM) |
| `ambiente/` | `docker-compose.yml`, imagem do Jupyter, Grafana e Postgres |
| `notebooks/comum/` | configuração compartilhada e **gerador de eventos** da loja fictícia |
| `notebooks/aula3_kafka/` | Aula 3: roteiro + 4 labs |
| `docs/` | passo a passo do aluno, custos, solução de problemas |
| `gabaritos/` | respostas dos exercícios, **só para o professor** |

## Como distribuir para a turma (professor)

Repositório: <https://github.com/pedrokrmlc/pafcd-streaming-praticas> (público, porque a VM clona sem senha). A pasta `gabaritos/` fica fora dele (`.gitignore`).

1. O aluno clona o repositório no Cloud Shell e roda `bash infra/criar_ambiente.sh SEU_IP`. A VM clona o mesmo repositório.
2. **Faça um ensaio completo na sua própria assinatura** antes da primeira aula (veja abaixo).
3. Peça aos alunos que criem o ambiente **antes** da Aula 3 (são 15 minutos, quase tudo esperando).

Material novo: `git add . && git commit -m "..." && git push`. O aluno roda, no Cloud Shell,
`git pull && bash infra/atualizar_material.sh`, e a VM faz `git pull`.

*Sem Git:* se os scripts rodarem fora de um clone (por exemplo, a partir de um .zip), o `criar_ambiente.sh`
empacota a pasta e envia direto para a VM por um armazenamento temporário na assinatura do aluno.

## Ensaio recomendado antes da aula

- [ ] `bash infra/criar_ambiente.sh SEU_IP` termina sem erro de política ou cota na região escolhida
- [ ] `bash infra/status.sh` mostra "AMBIENTE PRONTO" e 7 containers *Up*
- [ ] Jupyter abre, e no terminal `kafka-topics.sh --bootstrap-server kafka1:9092 --list` responde
- [ ] Kafka UI mostra 3 brokers
- [ ] Rodar os labs 01–04 da Aula 3 do início ao fim
- [ ] `bash infra/desligar.sh` e depois `bash infra/ligar.sh`: os containers voltam sozinhos

## Decisões de projeto

- **Kafka em Docker, e não Event Hubs:** o Event Hubs fala o protocolo Kafka, mas não expõe partições,
  réplicas, ISR nem falhas de broker, que são o centro da Aula 3. O Flink gerenciado da Azure
  (HDInsight on AKS) foi descontinuado em jan/2025.
- **Sem SSH:** a VM não abre a porta 22. Os comandos dentro dela passam por `az vm run-command`
  (`infra/vm.sh`), e as portas web só aceitam o IP do aluno. Kafka UI e Grafana têm senha (o token).
- **3 brokers numa VM só:** permite demonstrar replicação e eleição de líder. A limitação
  (a VM é um ponto único de falha) vira tema de discussão no Lab 4.
