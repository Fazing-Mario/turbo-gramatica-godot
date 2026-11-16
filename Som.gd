extends Node
## Autoload: trilha sonora e efeitos 100% sintetizados (sem arquivos de áudio).
## Sequenciador chiptune (onda quadrada, triangular, ruído) composto por semente para cada faixa,
## mais o ronco do motor, o vento e o canto dos pneus.

var SR := 22050.0  # 11025 no modo leve (Game.leve): o sintetizador em GDScript custa ~13% de um núcleo a 22050
const SQ := 0
const TRI := 1
const SAW := 2
const SEN := 3
const RUIDO_AG := 4  # ruído passa-alta (chimbal, caixa)
const RUIDO_GR := 5  # ruído passa-baixa (batida, carro passando)
# timbre por carro: [Hz em marcha lenta, faixa até o corte, ganho serra, sub-oitava, serra desafinada, apito, ronco, divisor do ronco]
const TIMBRE := [[52, 150, .5, .35, .3, 0, .25, 2], [40, 105, .45, .6, .35, 0, .5, 1], [66, 185, .55, .15, .3, .05, .15, 2], [58, 215, .4, .2, .35, .16, .2, 2]]
# outras categorias: [Hz em marcha lenta, faixa, serra, sub-oitava, serra desafinada, apito, ronco, divisor do ronco, brilho]
const TIMBRE_CAT := {"stock": [42, 115, .5, .6, .35, 0, .6, 1, 0.9],   # V8 grave e borbulhante
	"rali": [70, 210, .6, .12, .35, 0, .15, 2, 1.25],                    # 4 cilindros rasgado
	"formula": [95, 330, .55, .05, .4, 0, .05, 2, 1.5]}                   # agudo, gritando

var vm := 0.5
var vs := 0.7
var _pb: AudioStreamGeneratorPlayback
# voz: [onda, fase, incremento, mult. de frequência, amostra atual (negativa = atraso), duração, volume, música?, estado do filtro, coef. do filtro]
var _vozes: Array = []
var _faixa := ""
var _tr: Dictionary = {}
var _st := 0
var _falta := 0.0
# motor e ambiente: alvos (setados pela corrida) e valores suavizados
var _alvo := {"f": 0.0, "v": 0.0, "corte": 0.0, "g": [0.0, 0.0, 0.0, 0.0, 0.0], "lfo": 1.0, "ronco": 0.0, "vento": 0.0, "fv": 0.0, "pneu": 0.0, "fp": 0.0, "chia": 0.0}
var _boost := 0.0        # pressão do turbo 0..1: enche devagar (lag) e esvazia rápido
var _boost_alvo := 0.0
var _carga_ant := 0.0
var _phc := 0.0          # fase do guincho do pneu
var _phv := 0.0          # oscilação do guincho
var _nc := 0.0
var _nz := 0.0
var _m := _alvo.duplicate(true)
var _ph := [0.0, 0.0, 0.0, 0.0, 0.0]
# osciladores: serra, sub-oitava, serra desafinada, apito (turbo/compressor), chiado (câmbio reto/motor elétrico)
var _mult := [1.0, 0.5, 1.012, 4.0, 1.7]
var _tb := {}  # timbre atual, montado por timbre()
var _phl := 0.0
var _lp := 0.0
var _nv := 0.0
var _np := 0.0
var _mudo := 0
var _mp: AudioStreamPlayer  # toca musica/<faixa>.ogg|mp3|wav quando o arquivo existe


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Game.leve():
		SR = 11025.0
	var g := AudioStreamGenerator.new()
	g.mix_rate = SR
	g.buffer_length = 0.12
	var p := AudioStreamPlayer.new()
	p.stream = g
	add_child(p)
	p.play()
	_pb = p.get_stream_playback()
	_mp = AudioStreamPlayer.new()
	add_child(_mp)
	_mp.finished.connect(_mp.play)  # repete a faixa
	vol(Game.s.vol[0], Game.s.vol[1])
	timbre("gt", 0, [])


func vol(m: float, s: float) -> void:
	vm = m
	vs = s
	_mp.volume_db = linear_to_db(maxf(m * 0.7, 0.0001))


# ------------------------------------------------------------ síntese
func _process(_d: float) -> void:
	if _pb == null:
		return
	var n := _pb.get_frames_available()
	if n > 0:
		_pb.push_buffer(gera(n))


## Gera n amostras estéreo (música + efeitos + motor). Separado do _process para poder renderizar offline.
func gera(n: int) -> PackedVector2Array:
	for k in _m:  # suaviza os parâmetros do motor uma vez por bloco
		if k == "g":
			for i in 5:
				_m.g[i] = lerpf(_m.g[i], _alvo.g[i], 0.3)
		else:
			_m[k] = lerpf(_m[k], _alvo[k], 0.35)
	var inc := []
	for i in 5:
		inc.append(minf(_m.f * _mult[i], SR * 0.45) / SR)  # nunca acima de Nyquist (senão vira chiado)
	var turbo: bool = _tb.turbo
	if turbo:  # a turbina tem tom próprio, que sobe com a pressão (não com o giro do motor)
		var tau := 0.7 if _boost_alvo > _boost else 0.12
		_boost += (_boost_alvo - _boost) * (1.0 - exp(-n / SR / tau))
		inc[3] = minf(2600.0 + 3400.0 * _boost, SR * 0.45) / SR
	else:
		_boost = 0.0
	var g_ap: float = _boost * _boost if turbo else 1.0
	var a_lp := 1.0 - exp(-TAU * maxf(_m.corte, 50.0) / SR)
	var a_v := 1.0 - exp(-TAU * maxf(_m.fv, 50.0) / SR)
	var a_p := 1.0 - exp(-TAU * maxf(_m.fp, 50.0) / SR)
	var a_c := 1.0 - exp(-TAU * 1500.0 / SR)
	var fc: float = 820.0 * float(_tb.pneu)  # tom do guincho: slick mais agudo, cravo mais grave
	var motor_on: bool = _m.v > 0.002
	var amb_on: bool = _m.vento > 0.001 or _m.pneu > 0.001
	var chia_on: bool = _m.chia > 0.002
	var buf := PackedVector2Array()
	buf.resize(n)
	for j in n:
		if not _tr.is_empty():
			_falta -= 1.0
			if _falta <= 0.0:
				_passo()
				_falta += _tr.passo
		var mus := 0.0
		var efx := 0.0
		var k := _vozes.size() - 1
		while k >= 0:
			var v: Array = _vozes[k]
			k -= 1
			var t: int = v[4]
			v[4] = t + 1
			if t < 0:
				continue
			var dur: int = v[5]
			if t >= dur:
				_vozes.remove_at(k + 1)
				continue
			var f: float = v[1]
			var y: float
			var o: int = v[0]
			if o == SQ:
				y = 1.0 if f < 0.5 else -1.0
			elif o == TRI:
				y = 4.0 * absf(f - 0.5) - 1.0
			elif o == SAW:
				y = 2.0 * f - 1.0
			elif o == SEN:
				y = sin(TAU * f)
			else:
				var r := randf() * 2.0 - 1.0
				v[8] += v[9] * (r - v[8])
				y = r - v[8] if o == RUIDO_AG else v[8] * 2.5
			f += v[2]
			v[1] = f - floorf(f)
			v[2] *= v[3]
			var e: float
			var x := float(t) / dur
			if o >= SEN:  # percussão: decai desde o início
				e = (1.0 - x) * (1.0 - x)
			else:  # notas: sustenta 60% e decai
				e = 1.0 if x < 0.6 else (1.0 - (x - 0.6) / 0.4) * (1.0 - (x - 0.6) / 0.4)
			if v[7]:
				mus += y * e * v[6]
			else:
				efx += y * e * v[6]
		if motor_on:
			for i in 5:
				_ph[i] = fmod(_ph[i] + inc[i], 1.0)
			var bruto: float = (2.0 * _ph[0] - 1.0) * _m.g[0] + (1.0 if _ph[1] < 0.5 else -1.0) * _m.g[1] + (2.0 * _ph[2] - 1.0) * _m.g[2]
			_lp += a_lp * (bruto - _lp)
			_phl = fmod(_phl + _m.f / _m.lfo / SR, 1.0)
			# apito e chiado ficam fora do filtro: são agudos de propósito
			var agudo: float = (sin(TAU * _ph[3]) * _m.g[3] * g_ap + sin(TAU * _ph[4]) * _m.g[4]) * 0.5
			if turbo:  # sopro de ar da turbina junto com o assobio
				var rz := randf() * 2.0 - 1.0
				_nz += 0.35 * (rz - _nz)
				agudo += (rz - _nz) * _m.g[3] * _boost * 0.35
			efx += (_lp * (_m.v + _m.ronco * sin(TAU * _phl)) + agudo * _m.v * 4.0) * (0.05 if _mudo > 0 else 1.0)
			_mudo -= 1
		if amb_on:  # vento e ronco grave da grama/terra
			var r2 := randf() * 2.0 - 1.0
			_nv += a_v * (r2 - _nv)
			_np += a_p * (r2 - _np)
			efx += _nv * _m.vento * 3.0 + _np * _m.pneu * 2.5
		if chia_on:  # pneu cantando: guincho tonal que oscila, com um pouco de chiado de borracha
			_phv = fmod(_phv + 7.0 / SR, 1.0)
			_phc = fmod(_phc + (fc + 70.0 * sin(TAU * _phv) + randf() * 40.0) / SR, 1.0)
			var r3 := randf() * 2.0 - 1.0
			_nc += a_c * (r3 - _nc)
			efx += ((4.0 * absf(_phc - 0.5) - 1.0) * 0.75 + _nc * 1.6) * _m.chia * (0.75 + 0.25 * sin(TAU * _phv * 3.0))
		var s := clampf(mus * vm * 0.4 + efx * vs * 0.6, -1.0, 1.0)
		buf[j] = Vector2(s, s)
	return buf


func _voz(onda: int, hz: float, dur: float, vol_: float, musica: bool, atraso := 0.0, corte := 0.0, fmul := 1.0) -> void:
	if _vozes.size() > 40:
		return
	_vozes.append([onda, 0.0, hz / SR, fmul, -int(atraso * SR), maxi(1, int(dur * SR)), vol_, musica, 0.0, 1.0 - exp(-TAU * corte / SR)])


func _hz(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


func _nota(onda: int, n: float, dur: float, v: float, musica := true, atraso := 0.0) -> void:
	_voz(onda, _hz(n), dur, v, musica, atraso)


func _bumbo() -> void:
	_voz(SEN, 150.0, 0.14, 0.5, true, 0.0, 0.0, pow(40.0 / 150.0, 1.0 / (0.12 * SR)))


# ------------------------------------------------------------ música: progressão + motivos presos ao acorde
func musica(nome: String) -> void:
	if nome == _faixa:
		return
	# menu e estudo dividem o arquivo musica/menu.*: trocar entre eles não reinicia a faixa
	if nome in ["menu", "estudo"] and _faixa in ["menu", "estudo"] and _tr.is_empty():
		_faixa = nome
		return
	_faixa = nome
	_vozes = _vozes.filter(func(v): return not v[7])
	var arq := _arquivo(nome)
	if arq:
		_tr = {}
		_mp.stream = arq
		_mp.play()
		return
	_mp.stop()
	if nome == "menu":
		_tr = _compoe(7, 126, false)
	elif nome == "estudo":
		_tr = _compoe(21, 84, false, true)
	else:
		var g := int(nome.trim_prefix("corrida")) - 1
		_tr = _compoe(100 + g * 13, 136 + g * 3, g % 3 != 1)
	_st = 0
	_falta = 0.0


## Arquivo tem prioridade sobre o sintetizador: musica/<faixa> e, nas corridas, musica/corrida.
## Procura primeiro na pasta "musica" ao lado do .exe (troca de música sem exportar de novo) e depois
## dentro do jogo (res://musica). Dentro do jogo o áudio vai importado, então vem pelo load().
func _arquivo(nome: String) -> AudioStream:
	for pasta in [OS.get_executable_path().get_base_dir() + "/musica/", "res://musica/"]:
		for n in [nome, nome.rstrip("0123456789"), "menu" if nome == "estudo" else nome]:
			for ext in ["ogg", "mp3", "wav"]:
				var p: String = pasta + n + "." + ext
				if pasta.begins_with("res://") and ResourceLoader.exists(p):
					return load(p)
				if FileAccess.file_exists(p):
					match ext:
						"ogg": return AudioStreamOggVorbis.load_from_file(p)
						"mp3": return AudioStreamMP3.load_from_file(p)
						_: return AudioStreamWAV.load_from_file(p)
	return null


func _compoe(semente: int, bpm: float, menor: bool, leve := false) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = semente
	var sc := [0, 2, 3, 5, 7, 8, 10] if menor else [0, 2, 4, 5, 7, 9, 11]
	var ps := [[0, 5, 2, 6], [0, 6, 5, 6], [0, 3, 6, 2], [0, 5, 3, 4]] if menor else [[0, 4, 5, 3], [0, 3, 4, 3], [0, 5, 3, 4]]
	var a := _motivo(r)
	var b := _motivo(r)
	var c := _motivo(r)
	var fim := [4, null, null, 2, null, null, 0, null, null, null, null, null, null, null, null, null]
	return {"bpm": bpm, "prog": ps[r.randi() % ps.size()], "tom": (57 if menor else 60) + r.randi() % 6 - 3, "sc": sc, "leve": leve,
		"bars": [a, a, b, c, a, a, b, fim], "passo": SR * 60.0 / bpm / 4.0}


func _motivo(r: RandomNumberGenerator) -> Array:
	var m := []
	var p: int = [0, 2, 4][r.randi() % 3]
	for i in 16:
		var forte := i % 4 == 0
		if r.randf() > (0.9 if forte else (0.55 if i % 2 == 0 else 0.2)):
			m.append(null)
			continue
		p = clampi(p + [-2, -1, -1, 1, 1, 2][r.randi() % 6], -1, 8)
		if forte:  # tempo forte cai numa nota do acorde
			var melhor := 0
			for q in [0, 2, 4, 7]:
				if absi(q - p) < absi(melhor - p):
					melhor = q
			p = melhor
		m.append(p)
	return m


func _nt(d: int) -> float:
	return float(_tr.tom + _tr.sc[posmod(d, 7)] + 12 * floori(d / 7.0))


func _passo() -> void:
	var b := (_st >> 4) % 8
	var i := _st & 15
	var deg: int = _tr.prog[b % 4]
	var d: float = 60.0 / _tr.bpm / 4.0
	var bar: Array = _tr.bars[b]
	if bar[i] != null:
		var dur := 1
		while i + dur < 16 and bar[i + dur] == null and dur < 4:
			dur += 1
		_nota(SQ, _nt(deg + bar[i]) + 12, d * dur * 0.95, 0.09 if _tr.leve else 0.12)
	if _tr.leve:
		if i % 8 == 0:
			_nota(TRI, _nt(deg) - 12, d * 7, 0.22)
		if i % 2 == 0:
			_nota(TRI, _nt(deg + [0, 2, 4, 2][(i >> 1) % 4]), d * 1.8, 0.07)
	else:
		if i % 2 == 0:
			_nota(TRI, _nt(deg) - 12 + (12 if i % 8 == 6 else 0), d * 1.7, 0.26)
		_nota(SQ, _nt(deg + [0, 2, 4, 7][i % 4]), d * 0.8, 0.03)
		if i % 8 == 0:
			_bumbo()
		if i % 8 == 4 or (b == 7 and i >= 12):
			_voz(RUIDO_AG, 0.0, 0.12, 0.22, true, 0.0, 1500.0)
		if i % 2 == 0:
			_voz(RUIDO_AG, 0.0, 0.03, 0.06, true, 0.0, 7000.0)
	_st += 1


# ------------------------------------------------------------ efeitos
func sfx(n: String) -> void:
	match n:
		"ok": _seq([72, 76, 79, 84], 0.07)
		"erro": _seq([52, 46], 0.16, SAW, 0.25)
		"nav": _seq([81], 0.03, SQ, 0.08)
		"sel": _seq([76, 83], 0.04, SQ, 0.12)
		"moeda": _seq([88, 93], 0.06)
		"bip": _seq([69], 0.15)
		"ja": _seq([81], 0.4)
		"fanfarra": _seq([72, 72, 72, 76, 79, 76, 79, 84], 0.12)
		"nitro":
			_voz(RUIDO_AG, 0.0, 0.6, 0.3, false, 0.0, 900.0)
			_seq([60, 67, 72, 79], 0.05, SAW, 0.12)
		"marcha":
			_voz(RUIDO_AG, 0.0, 0.05, 0.2, false, 0.0, 1200.0)
			_mudo = int(_tb.mudo * SR)  # a troca corta o motor por um instante (menos com câmbio rápido)
			if _tb.turbo and _boost > 0.3:
				_sopro()
		"passa": _voz(RUIDO_GR, 0.0, 0.45, 0.35, false, 0.0, 700.0)
		"bate":
			_voz(RUIDO_GR, 0.0, 0.25, 0.5, false, 0.0, 200.0)
			_voz(SEN, 110.0, 0.25, 0.5, false, 0.0, 0.0, pow(35.0 / 110.0, 1.0 / (0.2 * SR)))


func _seq(ns: Array, d: float, onda := SQ, v := 0.2) -> void:
	for i in ns.size():
		_nota(onda, ns[i], d * 1.5, v, false, i * d)


## Monta o timbre do motor: base da categoria (no GT, a do modelo) alterada pelas peças instaladas (ids).
func timbre(cat: String, modelo: int, ids: Array) -> void:
	var b: Array
	if cat == "gt":
		b = TIMBRE[modelo].duplicate()
		b.append(1.0)
	else:
		b = TIMBRE_CAT[cat]
	var t := {"hz": b[0], "faixa": b[1], "saw": b[2], "sub": b[3], "detune": b[4], "apito": b[5], "ronco": b[6], "lfo": b[7], "brilho": b[8],
		"apito_mult": 4.0, "apito_carga": false, "chiado": 0.0, "chiado_mult": 1.7, "eletrico": false, "mudo": 0.06, "turbo": false,
		"pneu": 0.6 if cat == "rali" else 1.0}
	for id in ids:
		match id:
			"v6": t.hz *= 1.08; t.ronco *= 0.8
			"boxer": t.lfo = 1; t.ronco += 0.35; t.sub += 0.1                        # borbulha do boxer
			"turbo": t.apito = 0.08; t.turbo = true  # assobio com tom próprio, que enche com a pressão (ver gera)
			"super": t.apito = 0.11; t.apito_mult = 3.2                              # zunido que acompanha o giro
			"v12": t.hz *= 1.15; t.faixa *= 1.3; t.detune += 0.15; t.ronco *= 0.4    # liso e agudo
			"wankel": t.hz *= 1.3; t.faixa *= 1.4; t.saw += 0.15; t.ronco = 0.12; t.lfo = 3  # "brap" do rotativo
			"seq": t.mudo = 0.03
			"dct": t.mudo = 0.012
			"comp": t.chiado = 0.06; t.chiado_mult = 1.75                            # engrenagens retas
			"hibrido": t.chiado = 0.07; t.chiado_mult = 5.0; t.eletrico = true      # motor elétrico
			"misto", "rali": t.pneu *= 0.5                                           # cravos: som mais grave
			"slick", "composto": t.pneu *= 1.35                                      # borracha macia: chia agudo
	_tb = t
	_mult = [1.0, 0.5, 1.012, t.apito_mult, t.chiado_mult]


## p < 0 desliga; p = giro 0..1; carga = pé no acelerador 0..1.
func motor(p: float, carga := 0.0) -> void:
	if p < 0.0:
		_alvo.v = 0.0
		_alvo.ronco = 0.0
		_alvo.vento = 0.0
		_alvo.pneu = 0.0
		_alvo.chia = 0.0
		_boost_alvo = 0.0
		return
	var t := _tb
	var v := 0.045 + 0.07 * carga + 0.02 * p
	_alvo.f = t.hz + minf(1.1, p) * t.faixa
	if t.turbo:
		_boost_alvo = minf(1.0, p * carga * 1.2)
		if _boost > 0.35 and carga < 0.25 and _carga_ant > 0.6:  # tirou o pé com pressão: válvula de alívio
			_sopro()
	_carga_ant = carga
	var ap: float = t.apito if t.turbo else t.apito * (p * carga if t.apito_carga else p)  # compressor gira com o motor
	var ch: float = t.chiado * ((1.0 - p) if t.eletrico else p)    # elétrico aparece em baixa; engrenagem, em alta
	_alvo.g = [t.saw, t.sub, t.detune, ap, ch]
	_alvo.corte = (250.0 + p * 1300.0 + carga * 900.0) * t.brilho
	_alvo.v = v * ((0.55 + 0.45 * p) if t.eletrico else 1.0)
	_alvo.lfo = t.lfo
	_alvo.ronco = v * t.ronco


## Válvula de alívio do turbo: "tchiii" que cai, mais forte quanto maior a pressão; esvazia a turbina.
func _sopro() -> void:
	var f := clampf(_boost, 0.3, 1.0)
	_voz(RUIDO_AG, 0.0, 0.45, 0.12 * f, false, 0.0, 2800.0)
	_voz(SEN, 1900.0, 0.14, 0.025 * f, false, 0.0, 0.0, pow(0.45, 1.0 / (0.14 * SR)))
	_boost *= 0.25


## Vento cresce com a velocidade; pneus cantam (guincho) na derrapagem e roncam grave na grama.
func amb(v: float, derrapa: bool, grama: bool) -> void:
	_alvo.vento = v * v * 0.1
	_alvo.fv = 300.0 + v * 900.0
	_alvo.chia = (0.04 + 0.06 * minf(v, 1.0)) if derrapa else 0.0
	_alvo.pneu = 0.12 if grama else 0.0
	_alvo.fp = 260.0 * float(_tb.pneu)
