class_name RaidDirector
extends RefCounted
## 습격 이벤트의 흐름: 평소 → 경고 → 습격 → 숨 돌릴 틈 → 평소 …
## RAID_INTERVAL마다 한 번, 한 방향에서 몰려온다. 운석 폭풍과 날벌레 습격이 번갈아 온다.
## 무엇을 언제 만들지는 RunSim이 이 상태를 보고 정한다.

enum State { IDLE, WARNING, ACTIVE, CALM }

const STORM := "storm"
const SWARM := "swarm"

var state := State.IDLE
## 이번 습격 종류 (STORM / SWARM)
var kind := STORM
## 몰려오는 방향 (우주선 기준 각도, 라디안)
var direction := 0.0
## 지금 상태가 끝날 때까지 남은 시간
var timer := Balance.RAID_FIRST_TIME - Balance.RAID_WARNING_TIME
## 지금까지 끝난 습격 수
var count := 0


## 시간을 진행한다. 상태가 바뀌면 "raid_warning", "raid_start", "raid_end"를 돌려준다.
## swarm_ready: 날벌레가 등장할 시각이 지났는지 (그 전엔 운석 폭풍만)
func update(delta: float, random: RandomNumberGenerator, swarm_ready: bool) -> PackedStringArray:
	var events: PackedStringArray = []
	timer -= delta
	while timer <= 0.0:
		match state:
			State.IDLE:
				state = State.WARNING
				kind = kind_for(count, swarm_ready)
				direction = random.randf() * TAU
				timer += Balance.RAID_WARNING_TIME
				events.append("raid_warning")
			State.WARNING:
				state = State.ACTIVE
				timer += Balance.RAID_DURATION
				events.append("raid_start")
			State.ACTIVE:
				state = State.CALM
				timer += Balance.RAID_CALM_TIME
				count += 1
				events.append("raid_end")
			State.CALM:
				state = State.IDLE
				timer += idle_time()
	return events


## 습격 사이의 평소 시간 (습격 시작 간격이 RAID_INTERVAL이 되게)
static func idle_time() -> float:
	return maxf(Balance.RAID_INTERVAL - Balance.RAID_WARNING_TIME - Balance.RAID_DURATION - Balance.RAID_CALM_TIME, 0.0)


## n번째(0부터) 습격의 종류: 짝수 번째는 운석 폭풍, 홀수 번째는 날벌레 습격 (날벌레가 나온 뒤에만)
static func kind_for(n: int, swarm_ready: bool) -> String:
	return SWARM if n % 2 == 1 and swarm_ready else STORM


static func display_name(raid_kind: String) -> String:
	return "날벌레 습격" if raid_kind == SWARM else "운석 폭풍"
