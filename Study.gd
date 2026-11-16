extends Control
## Antes de cada Grand Prix: briefing com o material do módulo (abas) e classificatória,
## que define a posição de largada.

const Quiz = preload("res://Quiz.gd")

var g := 0
var abas: Array = []
var aba := 0
var _texto: RichTextLabel
var _voltar := Callable()


func _ready() -> void:
	g = Game.gp
	Som.musica("estudo")
	var m := Game.mod_gp(g)
	if m != "":
		abas = QuizManager.modulos[m].abas
	else:  # corrida final: estratégia (só na Gramática) + revisão rápida de todos os módulos da categoria
		abas = [["Estratégia", QuizManager.modulos["m0"].abas[0][1]]] if Game.s.cat == "gt" else []
		var ms := Game.mods_cat()
		for i in ms.size():
			var mod: Dictionary = QuizManager.modulos[ms[i]]
			for a in mod.abas:
				if a[0] == "Revisão rápida":
					abas.append([str(i + 1), "[font_size=26][color=#ffd400][b]%s[/b][/color][/font_size]\n\n%s" % [mod.titulo, a[1]]])
	briefing()


func _mods() -> Array:
	var m := Game.mod_gp(g)
	return [m] if m != "" else Game.mods_cat()


func briefing() -> void:
	_voltar = func():
		Game.abrir = "campeonato"
		get_tree().change_scene_to_file("res://Main.tscn")
	var v := Game.tela(self, "BRIEFING — %s · %s" % [Game.PISTAS[g][1], QuizManager.nome_mod(Game.mod_gp(g))], "LB / RB: abas · analógico direito: rolar")
	var h := HBoxContainer.new()
	v.add_child(h)
	for i in abas.size():
		var b := Game.botao(h, abas[i][0], _aba.bind(i))
		b.focus_mode = Control.FOCUS_NONE
		if i == aba:
			b.add_theme_color_override("font_color", Game.AMARELO)
			b.add_theme_stylebox_override("normal", b.get_theme_stylebox("focus"))
	var p := PanelContainer.new()
	Game.expande(p)
	v.add_child(p)
	_texto = RichTextLabel.new()
	_texto.bbcode_enabled = true
	_texto.text = abas[aba][1]
	_texto.focus_mode = Control.FOCUS_NONE
	p.add_child(_texto)
	var rod := Game.rodape(v)
	Game.botao(rod, "◀ VOLTAR", _voltar)
	Game.botao(rod, "CLASSIFICATÓRIA ▶", classificatoria).call_deferred("grab_focus")


func _aba(i: int) -> void:
	aba = posmod(i, abas.size())
	briefing()


func _process(dt: float) -> void:
	if _texto and is_instance_valid(_texto):
		var eixo := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y) if Input.get_connected_joypads().size() > 0 else 0.0
		if Input.is_action_pressed("ui_page_down"):
			eixo = 1.0
		elif Input.is_action_pressed("ui_page_up"):
			eixo = -1.0
		if absf(eixo) > 0.2:
			_texto.get_v_scroll_bar().value += eixo * 900.0 * dt


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") and _voltar.is_valid():
		_voltar.call()
	elif _texto and is_instance_valid(_texto) and e.is_action_pressed("resp_esq"):
		_aba(aba - 1)
	elif _texto and is_instance_valid(_texto) and e.is_action_pressed("resp_dir"):
		_aba(aba + 1)
	else:
		return
	get_viewport().set_input_as_handled()


func classificatoria() -> void:
	_voltar = briefing
	_texto = null
	var v := Game.tela(self, "CLASSIFICATÓRIA — %s" % Game.PISTAS[g][1])
	var q = Quiz.criar(v, QuizManager.sorteia(_mods(), 5, "ce"),
		{"titulo": "CLASSIFICATÓRIA (erro: multa de $ 40 e posições no grid)", "premio": 60, "multa": 40})
	q.terminou.connect(_grid)


func _grid(ac: int) -> void:
	var pos: int = Game.GRID[ac]
	var v := Game.tela(self, "GRID DE LARGADA — %s" % Game.PISTAS[g][1])
	var c := CenterContainer.new()
	Game.expande(c)
	v.add_child(c)
	var l := VBoxContainer.new()
	l.custom_minimum_size.x = 900
	c.add_child(l)
	Game.rotulo(l, "%d/5 → você larga em %dº" % [ac, pos], 48, Game.AMARELO).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Game.rotulo(l, "Caixas ? na pista: pergunta-relâmpago (LB/RB). Acerto = +1 nitro. Erro = motor engasga e multa.\n" +
		"O tanque não dura a corrida inteira: na reta final de cada volta, Y entra no BOX. " +
		"Acerto no box = parada de 2 s e +1 nitro; erro = parada de 7 s.", 22, Color.WHITE, true)
	var rod := Game.rodape(v)
	Game.botao(rod, "◀ ESTUDAR DE NOVO", briefing)
	Game.botao(rod, "LARGAR ▶", func():
		Game.grid = pos
		get_tree().change_scene_to_file("res://Race.tscn")).call_deferred("grab_focus")
