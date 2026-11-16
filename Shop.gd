extends Control
## Garagem: modelo do carro, pintura e peças. Cada categoria tem 3 níveis e, em cada nível, 2 peças à escolha.
## Toda peça passa por uma INSPEÇÃO de perguntas (nível n exige n acertos seguidos); reprovar custa 25% do preço.

const Quiz = preload("res://Quiz.gd")
const Car = preload("res://Car.gd")
const Pecas = preload("res://Pecas.gd")

var _sub := ""  # categoria aberta na tela de escolha/inspeção ("" = garagem)


func _ready() -> void:
	Som.musica("menu")
	garagem("")


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _sub != "":
			garagem("", _sub)
		else:
			get_tree().change_scene_to_file("res://Main.tscn")


func _exit_tree() -> void:
	Som.motor(-1)  # não deixa o motor ligado se sair no meio da acelerada


## Acelera o motor por uns 3 s com o timbre do carro atual (mais uma peça candidata, se houver).
func _ouvir(extra: Array = []) -> void:
	Som.timbre(Game.s.cat, int(Game.s.carro), Game.pecas_ids() + extra)
	var tw := create_tween()
	tw.tween_method(func(p: float): Som.motor(p, 1.0), 0.12, 1.0, 1.2)
	tw.tween_callback(Som.sfx.bind("marcha"))
	tw.tween_method(func(p: float): Som.motor(p, 1.0), 0.62, 1.0, 0.8)
	tw.tween_method(func(p: float): Som.motor(p, 0.0), 1.0, 0.12, 0.9)
	tw.tween_callback(Som.motor.bind(-1))


## Área com o desenho de uma peça; id "" = vaga vazia.
func _icone(pai: Control, id: String, esc: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(48, 32) * esc
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # texto do desenho ampliado sem borrar
	c.draw.connect(func(): Pecas.desenhar(c, id, Vector2(24, 16) * esc, esc))
	pai.add_child(c)
	return c


func garagem(msg: String, foco := "") -> void:
	_sub = ""
	var v := Game.tela(self, "GARAGEM — cada peça passa por uma inspeção de perguntas")
	if msg != "":
		Game.rotulo(v, msg, 22, Color("#9dffb8"), true)
	var duas := HBoxContainer.new()
	duas.add_theme_constant_override("separation", 24)
	Game.expande(duas)
	v.add_child(duas)
	# carro e pintura
	var pc := PanelContainer.new()
	pc.custom_minimum_size.x = 440
	duas.add_child(pc)
	var esq := VBoxContainer.new()
	pc.add_child(esq)
	var prev := Control.new()
	prev.custom_minimum_size = Vector2(400, 150)
	var eq: Array = Game.EQUIPES[Game.equipe_de(Game.EU)]
	prev.draw.connect(func(): Car.desenhar(prev, Vector2(200, 146), 3.6, int(Game.s.carro), Color(Game.PINT[int(Game.s.cor)][1]), 0, false,
		Game.asa(), Game.s.cat, Color(eq[1])))
	esq.add_child(prev)
	var md := Game.carro_base()
	var gt: bool = Game.s.cat == "gt"
	Game.rotulo(esq, "%s · %s" % [md.nome, eq[0]], 24, Game.AMARELO)
	Game.rotulo(esq, md.desc if gt else Game.CATEGORIAS[Game.s.cat].desc, 18, Color("#9fb4ff"), true)
	var barra := func(x: float) -> String: return "█".repeat(roundi(x * 5)) + "░".repeat(maxi(0, 8 - roundi(x * 5)))
	Game.rotulo(esq, "VELOCIDADE  %s\nACELERAÇÃO  %s\nADERÊNCIA   %s\nECONOMIA    %s" % [
		barra.call(md.vel * (1 + Game.ef_tudo("vel"))), barra.call(md.ace * (1 + Game.ef_tudo("ace"))),
		barra.call(md.ade * (1 + Game.ef_tudo("ade"))), barra.call((1 + Game.ef_tudo("tanque")) / (md.con * (1 + Game.ef_tudo("con"))))], 18)
	# o modelo só se escolhe no Turismo GT; nas outras categorias o carro é o da categoria
	var bm := Game.botao(esq, "TROCAR CARRO ▶" if gt else "CARRO DA CATEGORIA %s" % str(Game.CATEGORIAS[Game.s.cat].nome).to_upper(), func():
		Game.s.carro = (int(Game.s.carro) + 1) % Game.MODELOS.size()
		Game.salvar()
		garagem("Carro: %s." % Game.MODELOS[int(Game.s.carro)].nome, "carro"))
	bm.disabled = not gt
	var cores := GridContainer.new()
	cores.columns = 5
	esq.add_child(cores)
	var bc: Button = null
	for i in Game.PINT.size():
		var tem: bool = float(i) in Game.s.cores or i in Game.s.cores
		var b := Game.botao(cores, "" if tem else str(Game.PRECO_PINTURA), _pintar.bind(i))
		b.custom_minimum_size = Vector2(76, 40)
		b.add_theme_stylebox_override("normal", Game._caixa(Color(Game.PINT[i][1]), Color.WHITE if i == int(Game.s.cor) else Color(0, 0, 0, 0)))
		b.add_theme_stylebox_override("hover", Game._caixa(Color(Game.PINT[i][1]).lightened(0.2), Color.WHITE))
		b.tooltip_text = Game.PINT[i][0]
		if foco == "cor%d" % i:
			bc = b
	# peças
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.follow_focus = true
	duas.add_child(sc)
	var dir := VBoxContainer.new()
	dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(dir)
	var primeiro: Button = null
	for u in Game.UPS:
		var k: String = u[0]
		var n := Game.lv(k)
		var linha := HBoxContainer.new()
		dir.add_child(linha)
		var nomes := []
		for j in 3:  # as 3 vagas da categoria: peça instalada ou vazia
			var id: String = Game.peca(k, j)[0] if j < n else ""
			_icone(linha, id, 1.5)
			if j < n:
				nomes.append(Game.peca(k, j)[1])
		var prox := "COMPLETO" if n >= 3 else "Próximo: %s ($ %d) ou %s ($ %d)" % [
			Game.PECAS[k][n][0][1], Game.preco(k, n, 0), Game.PECAS[k][n][1][1], Game.preco(k, n, 1)]
		var b := Game.botao(linha, "%s  %s\n%s" % [u[1], " · ".join(nomes) if n else "original de fábrica", prox], _escolher.bind(k))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 18)
		b.disabled = n >= 3
		if foco == k or (primeiro == null and not b.disabled):
			primeiro = b
	var rod := Game.rodape(v)
	var deve := int(Game.s.divida)
	Game.botao(rod, "♪ OUVIR MOTOR", _ouvir.bind([]))
	var bb := Game.botao(rod, "QUITAR DÍVIDA ($ %d)" % deve if deve else "BANCO: EMPRÉSTIMO $ %d" % Game.EMPRESTIMO, _quitar if deve else _emprestimo)
	Game.botao(rod, "◀ MENU", func(): get_tree().change_scene_to_file("res://Main.tscn"))
	var bcamp := Game.botao(rod, "CAMPEONATO ▶", func():
		Game.abrir = "campeonato"
		get_tree().change_scene_to_file("res://Main.tscn"))
	var alvo: Button = bm if foco == "carro" else bb if foco == "banco" else (bc if bc else (primeiro if primeiro else bcamp))
	alvo.call_deferred("grab_focus")


func _pintar(i: int) -> void:
	var tem: bool = float(i) in Game.s.cores or i in Game.s.cores
	if not tem:
		if Game.s.moedas < Game.PRECO_PINTURA:
			garagem("Faltam moedas para a pintura ($ %d)." % Game.PRECO_PINTURA, "cor%d" % i)
			return
		Game.s.moedas -= Game.PRECO_PINTURA
		Game.s.cores.append(i)
		Som.sfx("moeda")
	Game.s.cor = i
	Game.salvar()
	garagem("Pintura %s aplicada." % Game.PINT[i][0], "cor%d" % i)


## Empréstimo único: a análise de crédito tem 3 perguntas e cada acerto baixa os juros (40% → 10%).
func _emprestimo() -> void:
	var v := Game.tela(self, "BANCO — análise de crédito")
	Game.rotulo(v, "Empréstimo de $ %d. Cada acerto baixa os juros (0 acertos = 40%%, 3 acertos = 10%%). Até quitar, o banco retém metade dos prêmios de corrida." % Game.EMPRESTIMO, 20, Color("#9fb4ff"), true)
	var q = Quiz.criar(v, QuizManager.sorteia(Game.mods_liberados(), 3, "ce"), {"titulo": "Análise de crédito"})
	q.terminou.connect(func(ac: int):
		var j := 40 - 10 * ac
		Game.s.moedas += Game.EMPRESTIMO
		Game.s.divida = roundi(Game.EMPRESTIMO * (1 + j / 100.0))
		Game.salvar()
		Som.sfx("moeda")
		garagem("Empréstimo liberado: +$ %d com juros de %d%%. Você deve $ %d." % [Game.EMPRESTIMO, j, Game.s.divida], "banco"))


func _quitar() -> void:
	var p := mini(int(Game.s.moedas), int(Game.s.divida))
	Game.s.moedas -= p
	Game.s.divida = int(Game.s.divida) - p
	Game.salvar()
	garagem("Pagou $ %d. %s" % [p, "Dívida quitada!" if Game.s.divida == 0 else "Ainda deve $ %d." % Game.s.divida], "banco")


## Tela de escolha: as 2 peças do próximo nível, lado a lado, com desenho e efeitos.
func _escolher(k: String) -> void:
	var n := Game.lv(k)
	if n >= 3:
		return
	_sub = k
	var cat: String = Game.UPS.filter(func(u): return u[0] == k)[0][1]
	var v := Game.tela(self, "%s — nível %d: escolha uma peça" % [cat.to_upper(), n + 1])
	Game.rotulo(v, "Preço pelo ganho de performance · inspeção de %d pergunta%s (acerte todas ou pague multa de 25%% do preço)" % [
		n + 1, "s" if n else ""], 20, Color("#9fb4ff"), true)
	var duas := HBoxContainer.new()
	duas.add_theme_constant_override("separation", 24)
	Game.expande(duas)
	v.add_child(duas)
	var b0: Button = null
	for i in 2:
		var pc: Array = Game.PECAS[k][n][i]
		var painel := PanelContainer.new()
		painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		duas.add_child(painel)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		painel.add_child(col)
		var cx := CenterContainer.new()
		col.add_child(cx)
		_icone(cx, pc[0], 6.0)
		Game.rotulo(col, pc[1], 28, Game.AMARELO)
		Game.rotulo(col, pc[2], 20, Color("#cfd8ff"), true)
		for e in pc[3]:  # ganho em verde, perda em vermelho
			var ruim: bool = float(pc[3][e]) * Game.PESO[e] < 0
			Game.rotulo(col, Game.efeitos_txt({e: pc[3][e]}), 22, Color("#ff8a7a") if ruim else Color("#9dffb8"))
		Game.rotulo(col, "Performance: %d pontos" % roundi(Game.pontos(pc[3])), 20, Color("#cfd8ff"))
		col.add_child(Game.expande(Control.new()))
		Game.botao(col, "♪ OUVIR O MOTOR COM ESTA PEÇA", _ouvir.bind([pc[0]])).alignment = HORIZONTAL_ALIGNMENT_CENTER
		var b := Game.botao(col, "INSTALAR — $ %d" % Game.preco(k, n, i), _comprar.bind(k, i))
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		if b0 == null:
			b0 = b
	var rod := Game.rodape(v)
	Game.botao(rod, "◀ VOLTAR", garagem.bind("", k))
	b0.call_deferred("grab_focus")


func _comprar(k: String, escolha: int) -> void:
	var n := Game.lv(k)
	var p := Game.preco(k, n, escolha)
	var nome: String = Game.PECAS[k][n][escolha][1]
	if Game.s.moedas < p:
		garagem("Faltam $ %d para %s. Corra, treine ou refaça o caderno de erros." % [p - int(Game.s.moedas), nome], k)
		return
	var m := roundi(p * 0.25)
	var v := Game.tela(self, "INSPEÇÃO — %s" % nome)
	var q = Quiz.criar(v, QuizManager.sorteia(Game.mods_liberados(), n + 1, "ce"),
		{"titulo": "Acerte %d de %d ou pague multa de $ %d" % [n + 1, n + 1, m], "parar": true})
	q.terminou.connect(func(ac: int):
		if ac < n + 1:
			garagem("REPROVADO na inspeção: multa de $ %d e %s não instalado. O item errado está no caderno de erros." % [Game.multa(m), nome], k)
			Game.salvar()
			return
		Game.s.moedas -= p
		var lista: Array = Game.s.up.get(k, [])
		lista.append(escolha)
		Game.s.up[k] = lista
		Game.salvar()
		Som.sfx("moeda")
		garagem("APROVADO: %s instalado por $ %d." % [nome, p], k))
