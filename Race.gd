extends Control
## Corrida pseudo-3D no estilo de corrida (SNES): pista por segmentos projetados, 11 rivais, 3 voltas,
## combustível, box com pergunta Certo/Errado e caixas "?" com perguntas-relâmpago (QTE) que dão nitro.
## A pista é desenhada em baixa resolução (SubViewport) e ampliada sem filtro, como nos 16 bits.

const Car = preload("res://Car.gd")
const SEG := 200.0
const RW := 1100.0
const CAMH := 1000.0
var DRAW := 180                 # segmentos desenhados (120 no modo leve, ver Game.leve)
const RQ := 12                  # máximo de quadriláteros por segmento da pista (o pior caso é a linha de largada: 11)
const BORDAS := [-0.93, 0.93]
const FAIXAS := [1, 2]
const VMAX := SEG * 60.0
const CARW := 360.0
const CARL := 0.23
const ESC := 0.6
const BOX0 := 285  # a zona do box vai de N-BOX0 até N-BOX1 (reta final)
const BOX1 := 25
const MARCHAS := [0.24, 0.43, 0.62, 0.82, 1.0]
const FORCA := [1.6, 1.2, 0.9, 0.66, 0.46]
# rivais: [reta, curva] = quanto do limite do carro cada um usa. RITMO desconta o tempo que o jogador perde no box.
const PERFIL := [[1, .95], [.975, 1], [.99, .975], [.97, .99], [.985, .95], [.96, .975], [.97, .93], [.945, .95], [.93, .94], [.92, .91], [.9, .9]]
const RITMO := 0.965
const FRASES := [["HOUVE", "NÃO HOUVERAM"], ["MENOS", "NUNCA MENAS"], ["VOU À", "VOLTO DA"], ["FAZ 2 ANOS", "NÃO FAZEM"], ["PREFIRA X", "A Y"],
	["ASSISTA", "AO JOGO"], ["POR QUÊ?", "PORQUE SIM"], ["A FIM DE", "≠ AFIM"], ["MEIO CANSADA", "NÃO MEIA"], ["CHEGUE A", "NÃO EM"]]
# cenário: [largura px, altura px, largura no mundo, sólido]
const SPR := {"arvore": [40, 56, 1250, true], "pinheiro": [32, 60, 1000, true], "palmeira": [48, 64, 1400, true], "cacto": [28, 44, 700, true],
	"pedra": [36, 22, 950, true], "arbusto": [28, 16, 700, false], "poste": [22, 64, 420, true], "predio": [48, 100, 2400, true],
	"torre": [40, 130, 2200, true], "casa": [48, 36, 1700, true], "sobrado": [44, 52, 1700, true], "outdoor": [72, 46, 1900, true],
	"seta": [26, 34, 640, true], "placa": [48, 44, 950, true], "portico": [260, 76, 6000, false], "caixa": [22, 22, 460, false],
	"torcida": [80, 44, 3000, true], "bandeira": [28, 64, 950, true]}
const LOD := 12.0  # largura em px (tela de 426) abaixo da qual rivais e bandeiras viram silhueta
const ATL := 2.0   # escala da arte no atlas, para não pixelar demais de perto
const AMARELO := Color("#ffd400")
const NAVY := Color("#080c24")
const K_111111 := Color("#111111")
const K_1a1a22 := Color("#1a1a22")
const K_20244a := Color("#20244a")
const K_2a6cf0 := Color("#2a6cf0")
const K_2f8fff := Color("#2f8fff")
const K_3fd97f := Color("#3fd97f")
const K_4a1010 := Color("#4a1010")
const K_6fc0ff := Color("#6fc0ff")
const K_801010 := Color("#801010")
const K_8fe0ff := Color("#8fe0ff")
const K_bcd0ff := Color("#bcd0ff")
const K_d8d8d8 := Color("#d8d8d8")
const K_dfe6ff := Color("#dfe6ff")
const K_e8e8e8 := Color("#e8e8e8")
const K_ff2a2a := Color("#ff2a2a")
const K_ff3030 := Color("#ff3030")
const K_ff6b6b := Color("#ff6b6b")
const K_ff7a1a := Color("#ff7a1a")
const K_ffd86b := Color("#ffd86b")
const K_ffe14a := Color("#ffe14a")
const K_ffe9a0 := Color("#ffe9a0")

var CAMD := 1.0 / tan(deg_to_rad(50.0))
var PZ := CAMH * CAMD

@onready var vp: SubViewport = $Tela/VP
@onready var cv: Node2D = $Tela/VP/Canvas
@onready var ui: Control = $UI
var font: Font

# pista
var curva := PackedFloat32Array()
var y1 := PackedFloat32Array()
var y2 := PackedFloat32Array()
var spr: Array = []
var pk: Array = []
var N := 0
var comp := 0.0
var _y := 0.0
var T: Array
var C := {}
var serra_ab := []
var estrelas := []
var cidade := []
var mods: Array
# estado
var g := 0
var md: Dictionary
var E := {}
var asa := -1
var cat := "gt"
var minha := 0               # equipe do jogador
var faixa: Color             # cor da equipe no carro do jogador
var box := {"ok": 0, "erro": 0}
var cor: Color
var x := 0.0
var speed := 0.0
var steer := 0.0
var m := 0
var rpm := 0.0
var fuel := 1.0
var nitro := 1
var nitro_t := 0.0
var dist := 0.0
var pos := 0.0
var pz_ant := 0.0
var t := 0.0
var est := "contagem"  # contagem, corrida, pit, fim, res
var cont := 3.6
var cont_n := 9
var volta := 1
var sky1 := 0.0
var sky2 := 0.0
var cars: Array = []
var stat := {"ac": 0, "n": 0}
var q: Dictionary = {}
var av_t := 0.0
var av_txt := ""
var msg := ""
var pit_t := 0.0
var pit_max := 1.0
var derr := 0.0
var fre := false
var fora := false
var fum := 0.0
var pos_final := 0
var fim_t := 0.0
var pausado: Control = null
# projeção dos segmentos visíveis
var a_sx := PackedFloat32Array()
var a_sy := PackedFloat32Array()
var a_sw := PackedFloat32Array()
var a_sc := PackedFloat32Array()
var a_cz := PackedFloat32Array()
var b_sx := PackedFloat32Array()
var b_sy := PackedFloat32Array()
var b_sw := PackedFloat32Array()
var b_sc := PackedFloat32Array()
var clip := PackedFloat32Array()
var seg_i := PackedInt32Array()
# painel de pergunta
var painel: PanelContainer
var p_q: Label
var p_linha: HBoxContainer
var p_ops: Array = []
var p_bar: ProgressBar
var p_x: Label
var _ox := 0.0
var _oy := 0.0
var _ci: CanvasItem          # onde _ret/_tri/_bola/_txt desenham: a pista ou o atlas
var _atlas: Texture2D
var _reg := {}               # chave da arte -> região no atlas
var _tt := 0.0               # relógio do quadro (animação da torcida e das bandeiras)
var _serra_tab := {}         # altura dos morros por pixel (ver _serra)
var _ceu_c := []             # as 14 faixas do céu, já misturadas
var _ent_caixa := {}         # a caixa "?" é um objeto de cenário como os outros
var _rp := PackedVector2Array()  # buffers da pista: vértices, cores e índices (ver _rq)
var _rc := PackedColorArray()
var _ri := PackedInt32Array()
var _rn := 0                     # quadriláteros acumulados no quadro


func _ready() -> void:
	g = Game.gp
	T = Game.PISTAS[g]
	cat = Game.s.cat
	mods = [Game.mod_gp(g)] if Game.mod_gp(g) != "" else Game.mods_cat()
	md = Game.carro_base()
	for e in Game.EFEITO:  # peças + categoria + equipe, somados uma vez por corrida
		E[e] = Game.ef_tudo(e)
	asa = Game.asa()
	Som.timbre(cat, int(Game.s.carro), Game.pecas_ids())
	minha = Game.equipe_de(Game.EU)
	faixa = Color(Game.EQUIPES[minha][1])
	cor = Color(Game.PINT[int(Game.s.cor)][1])
	font = ThemeDB.fallback_font.duplicate()
	if font is FontFile:
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	for k in ["ceu0:3", "ceu1:4", "astro:5", "serra1:7", "serra2:8", "g0:10", "g1:11", "p0:12", "p1:13", "z0:14", "z1:15", "folha:16"]:
		var par: PackedStringArray = k.split(":")
		C[par[0]] = Color(T[int(par[1])])
	for k in 14:
		_ceu_c.append(C.ceu0.lerp(C.ceu1, k / 13.0))
	_ent_caixa = _ent("caixa", 0.0, 0)
	if Game.leve():
		DRAW = 120
	_rp.resize(RQ * DRAW * 4)
	_rc.resize(RQ * DRAW * 4)
	_ri.resize(RQ * DRAW * 6)
	for q in RQ * DRAW:  # dois triângulos por quadrilátero
		var v := q * 4
		var j := q * 6
		_ri[j] = v; _ri[j + 1] = v + 1; _ri[j + 2] = v + 2
		_ri[j + 3] = v; _ri[j + 4] = v + 2; _ri[j + 5] = v + 3
	a_sx.resize(DRAW); a_sy.resize(DRAW); a_sw.resize(DRAW); a_sc.resize(DRAW); a_cz.resize(DRAW)
	b_sx.resize(DRAW); b_sy.resize(DRAW); b_sw.resize(DRAW); b_sc.resize(DRAW); clip.resize(DRAW); seg_i.resize(DRAW)
	_ci = cv
	cv.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cria_pista()
	_cria_ceu()
	_cria_rivais()
	_cria_atlas()  # depois dos rivais: os carros deles também vão para o atlas
	_cria_painel()
	cv.draw.connect(_desenha)
	Som.musica(cat if cat in ["rali", "formula"] else "corrida%d" % (g + 1))  # rali e formula têm faixa própria (musica/<cat>.*)


# ------------------------------------------------------------ pista
func _ein(a: float, b: float, p: float) -> float:
	return a + (b - a) * p * p


func _eio(a: float, b: float, p: float) -> float:
	return a + (b - a) * (0.5 - cos(p * PI) / 2.0)


func _add(c: float, yy: float) -> void:
	curva.append(c)
	y1.append(_y)
	y2.append(yy)
	spr.append([])
	_y = yy


func _via(en: int, ho: int, le: int, c: float, h: float) -> void:
	var y0 := _y
	var yf := y0 + h * SEG
	var tt := float(en + ho + le)
	var i0 := curva.size()
	for n in en:
		_add(_ein(0, c, n / float(en)), _eio(y0, yf, (n + 1) / tt))
	for n in ho:
		_add(c, _eio(y0, yf, (en + n + 1) / tt))
	for n in le:
		_add(_eio(c, 0, n / float(le)), _eio(y0, yf, (en + ho + n + 1) / tt))
	if absf(c) > 3.2:  # placas de curva forte, do lado de fora
		for n in range(4, en + ho, 14):
			spr[i0 + n].append(_ent("seta", -1.5 if c > 0 else 1.5, 0, 1 if c > 0 else -1))


func _poe(i: int, tp: String, off: float, r: RandomNumberGenerator) -> void:
	spr[i % N].append(_ent(tp, off, r.randi()))


## Objeto de cenário. Já guarda o desenho (dd) e a(s) chave(s) do atlas (k), para o quadro não montar texto:
## torcida e bandeira têm uma chave por quadro de animação, escolhida pelo relógio na taxa r.
func _ent(tp: String, off: float, s: int, d := 1) -> Dictionary:
	var ks := []
	var rate := 0.0
	if tp == "torcida":
		rate = 5.0
		for f in 2:
			ks.append("torcida%d_%d" % [s % 4, f])
	elif tp == "bandeira":
		rate = 9.0
		for f in 4:
			ks.append("bandeira%d" % f)
	else:
		ks.append(_chave(tp, s))
	return {"t": tp, "off": off, "s": s, "d": d, "dd": SPR[tp], "k": ks, "r": rate}


func _cria_pista() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 1000 + g * 77
	_via(40, 40, 40, 0, 0)
	var forca := minf(1.7, 1.0 + g * 0.07)
	var alvo := 1350 + g * 40
	while curva.size() < alvo:
		var k := r.randf()
		var L := 28 + int(r.randf() * 45)
		var c := (-1.0 if r.randf() < 0.5 else 1.0) * minf(6.0, (2.0 + r.randf() * 2.5) * forca)
		var h := (r.randf() * 2.0 - 1.0) * 45.0 if r.randf() < 0.6 else 0.0
		if absf(_y / SEG + h) > 110:
			h = -h
		if k < 0.2:
			_via(L, L, L, 0, h)
		elif k < 0.75:
			_via(L, L, L, c, h)
		else:
			_via(L, L >> 1, L, c, h / 2)
			_via(L, L >> 1, L, -c, h / 2)
	_via(60, 60, 60, 0, -_y / SEG)
	_via(110, 160, 60, 0, 0)  # fecha o circuito no nível da largada (reta do box)
	y2[y2.size() - 1] = 0
	N = curva.size()
	comp = N * SEG
	# cenário: fileira regular de postes/árvores; atrás, quarteirões ou mata
	var U: int = T[18]
	var cen: Array = T[17]
	var natural := "arvore"
	for n in cen:
		if n in ["arvore", "palmeira", "pinheiro", "cacto"]:
			natural = n
			break
	var fila := ["poste", natural]
	var i := 20
	var k2 := 0
	while i < N - 10:
		for l in [-1, 1]:
			_poe(i, fila[k2 % 2], l * 1.36, r)
		i += 9 if U else 14
		k2 += 1
	# arquibancadas com torcida e bandeiras do país-sede: reta de largada e alguns trechos da volta
	var zonas := [[N - 230, N], [0, 30]]
	for j in range(500, N - 500, 380):
		zonas.append([j, j + 45])
	var na_zona := func(j: int) -> bool:
		for z in zonas:
			if j >= z[0] and j < z[1]:
				return true
		return false
	for z in zonas:
		for j in range(z[0], z[1], 9):
			_poe(j, "torcida", -2.6, r)
			_poe(j, "torcida", 3.1, r)
			if (j / 9) % 2 == 0:
				_poe(j + 4, "bandeira", -1.6, r)
				_poe(j + 4, "bandeira", 2.3, r)
	i = 24
	while i < N - 10:
		for l in [-1, 1]:
			if r.randf() < 0.85 and not na_zona.call(i):
				var tp: String = cen[r.randi() % cen.size()]
				_poe(i + r.randi() % 3, tp, l * (1.75 + SPR[tp][2] * ESC / RW / 2.0 + r.randf() * (1.0 if U == 2 else (1.8 if U else 2.8))), r)
		i += 4 if U == 2 else (6 if U else 5)
	for j in range(N - BOX0, N - BOX1, 65):
		_poe(j, "placa", 1.9, r)
	_poe(3, "portico", 0, r)
	i = 260
	while i < N - BOX0 - 60:
		pk.append({"i": i, "off": [-0.6, 0.0, 0.6][r.randi() % 3], "t": 0.0})
		i += 420 + int(r.randf() * 140)


func _cria_ceu() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 50 + g
	for k in 2:
		serra_ab.append([r.randf() * 7, r.randf() * 7, r.randf() * 7])
	if T[6]:
		for k in 90:
			estrelas.append(Vector3(r.randf(), r.randf(), 1.0 if r.randf() < 0.2 else 0.0))
	if T[9] == "c":  # linha de prédios com janelas acesas (largura de referência 852 px)
		var xx := 0.0
		while xx < 852:
			var w := 10 + int(r.randf() * 18)
			var h := 18 + int(r.randf() * 58)
			var jan := []
			for yy in range(94 - h, 86, 6):
				for kx in range(int(xx) + 3, int(xx) + w - 2, 4):
					if r.randf() < 0.35:
						jan.append(Vector3(kx - xx, yy - 90 + h, 1.0 if r.randf() < 0.8 else 0.0))
			cidade.append({"x": xx, "w": w, "h": h, "jan": jan})
			xx += w + int(r.randf() * 3)


func _cria_rivais() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = g + 9
	var L := 3.0 * maxi(0, g - 1) / (Game.PISTAS.size() - 2)
	var forma := []
	for p in PERFIL:
		forma.append(1.0 + (r.randf() - 0.5) * 0.05)
	# a categoria muda o carro de todo mundo: final, curva (raiz da aderência) e arrancada
	var cb = Game.CATEGORIAS[cat].carro
	var cv_: Array = [cb.vel, sqrt(cb.ade), cb.ace] if cb else [1.0, 1.0, 1.0]
	var ordem := range(PERFIL.size())
	ordem.sort_custom(func(a, b): return PERFIL[a][0] * PERFIL[a][1] * forma[a] > PERFIL[b][0] * PERFIL[b][1] * forma[b])
	var ia := 0
	for s in 12:
		var z := (13 - s) * SEG * 2.5
		var off := 0.5 if s % 2 else -0.5
		if s == Game.grid - 1:
			dist = z
			pos = fposmod(z - PZ, comp)
			pz_ant = z
			x = off
			continue
		var id: int = ordem[ia]
		ia += 1
		var p: Array = PERFIL[id]
		var eq: Array = Game.EQUIPES[Game.equipe_de(id)]
		var rt: float = eq[4]  # ritmo da equipe
		cars.append({"id": id, "z": z, "dist": z, "off": off, "speed": 0.0, "vmax": VMAX * (1 + 0.07 * L) * p[0] * forma[id] * RITMO * rt * cv_[0],
			"vc": VMAX * sqrt(3.6 / (1 - 0.11 * L)) * p[1] * forma[id] * rt * cv_[1], "ace": VMAX / 6.5 * (1 + 0.1 * L) * cv_[2], "mi": id % 4,
			"cor": Color(eq[1]), "faixa": Color(eq[2]), "vir": 0, "lado": 0, "j": cars.size()})
	nitro = 1 + int(E.nitro_n)


# ------------------------------------------------------------ painel de pergunta (QTE e box)
func _cria_painel() -> void:
	painel = PanelContainer.new()
	painel.anchor_left = 0.12
	painel.anchor_right = 0.88
	painel.anchor_top = 0.16
	painel.anchor_bottom = 0.16
	painel.visible = false
	ui.add_child(painel)
	var v := VBoxContainer.new()
	painel.add_child(v)
	p_q = Game.rotulo(v, "", 26, Color.WHITE, true)
	p_linha = HBoxContainer.new()
	v.add_child(p_linha)
	for lado in 2:
		var l := Game.rotulo(p_linha, "", 28, AMARELO)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if lado else HORIZONTAL_ALIGNMENT_LEFT
		p_ops.append(l)
	p_bar = ProgressBar.new()
	p_bar.show_percentage = false
	p_bar.custom_minimum_size.y = 10
	v.add_child(p_bar)
	p_x = Game.rotulo(v, "", 22, Color("#cfd8ff"), true)


func _painel(it: Dictionary, tempo: float, rotulo: String, cb: Callable) -> void:
	var troca: bool = it.tipo == "ab" and randf() < 0.5
	q = {"it": it, "t": tempo, "max": tempo, "troca": troca, "cb": cb, "res": null, "fim": 0.0}
	painel.remove_theme_stylebox_override("panel")
	painel.visible = true
	p_q.text = rotulo + " " + str(it.enunciado)
	p_ops[0].text = "[LB]  " + str(it.opcoes[1 if troca else 0])
	p_ops[1].text = str(it.opcoes[0 if troca else 1]) + "  [RB]"
	p_linha.visible = true
	p_bar.visible = tempo > 0
	p_bar.value = 100
	p_x.text = ""


func _fecha_painel() -> void:
	q = {}
	painel.visible = false


func _responde(lado: int) -> void:
	var it: Dictionary = q.it
	var certa := int(it.certa)
	var ok: bool = lado >= 0 and (1 - lado if q.troca else lado) == certa
	q.res = ok
	QuizManager.registrar_resposta(it, ok)
	stat.n += 1
	if ok:
		stat.ac += 1
	var r: Dictionary = q.cb.call(ok)
	q.fim = r.t
	Game.salvar()
	painel.add_theme_stylebox_override("panel", Game._caixa(Color(0.02, 0.1, 0.05, 0.95) if ok else Color(0.14, 0.03, 0.03, 0.95), Color("#3fd97f") if ok else Color("#ff5050"), 3))
	p_q.text = ("CERTO! " if ok else ("TEMPO ESGOTADO. " if lado < 0 else "ERRADO. ")) + str(r.txt) + "   ·   Resposta: " + str(it.opcoes[certa])
	p_linha.visible = false
	p_bar.visible = false
	p_x.text = it.explicacao


func _painel_upd(dt: float) -> void:
	if q.res == null:
		if Input.is_action_just_pressed("resp_esq"):
			_responde(0)
		elif Input.is_action_just_pressed("resp_dir"):
			_responde(1)
		elif q.max > 0:
			q.t -= dt
			p_bar.value = maxf(0.0, q.t / q.max * 100.0)
			if q.t <= 0:
				_responde(-1)
	else:
		q.fim -= dt
		if q.fim <= 0:
			_fecha_painel()


func _qte() -> void:
	var it := QuizManager.sorteia(mods, 1, "ab")
	if it.is_empty():
		return
	_painel(it[0], 6.0 + E.tempo, "RELÂMPAGO —", func(ok: bool) -> Dictionary:
		if ok:
			nitro = mini(6, nitro + 1)
			Game.s.moedas += 50
			Som.sfx("ok")
			return {"t": 3.0, "txt": "+1 NITRO · +$ 50"}
		speed *= 0.5
		m = maxi(0, m - 2)
		Som.sfx("erro")
		Game.treme(0.3, 0.9)
		return {"t": 4.0, "txt": "Motor engasgou · multa de $ %d" % Game.multa(30)})


func _entra_pit() -> void:
	_fecha_painel()
	est = "pit"
	_painel(QuizManager.sorteia(mods, 1, "ce")[0], 0.0, "BOX —", func(ok: bool) -> Dictionary:
		pit_t = maxf(1.0, (2.0 if ok else 7.0) - E.pit)
		pit_max = pit_t
		box["ok" if ok else "erro"] += 1
		if ok:
			Game.s.moedas += 100
			nitro = mini(6, nitro + 1)
			Som.sfx("ok")
			return {"t": 99.0, "txt": "Parada relâmpago (%.1f s) · +$ 100 · +1 nitro" % pit_t}
		Som.sfx("erro")
		Game.treme(0.3, 0.9)
		return {"t": 99.0, "txt": "Mecânicos atrapalhados: parada de %.1f s" % pit_t})


# ------------------------------------------------------------ pausa e resultado
func _pausa() -> void:
	Som.motor(-1)
	pausado = CenterContainer.new()
	pausado.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(pausado)
	var p := PanelContainer.new()
	pausado.add_child(p)
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = 420
	p.add_child(v)
	Game.rotulo(v, "PAUSA", 48, AMARELO).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Game.botao(v, "CONTINUAR", _continua).call_deferred("grab_focus")
	Game.botao(v, "ABANDONAR CORRIDA", func():
		Game.abrir = "campeonato"
		get_tree().change_scene_to_file("res://Main.tscn"))


func _continua() -> void:
	pausado.queue_free()
	pausado = null


func _posicao() -> int:
	var p := 1
	for c in cars:
		if c.dist > dist:
			p += 1
	return p


func _tempo(s: float) -> String:
	return "%d:%04.1f" % [int(s / 60), fmod(s, 60.0)]


func _resultado() -> void:
	est = "res"
	_fecha_painel()
	Som.motor(-1)
	Som.amb(0, false, false)
	var ordem := []
	for c in cars:
		ordem.append([c.dist, c.id])
	ordem.sort_custom(func(a, b): return a[0] > b[0])
	var ids := ordem.map(func(o): return o[1])
	ids.insert(pos_final - 1, Game.EU)  # o jogador fica na posição em que cruzou; os demais, pela distância
	var pr: int = roundi(Game.PREMIO[pos_final - 1] * float(Game.CATEGORIAS[cat].premio))
	# meta do patrocinador da equipe
	var meta: Array = Game.EQUIPES[minha][6]
	var bateu: bool
	match meta[0]:
		"acertos": bateu = stat.n > 0 and float(stat.ac) / stat.n >= float(meta[1])
		"pos": bateu = pos_final <= int(meta[1])
		_: bateu = box.ok > 0 and box.erro == 0
	var bonus: int = meta[2] if bateu else 0
	var retido := Game.receber(pr + bonus)
	var ant := Game.pos_em(g)
	if ant == 0 or pos_final < ant:
		if not Game.s.res.has(cat):
			Game.s.res[cat] = {}
		if not Game.s.eqres.has(cat):
			Game.s.eqres[cat] = {}
		Game.s.res[cat][str(g)] = ids
		var eqs := []
		for pil in Game.PILOTOS.size():
			eqs.append(Game.equipe_de(pil))
		Game.s.eqres[cat][str(g)] = eqs
	Game.salvar()
	Som.musica("menu")
	var fundo := ColorRect.new()
	fundo.color = Color("#070a1c")
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(fundo)
	var v := Game.tela(fundo, "BANDEIRADA — %s · %s (%s)" % [Game.CATEGORIAS[cat].nome, T[1], Game.PAISES[T[2]]])
	var duas := HBoxContainer.new()
	duas.add_theme_constant_override("separation", 40)
	Game.expande(duas)
	v.add_child(duas)
	var l := VBoxContainer.new()
	duas.add_child(l)
	for k in ids.size():
		var eu: bool = int(ids[k]) == Game.EU
		var eq: Array = Game.EQUIPES[Game.equipe_de(int(ids[k]))]
		var lin := HBoxContainer.new()
		l.add_child(lin)
		var cr := ColorRect.new()  # cor da equipe
		cr.color = Color(eq[1])
		cr.custom_minimum_size = Vector2(8, 22)
		lin.add_child(cr)
		Game.rotulo(lin, "%2dº  %-14s %-20s +%d" % [k + 1, Game.PILOTOS[int(ids[k])], eq[0], Game.PTS[k]], 18, AMARELO if eu else Color("#e8ecff"))
	var dir := VBoxContainer.new()
	dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duas.add_child(dir)
	Game.rotulo(dir, "%dº LUGAR" % pos_final, 64, AMARELO)
	Game.rotulo(dir, "Tempo: %s\nPrêmio: $ %d%s\nPerguntas na pista: %d/%d certas" % [_tempo(t), pr,
		" (banco reteve $ %d)" % retido if retido else "", stat.ac, stat.n], 24)
	Game.rotulo(dir, ("PATROCÍNIO: meta batida (%s) +$ %d" if bateu else "Patrocínio: meta não batida (%s) — $ %d perdidos") % [meta[3], meta[2]],
		20, Color("#9dffb8") if bateu else Color("#ff9a8a"), true)
	var fim := g == Game.PISTAS.size() - 1 and pos_final <= 5
	var camp: bool = Game.tabela()[0].i == Game.EU
	var txt: String = ("CAMPEÃO — %s!" % str(Game.CATEGORIAS[cat].nome).to_upper() if camp else "Campeonato concluído — falta o título: melhore suas colocações.") if fim else \
		("Classificado! Próxima corrida liberada." if pos_final <= 5 else "Fique entre os 5 primeiros para avançar. Melhore o carro na garagem.")
	Game.rotulo(dir, txt, 24, Color("#9dffb8"), true)
	var rod := Game.rodape(v)
	Game.botao(rod, "GARAGEM", func(): get_tree().change_scene_to_file("res://Shop.tscn"))
	Game.botao(rod, "CADERNO DE ERROS", func(): get_tree().change_scene_to_file("res://ErrorNotebook.tscn"))
	Game.botao(rod, "CAMPEONATO ▶", func():
		Game.abrir = "campeonato"
		get_tree().change_scene_to_file("res://Main.tscn")).call_deferred("grab_focus")


# ------------------------------------------------------------ simulação
func _process(dt: float) -> void:
	if est == "res":
		return
	if pausado:
		if Input.is_action_just_pressed("pausa") or Input.is_action_just_pressed("ui_cancel"):
			_continua()
		return
	_atualiza(minf(dt, 0.05))
	cv.queue_redraw()


func _atualiza(dt: float) -> void:
	if Input.is_action_just_pressed("pausa"):
		_pausa()
		return
	var tinha_q: bool = not q.is_empty() and q.res == null
	if not q.is_empty():
		_painel_upd(dt)
	var acel := Input.get_action_strength("accelerate")
	var freio := Input.get_action_strength("brake")
	var dir := Input.get_axis("steer_left", "steer_right")
	if est == "contagem":
		cont -= dt
		var n := ceili(cont / 0.9)
		if n != cont_n:
			cont_n = n
			if n < 4:
				Som.sfx("bip" if n > 0 else "ja")
			if n <= 0:
				est = "corrida"
				av_txt = "JÁ!"
				av_t = 0.8
		rpm = 0.7 + randf() * 0.1 if acel > 0 else 0.15
		Som.motor(rpm, 1.0 if rpm > 0.5 else 0.0)
		return
	if est != "fim":
		t += dt
	if est == "pit":
		acel = 0.0
		freio = 1.0
		dir = 0.0
		x += (1.3 - x) * minf(1.0, dt * 3.0)
	if est == "fim":
		acel = 0.0
		freio = 0.25
		dir = 0.0
	steer += (dir - steer) * minf(1.0, dt * 12.0)
	fre = freio > 0.1
	var nit := nitro_t > 0
	var vtop: float = VMAX * md.vel * (1 + E.vel) * (1.25 + E.nitro_f if nit else 1.0)
	var lim := vtop * (0.25 if fuel <= 0 else 1.0)
	var sp := speed / VMAX
	var ps := int((pos + PZ) / SEG) % N
	# câmbio de 5 marchas: automático ou manual (LB/RB quando não há pergunta na tela)
	if Game.s.manual:
		if not tinha_q:
			if Input.is_action_just_pressed("resp_dir") and m < 4:
				m += 1
				Som.sfx("marcha")
			if Input.is_action_just_pressed("resp_esq") and m > 0:
				m -= 1
				Som.sfx("marcha")
	elif rpm > 0.94 and m < 4:
		m += 1
		Som.sfx("marcha")
	elif m > 0 and speed < vtop * MARCHAS[m - 1] * 0.8:
		m -= 1
	rpm = speed / (vtop * MARCHAS[m])
	if acel > 0 and rpm < 1:
		speed += VMAX / 4.8 * md.ace * (1 + E.ace) * FORCA[m] * (0.45 if rpm < 0.3 and m > 0 else 1.0) * (2.2 + 2.0 * E.nitro_f if nit else 1.0) * acel * dt
	else:
		speed -= VMAX / (1.6 if rpm > 1.02 else 7.0) * dt
	if freio > 0:
		speed -= VMAX * (0.9 + E.freio) * freio * dt
	# direção direta + força centrífuga que cresce com o quadrado da velocidade: curva forte exige aliviar
	if est != "pit":
		x += steer * 1.9 * (0.3 + 0.7 * minf(1.0, sp * 1.6)) * dt
		var cf: float = sp * sp * curva[ps] * 0.42 * (1 - minf(0.6, E.ade)) / md.ade
		x -= cf * dt
		if absf(cf) > 1.3 and steer * curva[ps] > 0 and sp > 0.5:
			speed -= VMAX * 0.1 * dt
			derr = 0.12
			fum = 0.15
	fora = absf(x) > 1.06 and est != "pit"
	if fora:
		var l: float = VMAX * 0.3 * (1 + E.grama)
		if speed > l:
			speed -= VMAX * 0.7 * (1 - 0.6 * clampf(E.grama, -0.5, 1.0)) * dt
		fum = 0.1
	if speed > lim:
		speed = maxf(lim, speed - VMAX / 2.0 * dt)
	speed = maxf(0.0, speed)
	x = clampf(x, -2.3, 2.3)
	fum -= dt
	if Input.is_action_just_pressed("nitro") and est == "corrida" and nitro > 0 and not nit and fuel > 0:
		nitro -= 1
		nitro_t = 3.0 + E.nitro_t
		Som.sfx("nitro")
		Game.treme(0.3, 0.6)
	nitro_t -= dt
	var dz := speed * dt
	pos = fmod(pos + dz, comp)
	dist += dz
	if est == "corrida":
		fuel = maxf(0.0, fuel - dz * md.con * (1 + E.con) / (comp * 2.2 * (1 + E.tanque)))
	sky1 += 0.012 * curva[ps] * sp * dt
	sky2 += 0.024 * curva[ps] * sp * dt
	var pz := fmod(pos + PZ, comp)
	var eu = null if est == "pit" else {"z": pz, "off": x, "speed": speed}
	var todos := cars.duplicate()
	if eu:
		todos.append(eu)
	# adversários: aceleram até a própria máxima, freiam antes das curvas e desviam de quem está mais lento
	for c in cars:
		var si := int(c.z / SEG) % N
		var cvv := maxf(absf(curva[si]), absf(curva[(si + 18) % N]))
		var alvo: float = minf(c.vmax, c.vc / sqrt(cvv) if cvv > 0.5 else 1e9)
		c.speed = minf(alvo, c.speed + c.ace * dt) if c.speed < alvo else maxf(alvo, c.speed - VMAX * 0.8 * dt)
		c.vir = clampi(roundi(curva[si] / 2.5), -2, 2)
		var lado := 1 if c.dist > dist else -1
		if c.lado and lado != c.lado and absf(c.off - x) < 1.2:
			Som.sfx("passa")
		c.lado = lado
		var dx2 := 0.0
		for o in todos:
			if is_same(o, c):
				continue
			var d := fposmod(o.z - c.z, comp)
			if d > 0 and d < SEG * 10 and o.speed < c.speed and absf(o.off - c.off) < 0.32:
				dx2 = 1.0 if c.off >= o.off else -1.0
				if absf(c.off + dx2 * 0.4) > 0.85:
					dx2 = -dx2
				if d < SEG * 1.3:
					c.speed = minf(c.speed, o.speed)
		c.off = clampf(c.off + dx2 * dt * 1.5, -0.85, 0.85)
		c.z = fmod(c.z + c.speed * dt, comp)
		c.dist += c.speed * dt
		# batida: na traseira perde velocidade e é empurrado de lado
		var d2 := fposmod(c.z - pz, comp)
		if eu and d2 < SEG * 1.4 and absf(c.off - x) < CARL and speed > c.speed:
			speed = c.speed * (0.75 + E.batida)
			x += (1.0 if x >= c.off else -1.0) * 0.12
			Som.sfx("bate")
			Game.treme(0.2, 1.0)
	# objetos de beira de pista, caixas "?" e box
	var ia := int(pz_ant / SEG)
	var ib := int(pz / SEG)
	var vao := posmod(ib - ia, N)
	pz_ant = pz
	if fora and vao < 12 and speed > VMAX * 0.15:
		for kk in vao + 1:
			for e in spr[(ia + kk) % N]:
				var dd: Array = SPR[e.t]
				if dd[3] and absf(e.off - x) < 0.1 + dd[2] * ESC / RW * 0.3:
					speed = VMAX * 0.08
					m = 0
					x += (1.0 if x > e.off else -1.0) * 0.25
					Som.sfx("bate")
					Game.treme(0.4, 1.0)
					av_txt = "BATEU!"
					av_t = 0.7
	if est == "corrida" and q.is_empty() and vao < 12:
		for k in pk:
			if k.t <= t and posmod(k.i - ia, N) <= vao and absf(x - k.off) < 0.3:
				k.t = t + 25
				_qte()
				break
	var no_box := ib >= N - BOX0 and ib < N - BOX1
	if no_box and est == "corrida" and Input.is_action_just_pressed("pit"):
		_entra_pit()
	if est == "pit" and not q.is_empty() and q.res != null:
		pit_t -= dt
		fuel = minf(1.0, fuel + dt / pit_max)
		if pit_t <= 0:
			est = "corrida"
			fuel = 1.0
			m = 0
			_fecha_painel()
	# voltas e bandeirada
	var v := mini(Game.VOLTAS, int(dist / comp) + 1)
	if v != volta:
		volta = v
		if v == Game.VOLTAS:
			av_txt = "ÚLTIMA VOLTA"
			av_t = 2.0
	if est != "fim" and dist >= Game.VOLTAS * comp:
		_fecha_painel()
		est = "fim"
		pos_final = _posicao()
		fim_t = 3.0
		av_txt = "BANDEIRADA!"
		av_t = 3.0
		Som.sfx("fanfarra")
	if est == "fim":
		fim_t -= dt
		if fim_t <= 0:
			_resultado()
			return
	if av_t > 0:
		av_t -= dt
		msg = av_txt
	elif est == "pit":
		msg = ""
	else:
		msg = "SEM COMBUSTÍVEL — VÁ AO BOX" if fuel <= 0 else ("[Y] PIT-STOP" if no_box else ("COMBUSTÍVEL BAIXO" if fuel < 0.2 else ""))
	derr -= dt
	Som.motor(0.12 + minf(1.05, rpm) * 0.88, acel if est == "corrida" else 0.0)
	Som.amb(sp, derr > 0, fora and sp > 0.05)


# ------------------------------------------------------------ desenho
## Acumula um quadrilátero da pista (dois pontos em ya, dois em yb) nos buffers que _desenha manda de uma vez.
func _rq(x1: float, x2: float, x3: float, x4: float, ya: float, yb: float, c: Color) -> void:
	var k := _rn * 4
	_rp[k] = Vector2(x1, ya)
	_rp[k + 1] = Vector2(x2, ya)
	_rp[k + 2] = Vector2(x3, yb)
	_rp[k + 3] = Vector2(x4, yb)
	_rc[k] = c
	_rc[k + 1] = c
	_rc[k + 2] = c
	_rc[k + 3] = c
	_rn += 1


func _ret(px: float, py: float, w: float, h: float, c) -> void:
	_ci.draw_rect(Rect2(px + _ox, py + _oy, w, h), Color(c))


func _tri(c, pts: Array) -> void:
	var v := PackedVector2Array()
	for i in range(0, pts.size(), 2):
		v.append(Vector2(pts[i] + _ox, pts[i + 1] + _oy))
	var k := Color(c)
	_ci.draw_primitive(v, PackedColorArray([k, k, k, k].slice(0, v.size())), PackedVector2Array())


func _bola(px: float, py: float, r: float, c) -> void:
	_ci.draw_circle(Vector2(px + _ox, py + _oy), r, Color(c))


func _larg(s: String, tam: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x


## Texto com y no topo; al: 0 esquerda, 1 centro, 2 direita.
func _txt(s: String, px: float, py: float, c: Color, tam: int, al := 0) -> void:
	var w := _larg(s, tam)
	var xx := px - w / 2.0 if al == 1 else (px - w if al == 2 else px)
	_ci.draw_string(font, Vector2(roundf(xx + _ox), roundf(py + _oy + font.get_ascent(tam))), s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, c)


func _proj(n: int, b: bool, yw: float, z: float, cam_x: float, cam_y: float, cam_z: float, W: float, H: float) -> void:
	var cz := z - cam_z
	var sc := CAMD / cz
	var sx := roundf(W / 2.0 - sc * cam_x * W / 2.0)
	var sy := roundf(H / 2.0 - sc * (yw - cam_y) * H / 2.0)
	var sw := sc * RW * W / 2.0
	if b:
		b_sx[n] = sx; b_sy[n] = sy; b_sw[n] = sw; b_sc[n] = sc
	else:
		a_sx[n] = sx; a_sy[n] = sy; a_sw[n] = sw; a_sc[n] = sc; a_cz[n] = cz


## Morro com paralaxe. A altura de cada pixel de u é calculada uma vez (tabela por morro, chave ab[0]):
## 850 senos por quadro custavam ~0,3 ms. shortcut: a rolagem anda em pixels inteiros, sem subpixel.
func _serra(c: Color, base: float, amp: float, off: float, ab: Array, fundo: float, W: float) -> void:
	var LW := 2.0 * W
	var o := int(fposmod(off * LW, LW))
	var tab: PackedFloat32Array = _serra_tab.get(ab[0], PackedFloat32Array())
	if tab.size() != int(3.0 * W) + 8:  # primeira vez, ou a janela mudou de largura no meio da corrida
		var f := PI / W
		tab.resize(int(3.0 * W) + 8)
		for u in tab.size():
			tab[u] = (sin(u * f * 3 + ab[0]) * 0.5 + sin(u * f * 7 + ab[1]) * 0.3 + sin(u * f * 13 + ab[2]) * 0.2 + 1) / 2.0
		_serra_tab[ab[0]] = tab
	var n := int((W + 3.0) / 3.0) + 1
	var pts := PackedVector2Array()
	pts.resize(n + 2)
	pts[0] = Vector2(W + 3, fundo)
	pts[1] = Vector2(0, fundo)
	for k in n:
		pts[k + 2] = Vector2(k * 3.0, fundo - (base + amp * tab[k * 3 + o]))
	cv.draw_colored_polygon(pts, c)


func _cidade(c: Color, off: float, fundo: float, W: float) -> void:
	var LW := 2.0 * W
	var esc := LW / 852.0
	var ox := fposmod(off * LW, LW)
	var claro := Car.tom(c, 1.5)
	for b in cidade:
		var bx := fposmod(b.x * esc - ox, LW)
		for rep in [bx, bx - LW]:
			if rep > W or rep + b.w * esc < 0:
				continue
			cv.draw_rect(Rect2(rep, fundo - b.h, b.w * esc, b.h), c)
			cv.draw_rect(Rect2(rep, fundo - b.h, 2, b.h), claro)
			for j in b.jan:
				cv.draw_rect(Rect2(rep + j.x * esc, fundo - b.h + j.y, 2, 3), K_ffd86b if j.z else K_8fe0ff)


func _desenha() -> void:
	_tt = Time.get_ticks_msec() / 1000.0
	var W := float(vp.size.x)
	var H := float(vp.size.y)
	if W < 10 or N == 0:
		return
	_ox = 0.0
	_oy = 0.0
	# céu em faixas, astro e serras com paralaxe
	var hz := H / 2.0 + 6.0
	for k in 14:
		cv.draw_rect(Rect2(0, hz * k / 14.0, W, hz / 14.0 + 1.0), _ceu_c[k])
	if T[6]:
		for e in estrelas:
			cv.draw_rect(Rect2(int(e.x * W), int(e.y * 95), 1, 1), K_ffe9a0 if e.z else Color.WHITE)
		cv.draw_circle(Vector2(W * 0.625, 52), 11, C.astro)
		cv.draw_circle(Vector2(W * 0.625 + 4, 49), 3, Car.tom(C.astro, 0.8))
	else:
		cv.draw_circle(Vector2(W * 0.625, 60), 22, Car.tom(C.astro, 0.92))
		cv.draw_circle(Vector2(W * 0.625, 60), 17, C.astro)
	var fundo := H / 2.0 + 2.0
	_serra(C.serra1, 20, 56, sky1, serra_ab[0], fundo, W)
	if T[9] == "c":
		_cidade(C.serra2, sky2, fundo, W)
	else:
		_serra(C.serra2, 8, 26, sky2, serra_ab[1], fundo, W)
	cv.draw_rect(Rect2(0, H / 2.0, W, H / 2.0), C.g0)
	# pista
	var base := int(pos / SEG) % N
	var bp := fmod(pos, SEG) / SEG
	var ps := int((pos + PZ) / SEG) % N
	var pp := fmod(pos + PZ, SEG) / SEG
	var cam_y := lerpf(y1[ps], y2[ps], pp) + CAMH
	var cam_x := x * RW
	var maxy := H
	var xx := 0.0
	var dx := -(curva[base] * bp)
	for n in DRAW:
		var i := (base + n) % N
		seg_i[n] = i
		var cz := pos - (comp if i < base else 0.0)
		_proj(n, false, y1[i], i * SEG, cam_x - xx, cam_y, cz, W, H)
		_proj(n, true, y2[i], (i + 1) * SEG, cam_x - xx - dx, cam_y, cz, W, H)
		xx += dx
		dx += curva[i]
		clip[n] = maxy
		if a_cz[n] <= CAMD or b_sy[n] >= a_sy[n] or b_sy[n] >= maxy:
			continue
		var asx := a_sx[n]; var asy := a_sy[n]; var asw := a_sw[n]
		var bsx := b_sx[n]; var bsy := b_sy[n]; var bsw := b_sw[n]
		var alt := (i / 3) % 2
		_rq(0.0, W, W, 0.0, asy, bsy, C.g1 if alt else C.g0)
		var box := i >= N - BOX0 and i < N - BOX1
		var ra := asw * 0.13
		var rb := bsw * 0.13
		var bx := 3.0 if box else 1.0
		var zeb: Color = C.z1 if alt else C.z0
		_rq(asx - asw - ra, asx - asw, bsx - bsw, bsx - bsw - rb, asy, bsy, zeb)
		_rq(asx + asw + ra * bx, asx + asw, bsx + bsw, bsx + bsw + rb * bx, asy, bsy, (Color.WHITE if alt else K_2a6cf0) if box else zeb)
		_rq(asx - asw, asx + asw, bsx + bsw, bsx - bsw, asy, bsy, Color.WHITE if i < 3 else (C.p1 if alt else C.p0))
		if i < 3:  # xadrez da largada
			for k in 12:
				if (k + i) % 2:
					_rq(asx - asw + asw * k / 6.0, asx - asw + asw * (k + 1) / 6.0, bsx - bsw + bsw * (k + 1) / 6.0, bsx - bsw + bsw * k / 6.0, asy, bsy, K_111111)
		elif asw > 14.0:  # mais longe que isso as faixas finas têm menos de 1 px: não valem o desenho
			for e in BORDAS:  # faixas de borda
				var la: float = asx + asw * e
				var lb: float = bsx + bsw * e
				_rq(la - asw * 0.022, la + asw * 0.022, lb + bsw * 0.022, lb - bsw * 0.022, asy, bsy, K_e8e8e8)
			if alt:
				for l in FAIXAS:
					var la: float = asx - asw + asw * 2.0 * l / 3.0
					var lb: float = bsx - bsw + bsw * 2.0 * l / 3.0
					_rq(la - asw * 0.02, la + asw * 0.02, lb + bsw * 0.02, lb - bsw * 0.02, asy, bsy, K_e8e8e8)
		var nv := float(n) / DRAW
		if nv > 0.35:  # névoa de distância
			var nev: Color = C.ceu1
			nev.a = minf(0.85, (nv - 0.35) * 1.5)
			_rq(0.0, W, W, 0.0, asy, bsy, nev)
		maxy = bsy
	if _rn > 0:  # a pista inteira num único comando (milhares de draw_primitive custavam ~1 ms)
		RenderingServer.canvas_item_add_triangle_array(cv.get_canvas_item(), _ri.slice(0, _rn * 6), _rp, _rc)
		_rn = 0
	# cenário, caixas e carros, de trás para frente
	var por := {}
	for c in cars:
		var i := int(c.z / SEG) % N
		if not por.has(i):
			por[i] = []
		por[i].append(c)
	for n in range(DRAW - 1, 0, -1):
		if a_cz[n] <= CAMD:
			continue
		var i := seg_i[n]
		var sc := a_sc[n]
		for e in spr[i]:
			_sprite(e, sc, a_sx[n] + sc * e.off * RW * W / 2.0, a_sy[n], clip[n], W)
		for k in pk:
			if k.i == i and k.t <= t:
				_sprite(_ent_caixa, sc, a_sx[n] + sc * k.off * RW * W / 2.0, a_sy[n] - sc * (260 + sin(t * 5) * 60) * H / 2.0, clip[n], W)
		for c in por.get(i, []):
			var p := fmod(c.z, SEG) / SEG
			var s2 := lerpf(sc, b_sc[n], p)
			var kk := CARW * s2 * W / 2.0 / 72.0
			var by := lerpf(a_sy[n], b_sy[n], p)
			if by - 40 * kk < clip[n] and kk > 0.02:
				_rival(c, c.j, lerpf(a_sx[n], b_sx[n], p) + s2 * c.off * RW * W / 2.0, by, kk, clip[n])
	# carro do jogador, fumaça e chama do nitro
	var qv := speed / VMAX
	var tre := (randi() % 3 - 1) if fora and qv > 0.05 else 0
	var px := W / 2.0 - 36.0 + (randi() % 2 if fora else 0)
	var py := H - 44.0 + (randi() % 2 if qv > 0.02 else 0) + tre
	if fum > 0 and qv > 0.1:
		for k in 6:
			var c2: Color = C.g1 if fora else K_d8d8d8
			var w := 2 + randi() % 4
			cv.draw_rect(Rect2(px + 8 + randf() * 10, py + 30 + randf() * 10, w, w), c2)
			cv.draw_rect(Rect2(px + 52 + randf() * 10, py + 30 + randf() * 10, w, w), c2)
	if nitro_t > 0:
		for fx in [17, 50]:
			cv.draw_rect(Rect2(px + fx, py + 33, 5, 4 + randi() % 7), K_ff7a1a)
			cv.draw_rect(Rect2(px + fx + 1, py + 33, 3, 2 + randi() % 5), K_ffe14a)
	Car.desenhar(cv, Vector2(px + 36, py + 40), 1.0, int(Game.s.carro), cor, clampi(roundi(steer * 2.2), -2, 2), fre, asa, cat, faixa)
	_hud(W, H)


## Coluna k (0..5, 4 px) da bandeira do país-sede, simplificada para 24x16 px.
func _pano(k: int, x0: float, y0: float) -> void:
	match T[2]:
		0:  # Brasil
			var h := 14.0 - absf(k - 2.5) * 4.0
			_ret(x0, y0, 4, 16, "#1f9a52"); _ret(x0, y0 + (16 - h) / 2, 4, h, "#eab308")
			if k == 2 or k == 3:
				_ret(x0, y0 + 5, 4, 6, "#2462d8")
		1:  # Portugal
			_ret(x0, y0, 4, 16, "#1f7a3a" if k < 2 else "#d02b2b")
			if k == 2:
				_ret(x0, y0 + 5, 4, 6, "#eab308")
		2:  # Angola
			_ret(x0, y0, 4, 8, "#d02b2b"); _ret(x0, y0 + 8, 4, 8, "#111111")
			if k == 2 or k == 3:
				_ret(x0, y0 + 6, 4, 4, "#eab308")
		_:  # Moçambique
			_ret(x0, y0, 4, 5, "#1f8a4a"); _ret(x0, y0 + 5, 4, 6, "#e4e6ea"); _ret(x0, y0 + 6, 4, 4, "#111111"); _ret(x0, y0 + 11, 4, 5, "#eab308")
			if k < 3:
				var h := 16.0 - k * 5.0
				_ret(x0, y0 + (16 - h) / 2, 4, h, "#d02b2b")


## Chave da arte sem animação no atlas. Torcida e bandeira têm uma chave por quadro (ver _ent e _sprite).
func _chave(tp: String, s: int) -> String:
	match tp:
		"predio", "torre": return tp + str(s % 6)
		"casa", "sobrado": return tp + str(s % 3)
		"outdoor": return tp + str(s % 10)
	return tp


## Desenha uma vez toda a arte do cenário e dos rivais num atlas (2x); depois cada objeto custa 1 chamada
## e pode ser recortado na linha do morro (ver _sprite).
func _cria_atlas() -> void:
	# [tipo, variante, quadro de animação]; "carro" = rival (variante = índice em cars, quadro = curva 0..2)
	var itens := []
	var variantes := {"predio": 6, "torre": 6, "casa": 3, "sobrado": 3, "outdoor": 10}
	for tp in SPR:
		if tp == "torcida":
			for v in 4:
				for f in 2:
					itens.append([tp, v, f * 0.31])
		elif tp == "bandeira":
			for f in 4:
				itens.append([tp, f, f * 0.224])
		else:
			for v in variantes.get(tp, 1):
				itens.append([tp, v, -1.0])
	for j in cars.size():
		for f in 3:
			itens.append(["carro", j, f])
	var av := SubViewport.new()
	av.size = Vector2i(2048, 2048)
	av.transparent_bg = true
	av.render_target_update_mode = SubViewport.UPDATE_ONCE
	var no := Node2D.new()
	av.add_child(no)
	add_child(av)
	var reg := {}
	var org := []
	var px := 1.0
	var py := 1.0
	var alt := 0.0
	for it in itens:
		var tam: Vector2 = Vector2(80, 44) if it[0] == "carro" else Vector2(SPR[it[0]][0], SPR[it[0]][1])
		if px + tam.x * ATL > 2047:
			px = 1.0
			py += alt + 2
			alt = 0.0
		org.append(Vector2(px, py))
		var ch: String
		match it[0]:
			"carro": ch = "carro%d_%d" % [it[1], it[2]]
			"torcida": ch = "torcida%d_%d" % [it[1], roundi(it[2] / 0.31)]
			"bandeira": ch = "bandeira%d" % it[1]
			_: ch = _chave(it[0], it[1])
		reg[ch] = Rect2(px, py, tam.x * ATL, tam.y * ATL)
		px += tam.x * ATL + 2
		alt = maxf(alt, tam.y * ATL)
	assert(py + alt < 2048, "atlas cheio")
	no.draw.connect(func():
		_ci = no
		_ox = 0.0
		_oy = 0.0
		for j in itens.size():
			var it: Array = itens[j]
			if it[0] == "carro":  # base do carro = centro de baixo da célula 80x44
				var c: Dictionary = cars[it[1]]
				Car.desenhar(no, org[j] + Vector2(40, 42) * ATL, ATL, c.mi, c.cor, it[2], false, -1, cat, c.faixa)
				continue
			no.draw_set_transform(org[j], 0.0, Vector2(ATL, ATL))
			_arte(it[0], it[1], 999.0, it[2])
		_ci = cv)
	await RenderingServer.frame_post_draw
	_atlas = av.get_texture()
	_reg = reg


## Desenha um pedaço do atlas com base em (X, Y), escala k, espelhado se d < 0, cortando tudo abaixo de lim
## (a linha do morro à frente): só aparece o que está acima dela.
func _do_atlas(rg: Rect2, w: float, h: float, X: float, Y: float, k: float, d: float, lim: float) -> void:
	var visivel := minf(h, (lim - (Y - h * k)) / k)
	if visivel <= 0.0:
		return
	cv.draw_set_transform(Vector2(X, Y), 0.0, Vector2(k * d, k))
	cv.draw_texture_rect_region(_atlas, Rect2(-w / 2.0, -h, w, visivel), Rect2(rg.position, Vector2(rg.size.x, rg.size.y * visivel / h)))
	cv.draw_set_transform(Vector2.ZERO)


## Rival: do atlas (com recorte); antes do atlas ficar pronto, desenhado na hora.
func _rival(c: Dictionary, j: int, X: float, Y: float, kk: float, lim: float) -> void:
	var rg = _reg.get("carro%d_%d" % [j, absi(c.vir)])
	if rg:
		_do_atlas(rg, 80.0, 44.0, X, Y + 2.0 * kk, kk, -1.0 if c.vir < 0 else 1.0, lim)
	else:
		Car.desenhar(cv, Vector2(X, Y), kk, c.mi, c.cor, c.vir, false, -1, cat, c.faixa)


## Cenário em pixel art; (0,0) do desenho = canto superior esquerdo do sprite.
func _sprite(e: Dictionary, sc: float, X: float, Y: float, lim: float, W: float) -> void:
	var dd: Array = e.dd
	var dw: float = dd[2] * ESC * sc * W / 2.0
	if dw < 2.5:  # longe demais para valer o desenho
		return
	var k: float = dw / dd[0]
	if Y - dd[1] * k >= lim or X + dw / 2.0 < 0 or X - dw / 2.0 > W:
		return
	var ks: Array = e.k
	var rg = _reg.get(ks[0] if ks.size() == 1 else ks[(int(_tt * e.r) + e.s) % ks.size()])
	if rg:
		_do_atlas(rg, dd[0], dd[1], X, Y, k, e.d, lim)
		return
	# só nos primeiros quadros, antes de o atlas ficar pronto
	cv.draw_set_transform(Vector2(X, Y), 0.0, Vector2(k * e.d, k))
	_ox = -dd[0] / 2.0
	_oy = -dd[1]
	_arte(e.t, e.s, dw)
	_ox = 0.0
	_oy = 0.0
	cv.draw_set_transform(Vector2.ZERO)


## Arte de cada objeto com primitivas em `_ci`; dw = largura na tela (detalhe da torcida e da bandeira);
## quadro = instante da animação (torcida/bandeira); -1 = relógio.
func _arte(tp: String, s: int, dw: float, quadro := -1.0) -> void:
	var dd: Array = SPR[tp]
	var f: Color = C.folha
	match tp:
		"arvore":
			_ret(18, 32, 6, 24, "#4a2e14"); _ret(18, 32, 2, 24, "#7a5226")
			_bola(20, 22, 17, Car.tom(f, 0.5)); _bola(19, 20, 16, Car.tom(f, 0.75)); _bola(17, 17, 13, f)
			_bola(13, 12, 7, Car.tom(f, 1.25)); _bola(25, 11, 5, Car.tom(f, 1.25)); _bola(11, 9, 3, Car.tom(f, 1.5))
			_bola(27, 29, 5, Car.tom(f, 0.5)); _bola(11, 30, 4, Car.tom(f, 0.5)); _bola(30, 18, 4, Car.tom(f, 0.75))
		"pinheiro":
			_ret(14, 48, 4, 12, "#4a2e14")
			for yw in [[30, 15], [18, 12], [6, 9]]:
				var y0: float = yw[0]
				var w: float = yw[1]
				_tri(Car.tom(f, 0.6), [16, y0 - 8, 16 + w, y0 + 18, 16 - w, y0 + 18])
				_tri(f, [16, y0 - 8, 16 + w - 3, y0 + 16, 16 - w, y0 + 18])
				_tri(Car.tom(f, 1.3), [16, y0 - 8, 18, y0 + 2, 10, y0 + 12])
			_ret(15, 0, 2, 2, "#f4f8ff")
		"palmeira":
			for i in 11:
				var tx := 22 + sin(i / 3.2) * 4
				_ret(tx, 22 + i * 4, 5, 4, "#8a6a3a" if i % 2 else "#6f5228")
			for fo in [[3, 30, 0.6], [8, 12, 0.8], [24, 3, 1.0], [40, 12, 0.8], [45, 30, 0.6], [14, 24, 1.25], [34, 24, 1.25]]:
				var meio := Vector2((24 + fo[0]) / 2.0 + _ox, fo[1] - 10 + _oy)
				_ci.draw_polyline(PackedVector2Array([Vector2(24 + _ox, 22 + _oy), meio, Vector2(fo[0] + _ox, fo[1] + _oy)]), Car.tom(f, fo[2]), 5.0)
			_bola(23, 23, 3, "#6f5228"); _bola(26, 24, 2, "#8a4a1a")
		"cacto":
			_ret(10, 4, 8, 40, Car.tom(f, 0.7)); _ret(10, 4, 5, 40, f); _ret(11, 5, 1, 38, Car.tom(f, 1.3))
			_ret(2, 12, 5, 12, Car.tom(f, 0.7)); _ret(2, 12, 3, 12, f); _ret(5, 20, 6, 4, f)
			_ret(21, 18, 5, 14, Car.tom(f, 0.7)); _ret(21, 18, 3, 14, f); _ret(17, 28, 6, 4, f); _ret(12, 2, 3, 3, "#e86aa0")
		"pedra":
			_tri("#55504a", [0, 22, 14, 1, 27, 3, 36, 22]); _tri("#7d7468", [4, 20, 14, 3, 24, 5, 30, 20])
			_tri("#a39a8e", [8, 10, 14, 4, 19, 9, 12, 13]); _tri("#55504a", [20, 22, 24, 12, 32, 14, 36, 22])
		"arbusto":
			_bola(8, 11, 7, Car.tom(f, 0.55)); _bola(20, 11, 7, Car.tom(f, 0.55)); _bola(14, 9, 8, Car.tom(f, 0.8))
			_bola(12, 7, 5, f); _bola(10, 5, 2, Car.tom(f, 1.3)); _bola(19, 8, 1, "#e8d44a")
		"poste":
			_ret(10, 8, 3, 56, "#3c3f4a"); _ret(10, 8, 1, 56, "#5d6170"); _ret(3, 6, 17, 2, "#3c3f4a"); _ret(8, 60, 7, 4, "#2a2c33")
			for bx in [4, 18]:
				_bola(bx, 10, 4, "#fff3b0"); _bola(bx, 10, 2, "#ffffff")
		"predio", "torre":
			var bc: Color = [Color("#2a2a48"), Color("#3a2f4f"), Color("#24364f")][s % 3]
			var bw: float = dd[0]
			var bh: float = dd[1]
			_ret(0, 6, bw, bh - 6, bc); _ret(0, 6, 3, bh - 6, Car.tom(bc, 1.25)); _ret(bw - 4, 6, 4, bh - 6, Car.tom(bc, 0.7))
			_ret(0, 6, bw, 2, Car.tom(bc, 1.4)); _ret(bw / 2 - 6, 0, 12, 6, Car.tom(bc, 0.8)); _ret(bw / 2 - 1, 0, 2, 1, "#e02b2b")
			var hh := s
			for yy in range(12, int(bh) - 6, 8):
				for wx in range(6, int(bw) - 8, 7):
					hh = (hh * 1103515245 + 12345) & 0x7fffffff
					_ret(wx, yy, 4, 5, "#ffd86b" if hh % 100 < 55 else "#12121f")
			_ret(bw / 2 - 5, bh - 8, 10, 8, "#12121f")
		"casa", "sobrado":
			var pc: Color = [Color("#e8d8b8"), Color("#d8e4ee"), Color("#f0c8a0")][s % 3]
			var alto := tp == "sobrado"
			var top := 16.0
			var bw: float = dd[0]
			var bh: float = dd[1]
			_ret(5, top, bw - 10, bh - top, pc); _ret(bw - 10, top, 5, bh - top, Car.tom(pc, 0.8))
			_tri("#a0402a", [0, top + 1, bw / 2, 2, bw, top + 1])
			_ret(bw / 2 - 4, bh - 12, 7, 12, "#5a3a1c")
			for jy in ([top + 5, top + 19] if alto else [top + 5]):
				_ret(9, jy, 7, 6, "#8fc4e8"); _ret(bw - 16, jy, 7, 6, "#8fc4e8")
		"outdoor":
			var fr: Array = FRASES[s % FRASES.size()]
			var oc: Color = [Color("#1f5fe0"), Color("#c2392b"), Color("#1f7a4d"), Color("#7a3ad0")][s % 4]
			_ret(14, 26, 4, 20, "#4a4d58"); _ret(54, 26, 4, 20, "#4a4d58"); _ret(0, 0, 72, 28, "#d8dce6"); _ret(2, 2, 68, 24, oc)
			_txt(fr[0], 36, 2, Color.WHITE, 9, 1); _txt(fr[1], 36, 13, Color("#ffe14a"), 9, 1)
		"seta":
			_ret(12, 20, 3, 14, "#4a4d58"); _ret(0, 0, 26, 22, "#111111"); _ret(1, 1, 24, 20, "#f2c21b")
			for sx in [3, 11]:
				_tri("#111111", [sx, 3, sx + 5, 3, sx + 11, 11, sx + 6, 11]); _tri("#111111", [sx + 6, 11, sx + 11, 11, sx + 5, 19, sx, 19])
		"placa":
			_ret(22, 24, 4, 20, "#4a4d58"); _ret(0, 0, 48, 26, "#ffffff"); _ret(2, 2, 44, 22, "#1f5fe0")
			_txt("BOX", 18, 4, Color.WHITE, 11, 1); _tri("#ffe14a", [32, 8, 40, 13, 32, 18])
		"portico":
			for px in [6, 244]:
				_ret(px, 0, 10, 76, "#3c3f4a"); _ret(px, 0, 3, 76, "#5d6170")
			_ret(0, 0, 260, 30, "#1a1a22")
			for cx in range(0, 260, 10):
				for cy in [0, 5]:
					_ret(cx, cy, 10, 5, "#ffffff" if (cx / 10 + cy / 5) % 2 else "#111111")
			_ret(0, 10, 260, 18, "#c2392b"); _ret(0, 10, 260, 2, "#e86a5a")
			_txt("TURBO GRAMÁTICA", 130, 12, Color.WHITE, 13, 1)
		"caixa":
			_ret(0, 0, 22, 22, "#8a5a00"); _ret(2, 2, 18, 18, "#ffd400"); _ret(2, 2, 18, 2, "#fff3a0"); _ret(2, 18, 18, 2, "#c99a00")
			_txt("?", 11, 2, Color("#3a2a00"), 14, 1)
		"torcida":
			var tt: float = quadro if quadro >= 0.0 else Time.get_ticks_msec() / 1000.0
			_ret(0, 0, 80, 4, "#c2392b"); _ret(0, 4, 80, 2, "#e86a5a"); _ret(2, 6, 3, 30, "#3c3f4a"); _ret(75, 6, 3, 30, "#3c3f4a")
			_ret(0, 34, 80, 10, "#5d6170"); _ret(0, 34, 80, 2, "#8a8fa0")
			for fl in 4:
				var yb := 9.0 + fl * 6
				_ret(4, yb + 4, 72, 2, "#2a2c33")
				if dw < 30.0:  # longe: a fila vira uma faixa colorida
					_ret(5, yb, 70, 4, ["#c8604a", "#4a7ac8", "#d8b040", "#5aa860"][(s + fl) % 4])
					continue
				for c in 12:
					var hh := (s + fl * 31 + c * 7) * 2654435761 & 0xffff
					var pula := -1.0 if sin(tt * 10.0 + c * 1.3 + fl * 2.1 + s) > 0.5 else 0.0
					_ret(5 + c * 6, yb + 1 + pula, 4, 3, ["#d02b2b", "#2462d8", "#eab308", "#1f9a52", "#e4e6ea", "#ea6c12"][hh % 6])
					_ret(6 + c * 6, yb - 1 + pula, 2, 2, ["#f0c8a0", "#c8905a", "#8a5a34", "#5a3a20"][(hh >> 4) % 4])
		"bandeira":
			var tt: float = quadro if quadro >= 0.0 else Time.get_ticks_msec() / 1000.0
			_ret(2, 0, 2, 64, "#c8ccd6"); _ret(1, 0, 4, 2, "#ffd400")
			if dw < LOD:  # longe: só a cor principal
				_ret(4, 2, 24, 16, ["#1f9a52", "#d02b2b", "#d02b2b", "#1f8a4a"][T[2]])
				return
			for col in 6:
				_pano(col, 4 + col * 4, 2 + sin(tt * 7.0 - col * 0.9) * col * 0.3)


func _caixa_hud(px: float, py: float, w: float, h: float) -> void:
	cv.draw_rect(Rect2(px, py, w, h), Color(NAVY, 0.72))
	cv.draw_rect(Rect2(px, py, w, h), K_dfe6ff, false, 1.0)


func _hud(W: float, H: float) -> void:
	var p := pos_final if est == "fim" else _posicao()
	var kmh := roundi(speed / VMAX * 240)
	_caixa_hud(4, 4, 74, 34)
	_txt(str(p), 8, 4, AMARELO, 24)
	_txt("º/12", 8 + _larg(str(p), 24) + 1, 16, Color.WHITE, 9)
	_txt("VOLTA %d/%d" % [volta, Game.VOLTAS], W / 2, 4, Color.WHITE, 9, 1)
	_txt(_tempo(t), W / 2, 15, AMARELO, 9, 1)
	cv.draw_rect(Rect2(W / 2 - 60, 30, 120, 3), NAVY)  # progresso da volta com os adversários
	for c in cars:
		cv.draw_rect(Rect2(W / 2 - 60 + int(fmod(c.dist, comp) / comp * 118), 29, 2, 5), K_ff6b6b)
	cv.draw_rect(Rect2(W / 2 - 60 + int(fmod(dist, comp) / comp * 118), 28, 3, 7), AMARELO)
	_caixa_hud(W - 100, 4, 96, 34)
	_txt("COMB", W - 96, 5, Color.WHITE, 8)
	cv.draw_rect(Rect2(W - 66, 8, 58, 6), K_20244a)
	var pisca := fmod(t * 4, 1.0) < 0.5
	cv.draw_rect(Rect2(W - 66, 8, int(58 * fuel), 6), (K_ff3030 if pisca else K_801010) if fuel < 0.2 else K_3fd97f)
	_txt("NITRO", W - 96, 15, K_6fc0ff, 8)
	for i in nitro:
		cv.draw_rect(Rect2(W - 62 + i * 9, 18, 6, 6), K_ffe14a if nitro_t > 0 and i == nitro - 1 else K_2f8fff)
	cv.draw_circle(Vector2(W - 91, 31), 4, AMARELO)
	_txt(str(int(Game.s.moedas)), W - 84, 25, AMARELO, 8)
	_caixa_hud(4, H - 40, 112, 36)  # velocímetro, conta-giros e marcha
	_txt(str(kmh), 62, H - 41, Color.WHITE, 22, 2)
	_txt("km/h", 64, H - 28, K_bcd0ff, 8)
	for i in 16:
		var on := i < rpm * 16
		cv.draw_rect(Rect2(8 + i * 5, H - 13, 4, 6), (K_ff3030 if i > 12 else (AMARELO if i > 9 else K_3fd97f)) if on else K_20244a)
	cv.draw_rect(Rect2(92, H - 37, 20, 20), AMARELO)
	cv.draw_rect(Rect2(93, H - 36, 18, 18), NAVY)
	_txt(str(m + 1), 102, H - 39, K_ff3030 if rpm > 0.94 and Game.s.manual else Color.WHITE, 16, 1)
	_txt("MAN" if Game.s.manual else "AUTO", 102, H - 16, K_bcd0ff, 7, 1)
	if est == "contagem":  # luzes de largada
		var n := ceili(cont / 0.9)
		_caixa_hud(W / 2 - 34, 52, 68, 26)
		for i in 3:
			cv.draw_circle(Vector2(W / 2 - 20 + i * 20, 65), 8, K_1a1a22)
			cv.draw_circle(Vector2(W / 2 - 20 + i * 20, 65), 6, K_ff2a2a if n <= 3 - i and n > 0 else K_4a1010)
	if msg != "" and (not msg[0] in "SC" or fmod(t * 3, 1.0) < 0.6):
		var grande := msg.length() <= 14
		_txt(msg, W / 2, 54 if grande else 60, K_6fc0ff if msg[0] == "[" else AMARELO, 20 if grande else 12, 1)
