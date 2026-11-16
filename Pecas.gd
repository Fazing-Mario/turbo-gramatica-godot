extends RefCounted
## Ícones das peças da garagem em pixel art 48x32, desenhados com primitivas (mesmo estilo do Car.gd).
## Uso: Pecas.desenhar(canvas, id, centro, escala)

const MET := "#9aa0ad"   # metal
const MEC := "#6b707c"   # metal escuro
const ESC := "#3c3f4a"
const PRE := "#24262e"
const BOR := "#16161c"   # borracha
const CLA := "#d8dce6"
const VER := "#d02b2b"
const AMA := "#eab308"
const AZU := "#2462d8"

static var _ci: CanvasItem


static func _r(x: float, y: float, w: float, h: float, c) -> void:
	_ci.draw_rect(Rect2(x, y, w, h), Color(c))


static func _b(x: float, y: float, r: float, c) -> void:
	_ci.draw_circle(Vector2(x, y), r, Color(c))


static func _p(c, pts: Array) -> void:
	var v := PackedVector2Array()
	for i in range(0, pts.size(), 2):
		v.append(Vector2(pts[i], pts[i + 1]))
	_ci.draw_colored_polygon(v, Color(c))


static func _l(x1: float, y1: float, x2: float, y2: float, c, w := 1.0) -> void:
	_ci.draw_line(Vector2(x1, y1), Vector2(x2, y2), Color(c), w)


static func _t(s: String, x: float, y: float, c, tam := 7) -> void:
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	_ci.draw_string(f, Vector2(x - w / 2.0, y + f.get_ascent(tam)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(c))


## Engrenagem: disco com dentes em volta.
static func _eng(x: float, y: float, r: float, dentes: int, c) -> void:
	for i in dentes:
		var a := TAU * i / dentes
		_b(x + cos(a) * r, y + sin(a) * r, maxf(1.2, r * 0.22), c)
	_b(x, y, r * 0.88, c)
	_b(x, y, r * 0.3, PRE)


## Pneu de lado: borracha, banda colorida opcional, aro e cubo; cravos = blocos na banda de rodagem.
static func _pneu(aro, faixa, cravos: int, grossos: bool) -> void:
	_b(24, 16, 15, BOR)
	for i in cravos:
		var a := TAU * i / cravos
		_b(24 + cos(a) * 14.5, 16 + sin(a) * 14.5, 2.6 if grossos else 1.3, "#2e2e36")
	if faixa:
		_b(24, 16, 11.5, faixa)
		_b(24, 16, 10.5, BOR)
	_b(24, 16, 9, aro)
	_b(24, 16, 3, PRE)


## Disco de freio com pinça.
static func _disco(cor_disco, furos: bool, pinca, larg := 10.0) -> void:
	_b(20, 16, 14, cor_disco)
	_b(20, 16, 6, MEC)
	_b(20, 16, 2.5, PRE)
	if furos:
		for i in 8:
			var a := TAU * i / 8
			_b(20 + cos(a) * 10, 16 + sin(a) * 10, 1.2, PRE)
	_r(28, 16 - 12, larg, 24, pinca)
	_r(28, 16 - 12, larg, 2, Color(pinca).lightened(0.35))


## Garrafa de nitro.
static func _garrafa(x: float, c, faixa := "#e4e6ea") -> void:
	_r(x, 8, 12, 22, c)
	_r(x, 8, 3, 22, Color(c).lightened(0.3))
	_r(x, 16, 12, 4, faixa)
	_r(x + 3, 3, 6, 5, MET)
	_r(x + 4, 0, 4, 3, VER)


static func desenhar(ci: CanvasItem, id: String, centro: Vector2, k: float) -> void:
	_ci = ci
	ci.draw_set_transform(centro - Vector2(24, 16) * k, 0.0, Vector2(k, k))
	match id:
		# ---------------- motor
		"v6":
			_r(8, 12, 32, 16, MET); _r(8, 24, 32, 4, MEC); _r(6, 5, 36, 8, VER); _r(6, 5, 36, 2, "#ff6a5a")
			for i in 3:
				_r(12 + i * 10, 0, 4, 5, ESC)
			_b(10, 22, 4, PRE); _t("V6", 24, 5, "#ffffff")
		"boxer":
			_r(8, 10, 32, 14, MET); _r(8, 20, 32, 4, MEC); _r(0, 8, 9, 18, VER); _r(39, 8, 9, 18, VER)
			for i in 4:
				_r(1, 10 + i * 4, 7, 1, "#8a1a1a"); _r(40, 10 + i * 4, 7, 1, "#8a1a1a")
			_t("BOXER", 24, 11, PRE)
		"turbo":
			_r(2, 13, 12, 7, "#c86a2a"); _r(2, 13, 12, 2, "#f0a060")
			_b(24, 17, 12, MET); _b(24, 17, 8, MEC); _b(24, 17, 5, CLA); _b(24, 17, 2, PRE)
			_r(30, 2, 16, 8, MET); _r(30, 2, 16, 2, CLA)
		"super":
			_r(6, 18, 36, 12, MET); _r(6, 26, 36, 4, MEC); _r(10, 7, 28, 12, CLA); _r(10, 7, 28, 2, "#ffffff")
			for i in 6:
				_r(12 + i * 4, 10, 2, 8, MET)
			_r(2, 6, 5, 22, PRE); _r(16, 0, 16, 7, VER)
		"v12":
			_r(2, 12, 44, 14, MET); _r(2, 22, 44, 4, MEC); _r(2, 5, 21, 7, VER); _r(25, 5, 21, 7, VER)
			_b(6, 28, 4, CLA); _b(42, 28, 4, CLA); _b(6, 28, 2, MEC); _b(42, 28, 2, MEC); _t("V12", 24, 13, PRE)
		"wankel":
			_b(24, 16, 15, MEC); _b(24, 16, 13, ESC)
			_p(CLA, [24, 4, 36, 23, 12, 23]); _p("#ffffff", [24, 4, 27, 9, 21, 9])
			_b(24, 17, 4, PRE); _r(40, 14, 8, 4, AMA)
		# ---------------- câmbio
		"curta":
			_eng(17, 18, 10, 9, MET); _eng(35, 12, 6, 6, CLA)
		"longa":
			_eng(14, 12, 6, 6, CLA); _eng(31, 18, 11, 10, MET)
		"seq":
			_r(14, 26, 20, 6, ESC); _r(18, 2, 12, 24, PRE); _r(22, 10, 4, 16, MET); _b(24, 9, 6, VER); _b(22, 7, 2, "#ff8a7a")
			_t("+", 34, 2, "#3fd97f", 9); _t("-", 34, 18, "#ff5050", 9)
		"lsd":
			_r(0, 14, 48, 4, MET); _b(24, 16, 13, MEC); _eng(24, 16, 8, 10, CLA); _b(24, 16, 3, AMA)
		"dct":
			_b(18, 16, 12, CLA); _b(18, 16, 7, ESC); _b(31, 16, 12, AMA); _b(31, 16, 7, ESC); _t("DCT", 31, 12, "#ffffff")
		"comp":
			_r(4, 6, 40, 22, ESC)
			for i in 5:
				_r(6 + i * 8, 8, 2, 18, PRE)
			_eng(24, 17, 7, 8, AMA); _t("6", 40, 6, "#ffffff", 8)
		# ---------------- pneus
		"esportivo": _pneu(CLA, null, 16, false)
		"misto": _pneu(ESC, null, 10, true)
		"slick": _pneu(MET, AMA, 0, false)
		"rali": _pneu("#e4e6ea", null, 12, true)
		"composto": _pneu(PRE, VER, 0, false)
		"magnesio":
			_pneu("#c8a040", null, 0, false)
			for i in 5:
				var a := TAU * i / 5
				_l(24, 16, 24 + cos(a) * 8, 16 + sin(a) * 8, "#7a5a20", 2.0)
			_b(24, 16, 3, PRE)
		# ---------------- freios
		"pastilha": _disco(MET, false, VER); _r(26, 7, 3, 18, ESC)
		"ventilado": _disco(MET, true, ESC)
		"pinca":
			_disco(MET, false, AMA, 14)
			for i in 3:
				_b(35, 9 + i * 7, 2, "#a07a00")
		"abs":
			_disco(MET, true, ESC); _b(20, 16, 8, PRE); _b(20, 16, 6, MEC)
			_r(36, 22, 12, 9, PRE); _t("ABS", 42, 23, "#3fd97f", 6)
		"carbono":
			_disco("#2a2a32", true, "#c8a040")
			for i in 6:
				_r(10 + i * 3, 8 + (i % 2) * 14, 1, 1, "#5a5a68")
		"kers":
			_b(14, 18, 11, MET); _b(14, 18, 5, MEC); _r(26, 4, 20, 22, "#1f9a52"); _r(26, 4, 20, 3, "#3fd97f")
			_p(AMA, [38, 7, 30, 16, 35, 16, 32, 24, 41, 13, 36, 13])
		# ---------------- nitro
		"cilindro": _garrafa(18, AZU)
		"bico":
			_r(0, 14, 24, 4, MET); _p(MEC, [24, 12, 30, 15, 30, 17, 24, 20])
			_p(Color("#8fc4e8", 0.8), [30, 16, 48, 6, 48, 26])
		"seco": _garrafa(10, AZU); _r(26, 18, 10, 8, VER); _l(22, 20, 26, 22, ESC, 2.0); _l(36, 22, 46, 22, ESC, 2.0)
		"molhado":
			_garrafa(6, AZU); _l(18, 20, 30, 20, ESC, 2.0); _l(18, 25, 30, 25, VER, 2.0)
			_p(Color("#c8e8ff", 0.8), [30, 22, 48, 12, 48, 32])
		"dupla": _garrafa(10, AZU); _garrafa(26, AZU)
		"direta":
			_garrafa(2, "#7a3ad0"); _r(24, 22, 24, 6, MET)
			for i in 4:
				_l(14, 12, 27 + i * 6, 22, AZU, 1.5)
		# ---------------- carenagem
		"parachoque":
			_r(2, 12, 44, 12, ESC); _r(2, 12, 44, 2, "#5d6170")
			for i in 3:
				_r(8 + i * 14, 15, 6, 6, MET)
		"saia": _r(0, 17, 48, 8, VER); _r(0, 17, 48, 2, "#ff6a5a"); _r(0, 23, 48, 2, "#8a1a1a")
		"aerofolio":
			_r(10, 11, 3, 16, PRE); _r(35, 11, 3, 16, PRE); _r(2, 6, 44, 6, ESC); _r(2, 6, 44, 2, "#5d6170")
			_r(0, 3, 3, 11, VER); _r(45, 3, 3, 11, VER)
		"widebody":
			_r(2, 6, 44, 22, VER); _r(2, 6, 44, 3, "#ff6a5a"); _b(24, 30, 14, "#8a1a1a"); _b(24, 31, 12, BOR); _b(24, 31, 6, MET)
		"fibra":
			_r(4, 4, 40, 24, "#1a1a22")
			for yy in range(4, 28, 4):
				for xx in range(4, 44, 4):
					if (xx + yy) % 8 == 0:
						_r(xx, yy, 4, 4, "#34343f")
		"drs":
			_r(10, 18, 3, 12, PRE); _r(35, 18, 3, 12, PRE); _r(2, 14, 44, 5, ESC)
			_p("#3fd97f", [2, 12, 46, 12, 46, 4, 2, 9]); _t("DRS", 24, 22, "#ffffff", 6)
		# ---------------- combustível
		"tanque80":
			_r(4, 8, 40, 20, MET); _r(4, 8, 40, 3, CLA); _r(12, 6, 3, 24, ESC); _r(33, 6, 3, 24, ESC); _b(24, 8, 4, PRE); _t("80L", 24, 15, PRE)
		"injecao":
			_r(20, 0, 8, 20, ESC); _r(18, 3, 12, 4, AMA); _p(MET, [20, 20, 28, 20, 24, 25])
			_p(Color("#8fc4e8", 0.8), [24, 25, 16, 32, 32, 32])
		"celula":
			_r(6, 6, 36, 22, VER)
			for i in 5:
				_l(6, 8 + i * 5, 42, 8 + i * 5, "#5a0f0f"); _l(10 + i * 8, 6, 10 + i * 8, 28, "#5a0f0f")
			_r(14, 12, 20, 9, PRE); _t("FUEL", 24, 12, "#ffffff", 6)
		"chip":
			_r(10, 8, 28, 16, "#1f5a33")
			for i in 6:
				_r(12 + i * 4, 4, 2, 4, "#c8a040"); _r(12 + i * 4, 24, 2, 4, "#c8a040")
			_r(18, 12, 12, 8, PRE); _t("ECO", 24, 12, "#3fd97f", 6)
		"engate":
			_r(0, 13, 20, 6, MET); _r(20, 8, 10, 16, AMA); _r(20, 8, 10, 3, "#ffe680"); _r(30, 13, 18, 6, PRE)
		"hibrido":
			_r(6, 8, 36, 18, PRE); _r(10, 4, 6, 4, VER); _r(32, 4, 6, 4, ESC)
			_p("#3fd97f", [26, 10, 18, 18, 23, 18, 20, 25, 30, 16, 25, 16])
		# ---------------- telemetria
		"radio":
			_r(16, 6, 16, 24, PRE); _r(28, 0, 3, 7, ESC); _r(19, 9, 10, 6, "#8fe0ff")
			for i in 3:
				_r(19, 18 + i * 3, 10, 1, ESC)
		"tpms":
			_b(16, 18, 11, BOR); _b(16, 18, 6, CLA); _b(16, 18, 2, PRE)
			for r in [6, 10, 14]:
				_ci.draw_arc(Vector2(30, 10), r, -1.2, 0.2, 8, Color("#3fd97f"), 1.5)
		"engenheiro":
			_ci.draw_arc(Vector2(24, 20), 15, PI, TAU, 16, Color(ESC), 3.0)
			_r(6, 16, 7, 12, PRE); _r(35, 16, 7, 12, PRE); _l(13, 24, 22, 30, ESC, 1.5); _b(23, 30, 2, VER)
		"gps":
			_r(6, 3, 36, 26, PRE); _r(8, 5, 32, 22, "#2f8a3a")
			_ci.draw_polyline(PackedVector2Array([Vector2(10, 24), Vector2(18, 16), Vector2(28, 18), Vector2(38, 8)]), Color(AMA), 2.0)
			_b(38, 8, 3, VER)
		"telemetria":
			_r(8, 2, 32, 20, PRE); _r(10, 4, 28, 16, "#0a1b33"); _r(4, 22, 40, 6, MET)
			_ci.draw_polyline(PackedVector2Array([Vector2(11, 16), Vector2(17, 9), Vector2(22, 13), Vector2(28, 6), Vector2(36, 11)]), Color("#3fd97f"), 1.5)
		"ia":
			_r(12, 6, 24, 20, ESC)
			for i in 5:
				_r(14 + i * 4, 2, 2, 4, MET); _r(14 + i * 4, 26, 2, 4, MET); _r(8, 8 + i * 4, 4, 2, MET); _r(36, 8 + i * 4, 4, 2, MET)
			_t("IA", 24, 11, "#12d8f0", 9)
		_:  # vaga vazia
			_r(4, 4, 40, 24, Color(1, 1, 1, 0.06)); _t("?", 24, 9, "#5a6080", 12)
	ci.draw_set_transform(Vector2.ZERO)
