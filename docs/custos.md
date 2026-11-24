# Custos estimados (Azure for Students, US$ 100 de crédito)

Valores aproximados para a região `eastus2`. Confira os preços atuais em <https://azure.microsoft.com/pricing/calculator>.

| Item | Quando cobra | Ordem de grandeza |
|---|---|---|
| VM Standard_B2ms (2 vCPU, 8 GB) | só **ligada** | ~US$ 0,08 / hora |
| Disco SSD Standard 32 GB | sempre, até destruir | ~US$ 2,50 / mês |
| IP público estático (Standard) | sempre, até destruir | ~US$ 3,60 / mês |

**Exemplo:** 4 aulas práticas × 4 h + 10 h de estudo em casa = 26 h ligada ≈ US$ 2, mais ~2 meses de disco e IP ≈ US$ 12. **Total: cerca de US$ 14.**

O que estoura o crédito é **esquecer a VM ligada**: 24 h × 30 dias ≈ US$ 60. Por isso:
- o script agenda **desligamento automático diário** à meia-noite (horário de Brasília);
- rode `bash infra/desligar.sh` ao fim de cada aula;
- rode `bash infra/destruir.sh` quando a disciplina acabar.

Acompanhe o saldo em <https://www.microsoftazuresponsorships.com/Balance>.
