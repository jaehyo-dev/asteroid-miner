class_name Juice
extends RefCounted
## 손맛(타격감·움직임) 수치 모음 (QUALITY_BAR.md, PLAN_v0.7.0 7번). 상수만 두고 Balance처럼 어디서나 읽는다.
## 화면 연출 값이 대부분이고, 광물 튕김·자석 가속처럼 RunSim이 쓰는 값도 여기 둔다 (손맛 조정을 한곳에서 하려고).

# ── 쏘기와 맞히기 ─────────────────────
## 쏠 때 우주선이 뒤로 밀리는 거리(픽셀)와 돌아오는 시간
const RECOIL_PX := 2.0
const RECOIL_TIME := 0.08
## 자동 포 총구 불꽃 프레임 속도 (쏜 직후 1번부터 끝까지 재생)
const CANNON_FPS := 28.0
## 맞은 적·운석이 흰색으로 번쩍이는 시간 (셰이더로 흰색을 섞음, 처음에 가장 하얗고 사라짐)
const ENEMY_FLASH_TIME := 0.05
## 맞으면 탄이 날아온 쪽으로 밀리는 거리(픽셀). 밀리는 시간은 Balance.HIT_KNOCK_TIME
const HIT_KNOCK_DISTANCE := 2.0

# ── 부수기 ─────────────────────
## 파괴 애니메이션 속도(초당 프레임): 적 함선, 운석 크기별(작음·중간·큼), 황금 운석. 클수록 느리게 = 묵직하게
const ENEMY_BOOM_FPS := 14.0
const ROCK_BOOM_FPS := [16.0, 14.0, 10.0]
const GOLD_BOOM_FPS := 10.0
## 파편 파티클: 기본 수 + 반지름 RADIUS_PER_DEBRIS마다 1개, 지속 시간, 속도(반지름 40마다 1배씩 빨라짐)
const DEBRIS_COUNT := 6
const RADIUS_PER_DEBRIS := 3.0
const DEBRIS_TIME := 0.35
const DEBRIS_SPEED := 60.0
const GOLDEN_DEBRIS_COUNT := 24
## 화면에 한꺼번에 있을 수 있는 파편 파티클 총량 (넘치면 새 파편을 만들지 않음, 폰 성능용)
const PARTICLE_MAX := 160
## 이 반지름 이상이면 파편이 2픽셀 덩어리 (큰 운석·황금 운석)
const DEBRIS_BIG_RADIUS := 16.0
## 히트스톱: 큰 운석·황금 운석을 부순 순간 시뮬레이션을 멈추는 시간 (Engine.time_scale은 안 씀, 입력은 계속)
const HITSTOP_BIG := 0.04
const HITSTOP_GOLD := 0.06
## 히트스톱과 함께 오는 약한 화면 흔들림 (시간, 세기 픽셀)
const BREAK_SHAKE_TIME := 0.15
const BREAK_SHAKE_STRENGTH := 1.0

# ── 광물 ─────────────────────
## 부서질 때 광물이 튀어 나가는 거리(최소~최대)와 감속(클수록 빨리 멈춤): 속도 = 거리 × 감속, 매 초 e^-감속 배로 줄어듦(ease-out)
const MINERAL_POP_MIN := 6.0
const MINERAL_POP_MAX := 18.0
const MINERAL_POP_DAMP := 6.0
## 자석: 범위 끝에서 기본 속도(Balance.MAGNET_SPEED) × FAR, 우주선 바로 옆에서 × NEAR (가까울수록 빨라짐)
const MAGNET_FAR := 1.0
const MAGNET_NEAR := 2.2
## 떠 있는 광물 반짝임: 등급별 초당 반짝임 횟수와 십자 크기(0이면 점 하나). 등급이 높을수록 자주·크게
const SPARKLE_RATE := [0.6, 1.2, 2.0, 3.0]
const SPARKLE_SIZE := [0, 1, 1, 2]
## 등급별 줍기 연출 시간과 퍼지는 고리 반지름 (일반, 희귀, 영웅, 전설)
const PICKUP_FX_TIME := [0.25, 0.35, 0.45, 0.7]
const PICKUP_RING_RADIUS := [6.0, 10.0, 14.0, 24.0]

# ── 우주선 ─────────────────────
## 보이는 방향이 실제 방향을 따라가는 빠르기 (lerp_angle, 초당 비율). 그림은 8방향으로 스냅
const SHIP_TURN_LERP := 18.0
## 최고 속도의 이 비율보다 빠르면 출력 불꽃(Powering), 아니면 대기(Idle)
const ENGINE_POWER_RATIO := 0.5
## 무적 중 깜빡이는 간격
const BLINK_INTERVAL := 0.08
## 피격: 중간 화면 흔들림(시간, 세기 픽셀), 화면 붉은 번쩍임·가장자리 테두리 시간
const HIT_SHAKE_TIME := 0.25
const HIT_SHAKE_STRENGTH := 3.0
const HIT_FLASH_TIME := 0.2

# ── 효과 강화 연출 ─────────────────────
## 효과 하나의 지속 시간(초): 관통 불꽃, 튕김 궤적, 폭발 고리, 치명타 숫자, 채굴 레이저 반짝임, 광물 더 나옴
const EFFECT_TIME := {"pierce": 0.16, "bounce": 0.14, "explode": 0.3, "crit": 0.6, "laser": 0.14, "drop_extra": 0.4}

# ── 기본 무기 효과 (v0.8.0, scripts/weapon_fx.gd) ─────────────────
## 그리는 순서: 내 무기 효과(빔·폭발·레일 자국)는 적·운석 아래, 튐·섬광은 내 탄 위·적 탄 아래. 적 탄은 어두운 테두리로 어떤 효과 위에서도 보이게.
## 2026-11-12 사용자 결정으로 고른 후보: 펄스 1(깔끔), 산탄 3(묵직), 레일 3(묵직, 빛줄기 = 공격), 플라스마 2(화려), 빔 2(화려).
## 공통: muzzle 총구 섬광 반지름(0 없음)·muzzle_time 시간·muzzle_color, recoil 반동(픽셀), hit_n 맞은 곳 튐 수·hit_speed·hit_life·hit_size(픽셀)·hit_colors,
## hit_ring 맞은 곳 고리 반지름(0 없음), hit_flash 맞은 곳 흰 번쩍임 반지름(0 없음)
## 펄스·산탄: size 탄 크기(산탄 알갱이 픽셀), glow 탄 빛 반지름, trail 탄 꼬리 길이, cone 총구 불꽃 부채꼴 길이, smoke 쏠 때 연기 수
## 레일: charge 충전 빛 반지름·charge_time 쏘기 전 충전 시간, (빛줄기 굵기는 맞는 굵기와 같게 Balance.WEAPONS의 width)·glow_w 바깥 빛 굵기·fade 잔상 시간·core_time 흰 속줄 시간, dots 잔상이 점선으로 흩어짐
## 플라스마: orb 구슬 반지름·orb_glow 빛 반지름, tail 꼬리 점 수·tail_step(초 전 위치), rings 충격파 고리 수·blast_time, embers 잔불 수·ember_life, scorch 그을음 진하기
## 빔: core 속줄 굵기·glow_w 바깥 빛 굵기·pulse_hz 맥동, travel 빔을 따라 흐르는 빛 점 수, sparks·chips 닿는 곳 불꽃·광물 부스러기(초당), wobble 굵기 흔들림
const WEAPON_FX := {
	"pulse": {"muzzle": 2.0, "muzzle_time": 0.05, "muzzle_color": Color("#99e9e6"), "recoil": 1.0, "glow": 0.0, "trail": 0.0,
		"hit_n": 3, "hit_speed": 45.0, "hit_life": 0.14, "hit_size": 1.0, "hit_colors": [Color("#99e9e6"), Color("#fef8e5")], "hit_ring": 0.0, "hit_flash": 0.0},
	"shotgun": {"muzzle": 6.0, "muzzle_time": 0.1, "muzzle_color": Color("#f89419"), "recoil": 5.0, "size": 3.0, "glow": 3.0, "trail": 3.0, "cone": 11.0, "smoke": 4,
		"hit_n": 3, "hit_speed": 30.0, "hit_life": 0.32, "hit_size": 2.0, "hit_colors": [Color("#f89419"), Color("#dc7f47")], "hit_ring": 0.0, "hit_flash": 3.0},
	"rail": {"muzzle": 6.0, "muzzle_time": 0.1, "muzzle_color": Color("#fef8e5"), "recoil": 5.0, "charge": 4.0, "charge_time": 0.5, "glow_w": 6.0, "fade": 0.25, "core_time": 0.08, "dots": true,
		"hit_n": 4, "hit_speed": 45.0, "hit_life": 0.35, "hit_size": 2.0, "hit_colors": [Color("#f6ce50"), Color("#f89419"), Color("#fef8e5")], "hit_ring": 0.0, "hit_flash": 5.0},
	"plasma": {"muzzle": 5.0, "muzzle_time": 0.08, "muzzle_color": Color("#a884f3"), "recoil": 3.0, "orb": 4.0, "orb_glow": 8.0, "tail": 7, "tail_step": 0.025, "rings": 2, "blast_time": 0.5, "embers": 12, "ember_life": 0.7, "scorch": 0.0,
		"hit_n": 2, "hit_speed": 50.0, "hit_life": 0.2, "hit_size": 1.0, "hit_colors": [Color("#fef8e5"), Color("#a884f3")], "hit_ring": 0.0, "hit_flash": 0.0},
	"beam": {"muzzle": 4.0, "muzzle_time": 0.0, "muzzle_color": Color("#f6ce50"), "recoil": 0.0, "core": 1.0, "glow_w": 6.0, "pulse_hz": 9.0, "travel": 3, "sparks": 30.0, "chips": 10.0, "wobble": 1.0,
		"hit_n": 0, "hit_speed": 80.0, "hit_life": 0.25, "hit_size": 1.0, "hit_colors": [Color("#f6ce50"), Color("#fef8e5"), Color("#f89419")], "hit_ring": 0.0, "hit_flash": 0.0},
}
## 광물 부스러기 색 (채굴 빔이 닿는 곳에서 튐)
const CHIP_COLORS := [Color("#625565"), Color("#966c6c"), Color("#f6ce50")]
## 무기 효과 상한 (폰 성능용): 튐·잔불 파티클 수, 레일 자국 수, 플라스마 폭발 수
const WEAPON_PARTICLE_MAX := 140
const WEAPON_TRAIL_MAX := 8
const WEAPON_BLAST_MAX := 8

# ── 보조 무기 효과 (v0.8.0 4단계, scripts/sub_weapon_fx.gd) ─────────────────
## 모두 내 효과라 적 탄 아래에 그린다 (블랙홀·파동·기뢰·폭발은 적 아래, 미사일·톱날·번개·맞은 자리 불꽃은 내 탄과 같은 층).
## 단계 연출 (2026-11-12 사용자 결정): 1·3·5단계에서 모양이 바뀌고(아래 [1단계, 3단계, 5단계] 세 칸 목록), 2·4단계는 minor_bright만큼 밝아진다.
## burst_time 폭발 시간(초)·smoke_time 5단계 기뢰 연기, zap_time 번개가 남는 시간·zap_kinks 꺾임 수·zap_jitter 옆으로 벌어지는 폭(픽셀)·zap_crackle 5단계 번개를 다시 꺾는 간격(초)·
## zap_branch 잔가지 수(대상 사이마다)·coil_ring 우주선 둘레 전기 고리 반지름·coil_ring_time 3단계 고리가 보이는 시간,
## 원 경계선 금지 (2026-11-12 사용자 결정): 범위·고리는 한 줄 원 대신 옅어지는 안개·흩뿌린 점·끊어진 호로 (arc_gap 호의 빈틈 비율).
## hole_dots 블랙홀 먼지 줄기 수·hole_dust 가장자리 흩뿌린 먼지 점 수·hole_band 중심을 감싼 빛 띠 진하기·hole_disk 점으로 된 원반의 점 수·hole_arms 5단계 나선 팔 수·hole_spin 도는 빠르기(라디안/초)·collapse_time 5단계 붕괴 연출 시간,
## wave_alpha 파동 고리 진하기·wave_rings 고리 겹 수·wave_glints 고리 위 반짝이는 점 수·hex_size 육각 격자 한 변(픽셀)·hex_band 격자가 비치는 폭·wave_rays 5단계 방사선 수·wave_after 5단계 잔광 시간·wave_band 앞쪽 뒤로 옅어지는 띠 폭(픽셀),
## crack_time 맞은 운석의 금·광맥이 남는 시간·dust 5단계 금가루 수, mine_blink 기뢰 불빛 깜빡임(초당)·mine_alert 적이 이 거리 안이면 깜빡임 3배·mine_flash 5단계 기뢰가 터질 때 폭발 범위 빨간 원이 번쩍이는 시간,
## missile_trail 꼬리 점 수·missile_sparks 5단계 폭발 불티 수·hatch_time 5단계 발사 때 포드 해치 번쩍임, saw_teeth 톱날 이 수·saw_trail 잔상 호 점 수·saw_chips 맞을 때 튀는 불꽃·부스러기 수
const SUB_FX := {"burst_time": 0.3, "smoke_time": 0.55, "zap_time": [0.22, 0.24, 0.28], "zap_kinks": 3, "zap_jitter": 4.0, "zap_crackle": 0.04,
	"zap_branch": [0, 1, 1], "coil_ring": 11.0, "coil_ring_time": 0.3,
	"hole_dots": [4, 6, 6], "hole_dust": 28, "hole_band": [0.6, 0.75, 0.9], "hole_disk": 14, "hole_arms": 3, "hole_spin": 5.0, "collapse_time": 0.45,
	"wave_alpha": 0.7, "wave_rings": [1, 2, 3], "wave_glints": 12, "hex_size": 6.0, "hex_band": 18.0, "wave_rays": 12, "wave_after": 0.5,
	"wave_band": 10.0, "arc_gap": 0.3,
	"crack_time": 0.45, "dust": 8, "mine_blink": 3.0, "mine_alert": 40.0, "mine_flash": 0.2,
	"missile_trail": [4, 4, 6], "missile_sparks": 10, "hatch_time": 0.12, "saw_teeth": [5, 6, 8], "saw_trail": [0, 4, 8], "saw_chips": [0, 3, 4],
	"minor_bright": 0.15}
## 한꺼번에 그리는 보조 무기 폭발·번개·붕괴 수, 맞은 자리 표시(금·불꽃) 수 (폰 성능용, 넘으면 오래된 것부터 지움)
const SUB_FX_MAX := 16
const SUB_HIT_MAX := 24
## 적 탄 어두운 테두리: 탄 반지름보다 이만큼 크게, 진하기
const ENEMY_SHOT_RIM := 2.0
const ENEMY_SHOT_RIM_ALPHA := 0.75
## 한꺼번에 그리는 효과 상한과 치명타 숫자 상한 (글자는 그리기 호출을 따로 쓴다)
const EFFECT_FX_MAX := 80
const CRIT_TEXT_MAX := 10
const CRIT_COLOR := Color("#ff5a6e")
const CRIT_RISE := 18.0
## 같은 대상의 치명타가 이 시간(초) 안에 또 나오면 새 숫자를 띄우지 않고 떠 있는 숫자에 더한다 (채굴 빔)
const CRIT_MERGE_TIME := 0.3
## 관통 불꽃 조각 수, 궤도 관통 가속기의 탄 꼬리 길이(그 시간 전 위치까지)
const PIERCE_SPARKS := 4
const ORBIT_TAIL_TIME := 0.05
## 번개 궤적 꺾임 수와 옆으로 벌어지는 폭
const LIGHTNING_SEGMENTS := 5
const LIGHTNING_JITTER := 5.0
## 편향 실드: 바깥 빛 비율, 완충 광택이 윤곽을 한 바퀴 도는 시간과 머리 길이(픽셀 수), 가끔 반짝이는 간격·시간·수, 막을 때 번쩍임 시간
const SHIELD_GLOW_ALPHA := 0.3
const SHIELD_SWEEP_TIME := 0.8
const SHIELD_SWEEP_HEAD := 8
const SHIELD_TWINKLE_EVERY := 3.5
const SHIELD_TWINKLE_TIME := 0.18
const SHIELD_TWINKLE_COUNT := 4
const SHIELD_BREAK_TIME := 0.14
## 과부하 반응로 맥동 빠르기, 전역 견인 비콘 고리 시간
const OVERLOAD_PULSE := 7.0
const BEACON_RING_TIME := 0.7

# ── 워프 점프 (GAME_SPEC 11번, 합쳐서 약 3.7초) ─────────────────────
## 기지 쪽: 이륙(조종사 탑승 포함), 충전, 점프(잔상·빛줄기·속도선을 남기고 위로 사라짐 + 흰 번쩍. 그림은 늘이지 않는다)
const WARP_TAKEOFF_TIME := 0.9
const WARP_BOARD_TIME := 0.25
const WARP_CHARGE_TIME := 0.9
const WARP_JUMP_TIME := 0.35
## 출격 화면 쪽: 터널(별이 빛줄기), 도착(감속, 충격파 고리, HUD가 밀려 들어옴)
const WARP_TUNNEL_TIME := 1.0
const WARP_ARRIVE_TIME := 0.5
## 터널 시작 때 흰 번쩍임이 사라지는 시간, 빛줄기 수·속도·길이, 도착 때 우주선이 밀려 들어오는 거리, 충격파 고리 반지름, HUD가 들어오는 거리
const WARP_WHITE_FADE := 0.25
const WARP_STREAKS := 70
const WARP_STREAK_SPEED := 620.0
const WARP_STREAK_LEN := 90.0
const WARP_ARRIVE_SLIDE := 34.0
const WARP_RING_RADIUS := 170.0
const WARP_HUD_SLIDE := 40.0
## 이륙 뒤 떠 있는 높이(기지 그림 칸), 충전 때 흔들림 최대(기지 그림 칸), 기수 앞 빛 알갱이 수, 모이는 거리(그림 칸), 빛 반지름(그림 칸)
const WARP_HOVER_CELLS := 26.0
const WARP_SHAKE_CELLS := 2.0
const WARP_GATHER_PARTS := 28
const WARP_GATHER_CELLS := 42.0
const WARP_GLOW_CELLS := 9
## 점프로 솟구치는 거리(기지 그림 칸), 잔상 수, 잔상 하나가 뒤처지는 정도(점프 진행 0~1 기준), 첫 잔상 진하기
const WARP_JUMP_CELLS := 300.0
const WARP_GHOSTS := 4
const WARP_GHOST_LAG := 0.09
const WARP_GHOST_ALPHA := 0.65
## 귀환 게이트로 빨려 들 때 모여드는 속도선 수와 길이, 우주선이 가운데를 지나 더 뻗는 거리 (출격 화면 픽셀)
const WARP_SUCK_LINES := 18
const WARP_SUCK_LINE_LEN := 34.0
const WARP_SUCK_OVERSHOOT := 70.0
## 귀환 후 기지 착륙 (셔터가 열린 뒤): 시간(출격보다 훨씬 짧게), 내려오는 높이(그림 칸)
const WARP_LAND_TIME := 0.9
const WARP_LAND_CELLS := 70.0
## 도착 충격 흔들림 (시간, 세기 픽셀)
const WARP_ARRIVE_SHAKE_TIME := 0.25
const WARP_ARRIVE_SHAKE := 2.0
## 기지로 돌아갈 때 충격 셔터: 위아래에서 닫히는 시간(쿵 소리의 가장 큰 순간과 같게) → 쿵 흔들림(칸, 0.03초씩) → 닫힌 채 기다림 → 열림 (초)
const SHUTTER_CLOSE := 0.18
const SHUTTER_SHAKE := [2, -1, 1, 0]
const SHUTTER_SHAKE_STEP := 0.03
const SHUTTER_HOLD := 0.12
const SHUTTER_OPEN := 0.24

# ── 레벨업과 화면 ─────────────────────
## 레벨업 순간 슬로모션: 실제 시간, 시뮬레이션 배율. 그동안 우주선 둘레에 빛이 퍼진다
const LEVELUP_SLOWMO_TIME := 0.3
const LEVELUP_SLOWMO_SCALE := 0.25
const LEVELUP_LIGHT_COLOR := Color("#fff4c8")
const LEVELUP_LIGHT_RADIUS := 56.0
## 레벨업 카드 등장: 뒤 화면 어두워짐 → 첫 카드까지 대기 → 카드마다 간격을 두고 내려옴(뒷면) → 뒤집힘 → 앞면 번쩍 (초)
const CARD_DIM_TIME := 0.12
const CARD_FIRST_DELAY := 0.15
const CARD_STAGGER := 0.28
const CARD_DROP_TIME := 0.12
const CARD_DROP_DISTANCE := 60.0
const CARD_FLIP_TIME := 0.08
## 등장 소리 A는 시작 0.1초 뒤가 가장 세다: 앞면이 보이는 순간에 맞게 이만큼 먼저 튼다
const CARD_SOUND_LEAD := 0.1
const CARD_FLASH_TIME := 0.25
## 다시 뽑을 때는 짧게 (어두워짐 없음)
const CARD_REROLL_STAGGER := 0.08
const CARD_REROLL_DROP_DISTANCE := 24.0
## 등급별(노멀~레전드리) 앞면 번쩍임 세기(흰색 섞는 비율), 더 퍼지는 빛 고리 폭(칸), 등장 소리 크기(dB)
const CARD_FLASH_STRENGTH := [0.25, 0.4, 0.55, 0.7, 0.85]
const CARD_FLASH_RING := [0, 3, 6, 10, 16]
## 레전드리: 뒤집히기 전에 빛이 모이는 시간과 모이는 알갱이 수
const CARD_LEGEND_GATHER := 0.3
const CARD_GATHER_PARTS := 48
## 앞면이 나오는 순간의 폭발 (등급별 노멀~레전드리): 파티클 수, 빛줄기 수, 빛줄기 길이, 파티클 속도(PC 카드 폭 기준), 지속 시간
const CARD_BURST_PARTS := [8, 18, 34, 60, 120]
const CARD_BURST_RAYS := [0, 6, 10, 14, 24]
const CARD_BURST_RAY_LEN := [0.0, 50.0, 80.0, 120.0, 220.0]
const CARD_BURST_SPEED := [40.0, 60.0, 80.0, 110.0, 170.0]
const CARD_BURST_TIME := [0.35, 0.45, 0.55, 0.7, 0.9]
## 유니크부터: 빛 기둥 시간, 약한 흔들림 세기(픽셀, 등급별)와 시간
const CARD_PILLAR_TIME := 0.6
## 높은 등급 카드 뒤 후광: 등급별 가장 안쪽 진하기(0이면 없음), 계단 띠 수, 띠 두께(작은 카드 기준 픽셀)
const CARD_HALO_ALPHA := [0.0, 0.0, 0.2, 0.32, 0.5]
const CARD_HALO_BANDS := [0, 0, 2, 3, 4]
const CARD_HALO_BAND_PX := 3
## 빛줄기가 터진 뒤 후광이 나오기까지, 나타나는 시간, 숨 쉬는 주기, 어두울 때 밝기 비율
const CARD_HALO_DELAY := 0.25
const CARD_HALO_FADE := 0.5
const CARD_HALO_PERIOD := 2.0
const CARD_HALO_LOW := 0.35
## 레전드리 후광의 색이 한 칸 넘어가는 시간
const CARD_HALO_RAINBOW_STEP := 0.25
const CARD_SHAKE := [0.0, 0.0, 0.0, 1.0, 2.0]
const CARD_SHAKE_TIME := 0.25
## 등장 효과 파티클 총량 상한, 건너뛸 때 가장 높은 등급 연출의 세기
const CARD_FX_MAX := 240
const CARD_SKIP_BURST := 0.6
## 건너뛴 직후 이 시간 동안은 눌러도 고르지 않는다 (연타로 실수 선택 방지)
const CARD_SKIP_GUARD := 0.2
## 카드가 뜨기 전부터 누르고 있던 손가락을 뗀 뒤 이 시간(밀리초) 안의 누름은 선택으로 치지 않는다 (조이스틱 손가락의 실수 선택 방지)
const CARD_STALE_RELEASE_MS := 120
## 그 손가락 기록을 믿는 시간(밀리초). 뗀 신호를 놓쳐도 이 뒤에는 카드를 고를 수 있다
const CARD_STALE_MAX_MS := 4000
## 카드를 고른 순간의 번쩍임, 빛 고리, 화면이 닫히기까지 시간
const CARD_PICK_FLASH := 0.8
const CARD_PICK_RING := 8
const CARD_PICK_TIME := 0.18
## HUD 숫자 카운트업: 남은 차이의 초당 비율 + 최소 초당 증가량 (목표에 빠르게 붙음)
const COUNT_UP_RATE := 12.0
const COUNT_UP_MIN := 20.0
## 버튼 눌림: 1픽셀 내려가고 밝기가 바뀜 (크기 변화 금지: 정수 배율 규칙)
const BUTTON_PRESS_PX := 1
const BUTTON_PRESS_MODULATE := Color(1.35, 1.35, 1.35)

# ── 소리 ─────────────────────
## 광물 줍기 소리 (v0.7.0 밸런스): PICKUP_GROUP_TIME초 안에 주운 광물은 소리 한 번(그 묶음의 가장 높은 등급, 더 높은 등급이 오면 따로).
## 최근 1초 재생 수가 PICKUP_RATE_REF를 넘으면 한 번의 음량 = -10·log10(횟수/기준) dB (전설은 PICKUP_LEGEND_FLOOR_DB까지만).
## 묶음마다 1반음씩 최대 PICKUP_COMBO_MAX_SEMITONES, PICKUP_COMBO_WINDOW초 끊기면 처음 음. 동시에 나는 줍기 소리는 전체 PICKUP_MAX_VOICES개
const PICKUP_GROUP_TIME := 0.05
const PICKUP_RATE_REF := 3.0
const PICKUP_LEGEND_FLOOR_DB := -3.0
const PICKUP_COMBO_WINDOW := 0.6
const PICKUP_COMBO_MAX_SEMITONES := 5
const PICKUP_MAX_VOICES := 3
## 광물 합치기 연출: 가운데로 빨려 드는 시간, 합칠 때 소리(줍기 소리 계열)의 기본 음 높이와 등급마다 더 올리는 반음
const MERGE_FX_TIME := 0.3
const MERGE_SOUND_SEMITONES := 2
## 운석 깨짐 소리 몰림 줄이기: BREAK_SOUND_WINDOW초 안에 이미 난 수마다 BREAK_SOUND_STEP_DB씩 작게, BREAK_SOUND_MAX개 넘으면 안 냄
const BREAK_SOUND_WINDOW := 0.5
const BREAK_SOUND_MAX := 3
const BREAK_SOUND_STEP_DB := -5.0
## 히트스톱이 끝난 뒤 이 시간 안에는 다시 걸지 않는다 (후반에 큰 운석이 연달아 깨질 때 멈춤이 이어져 버벅여 보이지 않게)
const HITSTOP_COOLDOWN := 0.4
## 적 소리 몰림 줄이기 (적 종류·맞음/파괴마다 따로 셈, 작아지는 크기와 개수는 운석과 같음). 맞음은 총알이 빠르게 이어지므로 창이 짧음
const ENEMY_HIT_SOUND_WINDOW := 0.25
const ENEMY_DESTROY_SOUND_WINDOW := 0.5
## 배경음: 기지(미리 먹먹하게 만든 층, BASE_DB), 출격(곡 RUN_DB), 값이 바뀔 때 따라가는 빠르기
const MUSIC_BASE_DB := -24.0
const MUSIC_RUN_DB := -11.5
const MUSIC_SILENT_DB := -60.0
## 곡에 섞어 넣는 베이스 선율의 크기 (출격 직후부터 곡과 함께 들림. 바꾸면 tools/make_music.py를 다시 실행)
const MUSIC_BASS_DB := -15.0
## 출격 시간에 따라 쌓이는 층 [시작 초, 커지는 초, 음량 dB]: 리듬, 화음·아르페지오, 빠른 리듬 + 멜로디 (tools/make_music.py도 이 줄을 읽음)
const MUSIC_STEMS := [[30.0, 10.0, -12.5], [60.0, 10.0, -15.0], [120.0, 10.0, -15.0]]
const MUSIC_SMOOTH := 1.5

## 기지: 출격을 누르면 끌어 둔 화면이 착륙장으로 돌아오는 빠르기 (초당 비율)
const BASE_CAM_RETURN := 12.0
