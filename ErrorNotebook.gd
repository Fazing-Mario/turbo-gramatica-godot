extends Control
## Caderno de erros: tudo o que foi errado (classificatória, pista, box, garagem, treino), com gabarito.
## Um item sai do caderno quando é acertado tantas vezes quanto foi errado.

const Quiz = preload("res://Quiz.gd")


func _ready() -> void:
	Som.musica("estudo")
	caderno()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file("res://Main.tscn")


func caderno() -> void:
	var lista := QuizManager.erros
	var s := Game.s
	var pct := " (%d%%)" % roundi(100.0 * s.ac / s.tot) if s.tot else ""
	var v := Game.tela(self, "CADERNO DE ERROS — %d itens" % lista.size(), "acertos %d/%d%s" % [int(s.ac), int(s.tot), pct])
	var p := PanelContainer.new()
	Game.expande(p)
	v.add_child(p)
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	p.add_child(t)
	if lista.is_empty():
		t.text = "Nenhum erro registrado. Tudo o que você errar na classificatória, na pista, no box e na inspeção da garagem aparece aqui, com o gabarito comentado."
	for it in lista:
		t.append_text("[color=#9fb4ff]%s · errou %d×[/color]\n%s\n[i][color=#ffd400]Resposta: %s.[/color][/i] %s\n\n" % [
			QuizManager.nome_mod(it.modulo), int(s.err[it.id]), _esc(it.enunciado), _esc(it.opcoes[int(it.certa)]), _esc(it.explicacao)])
	var rod := Game.rodape(v)
	var bm := Game.botao(rod, "◀ MENU", func(): get_tree().change_scene_to_file("res://Main.tscn"))
	var br := Game.botao(rod, "REFAZER ERROS ($ 80 por acerto) ▶", func():
		var itens := lista.duplicate()
		itens.shuffle()
		var q = Quiz.criar(Game.tela(self, "REVISÃO DO CADERNO DE ERROS"), itens.slice(0, 10), {"titulo": "REVISÃO", "premio": 80})
		q.terminou.connect(func(_ac: int): caderno()))
	br.disabled = lista.is_empty()
	(bm if br.disabled else br).call_deferred("grab_focus")


func _esc(x) -> String:
	return str(x).replace("[", "[lb]")
