# 건물 창 시안 3차 (게임에 적용 안 함)

`make_mockups3.py`가 2차 시안을 불러와 바뀐 곳만 덮어써요. 파일 이름 뒤 `_pc_1280x720.png`, `_phone_844x390.png`. 움직임은 `.gif`.

## 1) 격납고 회전
- 먼저 볼 것: `hangar_tilt_compare.gif` (카메라 30·35·40도 나란히, 초당 20장), `hangar_thickness.png` (뒤·옆·앞을 멈춰서 두께 확인).
- 창 전체: `hangar`, `hangar_side`, `hangar_spin_pc.gif`, `hangar_spin_phone.gif` (35도. 용량 때문에 초당 10장).
- 바꾼 것: 우주선을 받침 면과 나란히 눕히고 코만 6도 듦. 동체 6칸·날개 2칸으로 높이를 나눠 옆에서도 비행기로 보임. 위아래 3칸 떠오름은 유지.
- 받침은 새로 그림(윗면 비율 약 32도 시점). 그림자는 우주선 모양으로 함께 돌아요.
- 비교 GIF의 30·40도 받침은 35도 그림의 세로 칸을 늘리고 솎은 것이에요. 고른 각도로 다시 그릴 수 있어요.

## 2) 연구소 간격
- `research_start`, `research_drag_left`, `_far_left`, `_right`, `_far_right`, `_up`, `research_fork`, `research_fork_chosen`, `research_all_chosen_up`, `research_drag_pc.gif`, `research_drag_phone.gif`.
- 가지 사이 128~156 → 184칸, 칸 사이 46~50 → 68칸, 갈림길 소켓 사이 78 → 92칸. 소켓·이름 겹침 0건을 스크립트가 assert로 확인해요.
- 아래 이름표 띠를 불투명하게 해서 칸이 그 밑으로 지나가요. 안내 글자도 띠 안으로 옮겼어요.
- 결정 반영: 새 이름, 채굴 순서(자석 → 화물칸 → 이동 속도), 갈림길 무료(잘못 전달된 내용, PLAN 39장으로 바뀜), "곧 추가", "제안" 표시 제거.

## 3) 전시관, 격납고 아이콘
- `museum`, `museum_full`: 못 찾은 칸은 틀까지 어두운 색 하나로, 등급 색은 틀 전체에. 영웅 이상의 모서리 징, 전설·보스의 뿔은 유지.
- 격납고 설명 칸 무기 아이콘 2배.

다시 만들기: `godot --headless --path review/v070_fix3/spin3d --import`, `python3 review/v070_fix3/spin3d/bake.py`, `python3 review/v070_fix3/make_mockups3.py`.
