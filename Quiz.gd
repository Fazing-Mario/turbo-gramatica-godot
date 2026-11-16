extends VBoxContainer
## Sequência de perguntas usada na classificatória, inspeção da garagem, treino e caderno de erros.
## cfg: titulo, premio (por acerto), multa (por erro), parar (encerra no primeiro erro).
## Responde com os botões, ou LB / RB (Q / E no teclado).

signal terminou(acertos: int)

var itens: Array = []
var cfg: Dictionary = {}
var _k := 0
var _ac := 0
var _troca := false
var _feito := false
var _topo: Label
var _mod: Label
var _enun: Label
var _ops: Array = []
var _fb: Label
var _prox: Button


static func criar(pai: Control, lista: Array, config: Dictionary) -> Node:
	var q = load("res://Quiz.gd").new()
	q.itens = lista
	q.cfg = config
	q.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pai.add_child(q)
	return q


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	_topo = Game.rotulo(self, "", 20, Game.AMARELO)
	_mod = Game.rotulo(self, "", 18, Color("#9fb4ff"))
	_enun = Game.rotulo(self, "", 28, Color.WHITE, true)
	_enun.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	add_child(h)
	for lado in 2:
		var b := Game.botao(h, "", _responder.bind(lado))
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 64
		_ops.append(b)
	_fb = Game.rotulo(self, "", 22, Color.WHITE, true)
	_prox = Game.botao(Game.rodape(self), "CONTINUAR ▶", _mostrar)
	_mostrar()


func _mostrar() -> void:
	if _k >= itens.size() or (cfg.get("parar", false) and _ac < _k):
		terminou.emit(_ac)
		return
	var it: Dictionary = itens[_k]
	_troca = it.tipo == "ab" and randf() < 0.5
	_topo.text = "%s   ·   %d/%d   ·   $ %d" % [cfg.get("titulo", ""), _k + 1, itens.size(), int(Game.s.moedas)]
	_mod.text = QuizManager.nome_mod(it.modulo)
	_enun.text = it.enunciado
	for lado in 2:
		var b: Button = _ops[lado]
		b.text = ("[LB]  " if lado == 0 else "") + str(it.opcoes[1 - lado if _troca else lado]) + ("  [RB]" if lado == 1 else "")
		b.disabled = false
		b.modulate = Color.WHITE
	_fb.text = ""
	_prox.visible = false
	_feito = false
	_ops[0].grab_focus()


func _responder(lado: int) -> void:
	if _feito:
		return
	_feito = true
	var it: Dictionary = itens[_k]
	var certa := int(it.certa)
	var ok := (1 - lado if _troca else lado) == certa
	QuizManager.registrar_resposta(it, ok)
	var pen := 0
	if ok:
		_ac += 1
		Game.s.moedas += int(cfg.get("premio", 0))
	elif cfg.get("multa", 0):
		pen = Game.multa(cfg.multa)
	Game.salvar()
	Som.sfx("ok" if ok else "erro")
	if not ok:
		Game.treme(0.25, 0.8)
	for i in 2:
		var b: Button = _ops[i]
		b.disabled = true
		b.modulate = Color("#5dff8f") if (1 - i if _troca else i) == certa else (Color("#ff6b6b") if i == lado else Color(1, 1, 1, 0.4))
	var cab: String = "ACERTOU!" + (" +$ %d" % int(cfg.premio) if cfg.get("premio", 0) else "") if ok else \
		"ERROU" + (" — multa de $ %d" % pen if pen else "") + " — foi para o caderno de erros."
	_fb.text = "%s  Resposta: %s. %s" % [cab, it.opcoes[certa], it.explicacao]
	_fb.add_theme_color_override("font_color", Color("#9dffb8") if ok else Color("#ffb0a0"))
	_k += 1
	_prox.visible = true
	_prox.grab_focus()


func _unhandled_input(e: InputEvent) -> void:
	if _feito or not is_visible_in_tree():
		return
	if e.is_action_pressed("resp_esq"):
		_responder(0)
	elif e.is_action_pressed("resp_dir"):
		_responder(1)
	else:
		return
	get_viewport().set_input_as_handled()
