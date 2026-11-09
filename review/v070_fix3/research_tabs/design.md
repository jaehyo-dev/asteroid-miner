# 연구소 새 배치 시안 (게임에 적용 안 함)

`make_tabs.py`가 3차 시안의 그림·색·아이콘을 그대로 쓰고 배치만 바꿔요. 파일 이름 뒤 `_pc_1280x720.png`, `_phone_844x390.png`.

- 탭별: `tab_weapon`, `tab_hull`, `tab_mine`, `tab_elec`, `tab_survey`
- 격자 보조선 확인용: `grid_*` (게임에는 안 보임. 자홍 선이 격자, 진한 세로선이 줄기, 흰 십자가 칸 중심)
- 칸 누름: `press_can`(강화 가능), `press_poor`(광물 부족), `press_max`(최대), `press_locked`(잠김), `press_soon`(곧 추가), `press_step`(새 칸), `press_top_dragged`(끌어 올린 맨 위 칸)
- 갈림길(PLAN 39장 규칙): `fork1_before`(해금 전), `fork1_before_press`(해금 버튼), `fork2_one`(하나 해금), `fork2_one_press_on`(사용 중 칸 누름), `fork2_one_press_other`(다른 쪽 해금 버튼), `fork3_both`(둘 다 해금), `fork3_both_press_on`, `fork3_both_press_off`(이걸로 바꾸기 버튼), `fork4_swap_pressing`(버튼 눌린 순간), `fork4_swapped`(바꾼 뒤), `fork4_swapped_press_on`, `fork_poor`(광물 부족), `fork_locked`(앞 칸 안 찍음)
- `fork_open_left`, `fork_pick_right`, `fork_chosen`, `fork_swap`은 옛 "무료" 규칙 캡처예요. 보지 마세요.
- 끌기: `mine_dragged_top`, `grid_mine_dragged_top` (채굴만 5줄이라 넘쳐요)
- 자물쇠 탭 생김새: `tab_locked_look` (지금 잠긴 가지는 없어요. 모양만 확인)

## 수치
- 격자 72칸(가로·세로 같음, 배경 점 24칸의 3배). 갈림길은 줄기에서 좌우 1칸(72칸). 판 PC 540×292, 폰 744×310.
- 4줄 가지는 끌기 없이 다 들어와요. 채굴은 5줄이라 PC 70칸, 폰 52칸만 위아래로 끌어요.
- 갈림길 칸 이름은 칸 아래. 그래서 줄기는 갈림길 높이까지 올라와 T자로 칸 옆구리에 들어가고, 칸 위로 나가 가격 바로 위에서 합쳐져요.
- 갈림길 창은 바깥쪽에 떠서 반대쪽 칸과 자기 이름을 가리지 않아요. PC는 자리가 좁아 창 폭 158칸.
- 연달아 갈림길이면 가격과 이름이 겹쳐서 격자 한 줄을 띄워요.
- 진행 막대는 탭 안에 작게 넣었어요.

## 자동 검사 (`make_tabs.py`, 어긋나면 실패)
- 칸 중심이 격자 위, 줄기가 판 가운데, 갈림길 좌우 대칭·같은 높이, 연결선 대각선 없음, 칸·이름·가격 겹침 없음, 연결선이 이름·남의 가격·지나치는 칸과 겹치지 않음(자기 칸 위 가격은 자기 줄기 위에 얹는 표라 허용), 글자 넘침 없음.
- 갈림길 2번·연달아 갈림길인 나무도 같은 검사.
- 검사 자체도 확인: 일부러 어긋낸 배치 6가지가 실패해야 통과.
- 모든 가지·모든 칸·끌기 양 끝에서 설명 창이 판 안에 있고 누른 칸을 가리지 않음.

새 칸의 단계 수(단계 효과 칸 5단계, 나머지 1단계)와 단계별 가격(1.6배), 갈림길 해금 가격(한쪽 500)은 시안용 임시 값이에요.

다시 만들기: `python3 review/v070_fix3/research_tabs/make_tabs.py`
