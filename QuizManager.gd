extends Node
## Autoload: material dos módulos (dados/conteudo.json), banco de questões (questions.json)
## e registro de acertos e erros (gravado no save do Game).
## Tipos de item: "ce" = Certo/Errado (estilo Cebraspe), "ab" = pergunta-relâmpago com duas opções.

const MODULOS := ["m1", "m2", "m3", "m4", "m5", "m6", "m7", "m8", "m9", "m10"]

var perguntas: Array = []
var por_id: Dictionary = {}
var modulos: Dictionary = {}  # id -> {titulo, nivel, edital, abas: [[nome, bbcode], ...]}

## Itens do caderno de erros, do mais errado para o menos errado.
var erros: Array:
	get:
		var ids: Array = Game.s.err.keys().filter(func(id): return por_id.has(id))
		ids.sort_custom(func(a, b): return Game.s.err[a] > Game.s.err[b])
		return ids.map(func(id): return por_id[id])


func _ready() -> void:
	carregar_perguntas()


func carregar_perguntas() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://questions.json"))
	var mat = JSON.parse_string(FileAccess.get_file_as_string("res://dados/conteudo.json"))
	if not (data is Dictionary and mat is Dictionary):
		push_error("questions.json ou dados/conteudo.json não encontrado ou inválido")
		return
	perguntas = data["perguntas"]
	var todos: Array = MODULOS.duplicate()
	for c in Game.SERIES:  # módulos de Linguística: o conteudo.json não os conhece
		for m in Game.SERIES[c][1]:
			todos.append(m[0])
			mat["modulos"].append({"id": m[0], "nivel": Game.SERIES[c][0], "titulo": m[1], "edital": m[2], "abas": []})
	for m in todos:  # questões extras em texto (dados/questoes/<módulo>.txt)
		var arq := "res://dados/questoes/%s.txt" % m
		if FileAccess.file_exists(arq):
			perguntas.append_array(questoes(m, FileAccess.get_file_as_string(arq)))
	for p in perguntas:
		por_id[p.id] = p
	for m in mat["modulos"]:
		modulos[m.id] = m
		# aula em texto simples, se houver, substitui as abas do conteudo.json
		# shortcut: .txt não entra no jogo exportado sem o filtro "*.txt" nas opções de exportação
		var arq := "res://dados/aulas/%s.txt" % m.id
		if FileAccess.file_exists(arq):
			m.abas = aulas(FileAccess.get_file_as_string(arq))


## Questões em texto, uma por linha ("#" = comentário). O id vem da posição (m1n0, m1n1...):
## acrescente sempre no fim do arquivo, senão o caderno de erros perde a referência.
##   CE | C ou E | enunciado | explicação
##   AB | enunciado | opção certa | opção errada | explicação   (a ordem é sorteada na tela)
static func questoes(mod: String, txt: String) -> Array:
	var out := []
	for bruta in txt.split("\n"):
		var l := bruta.strip_edges()
		if l == "" or l.begins_with("#"):
			continue
		var c := Array(l.split("|")).map(func(x): return x.strip_edges())
		var id := "%sn%d" % [mod, out.size()]
		if c[0] == "CE" and c.size() == 4 and c[1] in ["C", "E"]:
			out.append({"id": id, "modulo": mod, "tipo": "ce", "enunciado": c[2], "opcoes": ["CERTO", "ERRADO"],
				"certa": 0 if c[1] == "C" else 1, "explicacao": c[3]})
		elif c[0] == "AB" and c.size() == 5:
			out.append({"id": id, "modulo": mod, "tipo": "ab", "enunciado": c[1], "opcoes": [c[2], c[3]], "certa": 0, "explicacao": c[4]})
		else:
			push_error("questoes/%s.txt: linha ignorada (formato inválido): %s" % [mod, l])
	return out


## Converte a marcação leve das aulas em abas com BBCode:
## "=== Nome" abre aba · "## " título · "### " subtítulo · "- " tópico · "  - " subtópico · "> " destaque ·
## linhas com "|" formam tabela (a primeira é o cabeçalho; "|---" é ignorada) · **negrito**.
static func aulas(txt: String) -> Array:
	var abas := []
	var linhas := []
	var tab := []
	var negrito := RegEx.new()
	negrito.compile("\\*\\*(.+?)\\*\\*")
	var fecha_tabela := func():
		if tab.is_empty():
			return
		var n: int = tab[0].size()
		var s := "[table=%d]" % n
		for i in tab.size():
			for c in tab[i]:
				s += "[cell][b][color=#ffd400]%s[/color][/b][/cell]" % c if i == 0 else "[cell]%s[/cell]" % c
		linhas.append(s + "[/table]")
		tab.clear()
	var fecha_aba := func():
		fecha_tabela.call()
		if not abas.is_empty():
			abas[-1][1] = "\n".join(linhas).lstrip("\n").rstrip("\n ")  # mantém o recuo do primeiro tópico
		linhas.clear()
	for bruta in txt.split("\n"):
		var l: String = negrito.sub(bruta.strip_edges(false, true).replace("[", "[lb]"), "[b]$1[/b]", true)
		if l.begins_with("==="):
			fecha_aba.call()
			abas.append([l.trim_prefix("===").strip_edges(), ""])
		elif l.strip_edges().begins_with("|"):
			if l.contains("---"):
				continue
			var cel := Array(l.strip_edges().trim_prefix("|").trim_suffix("|").split("|")).map(func(c): return c.strip_edges())
			if not tab.is_empty() and cel.size() != tab[0].size():
				fecha_tabela.call()
			tab.append(cel)
		else:
			fecha_tabela.call()
			if l.begins_with("### "):
				linhas.append("[color=#9fb4ff][b]%s[/b][/color]" % l.substr(4))
			elif l.begins_with("## "):
				linhas.append("[font_size=26][color=#ffd400][b]%s[/b][/color][/font_size]" % l.substr(3))
			elif l.begins_with("  - "):
				linhas.append("         ◦ " + l.substr(4))
			elif l.begins_with("- "):
				linhas.append("   • " + l.substr(2))
			elif l.begins_with("> "):
				linhas.append("[color=#9dffb8]» %s[/color]" % l.substr(2))
			else:
				linhas.append(l)
	fecha_aba.call()
	return abas


func nome_mod(m: String) -> String:
	return modulos[m].titulo if modulos.has(m) else "todo o edital"


## Sorteia n itens dos módulos, priorizando os menos vistos e os que estão no caderno de erros.
func sorteia(mods: Array, n: int, tipo: String) -> Array:
	var visto: Dictionary = Game.s.visto
	var err: Dictionary = Game.s.err
	var pares := []
	for p in perguntas:
		if p.tipo == tipo and p.modulo in mods:
			pares.append([float(visto.get(p.id, 0)) - (1.5 if err.has(p.id) else 0.0) + randf() * 0.9, p])
	pares.sort_custom(func(a, b): return a[0] < b[0])
	return pares.slice(0, n).map(func(x): return x[1])


func registrar_resposta(pergunta: Dictionary, acertou: bool) -> void:
	var s := Game.s
	var id: String = pergunta.id
	s.visto[id] = int(s.visto.get(id, 0)) + 1
	s.tot += 1
	if acertou:
		s.ac += 1
		if s.err.has(id):
			s.err[id] = int(s.err[id]) - 1
			if s.err[id] <= 0:
				s.err.erase(id)
	else:
		s.err[id] = int(s.err.get(id, 0)) + 1
	Game.salvar()
