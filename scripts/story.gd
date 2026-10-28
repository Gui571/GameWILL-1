class_name WilliamStory
extends RefCounted
## Original short campaign. Keep dialogue as data so chapters can grow independently.

const CHAPTERS: Array[Dictionary] = [
	{
		"title": "01 · A PLATAFORMA ESQUECIDA",
		"subtitle": "Estação Vesper · 23:57",
		"description": "Um bilhete sem destino. Uma voz no rádio. Os trilhos ainda se lembram de você."
	},
	{
		"title": "02 · A GALERIA DOS ECOS",
		"subtitle": "Arquivo de passageiros · nível inferior",
		"description": "Entre os nomes apagados, uma lembrança continua resistindo."
	},
	{
		"title": "03 · O CORAÇÃO DA ESTAÇÃO",
		"subtitle": "Câmara de ressonância · energia instável",
		"description": "Para abrir o caminho, William precisa escolher o que vale a pena carregar."
	},
	{
		"title": "04 · O ÚLTIMO REGENTE",
		"subtitle": "Terminal zero · um minuto para a partida",
		"description": "Aquele que governa o silêncio aguarda diante do último trem."
	}
]

static func opening() -> Array[Dictionary]:
	return [
		{"speaker": "VESPER · SETE ANOS APÓS O SILÊNCIO", "text": "Na noite em que o último trem partiu, uma cidade inteira esqueceu para onde ele ia. William perdeu algo mais: o irmão que prometera voltar."},
		{"speaker": "WILLIAM", "text": "Sete anos, Tomás. Hoje apareceu um bilhete seu debaixo da minha porta. A tinta ainda estava fresca."},
		{"speaker": "BILHETE AMASSADO", "text": "“Se você se perder, escute os trilhos. Plataforma zero. Antes da última badalada.”"},
		{"speaker": "VOZ NO RÁDIO", "text": "Viajante… consegue me ouvir? Não toque nos sinos. Eles acordam o que ficou aqui."},
		{"speaker": "LYRA", "text": "Meu nome é Lyra. Eu mantinha esta estação viva. Agora só consigo manter uma luz acesa. Siga a luz, William."},
		{"speaker": "WILLIAM", "text": "Você sabe meu nome. Então sabe por que eu vim. Abra o caminho… eu cuido do resto."}
	]

static func before_battle(index: int) -> Array[Dictionary]:
	match index:
		0:
			return [
				{"speaker": "LYRA", "text": "Os vigias ainda conferem os bilhetes. O Regente substituiu seus corações por fragmentos do Vazio."},
				{"speaker": "LYRA", "text": "Observe a intenção deles antes de agir. Seus cortes alimentam as técnicas; golpes de impacto quebram a resistência. Eu protejo você quando puder."},
				{"speaker": "WILLIAM", "text": "Meu bilhete é só de ida. Mas pretendo voltar acompanhado."}
			]
		1:
			return [
				{"speaker": "WILLIAM", "text": "São nomes nas paredes… milhares deles. Aqui: Tomás. Alguém tentou apagar, mas a pedra não deixou."},
				{"speaker": "LYRA", "text": "Esta estação guarda lembranças. O Regente as consome para mover o trem. Seu irmão se recusou a entregar a última."},
				{"speaker": "ECO DE TOMÁS", "text": "Will… não deixe que decidam por você o que merece ser lembrado."}
			]
		2:
			return [
				{"speaker": "LYRA", "text": "Preciso contar uma coisa. Não estou presa nesta sala. Estou presa naquele rádio. Sou o que restou da primeira condutora."},
				{"speaker": "WILLIAM", "text": "Você me avisou do perigo. Me ajudou a levantar. Para mim, isso basta para chamar alguém de vivo."},
				{"speaker": "LYRA", "text": "Então me leve com você. Uma última viagem. O coração da estação está logo adiante."}
			]
		_:
			return [
				{"speaker": "REGENTE VAZIO", "text": "Cada passageiro deixa alguma coisa para trás. Entregue a lembrança do seu irmão e eu lhe darei uma vida sem essa dor."},
				{"speaker": "WILLIAM", "text": "A dor não é tudo que ele deixou. Você não pode apagar as coisas boas só porque não sabe senti-las."},
				{"speaker": "LYRA", "text": "William, ele está carregando o sino! Guarde força para quebrar a resistência antes da badalada. Eu fico com você."}
			]

static func after_battle(index: int) -> Array[Dictionary]:
	match index:
		0:
			return [
				{"speaker": "WILLIAM", "text": "Dentro daquela máquina… uma fotografia. Eles eram passageiros."},
				{"speaker": "LYRA", "text": "E agora podem descansar. O fragmento que ficou responde à sua vontade. Escolha como vai usá-lo; há um caminho longo até o terminal."}
			]
		1:
			return [
				{"speaker": "ECO DE TOMÁS", "text": "“Você sempre quer ser o herói, Will. Só não esqueça de voltar para casa.”"},
				{"speaker": "WILLIAM", "text": "Eu lembro desse dia. Você me emprestou uma espada de madeira. Ainda devo uma revanche."},
				{"speaker": "LYRA", "text": "O eco veio do outro lado do portal. Ele atravessou. Ainda existe um caminho até seu irmão."}
			]
		2:
			return [
				{"speaker": "LYRA", "text": "Conseguimos. O coração voltou a pulsar por conta própria. Ouça… não são engrenagens. É chuva."},
				{"speaker": "WILLIAM", "text": "A estação está lembrando do mundo. Agora falta lembrar o Regente de que ele não é dono dela."}
			]
		_:
			return [
				{"speaker": "REGENTE VAZIO", "text": "Sem mim… quem dará um destino a vocês?"},
				{"speaker": "WILLIAM", "text": "Nós mesmos."}
			]

static func ending() -> Array[Dictionary]:
	return [
		{"speaker": "A PRIMEIRA MANHÃ", "text": "Quando o sino se partiu, os nomes voltaram às paredes. Um a um, os rostos de Vesper reapareceram nas janelas do trem."},
		{"speaker": "LYRA", "text": "Olhe o seu bilhete. Agora existe um destino: Aurora. Eu nunca levei ninguém tão longe."},
		{"speaker": "WILLIAM", "text": "Na parte de trás… é a letra dele. “Sabia que você ia me encontrar.”"},
		{"speaker": "LYRA", "text": "O portão vai fechar, William. Tem certeza de que quer embarcar?"},
		{"speaker": "WILLIAM", "text": "Tenho. Mas primeiro vamos tirar a poeira desse banco. Minha companheira merece viajar na janela."},
		{"speaker": "FIM DO PRÓLOGO · ECOS DO ÚLTIMO TREM", "text": "E, pela primeira vez em sete anos, o trem partiu levando esperança. A estrada até Tomás continuava — mas William já não viajava sozinho."}
	]
