extends Node
## Autoload: progresso salvo, regras do campeonato, controles extras e helpers de interface.

const SAVE := "user://save.json"
const AMARELO := Color("#ffd400")
const UPS := [["motor", "Motor"], ["cambio", "Câmbio"], ["pneus", "Pneus"], ["freios", "Freios"],
	["nitro", "Nitro"], ["aero", "Carenagem"], ["tanque", "Combustível"], ["tele", "Telemetria"]]
# peças por categoria: 3 níveis × 2 opções = [id do desenho, nome, descrição, efeitos]
# efeitos somam entre as peças instaladas: vel/ace/freio/tanque/con/grama/nitro_f em fração; ade reduz a força
# centrífuga; batida = velocidade mantida ao bater; nitro_n cargas; nitro_t, tempo e pit em segundos.
const PECAS := {
	"motor": [
		[["v6", "V6 3.0 aspirado", "mais cilindros, mais velocidade final", {"vel": .07}],
		 ["boxer", "Boxer 2.0", "motor baixo e plano: o carro gruda nas curvas", {"vel": .04, "ade": .05}]],
		[["turbo", "Turbo", "muito final, mas demora a encher", {"vel": .10, "ace": -.05}],
		 ["super", "Supercharger", "compressor na correia: arrancada imediata", {"ace": .22, "vel": .02}]],
		[["v12", "V12 biturbo", "o mais rápido de todos, e o mais beberrão", {"vel": .14, "con": .12}],
		 ["wankel", "Rotativo Wankel", "leve e gira alto: acelera muito", {"vel": .07, "ace": .15}]]],
	"cambio": [
		[["curta", "Relação curta", "marchas curtas: sai rápido, perde final", {"ace": .25, "vel": -.02}],
		 ["longa", "Relação longa", "marchas longas: mais final, sai devagar", {"vel": .04, "ace": .08}]],
		[["seq", "Sequencial", "trocas em milésimos", {"ace": .2}],
		 ["lsd", "Diferencial autoblocante", "a roda de fora não patina na curva", {"ace": .1, "ade": .06}]],
		[["dct", "Dupla embreagem", "a próxima marcha já está engatada", {"ace": .25}],
		 ["comp", "Câmbio de competição", "engrenagens retas e relações fechadas", {"ace": .15, "vel": .04}]]],
	"pneus": [
		[["esportivo", "Pneus esportivos", "borracha mais macia", {"ade": .11}],
		 ["misto", "Pneus mistos", "aguentam terra e grama", {"ade": .06, "grama": .25}]],
		[["slick", "Slick macio", "sem sulcos: aderência máxima no asfalto", {"ade": .15, "grama": -.1}],
		 ["rali", "Pneus de rali", "cravos grossos: fora da pista quase não freia", {"ade": .08, "grama": .35}]],
		[["composto", "Composto de corrida", "a borracha da Fórmula 1", {"ade": .14}],
		 ["magnesio", "Rodas de magnésio", "rodas leves: curva e acelera melhor", {"ade": .09, "ace": .08}]]],
	"freios": [
		[["pastilha", "Pastilhas esportivas", "mordem mais forte", {"freio": .35}],
		 ["ventilado", "Discos ventilados", "não esquentam e ajudam na curva", {"freio": .3, "ade": .02}]],
		[["pinca", "Pinças de 6 pistões", "força de frenagem de corrida", {"freio": .45}],
		 ["abs", "ABS", "freia sem travar e sem sair de traseira", {"freio": .3, "ade": .05}]],
		[["carbono", "Discos de carbono-cerâmica", "os melhores freios que existem", {"freio": .5}],
		 ["kers", "Freio regenerativo (KERS)", "a frenagem recarrega o boost", {"freio": .25, "nitro_t": .8}]]],
	"nitro": [
		[["cilindro", "Cilindro extra", "+1 carga de nitro", {"nitro_n": 1}],
		 ["bico", "Bico de alta vazão", "cada nitro dura e empurra mais", {"nitro_t": 1.0, "nitro_f": .1}]],
		[["seco", "Nitro seco", "mais uma carga e um pouco mais longa", {"nitro_n": 1, "nitro_t": .4}],
		 ["molhado", "Nitro molhado", "nitro com combustível: empurra mais forte", {"nitro_f": .2, "nitro_t": .5}]],
		[["dupla", "Garrafa dupla", "+2 cargas de nitro", {"nitro_n": 2}],
		 ["direta", "Injeção direta de N2O", "um bico por cilindro: o boost mais forte", {"nitro_n": 1, "nitro_f": .25}]]],
	"aero": [
		[["parachoque", "Para-choque reforçado", "perde menos velocidade ao bater", {"batida": .1, "grama": .1}],
		 ["saia", "Saias laterais", "o carro desliza melhor fora da pista", {"grama": .25}]],
		[["aerofolio", "Aerofólio traseiro", "pressão aerodinâmica: mais curva, menos final", {"ade": .07, "vel": -.02}],
		 ["widebody", "Kit widebody", "carroceria larga: aguenta batida e curva", {"batida": .08, "ade": .04}]],
		[["fibra", "Carroceria de fibra de carbono", "o carro inteiro fica mais leve", {"ace": .1, "vel": .03, "batida": .04}],
		 ["drs", "Asa móvel (DRS)", "abre na reta, fecha na curva", {"vel": .05, "ade": .05}]]],
	"tanque": [
		[["tanque80", "Tanque de 80 L", "+25% de combustível", {"tanque": .25}],
		 ["injecao", "Injeção eletrônica", "gasta 12% menos", {"con": -.12}]],
		[["celula", "Célula de competição", "tanque à prova de batida, bem maior", {"tanque": .3}],
		 ["chip", "Mapa econômico (chip)", "gasta bem menos, acelera um pouco menos", {"con": -.18, "ace": -.03}]],
		[["engate", "Engate rápido", "reabastece mais rápido no box", {"pit": 1.0, "tanque": .1}],
		 ["hibrido", "Motor híbrido", "a bateria divide o trabalho com o motor", {"con": -.25}]]],
	"tele": [
		[["radio", "Rádio com a equipe", "+1,5 s para responder na pista", {"tempo": 1.5}],
		 ["tpms", "Sensores de pneu", "+0,8 s e o carro avisa antes de escorregar", {"tempo": .8, "ade": .03}]],
		[["engenheiro", "Engenheiro de pista", "+2 s para responder na pista", {"tempo": 2.0}],
		 ["gps", "GPS de traçado", "+1 s e mostra o melhor traçado", {"tempo": 1.0, "ade": .04}]],
		[["telemetria", "Telemetria em tempo real", "+2,5 s para responder na pista", {"tempo": 2.5}],
		 ["ia", "Assistente de IA", "+1,5 s e ajuda nas frenagens", {"tempo": 1.5, "freio": .15}]]]}
const EFEITO := {"vel": ["%+d%% velocidade final", 100], "ace": ["%+d%% aceleração", 100], "ade": ["%+d%% aderência", 100],
	"freio": ["%+d%% frenagem", 100], "grama": ["%+d%% fora da pista", 100], "batida": ["%+d%% nas batidas", 100],
	"nitro_n": ["%+d carga de nitro", 1], "nitro_t": ["%+.1f s de nitro", 1], "nitro_f": ["%+d%% força do nitro", 100],
	"tanque": ["%+d%% combustível", 100], "con": ["%+d%% consumo", 100], "tempo": ["%+.1f s nas perguntas", 1],
	"pit": ["%+.1f s a menos no box", 1]}
# preço das peças: pontos de performance de cada efeito × fator do nível (peça que rende mais custa mais)
const PESO := {"vel": 100.0, "ace": 45.0, "ade": 80.0, "freio": 20.0, "grama": 15.0, "batida": 30.0, "nitro_n": 6.0,
	"nitro_t": 4.0, "nitro_f": 30.0, "tanque": 15.0, "con": -20.0, "tempo": 3.0, "pit": 3.0}
const FATOR_NIVEL := [85.0, 150.0, 260.0]
const PREMIO := [2000, 1500, 1200, 1000, 800, 650, 500, 400, 300, 200, 150, 100]
const PTS := [20, 15, 12, 10, 8, 6, 4, 3, 2, 1, 0, 0]
const GRID := [12, 10, 8, 5, 3, 1]  # posição de largada por acertos na classificatória (0..5)
const VOLTAS := 3
const EU := 11
const PRECO_PINTURA := 150
const EMPRESTIMO := 1000
const PINT := [["Vermelho", "#d62828"], ["Azul", "#2462d8"], ["Amarelo", "#eab308"], ["Verde", "#1f9a52"], ["Branco", "#e4e6ea"],
	["Grafite", "#44464f"], ["Laranja", "#ea6c12"], ["Roxo", "#7c3aed"], ["Rosa", "#e44d9a"], ["Ciano", "#12b4c8"]]
const PILOTOS := ["Ana Coluto", "Zé Ugma", "Dona Crase", "Hipérbato Jr.", "Sr. Hiato", "Mel Tonímia", "Pró Clise", "Eli Psis",
	"Cata Fora", "Para Doxo", "Íris Onia", "VOCÊ"]
const MODELOS := [
	{"nome": "Sabiá GT", "desc": "equilibrado", "vel": 1.0, "ace": 1.0, "ade": 1.0, "con": 1.0, "rt": 11, "rb": 17, "ry": 3, "asa": 0, "lz": 0},
	{"nome": "Onça V8", "desc": "mais final, arranca devagar, bebe mais", "vel": 1.03, "ace": 0.96, "ade": 0.95, "con": 1.08, "rt": 14, "rb": 19, "ry": 5, "asa": 0, "lz": 1},
	{"nome": "Arara RS", "desc": "gruda nas curvas e gasta pouco, menos final", "vel": 0.975, "ace": 1.15, "ade": 1.1, "con": 0.9, "rt": 15, "rb": 18, "ry": 1, "asa": 1, "lz": 2},
	{"nome": "Jaguatirica X", "desc": "arranca forte, escorrega nas curvas", "vel": 1.025, "ace": 1.08, "ade": 0.92, "con": 1.08, "rt": 8, "rb": 14, "ry": 6, "asa": 2, "lz": 3}]
# categorias: carro-base (null = o modelo escolhido na garagem), efeitos extras somados aos das peças,
# multiplicador de prêmio e quantos GPs classificados (top 5, em qualquer categoria) liberam a categoria
const CATEGORIAS := {
	"gt": {"nome": "Turismo GT", "desc": "o campeonato original: carros esportivos", "carro": null, "ef": {}, "premio": 1.0, "req": 0},
	"stock": {"nome": "Stock Car", "desc": "sedãs pesados de V8: batida faz parte do jogo",
		"carro": {"nome": "Stock Car V8", "vel": 1.0, "ace": 0.94, "ade": 0.96, "con": 1.1}, "ef": {"batida": .12}, "premio": 1.25, "req": 3},
	"rali": {"nome": "Rali", "desc": "4x4 com cravos: fora da pista quase não perde velocidade",
		"carro": {"nome": "Rali 4x4", "vel": 0.95, "ace": 1.12, "ade": 0.92, "con": 1.0}, "ef": {"grama": .6}, "premio": 1.4, "req": 6},
	"formula": {"nome": "Fórmula", "desc": "roda exposta: o mais rápido nas curvas, mas batida custa caro",
		"carro": {"nome": "Monoposto", "vel": 1.08, "ace": 1.15, "ade": 1.3, "con": 0.95}, "ef": {"batida": -.25}, "premio": 1.7, "req": 9}}
# equipes: [nome, cor 1, cor 2, estrelas, ritmo dos carros, bônus para quem assina, meta do patrocinador [tipo, alvo, prêmio, texto]]
const EQUIPES := [
	["Escuderia Crase", "#d02b2b", "#ffd400", 5, 1.02, {"pit": 1.0, "vel": .02}, ["acertos", 0.8, 800, "acertar 80% das perguntas da corrida"]],
	["Concordância Racing", "#2462d8", "#e4e6ea", 4, 1.01, {"vel": .04}, ["pos", 3, 650, "terminar no pódio"]],
	["Regência Motorsport", "#1f9a52", "#eab308", 4, 1.0, {"ace": .08}, ["box", 0, 600, "acertar a pergunta do box"]],
	["Próclise Team", "#7c3aed", "#e4e6ea", 3, 0.99, {"nitro_n": 1}, ["pos", 5, 500, "terminar entre os 5 primeiros"]],
	["Vírgula Velocità", "#ea6c12", "#111111", 2, 0.98, {"tempo": 1.5}, ["acertos", 0.7, 400, "acertar 70% das perguntas da corrida"]],
	["Hífen Garage", "#12b4c8", "#e44d9a", 1, 0.97, {"con": -.1}, ["pos", 10, 300, "terminar entre os 10 primeiros"]]]
const PROPOSTA := [0, 0, 0, 5, 3, 1]  # por estrelas: melhor colocação exigida para a equipe fazer proposta (0 = livre)
const PAISES := ["BRASIL", "PORTUGAL", "ANGOLA", "MOÇAMBIQUE"]
# [módulo, cidade, país, céu topo, céu base, astro, noite, serra longe, serra perto, 'm'ontanha|'c'idade,
#  grama a/b, pista a/b, zebra a/b, folhagem, cenário, urbanização 0..2]
const PISTAS := [
	["m1", "Brasília", 0, "#2a78e0", "#bfe4ff", "#fff6c0", false, "#7f9fc4", "#4c8a3f", "m", "#58a83a", "#4f9c33", "#6e6e72", "#68686c", "#ffffff", "#d02b2b", "#2f8a3a", ["arvore", "predio", "casa", "outdoor", "arvore", "sobrado"], 1],
	["m2", "Rio de Janeiro", 0, "#f0603e", "#ffd66b", "#fff0a0", false, "#a84c68", "#55305a", "m", "#e6c880", "#dcbc72", "#5e5762", "#58515c", "#ffffff", "#e0603a", "#2f9e62", ["palmeira", "sobrado", "predio", "outdoor", "casa", "palmeira"], 1],
	["m3", "Manaus", 0, "#1a8a82", "#c9f2d0", "#fffbd0", false, "#2c6e5a", "#1c4a34", "m", "#2f8f3a", "#288232", "#5c5c60", "#56565a", "#ffffff", "#d02b2b", "#1f7a34", ["arvore", "palmeira", "arbusto", "arvore", "outdoor"], 0],
	["m4", "Lisboa", 1, "#0a0e2e", "#3d2b70", "#f4f1d0", true, "#1e1e42", "#10102a", "c", "#1f3a2a", "#1a3324", "#3d3d48", "#383842", "#ffffff", "#e0b020", "#1f5a33", ["predio", "sobrado", "sobrado", "torre", "outdoor", "torre"], 2],
	["m5", "Serra da Estrela", 1, "#86b2dc", "#eaf4ff", "#ffffff", false, "#b8cce4", "#8fa9c6", "m", "#f4f8ff", "#e2ebf7", "#7a838d", "#747d87", "#ffffff", "#3a78d0", "#2f6b4f", ["pinheiro", "pinheiro", "pedra", "casa", "pinheiro"], 0],
	["m6", "Porto", 1, "#6f9bd0", "#f6e2c0", "#fff6c0", false, "#84698c", "#9c5a2c", "m", "#b98a2f", "#ad7f29", "#666062", "#605a5c", "#ffffff", "#d02b2b", "#d9722a", ["sobrado", "sobrado", "arvore", "outdoor", "casa", "sobrado"], 1],
	["m7", "Namibe", 2, "#f09a48", "#fde3a7", "#ffffff", false, "#c97b4a", "#a85d32", "m", "#dca468", "#d2985a", "#72665c", "#6c6056", "#ffffff", "#b5432e", "#5a8a3a", ["pedra", "cacto", "arbusto", "pedra", "outdoor"], 0],
	["m7", "Lubango", 2, "#d8503a", "#f7b267", "#ffe6a0", false, "#8c2f39", "#5e1f2b", "m", "#b5653a", "#a95b33", "#645850", "#5e524a", "#ffffff", "#222222", "#4a8a3a", ["pedra", "arbusto", "outdoor", "pedra", "arvore"], 0],
	["m8", "Luanda", 2, "#06142e", "#1f5490", "#e8f0ff", true, "#0f2a4a", "#0a1b33", "c", "#174a3a", "#134132", "#42464f", "#3c404a", "#ffffff", "#d02b2b", "#1f7a55", ["torre", "predio", "palmeira", "outdoor", "sobrado", "torre"], 2],
	["m9", "Gorongosa", 3, "#e8a23c", "#fbe9b0", "#fff6c0", false, "#b08a5a", "#7a6a2c", "m", "#c8a83a", "#bc9c32", "#6a625a", "#645c54", "#ffffff", "#d02b2b", "#6a8a2a", ["arvore", "arbusto", "pedra", "arvore", "outdoor"], 0],
	["m10", "Maputo", 3, "#18062f", "#f0489a", "#ffe0f0", true, "#3a1466", "#12062b", "c", "#2b1a4a", "#251642", "#30303c", "#2a2a36", "#00f0f0", "#f000f0", "#7a3ad0", ["torre", "predio", "torre", "outdoor", "palmeira", "torre"], 2],
	["", "Ilha de Moçambique", 3, "#28368a", "#ffcf7a", "#fff3b0", false, "#5b5fa8", "#33386f", "m", "#3f9a5a", "#389052", "#666668", "#606062", "#ffffff", "#d02b2b", "#2e8b3d", ["palmeira", "sobrado", "casa", "outdoor", "arvore", "sobrado"], 1]]

# Cada categoria fora do GT estuda uma série de Linguística: 11 módulos (um por corrida; a 12ª corrida é a final,
# que revisa a série toda). O GT segue com a Gramática (módulos m1..m10 em PISTAS). [nome da série, [[id, título, edital], ...]]
const SERIES := {
	"stock": ["Linguística I · Língua, sentido e texto", [
		["l1", "Linguagem, língua, fala e discurso", "edital 1"],
		["l2", "O signo linguístico de Saussure", "edital 1"],
		["l3", "Saussure × Chomsky e a linguagem humana", "edital 1"],
		["l4", "Significado, sentido e referente", "edital 1 e 3.4"],
		["l5", "Relações semânticas entre palavras", "edital 3.5"],
		["l6", "Categorias semânticas e formação de palavras", "edital 2"],
		["l7", "Leitura: explícito, inferido, fato e opinião", "edital 3.1, 3.7 e 3.8"],
		["l8", "Textualidade, coesão e coerência", "edital 3.2 e 3.3"],
		["l9", "Conectores e operadores argumentativos", "edital 3.2 e 3.5"],
		["l10", "Implícitos: pressuposto e subentendido", "edital 3.6"],
		["l11", "Tipos textuais e gêneros", "edital 6.1"]]],
	"rali": ["Linguística II · Gêneros, argumentação e discurso", [
		["l12", "Discurso relatado e adequação ao gênero", "edital 4.2 e 6.1"],
		["l13", "Intertextualidade, retextualização e reescritura", "edital 6.2"],
		["l14", "Tese, argumentos e raciocínios", "edital 3.8 e 10"],
		["l15", "Modalizadores e falácias", "edital 3.8 e 10"],
		["l16", "Retórica clássica e oratória parlamentar", "edital 5.3 e 10"],
		["l17", "Enunciação e dêixis", "edital 5.1"],
		["l18", "Dialogismo, polifonia e heterogeneidade", "edital 5.2"],
		["l19", "Atos de fala: Austin e Searle", "edital 5.1 e 5.2"],
		["l20", "Implicatura, discurso e ideologia", "edital 5.2"],
		["l21", "As seis funções da linguagem", "edital 9"],
		["l22", "Funções da linguagem no Parlamento", "edital 9"]]],
	"formula": ["Linguística III · Língua em uso, estilo e redação oficial", [
		["l23", "Variação linguística", "edital 7.1"],
		["l24", "Normas, oralidade, escrita e preconceito linguístico", "edital 7.2 e 7.3"],
		["l25", "Concepções de gramática e correção × propriedade", "edital 8"],
		["l26", "Figuras de palavra", "edital 4.1 e 10"],
		["l27", "Figuras de pensamento", "edital 4.1 e 10"],
		["l28", "Figuras de construção e de som", "edital 4.1 e 10"],
		["l29", "Redação oficial: atributos e linguagem", "edital 11"],
		["l30", "Tratamento, vocativo, endereçamento e fecho", "edital 11"],
		["l31", "Padrão ofício: estrutura e formatação", "edital 11"],
		["l32", "Exposição de motivos, mensagem e e-mail", "edital 11"],
		["l33", "Ata, relatório, parecer e certidão", "edital 11"]]]}

var s: Dictionary = {}
var gp := 0          # grande prêmio escolhido
var grid := 12       # posição de largada vinda da classificatória
var abrir := ""      # sub-tela a abrir ao voltar para o Main ("campeonato")
var teste := false   # testes automáticos: salvar() não grava nada


func _ready() -> void:
	s = _carrega()
	RenderingServer.set_default_clear_color(Color("#070a1c"))
	_tema()
	_controles()


# ------------------------------------------------------------ progresso
func _carrega() -> Dictionary:
	var d := {"moedas": 500, "ups": {}, "carro": 0, "cor": 0, "cores": [0], "res": {}, "err": {}, "visto": {}, "ac": 0, "tot": 0, "vol": [0.5, 0.7], "manual": false, "divida": 0,
		"cat": "gt", "eqres": {}, "equipes": [[0, 1], [2, 3], [4, 5], [6, 7], [8, 9], [10, EU]], "qual": "auto"}
	if FileAccess.file_exists(SAVE):
		var lido = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		if lido is Dictionary:
			d.merge(lido, true)
	if not CATEGORIAS.has(d.cat):  # save editado ou de outra versão: não deixa o jogo quebrar
		d.cat = "gt"
	if not d.qual in ["auto", "alta", "leve"]:
		d.qual = "auto"
	_migra_ups(d)
	d.res = _migra_res(d.res)
	d.equipes = d.equipes.map(func(e): return [int(e[0]), int(e[1])])  # o JSON devolve float
	return d


## Save antigo guardava os resultados direto por GP ("0": [...]): eram todos do Turismo GT.
static func _migra_res(res: Dictionary) -> Dictionary:
	for k in res:
		if str(k).is_valid_int():
			return {"gt": res}
	return res


## Cada categoria tem garagem própria (d.ups[cat]). Save antigo tinha uma garagem só (d.up):
## todas as categorias herdam as peças já compradas, para ninguém perder o que pagou.
static func _migra_ups(d: Dictionary) -> void:
	var velho: Dictionary = d.get("up", {})
	_migra_up(velho)
	for c in CATEGORIAS:
		if not d.ups.get(c) is Dictionary:
			d.ups[c] = velho.duplicate(true)
		_migra_up(d.ups[c])
	d.erase("up")


## Save antigo guardava só o nível de cada upgrade: vira a primeira opção de cada nível.
static func _migra_up(up: Dictionary) -> void:
	for k in up:
		if not up[k] is Array:
			var a := []
			a.resize(int(up[k]))
			a.fill(0)
			up[k] = a


func salvar() -> void:
	if teste:
		return
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(s))


func apagar() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	s = _carrega()
	Som.vol(s.vol[0], s.vol[1])


## Peças da garagem da categoria atual: {"motor": [opção do nível 1, ...], ...}.
func up() -> Dictionary:
	return s.ups[s.cat]


func lv(k: String) -> int:
	return up().get(k, []).size()


## Modo leve: pista menos profunda (Race) e som sintetizado a 11 kHz (Som), para PCs fracos.
## "auto" liga em CPU de 2 núcleos ou menos (Celeron e Atom de notebook); "alta" e "leve" forçam.
func leve() -> bool:
	var q: String = s.get("qual", "auto")
	return q == "leve" or (q == "auto" and OS.get_processor_count() <= 2)


## Peça instalada no nível n (0..2) da categoria k: [id, nome, descrição, efeitos].
func peca(k: String, n: int) -> Array:
	return PECAS[k][n][int(up()[k][n])]


## Asa que aparece no carro: a das peças de carenagem, se houver; senão, a do modelo (ver Car.desenhar).
func asa() -> int:
	var a := -1
	for n in lv("aero"):
		match peca("aero", n)[0]:
			"aerofolio": a = maxi(a, 2)
			"drs": a = 3
	return a


## Pontos de performance de uma peça: soma dos efeitos com peso (ex.: +7% de velocidade = 7 pontos).
func pontos(ef_: Dictionary) -> float:
	var t := 0.0
	for e in ef_:
		t += float(ef_[e]) * PESO[e]
	return t


## Preço da opção i do nível n da categoria k, arredondado de 50 em 50 (mínimo $ 300).
func preco(k: String, n: int, i: int) -> int:
	return maxi(300, roundi(pontos(PECAS[k][n][i][3]) * FATOR_NIVEL[n] / 50.0) * 50)


## Ids de todas as peças instaladas (para o timbre do motor).
func pecas_ids() -> Array:
	var ids := []
	for k in up():
		for n in lv(k):
			ids.append(peca(k, n)[0])
	return ids


## Soma de um efeito em todas as peças instaladas.
func ef(e: String) -> float:
	var t := 0.0
	for k in up():
		for n in lv(k):
			t += float(peca(k, n)[3].get(e, 0.0))
	return t


## Efeitos de uma peça em texto, um por linha.
func efeitos_txt(ef_: Dictionary) -> String:
	var l := []
	for e in ef_:
		var f: Array = EFEITO[e]
		var v: float = ef_[e] * f[1]
		l.append(f[0] % (roundi(v) if str(f[0]).contains("%+d") else v))
	return "\n".join(l).replace(".", ",")  # 0,4 s, com vírgula


func multa(v: int) -> int:
	v = mini(int(s.moedas), v)
	s.moedas -= v
	return v


## Prêmio de corrida: enquanto houver dívida, o banco retém metade. Devolve o valor retido.
func receber(v: int) -> int:
	var ret := mini(int(s.divida), v / 2)
	s.divida = int(s.divida) - ret
	s.moedas += v - ret
	return ret


## Colocação do jogador no GP g da categoria (padrão: a atual); 0 = não correu.
func pos_em(g: int, cat := "") -> int:
	var r: Array = s.res.get(cat if cat else s.cat, {}).get(str(g), [])
	for k in r.size():
		if int(r[k]) == EU:  # o JSON devolve números como float
			return k + 1
	return 0


func liberado(g: int, cat := "") -> bool:
	return g == 0 or (pos_em(g - 1, cat) > 0 and pos_em(g - 1, cat) <= 5)


## Módulo estudado na corrida g da categoria (padrão: a atual); "" = corrida final, que revisa tudo.
func mod_gp(g: int, cat := "") -> String:
	var c: String = cat if cat else s.cat
	if SERIES.has(c):
		var ms: Array = SERIES[c][1]
		return ms[g][0] if g < ms.size() else ""
	return PISTAS[g][0]


## Módulos da categoria (a atual, se não vier nenhuma): a matéria da corrida final e do treino.
func mods_cat(cat := "") -> Array:
	var c: String = cat if cat else s.cat
	if SERIES.has(c):
		return SERIES[c][1].map(func(m): return m[0])
	return QuizManager.MODULOS


## Módulos já liberados em qualquer categoria (para as perguntas fora da corrida).
func mods_liberados() -> Array:
	var ms := []
	for c in CATEGORIAS:
		for i in PISTAS.size():
			var m := mod_gp(i, c)
			if liberado(i, c) and m != "" and not m in ms:
				ms.append(m)
	return ms


## GPs em que o jogador chegou entre os 5 primeiros, somando todas as categorias.
func classificados() -> int:
	var n := 0
	for c in CATEGORIAS:
		for i in PISTAS.size():
			if pos_em(i, c) > 0 and pos_em(i, c) <= 5:
				n += 1
	return n


func cat_liberada(c: String) -> bool:
	return classificados() >= int(CATEGORIAS[c].req)


## Melhor colocação do jogador em qualquer corrida (0 = nunca correu).
func melhor_pos() -> int:
	var m := 0
	for c in CATEGORIAS:
		for i in PISTAS.size():
			var p := pos_em(i, c)
			if p > 0 and (m == 0 or p < m):
				m = p
	return m


## Carro-base da categoria atual: o modelo da garagem no GT, o carro da categoria nas demais.
func carro_base() -> Dictionary:
	var c = CATEGORIAS[s.cat].carro
	return c if c else MODELOS[int(s.carro)]


## Efeito total: peças + categoria + bônus da equipe.
func ef_tudo(e: String) -> float:
	return ef(e) + float(CATEGORIAS[s.cat].ef.get(e, 0.0)) + float(EQUIPES[equipe_de(EU)][5].get(e, 0.0))


func equipe_de(p: int) -> int:
	for t in s.equipes.size():
		for q in s.equipes[t]:
			if int(q) == p:
				return t
	return 0


func companheiro() -> int:
	for q in s.equipes[equipe_de(EU)]:
		if int(q) != EU:
			return int(q)
	return 0


## A equipe t faz proposta se a melhor colocação do jogador atende à exigência das estrelas dela.
func proposta(t: int) -> bool:
	var exige: int = PROPOSTA[EQUIPES[t][3]]
	return exige == 0 or (melhor_pos() > 0 and melhor_pos() <= exige)


## Assina com a equipe t: o jogador troca de lugar com o segundo piloto dela.
func assinar(t: int) -> void:
	var minha := equipe_de(EU)
	if t == minha:
		return
	var sai: int = s.equipes[t][1]
	s.equipes[t][1] = EU
	s.equipes[minha][s.equipes[minha].find(EU)] = sai


func tabela(cat := "") -> Array:
	var p := []
	for i in PILOTOS.size():
		p.append({"i": i, "n": PILOTOS[i], "p": 0})
	for ordem in s.res.get(cat if cat else s.cat, {}).values():
		for k in ordem.size():
			p[int(ordem[k])].p += PTS[k]
	p.sort_custom(func(a, b): return a.p > b.p or (a.p == b.p and a.i < b.i))
	return p


## Construtores: pontos dos 2 pilotos de cada equipe, pela equipe em que cada um estava em cada corrida.
func construtores(cat := "") -> Array:
	cat = cat if cat else s.cat
	var t := []
	for i in EQUIPES.size():
		t.append({"i": i, "n": EQUIPES[i][0], "p": 0})
	var res: Dictionary = s.res.get(cat, {})
	var eqs: Dictionary = s.eqres.get(cat, {})
	for g in res:
		var ordem: Array = res[g]
		for k in ordem.size():
			var pil := int(ordem[k])
			var eq: int = int(eqs[g][pil]) if eqs.has(g) else equipe_de(pil)
			t[eq].p += PTS[k]
	t.sort_custom(func(a, b): return a.p > b.p or (a.p == b.p and a.i < b.i))
	return t


func treme(seg: float, forca: float) -> void:
	for d in Input.get_connected_joypads():
		Input.start_joy_vibration(d, forca, forca, seg)


# ------------------------------------------------------------ controles extras (o project.godot traz os da pista)
func _controles() -> void:
	# menus: A confirma e B volta (o padrão do Godot só traz teclado para isso)
	_liga("ui_accept", [_bt(JOY_BUTTON_A)])
	_liga("ui_cancel", [_bt(JOY_BUTTON_B)])
	_liga("accelerate", [_bt(JOY_BUTTON_A), _tc(KEY_UP)])
	_liga("brake", [_tc(KEY_DOWN)])
	_liga("steer_left", [_tc(KEY_LEFT), _bt(JOY_BUTTON_DPAD_LEFT)])
	_liga("steer_right", [_tc(KEY_RIGHT), _bt(JOY_BUTTON_DPAD_RIGHT)])
	_liga("resp_esq", [_bt(JOY_BUTTON_LEFT_SHOULDER), _tc(KEY_Q)])   # resposta da esquerda / marcha − / aba anterior
	_liga("resp_dir", [_bt(JOY_BUTTON_RIGHT_SHOULDER), _tc(KEY_E)])  # resposta da direita / marcha + / próxima aba
	_liga("pausa", [_bt(JOY_BUTTON_START), _tc(KEY_ESCAPE)])
	_liga("ui_up", [_ax(JOY_AXIS_LEFT_Y, -1.0)])
	_liga("ui_down", [_ax(JOY_AXIS_LEFT_Y, 1.0)])
	_liga("ui_left", [_ax(JOY_AXIS_LEFT_X, -1.0)])
	_liga("ui_right", [_ax(JOY_AXIS_LEFT_X, 1.0)])


func _liga(acao: String, eventos: Array) -> void:
	if not InputMap.has_action(acao):
		InputMap.add_action(acao, 0.5)
	for e in eventos:
		InputMap.action_add_event(acao, e)


func _tc(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	return e


func _bt(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	return e


func _ax(a: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	return e


# ------------------------------------------------------------ interface (tema 16 bits e montagem de telas)
func _caixa(fundo: Color, borda: Color, larg := 2) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fundo
	b.border_color = borda
	b.set_border_width_all(larg)
	b.set_content_margin_all(10)
	return b


func _tema() -> void:
	var t := Theme.new()
	t.default_font_size = 22
	t.set_stylebox("normal", "Button", _caixa(Color("#14183a"), Color("#3a4580")))
	t.set_stylebox("hover", "Button", _caixa(Color("#20265a"), Color("#6f80d0")))
	t.set_stylebox("focus", "Button", _caixa(Color(0, 0, 0, 0), AMARELO, 3))
	t.set_stylebox("pressed", "Button", _caixa(Color("#3a3000"), AMARELO))
	t.set_stylebox("disabled", "Button", _caixa(Color("#0c0f24"), Color("#20243a")))
	t.set_color("font_color", "Button", Color("#e8ecff"))
	t.set_color("font_focus_color", "Button", AMARELO)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("#5a6080"))
	t.set_stylebox("panel", "PanelContainer", _caixa(Color(0.03, 0.05, 0.14, 0.94), Color("#dfe6ff")))
	t.set_stylebox("panel", "Panel", _caixa(Color(0.03, 0.05, 0.14, 0.94), Color("#dfe6ff")))
	t.set_color("font_color", "Label", Color("#e8ecff"))
	t.set_color("default_color", "RichTextLabel", Color("#e8ecff"))
	t.set_font_size("normal_font_size", "RichTextLabel", 21)
	t.set_font_size("bold_font_size", "RichTextLabel", 21)
	get_tree().root.theme = t


## Limpa `raiz` e monta o esqueleto da tela: barra de título e coluna de conteúdo (retornada).
func tela(raiz: Control, titulo: String, info := "") -> VBoxContainer:
	for c in raiz.get_children():
		c.queue_free()
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + lado, 28)
	raiz.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)
	var topo := HBoxContainer.new()
	v.add_child(topo)
	rotulo(topo, titulo, 24, AMARELO, true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var din := "$ %d" % int(s.moedas) + ("   dívida $ %d" % int(s.divida) if int(s.divida) > 0 else "")
	rotulo(topo, info if info != "" else din, 24, AMARELO)
	return v


func rotulo(pai: Node, texto: String, tam := 22, cor := Color("#e8ecff"), quebra := false) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	if quebra:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pai.add_child(l)
	return l


func botao(pai: Node, texto: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func(): Som.sfx("sel"); f.call())
	b.focus_entered.connect(Som.sfx.bind("nav"))
	pai.add_child(b)
	return b


func rodape(pai: Node) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.alignment = BoxContainer.ALIGNMENT_END
	pai.add_child(h)
	return h


func expande(c: Control) -> Control:
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c
