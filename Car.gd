extends RefCounted
## Desenho do carro visto de trás, em pixel art 72x40 (quadros de curva e luz de freio).
## Uso: Car.desenhar(canvas, base_centro_inferior, escala, modelo, cor, curva -2..2, freio)

static var _ci: CanvasItem


static func tom(c: Color, f: float) -> Color:
	if f <= 1.0:
		return Color(c.r * f, c.g * f, c.b * f)
	return Color(c.r + (1.0 - c.r) * (f - 1.0), c.g + (1.0 - c.g) * (f - 1.0), c.b + (1.0 - c.b) * (f - 1.0))


static func _r(x: float, y: float, w: float, h: float, c) -> void:
	_ci.draw_rect(Rect2(x - 36.0, y - 40.0, w, h), Color(c))


static func _p(c, pts: Array) -> void:
	var v := PackedVector2Array()
	for i in range(0, pts.size(), 2):
		v.append(Vector2(pts[i] - 36.0, pts[i + 1] - 40.0))
	var cor := Color(c)
	_ci.draw_primitive(v, PackedColorArray([cor, cor, cor, cor].slice(0, v.size())), PackedVector2Array())


static func _bola(x: float, y: float, raio: float, c) -> void:
	_ci.draw_circle(Vector2(x - 36.0, y - 40.0), raio, Color(c))


## asa: -1 = a do modelo; 1 = lábio; 2 = aerofólio; 3 = aerofólio com asa móvel (DRS).
## corpo: "gt" (os 4 modelos), "stock", "rali" ou "formula"; faixa: cor da equipe (transparente = sem faixa).
static func desenhar(ci: CanvasItem, base: Vector2, k: float, mi: int, cor: Color, curva: int, freio: bool, asa := -1,
		corpo := "gt", faixa := Color(0, 0, 0, 0)) -> void:
	if corpo != "gt":
		_outro(ci, base, k, corpo, cor, curva, freio, asa, faixa)
		return
	_ci = ci
	ci.draw_set_transform(base, 0.0, Vector2(-k if curva < 0 else k, k))
	var m: Dictionary = Game.MODELOS[mi]
	var c := []
	for f in [0.42, 0.62, 0.8, 1.0, 1.22, 1.5]:
		c.append(tom(cor, f))
	var f := absi(curva)
	var s := f * 4.0
	var d := s * 0.5
	var t := s * 0.9
	var X := 36.0
	var rt: float = m.rt
	var rb: float = m.rb
	var ry: float = m.ry
	var sombra := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		sombra.append(Vector2(X + s / 2.0 - 36.0 + cos(a) * (29.0 + s / 2.0), 37.0 - 40.0 + sin(a) * 3.0))
	ci.draw_colored_polygon(sombra, Color("#0a0a12"))
	if f:
		_r(57 + s, 25, 6, 11, "#121218"); _r(58 + s, 27, 1, 8, "#2a2a34")  # roda dianteira aparece na curva
		_p(c[1], [62, 15, 62 + s, 14, 63 + s, 28, 63, 29]); _p(c[0], [62, 25, 63 + s, 24, 63 + s, 28, 63, 29])
		_p("#16233c", [X + rb + d, 11, X + rb + d + s * 0.8, 10.5, X + rt + t + s * 0.7, ry + 2, X + rt + t, ry + 2])
	for x in [8, 53]:
		_r(x, 23, 11, 14, "#121218"); _r(x + 2, 25, 1, 11, "#2c2c38"); _r(x + 5, 25, 1, 11, "#2c2c38"); _r(x + 8, 25, 1, 11, "#2c2c38")
	_r(11, 28, 50, 6, "#24242c"); _r(11, 28, 50, 1, "#3c3c48"); _r(17, 31, 5, 2, "#9a9aa6"); _r(50, 31, 5, 2, "#9a9aa6")
	_r(18, 31, 3, 1, "#111111"); _r(51, 31, 3, 1, "#111111")
	_p(c[3], [10, 16, 62, 16, 63, 29, 9, 29]); _r(10, 16, 52, 2, c[4]); _r(9, 25, 54, 2, c[2]); _r(9, 27, 54, 2, c[1])
	_p(c[4], [13 + d, 12, 59 + d, 12, 62, 16, 10, 16]); _r(14 + d, 12, 44, 1, c[5])
	_p(c[3], [X - rb + d, 12, X + rb + d, 12, X + rt + t, ry, X - rt + t, ry]); _r(X - rt + t + 1, ry, rt * 2 - 2, 1, c[5])
	_p("#16233c", [X - rb + 3 + d, 11, X + rb - 3 + d, 11, X + rt - 2 + t, ry + 2, X - rt + 2 + t, ry + 2])
	_p("#3a5d8c", [X - rb + 6 + d, 11, X - rb + 11 + d, 11, X - rt + 8 + t, ry + 2, X - rt + 4 + t, ry + 2])
	_p("#27405f", [X + 2 + d, 11, X + 5 + d, 11, X + 3 + t, ry + 2, X + 1 + t, ry + 2])
	var L := "#ff5a3a" if freio else "#d01818"
	var L2 := "#ffd0a0" if freio else "#ff5a4a"
	match int(m.lz):
		0:
			_r(11, 19, 50, 3, L); _r(12, 19, 10, 1, L2); _r(50, 19, 10, 1, L2); _r(11, 22, 6, 1, "#ffb020"); _r(55, 22, 6, 1, "#ffb020")
		1:
			for x in [11, 18, 47, 54]:
				_r(x, 18, 7, 5, "#1a1a20"); _r(x + 1, 19, 5, 3, L); _r(x + 1, 19, 2, 1, L2)
		2:
			for x in [11, 56]:
				_r(x, 17, 5, 8, L); _r(x + 1, 18, 2, 2, L2); _r(x, 23, 5, 2, "#ffb020")
		_:
			for x in [15, 22, 50, 57]:
				_bola(x, 20.5, 3.4, "#1a1a20"); _bola(x, 20.5, 2.4, L); _r(x - 1, 19, 1, 1, L2)
	_r(30, 21, 12, 5, "#ececec"); _r(30, 21, 12, 1, "#2f55b0"); _r(32, 23, 8, 1, "#333333")
	var a: int = int(m.asa) if asa < 0 else asa
	if a == 1:
		_r(X - rt + t - 1, ry - 1, rt * 2 + 2, 2, c[1]); _r(X - rt + t - 1, ry - 1, rt * 2 + 2, 1, c[4])
	elif a >= 2:
		_r(15 + d, 8, 2, 6, c[0]); _r(55 + d, 8, 2, 6, c[0]); _r(7 + d, 6, 58, 3, c[2]); _r(7 + d, 6, 58, 1, c[5])
		_r(6 + d, 4, 2, 6, c[1]); _r(64 + d, 4, 2, 6, c[1])
		if a == 3:  # flap da asa móvel
			_r(8 + d, 3, 56, 2, "#3fd97f")
	_r(9 + d, 13, 3, 2, c[2]); _r(60 + d, 13, 3, 2, c[2])
	if faixa.a > 0:
		_r(9, 25, 54, 2, faixa)
	ci.draw_set_transform(Vector2.ZERO)


## Stock Car, Rali e Fórmula, vistos de trás. Na curva a parte de cima desloca d px (perspectiva simples).
static func _outro(ci: CanvasItem, base: Vector2, k: float, corpo: String, cor: Color, curva: int, freio: bool, asa: int, faixa: Color) -> void:
	_ci = ci
	ci.draw_set_transform(base, 0.0, Vector2(-k if curva < 0 else k, k))
	var c := []
	for f in [0.42, 0.62, 0.8, 1.0, 1.22, 1.5]:
		c.append(tom(cor, f))
	var d := absi(curva) * 2.0
	var s := absi(curva) * 4.0  # quanto da lateral aparece na curva (o espelhamento cuida do lado)
	var L := "#ff5a3a" if freio else "#d01818"
	var tem_faixa := faixa.a > 0
	_r(4, 35, 64 + s, 4, "#0a0a12")  # sombra
	if s > 0:  # lateral e roda dianteira do lado de fora da curva, como no carro GT
		match corpo:
			"formula":
				_r(56 + s, 22, 7, 12, "#121218"); _p(c[1], [47, 22, 47 + s, 21, 49 + s, 32, 47, 33])
			"stock":
				_r(58 + s, 25, 7, 11, "#121218"); _p(c[1], [66, 14, 66 + s, 13, 67 + s, 31, 67, 32]); _p(c[0], [66, 26, 67 + s, 25, 67 + s, 31, 67, 32])
			"rali":
				_r(56 + s, 25, 7, 11, "#121218"); _p(c[1], [62, 12, 62 + s, 11, 64 + s, 30, 64, 31]); _p(c[0], [62, 24, 64 + s, 23, 64 + s, 30, 64, 31])
	match corpo:
		"formula":
			for x in [3, 54]:  # rodas traseiras expostas
				_r(x, 17, 15, 21, "#121218"); _r(x + 2, 19, 11, 1, "#2c2c38"); _r(x + 2, 35, 11, 1, "#2c2c38")
			_r(18, 26, 10, 2, "#2a2a34"); _r(44, 26, 10, 2, "#2a2a34")
			_r(22, 32, 28, 4, "#24242c")  # difusor
			_p(c[3], [28 + d, 12, 44 + d, 12, 47, 33, 25, 33]); _r(30 + d, 12, 12, 2, c[4])
			if tem_faixa:
				_p(faixa, [35 + d, 12, 37 + d, 12, 37, 33, 35, 33])
			_r(32 + d, 5, 8, 8, c[2]); _r(33 + d, 6, 6, 3, "#16233c")  # entrada de ar
			_r(33, 28, 6, 3, L)  # luz de chuva
			_r(10 + d, 1, 3, 15, c[1]); _r(59 + d, 1, 3, 15, c[1])  # placas laterais da asa
			_r(10 + d, 3, 52, 5, c[2]); _r(11 + d, 1, 50, 2, "#3fd97f" if asa == 3 else (faixa if tem_faixa else c[4]))
		"stock":
			for x in [6, 54]:
				_r(x, 24, 12, 14, "#121218"); _r(x + 2, 26, 1, 10, "#2c2c38"); _r(x + 6, 26, 1, 10, "#2c2c38")
			_p(c[3], [6, 14, 66, 14, 67, 32, 5, 32]); _r(8, 14, 56, 3, c[4]); _r(5, 26, 62, 2, c[2])
			_p("#16233c", [16 + d, 4, 56 + d, 4, 62, 13, 10, 13]); _r(18 + d, 2, 36, 3, c[2]); _r(24 + d, 5, 6, 7, "#3a5d8c")
			_r(7, 11, 58, 3, c[1]); _r(7, 11, 58, 1, c[5])  # aerofólio de porta-malas
			if tem_faixa:
				_r(29, 14, 5, 18, faixa); _r(38, 14, 5, 18, faixa)
			_r(8, 18, 13, 4, L); _r(51, 18, 13, 4, L); _r(9, 18, 4, 1, "#ffd0a0"); _r(59, 18, 4, 1, "#ffd0a0")
			_r(5, 30, 62, 4, "#24242c"); _r(58, 33, 5, 3, "#4a4a55")  # escapamento
		"rali":
			for x in [8, 53]:
				_r(x, 24, 11, 13, "#121218")
				_r(x - 1, 30, 13, 8, "#d02b2b"); _r(x + 1, 32, 9, 2, "#ffffff")  # para-barro
			_p(c[3], [10, 12, 62, 12, 64, 31, 8, 31])
			_p("#16233c", [16 + d, 3, 56 + d, 3, 60, 12, 12, 12]); _r(22 + d, 5, 5, 6, "#3a5d8c")
			_r(14 + d, 0, 44, 3, c[1]); _r(32 + d, 3, 8, 2, "#24242c")  # aerofólio de teto e entrada de ar
			if tem_faixa:
				_r(10, 21, 52, 3, faixa)
			_r(11, 14, 5, 7, L); _r(56, 14, 5, 7, L)
			_r(9, 28, 54, 3, "#24242c")
			for x in [14, 30, 47]:  # lama
				_r(x, 26, 4, 2, Color("#7a5a34", 0.8))
	ci.draw_set_transform(Vector2.ZERO)
