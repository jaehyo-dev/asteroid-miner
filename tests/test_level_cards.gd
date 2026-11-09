extends TestCase
## 레벨업 카드 화면 크기: 어떤 화면과 어떤 카드 조합에서도 넘치지 않고 글자가 줄 수 안에 들어간다.

const PHONE := Vector2(844, 390)
const SMALL_PHONE := Vector2(793, 357)
const VIEWS: Array[Vector2] = [PHONE, SMALL_PHONE, Vector2(640, 360), Vector2(640, 320), Vector2(560, 320), Vector2(720, 450), Vector2(1000, 480), Vector2(790, 345), Vector2(699, 345), Vector2(700, 340)]


## 모든 강화 × 그 강화에 나올 수 있는 등급
static func _all_cards() -> Array:
	var result: Array = []
	for u in Balance.UPGRADES:
		for grade in 4:
			result.append({"id": u["id"], "grade": grade})
	for u in Balance.EFFECT_UPGRADES:
		for grade in [Upgrades.EPIC, Upgrades.UNIQUE]:
			result.append({"id": u["id"], "grade": grade})
	for u in Balance.LEGENDARY_UPGRADES:
		result.append({"id": u["id"], "grade": Upgrades.LEGENDARY})
	return result


## 이름과 설명이 가장 긴 카드를 담은 3장 (화면마다 줄 수가 달라 그 화면 기준으로 고른다)
static func _worst_three(view: Vector2) -> Array:
	var lay := LevelCard.layout_for(view, _all_cards().slice(0, 3))
	var by_name: Array = _all_cards()
	by_name.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return LevelCard.wrap_text(Upgrades.display_name(a["id"]), lay["name_size"], lay["inner"]).size() > LevelCard.wrap_text(Upgrades.display_name(b["id"]), lay["name_size"], lay["inner"]).size())
	var by_desc: Array = _all_cards()
	by_desc.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return LevelCard.desc_lines(a, lay["desc_size"], lay["inner"]).size() > LevelCard.desc_lines(b, lay["desc_size"], lay["inner"]).size())
	return [by_name[0], by_desc[0], by_desc[1]]


func test_모든_카드가_모든_화면에서_넘치지_않음() -> void:
	for view in VIEWS:
		var lay := LevelCard.layout_for(view, _worst_three(view))
		assert_true(3 * int(lay["w"]) + 2 * int(lay["gap"]) <= view.x, "%s 폭" % view)
		assert_true(int(lay["total"]) <= int(view.y), "%s 높이 %d" % [view, lay["total"]])


func test_폰은_위아래_8px_이상_여백() -> void:
	for view in [PHONE, SMALL_PHONE]:
		var lay := LevelCard.layout_for(view, _worst_three(view))
		assert_true(lay["large"], "%s 글자 큰 화면" % view)
		assert_true(view.y - int(lay["total"]) >= 16, "%s 여백 합 %d" % [view, view.y - int(lay["total"])])


func test_카드_크기와_픽셀_격자() -> void:
	# 예전(PC 196, 폰 262)의 70~75%이고, 아이콘은 게임 그림과 같은 1배 48px
	var pc := LevelCard.layout_for(Vector2(640, 360), _all_cards().slice(0, 3))
	var phone := LevelCard.layout_for(PHONE, _all_cards().slice(0, 3))
	assert_true(pc["w"] >= 196 * 0.7 and pc["w"] <= 196 * 0.75, "PC 폭 %d" % pc["w"])
	assert_true(phone["w"] >= 262 * 0.7 and phone["w"] <= 262 * 0.75, "폰 폭 %d" % phone["w"])
	assert_eq(LevelCard.tex("icons/pierce").get_width(), LevelCard.ICON_SIZE)
	assert_true(LevelCard.tex("ped_pc").get_width() >= LevelCard.ICON_SIZE, "아이콘이 받침 안에 들어감")


func test_폰_설명_글자는_3_5mm_이상() -> void:
	# 폭 약 147mm 폰이 844 논리 픽셀: 1픽셀 = 0.174mm
	var phone := LevelCard.layout_for(PHONE, _all_cards().slice(0, 3))
	assert_true(phone["desc_size"] * 147.0 / PHONE.x >= 3.5, "폰 설명 글자 %dpx" % phone["desc_size"])


func test_PC는_글자_작은_화면() -> void:
	assert_false(LevelCard.layout_for(Vector2(640, 360), _all_cards().slice(0, 3))["large"])
	assert_false(LevelCard.layout_for(Vector2(640, 320), _all_cards().slice(0, 3))["large"])


func test_설명과_이름은_최대_2줄() -> void:
	for view in VIEWS:
		var lay := LevelCard.layout_for(view, _all_cards().slice(0, 3))
		for c in _all_cards():
			var lines := LevelCard.desc_lines(c, lay["desc_size"], lay["inner"])
			assert_true(lines.size() <= LevelCard.DESC_MAX_LINES, "%s %s 설명 %d줄 %s" % [view, c["id"], lines.size(), lines])
			for line in lines:
				assert_true(LevelCard.FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, lay["desc_size"]).x <= lay["inner"], "%s 폭 넘침: %s" % [view, line])
			var names := LevelCard.wrap_text(Upgrades.display_name(c["id"]), lay["name_size"], lay["inner"])
			assert_true(names.size() <= 2, "%s 이름 %s" % [view, names])
			for line in names:
				assert_true(LevelCard.FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, lay["name_size"]).x <= lay["inner"], "%s 이름 폭 넘침: %s" % [view, line])


func test_글꼴에_없는_글자가_없음() -> void:
	for c in _all_cards():
		for text in [Upgrades.display_name(c["id"]), Upgrades.describe(c["id"], c["grade"]), Upgrades.describe(c["id"], c["grade"], true), Upgrades.kind_of(c["id"])]:
			for i in text.length():
				assert_true(LevelCard.FONT.has_char(text.unicode_at(i)), "글꼴에 없음: %s (%s)" % [text[i], text])


func test_줄바꿈은_공백에서만() -> void:
	assert_eq(LevelCard.wrap_text("가나 다라", 12, 1000.0), PackedStringArray(["가나 다라"]))
	assert_eq(LevelCard.wrap_text("가나 다라", 12, 30.0), PackedStringArray(["가나", "다라"]))
	assert_eq(LevelCard.wrap_text("가나다라마바사", 12, 10.0).size(), 1, "한 단어는 자르지 않음")


func test_등급_재질은_등급별로_만들어짐() -> void:
	for grade in 5:
		var mat := LevelCard.grade_material(grade)
		assert_true(int(mat.get_shader_parameter("color_count")) <= 16, "셰이더 색 수 한도")
	assert_true(LevelCard.grade_material(0) == LevelCard.grade_material(0), "같은 재질을 함께 씀")


func test_카드_화면이_레전드리까지_오류_없이_그려짐() -> void:
	var screen := LevelUpCards.new()
	add_child(screen)
	var five: Array = [{"id": "fire_rate", "grade": 0}, {"id": "damage", "grade": 1}, {"id": "pierce", "grade": 2}, {"id": "drone", "grade": 3}, {"id": "chain_matrix", "grade": 4}]
	screen.show_cards(five, {}, 2)
	await wait_frames(3)
	assert_eq(screen.cards.size(), 5)
	screen.skip()
	await wait_frames(2)
	for c in screen.cards:
		assert_true(c.visible, "펼쳐짐")
	screen.queue_free()


# ── 카드 소리와 후광 (계획서 31번) ─────────────────

func test_카드_소리는_등급마다_전용이고_빌려_쓰지_않음() -> void:
	assert_eq(LevelUpCards.CARD_GRADE_SOUND.size(), 5)
	for sound in LevelUpCards.CARD_GRADE_SOUND:
		assert_true(Sfx.SOUNDS.has(sound), sound)
	assert_true(Sfx.SOUNDS.has("card_normal") and Sfx.SOUNDS.has("card_gather") and Sfx.SOUNDS.has("card_pick"))
	assert_false(Sfx.SOUNDS.has("card_show"), "옛 등장 소리는 카드에서 뺌")


func test_후광은_터진_뒤_나타나고_약_2초_주기로_숨_쉼() -> void:
	assert_eq(CardFx.halo_light(0.0), 0.0, "터지는 순간에는 없음")
	var t := Juice.CARD_HALO_DELAY + 2.0 * Juice.CARD_HALO_PERIOD
	assert_true(is_equal_approx(CardFx.halo_light(t), 1.0), "밝을 때")
	assert_true(is_equal_approx(CardFx.halo_light(t + Juice.CARD_HALO_PERIOD * 0.5), Juice.CARD_HALO_LOW), "어두울 때")
	assert_true(is_equal_approx(CardFx.halo_light(t + Juice.CARD_HALO_PERIOD), 1.0), "한 주기 뒤")


func test_후광_세기는_에픽_유니크_레전드리_순서() -> void:
	assert_eq(Juice.CARD_HALO_BANDS[Upgrades.NORMAL], 0)
	assert_eq(Juice.CARD_HALO_BANDS[Upgrades.RARE], 0)
	assert_true(Juice.CARD_HALO_ALPHA[Upgrades.EPIC] < Juice.CARD_HALO_ALPHA[Upgrades.UNIQUE])
	assert_true(Juice.CARD_HALO_ALPHA[Upgrades.UNIQUE] < Juice.CARD_HALO_ALPHA[Upgrades.LEGENDARY])


func test_후광은_에픽부터_걸리고_고르면_사라짐() -> void:
	var screen := LevelUpCards.new()
	add_child(screen)
	screen.size = PHONE
	await wait_frames(1)
	screen.show_cards([{"id": "fire_rate", "grade": Upgrades.NORMAL}, {"id": "damage", "grade": Upgrades.EPIC}, {"id": "orbit_pierce", "grade": Upgrades.LEGENDARY}], {}, 1)
	screen.skip()
	await wait_frames(1)
	assert_eq(screen._fx.halos.keys().size(), 2, "에픽, 레전드리만")
	assert_false(screen._fx.halos.has(0))
	var t0: float = screen._fx.halos[1]["t"]
	await wait_frames(3)
	assert_true(screen._fx.halos[1]["t"] >= t0, "시간이 흐름")
	screen._fx.clear_halos()
	assert_true(screen._fx.halos.is_empty())
	screen.queue_free()
