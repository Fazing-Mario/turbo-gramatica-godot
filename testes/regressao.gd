extends SceneTree
# Rodar (com janela): Godot_v4.7.2-stable_win64_console.exe --path <projeto> -s testes/regressao.gd --quit-after 6000
# Passou = aparece "REG FIM" e nenhuma linha "SCRIPT ERROR" nem "REG FALHA". Não grava o save (Game.teste).
# Regressão depois da otimização: telas abrem, corrida roda nos dois modos, conteúdo carrega, tempo de carga.

func _init() -> void:
	await process_frame
	var G = root.get_node("Game")
	var Q = root.get_node("QuizManager")
	var S = root.get_node("Som")
	G.teste = true
	var t := Time.get_ticks_msec()
	Q.perguntas = []
	Q.carregar_perguntas()
	print("REG carga do conteudo: ", Time.get_ticks_msec() - t, " ms; perguntas=", Q.perguntas.size(), " modulos=", Q.modulos.size())
	print("REG leve auto=", G.leve(), " nucleos=", OS.get_processor_count(), " SR=", S.SR)
	# questão AB precisa caber numa linha do painel da corrida (76% de 1280 px, fonte 28/26)
	var fonte: Font = ThemeDB.fallback_font
	var lim := 1280.0 * 0.76 - 28.0
	for it in Q.perguntas:
		if it.tipo == "ab":
			var w: float = fonte.get_string_size("[LB]  " + str(it.opcoes[0]), 0, -1, 28).x + fonte.get_string_size(str(it.opcoes[1]) + "  [RB]", 0, -1, 28).x
			if w > lim or fonte.get_string_size(str(it.enunciado), 0, -1, 26).x > lim:
				print("REG FALHA questão longa demais para a corrida: ", it.id)
	# garagem por categoria: save antigo (uma garagem só) vira uma por categoria sem perder peças
	var velho := {"up": {"motor": [1.0, 0.0], "pneus": 2}, "ups": {}}
	G._migra_ups(velho)
	var gar_ok: bool = not velho.has("up") and velho.ups.size() == G.CATEGORIAS.size() and velho.ups.rali.motor == [1.0, 0.0] and velho.ups.gt.pneus == [0, 0]
	velho.ups.gt.motor.append(1)
	gar_ok = gar_ok and velho.ups.rali.motor.size() == 2  # comprar no GT não muda o rali
	print("REG garagens ", "ok" if gar_ok else "FALHA na migração")
	for qual in ["alta", "leve"]:
		G.s.qual = qual
		for caso in [["gt", 0], ["stock", 3], ["rali", 7], ["formula", 11]]:
			G.s.cat = caso[0]
			G.gp = caso[1]
			G.grid = 12
			var r = load("res://Race.tscn").instantiate()
			root.add_child(r)
			for i in 20:
				await process_frame
			r.est = "corrida"
			Input.action_press("accelerate")
			for i in 200:
				await process_frame
			Input.action_release("accelerate")
			print("REG corrida ", qual, " ", caso, " DRAW=", r.DRAW, " quads=", r._rp.size() / 4, " vel=", snappedf(r.speed, 1.0), " pos=", r._posicao())
			r.queue_free()
			await process_frame
	G.s.qual = "auto"
	for caso in [["stock", 0], ["formula", 11], ["gt", 11]]:
		G.s.cat = caso[0]
		G.gp = caso[1]
		var st = load("res://Study.tscn").instantiate()
		root.add_child(st)
		await process_frame
		await process_frame
		print("REG estudo ", caso, " abas=", st.abas.size())
		st.queue_free()
		await process_frame
	var m = load("res://Main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	for f in ["opcoes", "treino", "campeonato", "equipes"]:
		m.call(f)
		await process_frame
		print("REG main.", f, " ok")
	var sh = load("res://Shop.tscn").instantiate()
	root.add_child(sh)
	await process_frame
	await process_frame
	print("REG garagem ok")
	print("REG FIM")
	quit()
