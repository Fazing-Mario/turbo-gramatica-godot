extends Control
## Menu principal, campeonato, treino livre e opções.

const Quiz = preload("res://Quiz.gd")

var _voltar := Callable()


func _ready() -> void:
	Som.musica("menu")
	if Game.abrir == "campeonato":
		Game.abrir = ""
		campeonato()
	else:
		menu()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") and _voltar.is_valid():
		Som.sfx("sel")
		_voltar.call()
		get_viewport().set_input_as_handled()


func _foco(b: Button) -> void:
	b.call_deferred("grab_focus")


func menu() -> void:
	Som.musica("menu")
	_voltar = Callable()
	var v := Game.tela(self, "", " ")
	var t := Game.rotulo(v, "TURBO GRAMÁTICA RACER", 64, Game.AMARELO)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := Game.rotulo(v, "Campeonato de corrida e gramática · %d questões do edital" % QuizManager.perguntas.size(), 22, Color("#9fb4ff"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var c := CenterContainer.new()
	Game.expande(c)
	v.add_child(c)
	var l := VBoxContainer.new()
	l.custom_minimum_size.x = 560
	l.add_theme_constant_override("separation", 10)
	c.add_child(l)
	var feitos := 0
	for i in Game.PISTAS.size():
		if Game.pos_em(i) > 0 and Game.pos_em(i) <= 5:
			feitos += 1
	_foco(Game.botao(l, "CAMPEONATO %s   (%d/%d corridas)" % [str(Game.CATEGORIAS[Game.s.cat].nome).to_upper(), feitos, Game.PISTAS.size()], campeonato))
	Game.botao(l, "EQUIPES   (%s)" % Game.EQUIPES[Game.equipe_de(Game.EU)][0], equipes)
	Game.botao(l, "GARAGEM   ($ %d)" % int(Game.s.moedas), func(): get_tree().change_scene_to_file("res://Shop.tscn"))
	Game.botao(l, "TREINO LIVRE   (ganhe moedas)", treino)
	Game.botao(l, "CADERNO DE ERROS   (%d itens)" % Game.s.err.size(), func(): get_tree().change_scene_to_file("res://ErrorNotebook.tscn"))
	Game.botao(l, "CONTROLES E OPÇÕES", opcoes)
	Game.botao(l, "SAIR", func(): get_tree().quit())
	var pad := "Controle detectado ✔" if Input.get_connected_joypads().size() > 0 else "Conecte o controle Xbox, ou use o teclado"
	var r := Game.rotulo(v, "%s   ·   acertos: %d/%d" % [pad, int(Game.s.ac), int(Game.s.tot)], 18, Color("#9fb4ff"))
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func campeonato() -> void:
	Som.musica("menu")
	_voltar = menu
	var v := Game.tela(self, "CAMPEONATO %s — top 5 libera a próxima corrida" % str(Game.CATEGORIAS[Game.s.cat].nome).to_upper())
	var cats := HBoxContainer.new()  # categorias: as trancadas mostram quantos GPs classificados faltam
	cats.add_theme_constant_override("separation", 10)
	v.add_child(cats)
	for c in Game.CATEGORIAS:
		var lib := Game.cat_liberada(c)
		var nm: String = Game.CATEGORIAS[c].nome
		var b := Game.botao(cats, ("▶ " + nm) if c == Game.s.cat else (nm if lib else "%s  (%d/%d top 5)" % [nm, Game.classificados(), Game.CATEGORIAS[c].req]), _categoria.bind(c))
		b.disabled = not lib
		b.add_theme_font_size_override("font_size", 18)
		b.tooltip_text = Game.CATEGORIAS[c].desc
	var duas := HBoxContainer.new()
	duas.add_theme_constant_override("separation", 24)
	Game.expande(duas)
	v.add_child(duas)
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_stretch_ratio = 1.8
	sc.follow_focus = true
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	duas.add_child(sc)
	var l := VBoxContainer.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(l)
	var prox: Button = null
	for i in Game.PISTAS.size():
		var g: Array = Game.PISTAS[i]
		if i % 3 == 0:
			Game.rotulo(l, Game.PAISES[g[2]], 20, Game.AMARELO)
		var p := Game.pos_em(i)
		var lib := Game.liberado(i)
		var st := ("%dº" % p) if p else ("NOVA" if lib else "TRANCADA")
		var b := Game.botao(l, "%s — %s   [%s]" % [g[1], QuizManager.nome_mod(Game.mod_gp(i)), st], _gp.bind(i))
		b.disabled = not lib
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 19)
		if lib:
			prox = b
	var tab := PanelContainer.new()
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duas.add_child(tab)
	var tv := VBoxContainer.new()
	tab.add_child(tv)
	Game.rotulo(tv, "PILOTOS", 18, Game.AMARELO)
	var tb := Game.tabela()
	for k in tb.size():
		Game.rotulo(tv, "%2dº  %-16s %3d" % [k + 1, tb[k].n, tb[k].p], 15, Game.AMARELO if tb[k].i == Game.EU else Color("#e8ecff"))
	Game.rotulo(tv, "CONSTRUTORES", 18, Game.AMARELO)
	var minha := Game.equipe_de(Game.EU)
	var ct := Game.construtores()
	for k in ct.size():
		Game.rotulo(tv, "%dº  %-20s %3d" % [k + 1, ct[k].n, ct[k].p], 15, Game.AMARELO if ct[k].i == minha else Color(Game.EQUIPES[ct[k].i][1]).lightened(0.3))
	var rod := Game.rodape(v)
	Game.botao(rod, "◀ MENU", menu)
	Game.botao(rod, "GARAGEM ▶", func(): get_tree().change_scene_to_file("res://Shop.tscn"))
	if prox:
		_foco(prox)


func _categoria(c: String) -> void:
	Game.s.cat = c
	Game.salvar()
	campeonato()


## Equipes: bônus, patrocínio, pilotos e propostas de contrato.
func equipes() -> void:
	Som.musica("menu")
	_voltar = menu
	var minha := Game.equipe_de(Game.EU)
	var v := Game.tela(self, "EQUIPES — você corre pela %s, ao lado de %s" % [Game.EQUIPES[minha][0], Game.PILOTOS[Game.companheiro()]])
	var mp := Game.melhor_pos()
	Game.rotulo(v, "Cada equipe dá um bônus ao seu carro e tem um patrocinador que paga em toda corrida em que você bater a meta. As melhores só fazem proposta depois de bons resultados (sua melhor colocação: %s)." % ("%dº" % mp if mp else "nenhuma corrida"), 18, Color("#9fb4ff"), true)
	var sc := ScrollContainer.new()
	sc.follow_focus = true
	Game.expande(sc)
	v.add_child(sc)
	var l := VBoxContainer.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(l)
	var foco: Button = null
	for t in Game.EQUIPES.size():
		var eq: Array = Game.EQUIPES[t]
		var lin := HBoxContainer.new()
		l.add_child(lin)
		for k in [1, 2]:  # cores da equipe
			var cr := ColorRect.new()
			cr.color = Color(eq[k])
			cr.custom_minimum_size.x = 14 if k == 1 else 6
			lin.add_child(cr)
		var exige: int = Game.PROPOSTA[eq[3]]
		var st := "SUA EQUIPE" if t == minha else ("ASSINAR CONTRATO ▶" if Game.proposta(t) else "sem proposta: precisa de %s" % (
			"uma vitória" if exige == 1 else ("um pódio" if exige == 3 else "um top %d" % exige)))
		var pil := " & ".join(Game.s.equipes[t].map(func(p): return Game.PILOTOS[int(p)]))
		var b := Game.botao(lin, "%s  %s   ·   %s\nBônus: %s   ·   Patrocínio: %s → $ %d   ·   %s" % [eq[0], "★".repeat(eq[3]) + "☆".repeat(5 - eq[3]),
			pil, Game.efeitos_txt(eq[5]).replace("\n", ", "), eq[6][3], eq[6][2], st], _assinar.bind(t))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 16)
		b.disabled = t != minha and not Game.proposta(t)
		if t == minha:
			foco = b
	Game.botao(Game.rodape(v), "◀ MENU", menu)
	_foco(foco)


func _assinar(t: int) -> void:
	if t == Game.equipe_de(Game.EU):
		return
	Game.assinar(t)
	Game.salvar()
	Som.sfx("fanfarra")
	equipes()


func _gp(i: int) -> void:
	Game.gp = i
	get_tree().change_scene_to_file("res://Study.tscn")


func treino() -> void:
	Som.musica("estudo")
	_voltar = menu
	var v := Game.tela(self, "TREINO LIVRE — 6 perguntas, $ 40 por acerto, sem multa")
	var sc := ScrollContainer.new()
	sc.follow_focus = true
	Game.expande(sc)
	v.add_child(sc)
	var l := VBoxContainer.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(l)
	_foco(Game.botao(l, "TUDO MISTURADO (Gramática)", _treinar.bind(QuizManager.MODULOS)))
	for i in QuizManager.MODULOS.size():
		var m: String = QuizManager.MODULOS[i]
		Game.botao(l, "%d. %s" % [i + 1, QuizManager.nome_mod(m)], _treinar.bind([m]))
	for c in Game.SERIES:  # séries de Linguística: só as categorias já liberadas
		if not Game.cat_liberada(c):
			continue
		var ms: Array = Game.mods_cat(c)
		Game.rotulo(l, Game.SERIES[c][0], 20, Game.AMARELO)
		Game.botao(l, "TUDO MISTURADO (%s)" % Game.CATEGORIAS[c].nome, _treinar.bind(ms))
		for m in ms:
			Game.botao(l, QuizManager.nome_mod(m), _treinar.bind([m]))
	Game.botao(Game.rodape(v), "◀ MENU", menu)


func _treinar(ms: Array) -> void:
	_voltar = treino
	var v := Game.tela(self, "TREINO LIVRE")
	var itens := QuizManager.sorteia(ms, 3, "ce") + QuizManager.sorteia(ms, 3, "ab")
	itens.shuffle()
	var q = Quiz.criar(v, itens, {"titulo": "TREINO LIVRE", "premio": 40})
	q.terminou.connect(func(ac: int):
		var r := Game.tela(self, "TREINO CONCLUÍDO")
		Game.expande(Game.rotulo(r, "%d/%d acertos  ·  +$ %d" % [ac, itens.size(), ac * 40], 40, Game.AMARELO))
		var rod := Game.rodape(r)
		Game.botao(rod, "◀ MENU", menu)
		_foco(Game.botao(rod, "OUTRO TREINO ▶", treino)))


func opcoes(confirmar := false) -> void:
	_voltar = menu
	var v := Game.tela(self, "CONTROLES E OPÇÕES")
	var duas := HBoxContainer.new()
	duas.add_theme_constant_override("separation", 32)
	Game.expande(duas)
	v.add_child(duas)
	var ajuda := Game.rotulo(duas, "\n".join([
		"Acelerar ............ RT ou A   ·  W / ↑",
		"Frear ............... LT        ·  S / ↓",
		"Direção ............. analógico / direcional  ·  A D / ← →",
		"Nitro ............... X         ·  Espaço",
		"Pit-stop (zona BOX) . Y         ·  P",
		"Responder esq./dir. . LB / RB   ·  Q / E",
		"Marcha −/+ (manual) . LB / RB   ·  Q / E",
		"Pausa ............... Start     ·  Esc",
		"Menus ............... A confirma, B volta  ·  Enter, Esc"]), 20)
	ajuda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := VBoxContainer.new()
	l.custom_minimum_size.x = 420
	duas.add_child(l)
	var pc := func(x: float) -> String: return "%d%%" % roundi(x * 100)
	_foco(Game.botao(l, "CÂMBIO: " + ("MANUAL" if Game.s.manual else "AUTOMÁTICO"), func():
		Game.s.manual = not Game.s.manual
		Game.salvar()
		opcoes()))
	Game.botao(l, "MÚSICA: " + pc.call(Game.s.vol[0]), _volume.bind(0))
	Game.botao(l, "EFEITOS: " + pc.call(Game.s.vol[1]), _volume.bind(1))
	var qual := {"auto": "AUTOMÁTICA", "alta": "ALTA", "leve": "LEVE"}
	Game.botao(l, "QUALIDADE: %s%s" % [qual[Game.s.get("qual", "auto")], " (leve)" if Game.s.get("qual", "auto") == "auto" and Game.leve() else ""], func():
		var ordem := ["auto", "alta", "leve"]
		Game.s.qual = ordem[(ordem.find(Game.s.get("qual", "auto")) + 1) % 3]
		Game.salvar()
		opcoes())
	Game.rotulo(l, "Leve = pista mais curta e som mais simples (bom para PCs fracos). A pista muda na próxima corrida; o som, ao reabrir o jogo.", 14, Color("#9fb4ff"), true)
	Game.botao(l, "TELA CHEIA", func():
		var cheia := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if cheia else DisplayServer.WINDOW_MODE_FULLSCREEN))
	Game.botao(l, "CONFIRMAR: APAGAR TUDO" if confirmar else "APAGAR PROGRESSO", func():
		if not confirmar:
			opcoes(true)
			return
		Game.apagar()
		menu())
	Game.botao(Game.rodape(v), "◀ MENU", menu)


func _volume(i: int) -> void:
	Game.s.vol[i] = fmod(Game.s.vol[i] + 0.25, 1.25)
	Som.vol(Game.s.vol[0], Game.s.vol[1])
	Game.salvar()
	opcoes()
