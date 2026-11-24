"""Dados de referência da loja fictícia usada em todas as aulas."""

PRODUTOS = [
    # (produto_id, nome, categoria, preco)
    ("p01", "Fone Bluetooth", "eletronicos", 199.90),
    ("p02", "Carregador Turbo", "eletronicos", 89.90),
    ("p03", "Smartwatch", "eletronicos", 899.00),
    ("p04", "Caixa de Som", "eletronicos", 349.00),
    ("p05", "Teclado Mecânico", "informatica", 459.00),
    ("p06", "Mouse Sem Fio", "informatica", 129.90),
    ("p07", "Monitor 27\"", "informatica", 1599.00),
    ("p08", "SSD 1TB", "informatica", 499.00),
    ("p09", "Camiseta Dry", "moda", 79.90),
    ("p10", "Tênis Corrida", "moda", 499.90),
    ("p11", "Jaqueta Corta-vento", "moda", 259.00),
    ("p12", "Boné", "moda", 59.90),
    ("p13", "Cafeteira", "casa", 389.00),
    ("p14", "Air Fryer", "casa", 549.00),
    ("p15", "Jogo de Panelas", "casa", 699.00),
    ("p16", "Luminária", "casa", 149.00),
    ("p17", "Livro: Streaming Systems", "livros", 289.00),
    ("p18", "Livro: Designing Data-Intensive Apps", "livros", 319.00),
    ("p19", "Livro: Kafka: The Definitive Guide", "livros", 279.00),
    ("p20", "Kindle", "livros", 549.00),
]

CIDADES = ["Belo Horizonte", "São Paulo", "Rio de Janeiro", "Curitiba", "Salvador",
           "Recife", "Porto Alegre", "Brasília", "Fortaleza", "Manaus"]

USUARIOS = [(f"u{i:03d}", CIDADES[i % len(CIDADES)]) for i in range(1, 201)]

PAGINAS = ["home", "busca", "produto", "produto", "produto", "carrinho"]
METODOS_PAGAMENTO = ["pix", "pix", "cartao", "cartao", "boleto"]
