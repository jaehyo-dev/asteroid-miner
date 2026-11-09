# AI 그림 요청문

Codex 내장 이미지 생성으로 만든 그림과 요청문 기록입니다. 출처·라이선스는 [CREDITS.md](CREDITS.md)에 함께 적습니다.

## 기지 그림 (v0.6.1, 2026-11-07)

계획: 12장. 콘셉트 그림 1(`assets/raw/base_concept_overview.png`)을 `--image`로 넘겨 같은 화풍으로 만들고, 원본은 `assets/raw/base/`(빌드 제외), 게임용은 `tools/pixelate.py`로 정리해 `assets/sprites/base/`에 둠. 바뀌는 부분(연구소 안테나·불빛, 창고 광물 더미)은 부품 시트로 따로 만들어 `--split`으로 나눔.

### `assets/raw/base/ground_landscape.png`

> 첨부한 콘셉트 그림의 소행성 표면 배경만 1장 만들어 줘(16:9 가로). 건물, 착륙장, 우주선, 사람, 길은 하나도 넣지 마. 위쪽 5분의 1은 별이 있는 짙은 우주 하늘과 멀리 떠 있는 작은 소행성 2~3개, 그 아래는 회갈색 울퉁불퉁한 소행성 땅: 크고 작은 분화구, 바위, 자갈이 화면 전체에 고르게. 땅 한가운데는 비교적 평평하게. 스타일: 첨부한 콘셉트 그림과 똑같은 16비트 픽셀 아트, 선명한 픽셀, 제한된 색상, 같은 시점(옆에서 약간 내려다본 3/4 시점), 같은 조명(왼쪽 위에서 빛), 같은 색감(회색 금속, 노랑-검정 경고 줄무늬, 청록·주황 표시등). 글자, 로고는 넣지 마. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

### `assets/raw/base/ground_portrait.png`

> 첨부한 콘셉트 그림의 소행성 표면 배경만 1장 만들어 줘(9:16 세로, 휴대폰 화면). 건물, 착륙장, 우주선, 사람, 길은 하나도 넣지 마. 위쪽 6분의 1은 별이 있는 짙은 우주 하늘과 멀리 떠 있는 작은 소행성 2개, 그 아래는 회갈색 울퉁불퉁한 소행성 땅: 크고 작은 분화구, 바위, 자갈이 화면 전체에 고르게. 스타일: 첨부한 콘셉트 그림과 똑같은 16비트 픽셀 아트, 선명한 픽셀, 제한된 색상, 같은 시점(옆에서 약간 내려다본 3/4 시점), 같은 조명(왼쪽 위에서 빛), 같은 색감(회색 금속, 노랑-검정 경고 줄무늬, 청록·주황 표시등). 글자, 로고는 넣지 마. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

### `assets/raw/base/research.png`

> 첨부한 콘셉트 그림 왼쪽 위의 연구소 건물 하나만 그려 줘: 푸른 유리 돔 지붕(안에 실험 장비가 비침), 아래 금속 받침 건물과 창문, 가운데 문과 앞 계단, 노랑-검정 줄무늬. 지붕 위 안테나·접시 안테나·표시등은 빼고 돔만 (나중에 따로 겹쳐 그림). 스타일: 첨부한 콘셉트 그림과 똑같은 16비트 픽셀 아트, 선명한 픽셀, 제한된 색상, 같은 시점(옆에서 약간 내려다본 3/4 시점), 같은 조명(왼쪽 위에서 빛), 같은 색감(회색 금속, 노랑-검정 경고 줄무늬, 청록·주황 표시등). 물체 하나만 화면 가운데에 크게, 잘리지 않게 여백을 두고. 배경은 무늬·그림자·바닥·땅이 전혀 없는 단색 마젠타(#FF00FF)로 꽉 채우고, 물체에는 마젠타나 분홍색을 쓰지 마. 글자, 숫자, 로고는 넣지 마. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

### `assets/raw/base/research_parts.png`

> 첨부한 콘셉트 그림의 연구소 지붕에 달린 부품 3개를 한 장에 그려 줘. 가로로 한 줄, 서로 멀리 떨어뜨려서: 1) 꼭대기에 주황 표시등이 달린 가는 금속 안테나 기둥 2) 받침대가 달린 흰 접시 안테나 3) 작고 둥근 청록색 불빛 창(벽에 붙는 작은 램프). 셋은 서로 닿지 않게 넓은 간격. 스타일: 첨부한 콘셉트 그림과 똑같은 16비트 픽셀 아트, 선명한 픽셀, 제한된 색상, 같은 시점(옆에서 약간 내려다본 3/4 시점), 같은 조명(왼쪽 위에서 빛), 같은 색감(회색 금속, 노랑-검정 경고 줄무늬, 청록·주황 표시등). 배경은 무늬·그림자 없는 단색 마젠타(#FF00FF)로 꽉 채우고, 물체에는 마젠타나 분홍색을 쓰지 마. 글자, 숫자는 넣지 마. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

### `assets/raw/base/hangar.png`

> 첨부한 콘셉트 그림 위쪽 가운데의 격납고 건물 하나만 그려 줘: 붉은 녹 줄무늬가 있는 둥근 아치 지붕, 큰 금속 미닫이 문, 문 위 주황 불빛, 양옆 노란 창문과 파이프, 문 앞 노랑-검정 줄무늬. 스타일: 첨부한 콘셉트 그림과 똑같은 16비트 픽셀 아트, 선명한 픽셀, 제한된 색상, 같은 시점(옆에서 약간 내려다본 3/4 시점), 같은 조명(왼쪽 위에서 빛), 같은 색감(회색 금속, 노랑-검정 경고 줄무늬, 청록·주황 표시등). 물체 하나만 화면 가운데에 크게, 잘리지 않게 여백을 두고. 배경은 무늬·그림자·바닥·땅이 전혀 없는 단색 마젠타(#FF00FF)로 꽉 채우고, 물체에는 마젠타나 분홍색을 쓰지 마. 글자, 숫자, 로고는 넣지 마. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

### `assets/raw/base/storage.png`

> 첨부한 콘셉트 그림 왼쪽 아래의 광물 창고 건물 하나만 그려 줘: 굴뚝 두 개, 지붕 채광창, 열린 큰 문 안에 나무 상자들, 옆에 빨강·파랑 컨테이너. 문 앞의 광물 더미와 광물 상자는 빼고 (나중에 따로 겹쳐 그림). 스타일: 첨부한 콘셉트 그림과 똑같은 16비트 픽셀 아트, 선명한 픽셀, 제한된 색상, 같은 시점(옆에서 약간 내려다본 3/4 시점), 같은 조명(왼쪽 위에서 빛), 같은 색감(회색 금속, 노랑-검정 경고 줄무늬, 청록·주황 표시등). 물체 하나만 화면 가운데에 크게, 잘리지 않게 여백을 두고. 배경은 무늬·그림자·바닥·땅이 전혀 없는 단색 마젠타(#FF00FF)로 꽉 채우고, 물체에는 마젠타나 분홍색을 쓰지 마. 글자, 숫자, 로고는 넣지 마. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

### `assets/raw/base/piles.png`

> 첨부한 콘셉트 그림의 창고 앞 반짝이는 광물 더미를 크기별로 5개 그려 줘. 가로로 한 줄, 왼쪽부터 아주 작은 것 → 아주 큰 것 순서로, 서로 멀리 떨어뜨려서. 광물은 푸른 결정, 보라 보석, 금덩이가 섞여 있고 작게 반짝임. 더미마다 바닥이 평평하게. 스타일: 첨부한 콘셉트 그림과 똑같은 16비트 픽셀 아트, 선명한 픽셀, 제한된 색상, 같은 시점(옆에서 약간 내려다본 3/4 시점), 같은 조명(왼쪽 위에서 빛), 같은 색감(회색 금속, 노랑-검정 경고 줄무늬, 청록·주황 표시등). 배경은 무늬·그림자 없는 단색 마젠타(#FF00FF)로 꽉 채우고, 물체에는 마젠타나 분홍색을 쓰지 마. 글자, 숫자는 넣지 마. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

### `assets/raw/base/museum.png`

> 첨부한 콘셉트 그림 오른쪽 아래의 전시관 건물 하나만 그려 줘: 유리 지붕, 양쪽 큰 진열창(왼쪽엔 푸른 결정, 오른쪽엔 금괴가 진열), 가운데 문과 앞 계단, 노랑-검정 줄무늬, 주황 표시등. 스타일: 첨부한 콘셉트 그림과 똑같은 16비트 픽셀 아트, 선명한 픽셀, 제한된 색상, 같은 시점(옆에서 약간 내려다본 3/4 시점), 같은 조명(왼쪽 위에서 빛), 같은 색감(회색 금속, 노랑-검정 경고 줄무늬, 청록·주황 표시등). 물체 하나만 화면 가운데에 크게, 잘리지 않게 여백을 두고. 배경은 무늬·그림자·바닥·땅이 전혀 없는 단색 마젠타(#FF00FF)로 꽉 채우고, 물체에는 마젠타나 분홍색을 쓰지 마. 글자, 숫자, 로고는 넣지 마. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

### `assets/raw/base/drone_factory.png`

> 첨부한 콘셉트 그림 오른쪽 위의 공사 중인 드론 공장 하나만 그려 줘: 짓다 만 철골 뼈대(붉은 들보, 회색 기둥), 양옆 노란 비계, 위에 노란 크레인, 앞에 빨강-흰 차단막과 나무 상자. 비어 있는 노란 표지판 하나를 앞에 세워 둬 (글자는 넣지 마). 스타일: 첨부한 콘셉트 그림과 똑같은 16비트 픽셀 아트, 선명한 픽셀, 제한된 색상, 같은 시점(옆에서 약간 내려다본 3/4 시점), 같은 조명(왼쪽 위에서 빛), 같은 색감(회색 금속, 노랑-검정 경고 줄무늬, 청록·주황 표시등). 물체 하나만 화면 가운데에 크게, 잘리지 않게 여백을 두고. 배경은 무늬·그림자·바닥·땅이 전혀 없는 단색 마젠타(#FF00FF)로 꽉 채우고, 물체에는 마젠타나 분홍색을 쓰지 마. 글자, 숫자, 로고는 넣지 마. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

### `assets/raw/base/pad.png`

> 첨부한 콘셉트 그림 가운데의 팔각형 착륙장 하나만 그려 줘: 어두운 금속 바닥, 안쪽 노란 팔각 표시선, 둘레의 주황·청록 표시등, 아래쪽 받침 기둥과 앞쪽 계단. 착륙장 위는 비워 둬 (우주선과 사람 없음). 스타일: 첨부한 콘셉트 그림과 똑같은 16비트 픽셀 아트, 선명한 픽셀, 제한된 색상, 같은 시점(옆에서 약간 내려다본 3/4 시점), 같은 조명(왼쪽 위에서 빛), 같은 색감(회색 금속, 노랑-검정 경고 줄무늬, 청록·주황 표시등). 물체 하나만 화면 가운데에 크게, 잘리지 않게 여백을 두고. 배경은 무늬·그림자·바닥·땅이 전혀 없는 단색 마젠타(#FF00FF)로 꽉 채우고, 물체에는 마젠타나 분홍색을 쓰지 마. 글자, 숫자, 로고는 넣지 마. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

### `assets/raw/base/ship.png`

> 첨부한 콘셉트 그림 가운데 착륙장 위의 흰 우주선 하나만 그려 줘: 흰 선체에 빨간 줄무늬, 푸른 조종석 유리, 뒤로 뻗은 날개, 착륙 다리. 콘셉트와 같은 방향(앞이 왼쪽 위를 향함). 스타일: 첨부한 콘셉트 그림과 똑같은 16비트 픽셀 아트, 선명한 픽셀, 제한된 색상, 같은 시점(옆에서 약간 내려다본 3/4 시점), 같은 조명(왼쪽 위에서 빛), 같은 색감(회색 금속, 노랑-검정 경고 줄무늬, 청록·주황 표시등). 물체 하나만 화면 가운데에 크게, 잘리지 않게 여백을 두고. 배경은 무늬·그림자·바닥·땅이 전혀 없는 단색 마젠타(#FF00FF)로 꽉 채우고, 물체에는 마젠타나 분홍색을 쓰지 마. 글자, 숫자, 로고는 넣지 마. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

### `assets/raw/base/pilot.png`

> 첨부한 콘셉트 그림의 우주복 입은 조종사 한 명만 그려 줘: 흰 우주복, 둥근 헬멧과 청록 얼굴 유리, 등 뒤 주황 산소통, 서 있는 자세, 정면을 봄. 아주 작은 캐릭터를 크게 그린 느낌으로 단순하게. 스타일: 첨부한 콘셉트 그림과 똑같은 16비트 픽셀 아트, 선명한 픽셀, 제한된 색상, 같은 시점(옆에서 약간 내려다본 3/4 시점), 같은 조명(왼쪽 위에서 빛), 같은 색감(회색 금속, 노랑-검정 경고 줄무늬, 청록·주황 표시등). 물체 하나만 화면 가운데에 크게, 잘리지 않게 여백을 두고. 배경은 무늬·그림자·바닥·땅이 전혀 없는 단색 마젠타(#FF00FF)로 꽉 채우고, 물체에는 마젠타나 분홍색을 쓰지 마. 글자, 숫자, 로고는 넣지 마. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

## 기지 전초기지 콘셉트 (v0.6.0, 2026-11-07)

계획: 2장 (가로 화면 전체 구도 1장, 휴대폰 세로 구도 1장). 게임에 직접 넣지 않고, 코드로 그리는 기지 픽셀 아트(`scripts/ui/base_view.gd`)와 가로·세로 배치(`scripts/logic/base_layout.gd`)의 참고 그림으로만 씀. `assets/raw/`는 `.gdignore`로 게임 빌드에 들어가지 않음.

### 1. `assets/raw/base_concept_overview.png` (가로 전체 구도)

> 게임 콘셉트 아트 이미지를 1장 만들어 줘. 대상: 우주 채굴 게임의 '소행성 위의 광부 조합 전초기지' 전체 모습. 옆에서 약간 내려다본 2D 시점, 가로로 넓은 화면(16:9). 울퉁불퉁한 회갈색 소행성 표면 위, 화면 가운데에 작은 흰색 삼각형 전투기 우주선이 착륙 패드 위에 착륙해 있고, 그 옆에 우주복 입은 조종사가 아주 작게 서 있음. 주변에 산업용 건물 5채가 둘러싸고 있음: 1) 연구소(돔 지붕, 안테나, 푸른 불빛) 2) 격납고(큰 문이 달린 아치형 건물) 3) 광물 창고(컨테이너와 앞에 쌓인 반짝이는 광물 더미) 4) 전시관(유리 진열창이 있는 작은 박물관 건물) 5) 드론 공장(공사 중, 비계와 크레인). 하늘은 별이 가득한 짙은 우주, 멀리 다른 소행성들. 건물마다 노란-검정 경고 줄무늬, 청록·주황 표시등. 사람이 만든 아늑한 광산 기지 느낌. 스타일: 16비트 픽셀 아트, 선명한 픽셀, 제한된 색상. 글자나 로고는 넣지 마. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

### 2. `assets/raw/base_concept_portrait.png` (휴대폰 세로 구도, 1번을 `--image`로 넘김)

> 첨부한 소행성 광부 조합 전초기지와 같은 디자인(같은 건물 5채: 돔 연구소, 아치형 격납고, 광물 더미가 있는 창고, 유리 진열창 전시관, 비계와 크레인이 있는 공사 중 드론 공장, 가운데 착륙 패드의 흰 우주선과 작은 조종사)으로, 휴대폰 세로 화면(9:16) 구도의 콘셉트 이미지를 1장 만들어 줘. 위쪽 4분의 1은 별이 있는 우주 하늘, 그 아래 소행성 표면. 착륙 패드와 우주선은 화면 한가운데, 건물은 위 2채·아래 2채·맨 아래 가운데 1채처럼 세로로 나눠 배치하고 건물끼리 겹치지 않게 간격을 둬. 건물들이 살짝 빛나서 누를 수 있어 보이게. 작은 정찰 드론 1대가 떠 있음. 스타일: 16비트 픽셀 아트, 선명한 픽셀, 제한된 색상. 글자나 로고는 넣지 마. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

## 워프 게이트 콘셉트 (v0.4.1, 2026-11-06)

계획: 2장. 게임에 직접 넣지 않고, 코드로 그리는 픽셀 아트(`scripts/pixel_art.gd`, `scripts/gate_view.gd`)의 참고 그림으로만 씀.
`assets/raw/`는 `.gdignore`로 Godot 리소스에서 빠져 있어 게임 빌드에 들어가지 않음.

### 1. `assets/raw/gate_concept_design.png` (디자인)

> 게임 콘셉트 아트 이미지를 1장 만들어 줘. 대상: 우주 채굴 슈팅 게임에서 광부 조합이 설치한 기계식 워프 게이트(귀환 포탈). 위에서 내려다본 2D 시점, 화면 가운데에 크게. 두꺼운 산업용 금속 고리(볼트, 이음새, 8개의 맞물린 장갑 조각, 노란-검정 경고 줄무늬 일부), 고리 둘레에 작은 표시등들(청록과 주황), 고리 안쪽은 보라와 청록이 섞인 소용돌이 포탈, 주변에 안쪽으로 빨려 들어가는 빛 알갱이. 생물이나 고대 유물이 아니라 사람이 만든 기계라는 느낌이 확실해야 함. 스타일: 16비트 픽셀 아트, 선명한 픽셀, 제한된 색상. 배경은 무늬 없는 단색 짙은 남색(#0b0b1a). 글자나 로고는 넣지 마. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

### 2. `assets/raw/gate_concept_states.png` (상태별 시트, 1번을 `--image`로 넘김)

> 첨부한 기계식 워프 게이트와 같은 디자인으로, 상태별 콘셉트 시트 이미지를 1장 만들어 줘. 가로로 4칸, 칸마다 같은 크기의 게이트를 위에서 내려다본 2D 시점으로: 1) 등장: 흩어진 금속 고리 조각들이 가운데로 모여 맞물리는 중, 하얀 섬광 2) 열림: 보라·청록 소용돌이, 빛 알갱이가 안으로 빨려 들어감, 고리 둘레에 청록 원형 게이지 3) 충전 중: 작은 흰 우주선과 게이트 사이에 밝은 빛줄기, 소용돌이가 빠르게 돌고 원형 게이지가 차오름 4) 닫히기 직전: 소용돌이와 표시등이 붉은색으로 변하고 고리가 떨리며 조각이 떨어져 나감. 스타일: 16비트 픽셀 아트, 선명한 픽셀, 제한된 색상. 배경은 무늬 없는 단색 짙은 남색(#0b0b1a). 글자, 숫자, 로고는 넣지 마. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

## 기지 3/4 조감 콘셉트 (v0.6.3, 2026-11-07)

계획: 콘셉트 1장(가로). 확인 뒤 건물·길·소품 그림을 따로 만듦.

### `assets/raw/base_concept_v063.png`

> 게임 콘셉트 아트 1장(16:9). 우주 채굴 게임의 소행성 전초기지를 클래식 픽셀 RPG 마을 화면처럼 비스듬한 탑다운(3/4 조감)으로 그려 줘: 지면은 위에서 내려다보이고 건물은 지붕과 앞면이 함께 보임. 화면 대부분이 바위 지면이고 건물은 작게(건물 하나가 화면 폭의 약 12~15%). 첨부한 그림의 건물 5채(돔 연구소, 아치 격납고, 광물 창고, 유리 전시관, 공사 중 드론 공장)와 가운데 팔각 착륙장·흰 우주선·작은 조종사를 같은 디자인으로 쓰되 더 작게. 배치는 위 3채, 가운데 착륙장, 아래 2채 정도. 모든 건물은 금속 바닥 패드 위에 서 있고, 왼쪽 위 광원에 맞춘 같은 방향의 접지 그림자가 있고, 건물 입구와 착륙장 사이를 흙길·금속판 길·배관·케이블로 이어 주고, 주변에 울타리, 상자, 표지판, 통, 안테나 같은 소품이 있음. 지면은 회갈색 바위에 작은 돌과 분화구, 가장자리는 어두운 우주 배경. 건물과 지면은 같은 픽셀 크기, 같은 팔레트. 16비트 픽셀 아트, 선명한 픽셀, 제한된 색상. 글자·로고 없음. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

### v0.6.3 구현용 (2026-11-07): 건물은 승인된 콘셉트에서 잘라 쓰고, 지면만 새로 만듦

#### `assets/raw/base/ground_v063_landscape.png` (콘셉트를 `--image`로 넘김)

> 첨부한 그림과 똑같은 소행성 지면 그림을 다시 그려 줘 (같은 시점, 같은 팔레트, 같은 픽셀 크기, 같은 16:9 구도, 같은 소행성 가장자리·우주 배경·분화구·바위). 단, 건물 5채, 가운데 착륙장, 우주선, 조종사, 건물 그림자, 길, 배관, 케이블, 표시등, 상자, 울타리, 통은 전부 지우고 그 자리를 바위 지면으로 채워 줘. 지면 위에는 작은 돌, 분화구, 가장자리 바위, 안테나 탑 2개와 빈 표지판 2개만 남겨. 글자·로고 없음. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

#### `assets/raw/base/ground_v063_portrait.png` (위 지면을 `--image`로 넘김)

> 첨부한 소행성 지면과 같은 시점·팔레트·픽셀 크기로, 휴대폰 세로 화면(9:16) 구도의 소행성 지면 그림을 1장 그려 줘. 세로로 긴 소행성 하나가 화면을 거의 채우고 가장자리에는 우주와 별. 건물·길·우주선·그림자는 없고 바위 지면, 작은 돌, 분화구, 가장자리 바위만. 글자·로고 없음. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

### v0.6.3 수정 (2026-11-08): 지면 축소판 (소행성 전체가 화면 안에, 바위·분화구는 작게)

#### `assets/raw/base/ground_v063b_landscape.png` (v0.6.3 가로 지면을 `--image`로 넘김)

> 첨부한 소행성 지면 그림을 다시 그려 줘. 같은 시점, 같은 팔레트, 같은 픽셀 스타일의 16:9 그림. 단, 소행성 전체가 그림 안에 여유 있게 들어오게 줄여 줘: 소행성 가장자리가 그림의 위·아래·좌·우 어디에도 닿거나 잘리지 않고, 소행성 바깥에 짙은 남색 우주와 별이 사방으로 약 8~10% 보이게 해. 소행성 윤곽은 둥근 타원. 지면의 바위, 작은 돌, 분화구, 가장자리 바위는 첨부 그림의 약 절반 크기로 작게 그리고, 작은 돌과 분화구 수는 더 많게. 건물·길·우주선·그림자는 없고, 안테나 탑 2개와 빈 표지판 2개만 지면 가장자리 쪽에 작게 남겨. 글자·로고 없음. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

#### `assets/raw/base/ground_v063b_portrait.png` (위 가로 지면을 `--image`로 넘김)

> 첨부한 가로 소행성 지면 그림과 같은 시점·팔레트·픽셀 스타일로, 휴대폰 세로 화면(9:16) 구도의 소행성 지면 그림을 1장 그려 줘. 소행성 전체가 그림 안에 여유 있게 들어오게: 가장자리가 위·아래·좌·우 어디에도 닿거나 잘리지 않고 사방으로 짙은 남색 우주와 별이 약 8~10% 보여야 해. 소행성은 세로로 긴 둥근 타원. 바위·작은 돌·분화구·가장자리 바위는 첨부 그림과 같은 크기(작게). 건물·길·우주선·그림자는 없고, 안테나 탑 2개와 빈 표지판 2개만 가장자리 쪽에 작게. 글자·로고 없음. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

후처리: 소행성(붉은 갈색 덩어리)만 남기고 바깥 우주·별을 투명하게(`*_keyed.png`) → `tools/pixelate.py --no-key --width 640 --height 360`(가로) / `--width 360 --height 640`(세로) → `assets/sprites/base/ground_*.png`. 건물·착륙장·우주선은 `crop063`·`base/` 원본을 `--width 54~71`(전 0.8배)로 다시 정리.

### v0.6.4 (2026-11-08): 세로 화면 전용 소행성 지면 (그림을 늘이지 않고 3:4 둥근 모양으로 새로 그림)

#### `assets/raw/base/ground_v063d_portrait.png` (가로 지면 `ground_v063b_landscape.png`를 `--image`로 넘김)

> 첨부한 소행성 지면 그림과 같은 시점·팔레트·픽셀 스타일로, 3:4 세로 비율 그림 1장을 그려 줘. 소행성의 윤곽은 세로로 긴 둥근 달걀 모양이어야 해: 소행성의 높이가 폭의 1.33배(폭 3 : 높이 4). 소행성의 폭이 그림 폭의 약 92%, 높이가 그림 높이의 약 92%를 차지하고, 위·아래·좌·우 어디에도 닿거나 잘리지 않으며 가장자리 바깥에 짙은 남색 우주와 별이 조금 보여야 해. 가장자리 바위 윤곽과 바위·작은 돌·분화구 크기는 첨부 그림과 같게(작게) 하고, 분화구와 돌은 서로 다르게 고르게 흩어 줘 (같은 모양을 반복하지 마). 건물·길·우주선·그림자·안테나·표지판 없음. 글자·로고 없음. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

(첫 시도는 소행성이 거의 정원(가로로 넓음)으로 나와 버려 위 문구로 다시 요청함)
후처리: `tools/key_asteroid.py`로 우주 배경·떠다니는 돌을 지움(`*_keyed.png`) → `tools/pixelate.py --no-key --width 332` → 360x480 투명 바탕 가운데에 붙여 `assets/sprites/base/ground_portrait.png` (소행성 332x440).

### v0.6.5 (2026-11-08): 세로 화면 소행성 지면 (Codex 요청 없음)

바위 윤곽(4:5, 좌우 비대칭)은 이미지 생성 없이 `tools/make_ground.py`(시드 64)로 만듦: v0.6.4 세로 지면(`assets/raw/base/ground_portrait_v064.png`, Codex 그림)의 바위 질감을 잘라 새 윤곽에 입히고, 절벽 단면·가장자리 명암을 더해 36색으로 줄임.

### v0.6.6 (2026-11-08): 가로 고정 — 건물 12~13% 폭 (Codex 요청 없음)

새 그림 생성 없이 기존 원본(`assets/raw/base/crop063/*`, `pad.png`, `ship.png`, `pilot.png`, `research_parts.png`, `piles.png`)을 `tools/make_base_sprites.sh`로 더 큰 격자(건물 폭 78~83)에 다시 정리. 세로 지면(`ground_portrait`)은 사용 중단.

### v0.7.0 3단계 (2026-11-08): 출격 화면 작은·큰 운석, 광물 4등급 (3장)

계획: 팩(Foozle Void)에 운석이 한 크기(보이는 폭 38)뿐이라 작은(약 24)·큰(약 60) 운석 2장, 팩에 없는 광물 4등급 1장(4개를 한 줄로). 참고 그림은 팩 그림을 8배로 키워 마젠타 바탕에 놓은 것(`assets/raw/run/ref_*.png`)을 `-i`로 넘김.

#### `assets/raw/run/asteroid_small.png` (`ref_asteroid01_x8.png`를 `-i`로 넘김)

> 첨부한 그림 왼쪽의 픽셀 아트 소행성(위에서 내려다본 2D 게임 그림)과 똑같은 스타일로, 더 작고 둥근 소행성 1개를 그려 줘. 같은 외곽선(1픽셀 어두운 테두리), 같은 보라빛 회갈색 팔레트, 같은 분화구 표현, 빛은 왼쪽 위에서. 원본보다 둥글고 분화구는 2~3개만. 큰 픽셀이 또렷한 픽셀 아트(약 24x24 픽셀 격자를 크게 키운 느낌), 부드러운 그라데이션·안티에일리어싱 없음. 배경은 단색 마젠타(#FF00FF)만, 소행성 1개만 가운데에, 그림자·별·글자 없음. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

#### `assets/raw/run/asteroid_large.png` (`ref_asteroid01_x8.png`를 `-i`로 넘김)

> 첨부한 그림 왼쪽의 픽셀 아트 소행성(위에서 내려다본 2D 게임 그림)과 똑같은 스타일로, 더 크고 울퉁불퉁한 소행성 1개를 그려 줘. 같은 외곽선(1픽셀 어두운 테두리), 같은 보라빛 회갈색 팔레트, 같은 분화구 표현, 빛은 왼쪽 위에서. 원본보다 길쭉하고 모서리가 각진 덩어리 모양, 크고 작은 분화구 6~8개. 큰 픽셀이 또렷한 픽셀 아트(약 60x60 픽셀 격자를 크게 키운 느낌), 부드러운 그라데이션·안티에일리어싱 없음. 배경은 단색 마젠타(#FF00FF)만, 소행성 1개만 가운데에, 그림자·별·글자 없음. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

#### `assets/raw/run/minerals.png` (`ref_pack_x8.png`(팩 운석·우주선)를 `-i`로 넘김)

> 첨부한 픽셀 아트 우주 게임 그림(소행성, 우주선)과 같은 스타일로, 줍는 광물 아이템 4개를 가로 한 줄로 간격을 넉넉히 두고 그려 줘. 왼쪽부터: 1) 회색 거친 돌 조각(일반), 2) 밝은 시안색 뾰족한 결정(희귀), 3) 보라색 육각형 보석(영웅), 4) 빛나는 금덩어리(전설). 오른쪽으로 갈수록 조금씩 크고 화려하게. 모두 1픽셀 어두운 외곽선, 빛은 왼쪽 위, 밝은 면 하이라이트 1~2픽셀. 큰 픽셀이 또렷한 픽셀 아트(하나가 약 10x10 픽셀 격자를 크게 키운 느낌), 그라데이션·안티에일리어싱 없음. 배경은 단색 마젠타(#FF00FF)만, 그림자·별·글자 없음. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

후처리: 운석은 `tools/pixelate.py --width 24/60 --palette "Asteroid 01 - Base.png"`(팩 운석 5색) → `tools/build_run_sprites.py`(금·깨짐 프레임, 8방향). 광물은 `tools/make_minerals.py`(엄격한 마젠타 키, 평균 축소 8/10/11/12px, void32 등급별 색, 보라 보석 면 다듬기). 첫 실행은 `-i` 뒤에 요청문을 두어 요청문이 그림 경로로 읽혀 실패했고, 요청문을 앞에 두어 다시 실행함.


### v0.7.0 3c (2026-11-08): 심연의 포격 에너지 구체 (1장)

계획: 팩(Foozle Void)에 크고 둥근 에너지 구가 없음(Nautolan Bomb은 16px 작은 보석, Kla'ed·Nairan 탄은 길쭉함) → 맥동 4프레임을 가로 한 줄로 1장. 구체가 분홍이라 마젠타 대신 초록 배경으로 요청. 참고 그림은 팩 우주선·Nairan 볼트·Nautolan 폭탄·Kla'ed 탄을 8배로 키워 어두운 바탕에 놓은 것(`assets/raw/run/ref_orb_x8.png`)을 `-i`로 넘김.

#### `assets/raw/run/barrage_orb.png` (`ref_orb_x8.png`를 `-i`로 넘김)

> 첨부한 픽셀 아트 우주 게임 그림(우주선, 분홍 볼트 탄, 빨간 폭탄, 주황 탄)과 같은 스타일로, 적이 화면 밖에서 쏘는 위협적인 '에너지 구체' 탄 4프레임(맥동 애니메이션)을 가로 한 줄로 간격을 넉넉히 두고 그려 줘. 둥글고 큰 에너지 공: 가운데는 거의 흰색(#fef8e5) 핵, 그 바깥은 밝은 핫핑크(#ff2567)와 연분홍(#f25c76), 가장자리는 진한 자홍(#861a59), 맨 바깥 1픽셀 어두운 보라(#3a1c57) 외곽선. 가장자리에 작은 전기 불꽃 2~3개가 튀어나옴. 4프레임은 같은 크기·같은 위치에서 핵이 조금 커졌다 작아지고 불꽃 위치가 바뀌는 맥동. 큰 픽셀이 또렷한 픽셀 아트(한 프레임이 약 16x16 픽셀 격자를 크게 키운 느낌), 그라데이션·안티에일리어싱 없음, 위 5색만 사용. 배경은 단색 초록(#00FF00)만, 그림자·별·글자·꼬리 없음. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

후처리: 초록(G>200, R·B<90)을 마젠타로 바꾼 임시 그림 → `tools/pixelate.py --width 88 --colors 8 --palette <위 5색>` → `assets/sprites/run/barrage_orb_base.png`(88x16, 4프레임) → `tools/build_run_sprites.py`의 `orb_frames`가 프레임마다 구체 몸통 가운데를 20x20 칸 가운데에 맞춰 `barrage_shot.png`(돌리지 않음, 행 1개). 첫 시도 1장으로 끝남.


### v0.7.0 5단계 1부 (2026-11-08): 레벨업 아이콘 스타일 샘플 (1장에 3개)

계획: 강화 15종 중 시스템 쿨러 개량, 텅스텐 관통탄, 호위 드론 사출만 먼저 만들어 시안에 넣음. 나머지 12종은 스타일이 정해진 뒤에. 참고 그림은 `assets/raw/run/ref_pack_x8.png`를 `-i`로 넘김.

#### `assets/raw/run/icons/icons_sample.png`

> 첨부한 픽셀 아트 우주 게임 그림(우주선, 운석)과 같은 스타일로, 레벨업 카드에 넣을 장비 아이콘 3개를 가로 한 줄로 간격을 넉넉히 두고 그려 줘. 왼쪽부터: 1) 시스템 쿨러: 각진 금속 프레임 안에 날 6개짜리 냉각 팬, 옆에 방열핀, 팬 가운데 청록빛(#99e9e6, #30e1b9). 2) 텅스텐 관통탄: 어두운 회색 금속판을 뚫고 오른쪽 위 대각선으로 튀어나오는 뾰족한 회백색 탄두, 뚫린 자리에 주황 불꽃(#f89419) 몇 픽셀. 3) 호위 드론: 위에서 본 작은 무인기, 가운데 몸체에 청록 렌즈 1개, 양쪽에 작은 추진기 2개와 주황 엔진 불꽃. 모두 금속 부분은 #3c3544 #5c5164 #917487 #a5b29d #fef8e5 범위의 색, 바깥쪽 1픽셀 어두운 외곽선(#2b1925), 빛은 왼쪽 위에서, 밝은 면 하이라이트 1~2픽셀. 큰 픽셀이 또렷한 픽셀 아트(아이콘 하나가 약 48x48 픽셀 격자를 크게 키운 느낌), 그라데이션·안티에일리어싱·디더링 없음. 배경은 단색 마젠타(#FF00FF)만, 그림자·별·글자·테두리 없음. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

#### `assets/raw/run/icons/icon_pierce.png` (관통탄을 다시, `icons_sample.png`를 `-i`로 넘김)

첫 장의 관통탄은 탄두와 판이 엉켜 작게 줄이면 알아보기 어려워 1번 다시 만듦.

> 첨부한 픽셀 아트 장비 아이콘(쿨러, 드론)과 똑같은 스타일·같은 색·같은 외곽선으로, 레벨업 카드 아이콘 1개를 가운데에 크게 그려 줘. 주제: 텅스텐 관통탄. 구도는 아주 단순하게: 왼쪽 아래에서 오른쪽 위로 45도 대각선으로 놓인 길고 날씬한 탄환 1개가 화면 전체 대각선을 차지하고, 탄두는 바늘처럼 뾰족한 회백색(#fef8e5, #a5b29d), 몸통은 어두운 금속(#5c5164, #3c3544), 꼬리 쪽에 청록(#30e1b9) 띠 1줄. 탄환 가운데를 얇고 어두운 금속판 1장이 세로로 가로지르고 탄환이 그 판을 뚫고 지나간 모습, 뚫린 자리 둘레에 주황 불꽃(#f89419) 조각 4~5개. 판은 탄환보다 앞으로 튀어나오지 않고 탄환 윤곽이 끊기지 않고 한눈에 보여야 함. 바깥쪽 1픽셀 어두운 외곽선(#2b1925), 빛은 왼쪽 위. 큰 픽셀이 또렷한 픽셀 아트(약 48x48 픽셀 격자를 크게 키운 느낌), 그라데이션·안티에일리어싱·디더링 없음. 배경은 단색 마젠타(#FF00FF)만, 그림자·별·글자·테두리 없음. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마


### v0.7.0 5단계 카드 프레임 (2026-11-08): 2방향 × (빈 프레임 + 부품) = 4장

계획: 프레임 결 2개(각진 군용 장갑판 M, 매끈한 고급 기술 장비 S). 등급은 재색칠과 장식 추가로 만들어 그림 수를 늘리지 않음. 후처리는 `review/v070_step5/frame/make_frames.py`.

#### `assets/raw/run/frame/frame_m.png` (`assets/raw/run/ref_pack_x8.png`를 `-i`로 넘김)

> 첨부한 픽셀 아트 우주 게임 그림과 같은 스타일로, 게임 UI에 쓰는 세로 직사각형 카드 프레임 1개를 정면에서 그려 줘. 비율 2:3, 화면에 꽉 차게, 전체가 약 192x288 픽셀 격자를 크게 키운 느낌. 좌우 대칭. 결은 각진 군용 장갑판: 모서리가 사선으로 크게 잘리고, 두꺼운 판이 겹쳐 있고, 볼트와 리벳, 판 이음매, 얕게 판 회로 홈이 보이는 묵직한 모습. 테두리 두께는 카드 폭의 약 6%(격자로 12픽셀)이고 여러 겹(바깥 어두운 선, 두툼한 금속 층, 안쪽 홈, 안쪽 가장자리를 따라 도는 얇은 청록 발광 띠 1줄)으로 됨. 장식과 리벳은 네 모서리에 모으고, 네 변의 가운데 구간은 위아래 또는 좌우로 반복해도 이어지는 단순한 직선 패턴(9칸 나누기용). 카드 안쪽은 어두운 금속판(#2b1925 바탕에 #3c3544의 아주 희미한 회로 홈 몇 줄)으로 채우고 큰 그림이나 장식을 넣지 말 것. 큰 픽셀이 또렷한 픽셀 아트, 그라데이션·안티에일리어싱·디더링 없음, 바깥쪽 1픽셀 어두운 외곽선(#2b1925), 빛은 왼쪽 위에서(위 면 밝고 아래 면 어두워 입체감이 남). 금속 색은 #3c3544 #5c5164 #917487 #a5b29d #fef8e5 범위만 쓰고, 발광 띠와 보석은 모두 순수한 청록 #30e1b9와 밝은 청록 #99e9e6만 씀(나중에 등급 색으로 바꿈). 글자·숫자·별·그림자 없음, 실제 게임이나 영화의 문장·로고 모양을 쓰지 말고 새로 디자인. 배경은 단색 마젠타(#FF00FF)만. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

#### `assets/raw/run/frame/parts_m.png` (`assets/raw/run/frame/frame_m.png`를 `-i`로 넘김)

> 첨부한 카드 프레임과 똑같은 결·색·외곽선으로 UI 부품 7개를 2줄로, 서로 닿지 않게 간격을 넉넉히 두고 그려 줘. 전체 그림의 격자 크기는 첨부 프레임과 같은 픽셀 크기. 윗줄 왼쪽부터: 1) 카드 위쪽 가운데에 붙는 작은 장식 받침(폭 약 40픽셀, 가운데 큰 청록 보석 1개). 2) 받침 양옆에 붙는 작은 날개 장식 한 쌍(폭 약 56픽셀, 좌우 대칭으로 이어 붙여 그리기, 가운데는 비움). 3) 받침 양옆에 붙는 크고 화려한 날개 장식 한 쌍(폭 약 96픽셀, 지느러미 여러 겹과 청록 발광선, 가운데는 비움). 4) 카드 왼쪽 위 모서리에 덧대는 장식 쇠(약 40x40픽셀, ㄱ자 모양). 아랫줄 왼쪽부터: 5) 아이콘을 받치는 각진 육각형 받침(폭 약 144픽셀, 가운데 넓고 어둡게 파인 자리, 가장자리에 청록 발광선). 6) 알약 모양 꼬리표(폭 약 64 높이 16픽셀, 양끝이 둥글고 가운데는 어두운 띠). 7) 넓은 버튼 판(폭 약 180 높이 24픽셀, 모서리가 사선으로 잘리고 양끝에 볼트, 가운데는 비어 있는 어두운 면). 결은 각진 군용 장갑판: 모서리가 사선으로 크게 잘리고, 두꺼운 판이 겹쳐 있고, 볼트와 리벳, 판 이음매, 얕게 판 회로 홈이 보이는 묵직한 모습. 큰 픽셀이 또렷한 픽셀 아트, 그라데이션·안티에일리어싱·디더링 없음, 바깥쪽 1픽셀 어두운 외곽선(#2b1925), 빛은 왼쪽 위에서(위 면 밝고 아래 면 어두워 입체감이 남). 금속 색은 #3c3544 #5c5164 #917487 #a5b29d #fef8e5 범위만 쓰고, 발광 띠와 보석은 모두 순수한 청록 #30e1b9와 밝은 청록 #99e9e6만 씀(나중에 등급 색으로 바꿈). 글자·숫자·별·그림자 없음, 실제 게임이나 영화의 문장·로고 모양을 쓰지 말고 새로 디자인. 배경은 단색 마젠타(#FF00FF)만. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

#### `assets/raw/run/frame/frame_s.png` (`assets/raw/run/ref_pack_x8.png`를 `-i`로 넘김)

> 첨부한 픽셀 아트 우주 게임 그림과 같은 스타일로, 게임 UI에 쓰는 세로 직사각형 카드 프레임 1개를 정면에서 그려 줘. 비율 2:3, 화면에 꽉 차게, 전체가 약 192x288 픽셀 격자를 크게 키운 느낌. 좌우 대칭. 결은 매끈한 고급 기술 장비: 부드럽게 둥근 모서리, 매끈한 밝은 세라믹 판과 얇은 금속 선, 가늘고 정밀한 홈과 작은 조명 점, 군더더기 없는 고급스러운 모습. 리벳 대신 작은 정밀 나사와 얇은 이음선. 테두리 두께는 카드 폭의 약 6%(격자로 12픽셀)이고 여러 겹(바깥 어두운 선, 두툼한 금속 층, 안쪽 홈, 안쪽 가장자리를 따라 도는 얇은 청록 발광 띠 1줄)으로 됨. 장식과 리벳은 네 모서리에 모으고, 네 변의 가운데 구간은 위아래 또는 좌우로 반복해도 이어지는 단순한 직선 패턴(9칸 나누기용). 카드 안쪽은 어두운 금속판(#2b1925 바탕에 #3c3544의 아주 희미한 회로 홈 몇 줄)으로 채우고 큰 그림이나 장식을 넣지 말 것. 큰 픽셀이 또렷한 픽셀 아트, 그라데이션·안티에일리어싱·디더링 없음, 바깥쪽 1픽셀 어두운 외곽선(#2b1925), 빛은 왼쪽 위에서(위 면 밝고 아래 면 어두워 입체감이 남). 금속 색은 #3c3544 #5c5164 #917487 #a5b29d #fef8e5 범위만 쓰고, 발광 띠와 보석은 모두 순수한 청록 #30e1b9와 밝은 청록 #99e9e6만 씀(나중에 등급 색으로 바꿈). 글자·숫자·별·그림자 없음, 실제 게임이나 영화의 문장·로고 모양을 쓰지 말고 새로 디자인. 배경은 단색 마젠타(#FF00FF)만. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

#### `assets/raw/run/frame/parts_s.png` (`assets/raw/run/frame/frame_s.png`를 `-i`로 넘김)

> 첨부한 카드 프레임과 똑같은 결·색·외곽선으로 UI 부품 7개를 2줄로, 서로 닿지 않게 간격을 넉넉히 두고 그려 줘. 전체 그림의 격자 크기는 첨부 프레임과 같은 픽셀 크기. 윗줄 왼쪽부터: 1) 카드 위쪽 가운데에 붙는 작은 장식 받침(폭 약 40픽셀, 가운데 큰 청록 보석 1개). 2) 받침 양옆에 붙는 작은 날개 장식 한 쌍(폭 약 56픽셀, 좌우 대칭으로 이어 붙여 그리기, 가운데는 비움). 3) 받침 양옆에 붙는 크고 화려한 날개 장식 한 쌍(폭 약 96픽셀, 지느러미 여러 겹과 청록 발광선, 가운데는 비움). 4) 카드 왼쪽 위 모서리에 덧대는 장식 쇠(약 40x40픽셀, ㄱ자 모양). 아랫줄 왼쪽부터: 5) 아이콘을 받치는 매끈한 둥근 원형 받침(폭 약 144픽셀, 가운데 넓고 어둡게 파인 자리, 가장자리에 청록 발광선). 6) 알약 모양 꼬리표(폭 약 64 높이 16픽셀, 양끝이 둥글고 가운데는 어두운 띠). 7) 넓은 버튼 판(폭 약 180 높이 24픽셀, 양끝이 부드럽게 둥글고 얇은 조명선, 가운데는 비어 있는 어두운 면). 결은 매끈한 고급 기술 장비: 부드럽게 둥근 모서리, 매끈한 밝은 세라믹 판과 얇은 금속 선, 가늘고 정밀한 홈과 작은 조명 점, 군더더기 없는 고급스러운 모습. 리벳 대신 작은 정밀 나사와 얇은 이음선. 큰 픽셀이 또렷한 픽셀 아트, 그라데이션·안티에일리어싱·디더링 없음, 바깥쪽 1픽셀 어두운 외곽선(#2b1925), 빛은 왼쪽 위에서(위 면 밝고 아래 면 어두워 입체감이 남). 금속 색은 #3c3544 #5c5164 #917487 #a5b29d #fef8e5 범위만 쓰고, 발광 띠와 보석은 모두 순수한 청록 #30e1b9와 밝은 청록 #99e9e6만 씀(나중에 등급 색으로 바꿈). 글자·숫자·별·그림자 없음, 실제 게임이나 영화의 문장·로고 모양을 쓰지 말고 새로 디자인. 배경은 단색 마젠타(#FF00FF)만. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마


### v0.7.0 5단계 2부 (2026-11-08): 레벨업 아이콘 나머지 (쿨러·드론 샘플 재사용 + 7장에 17개)

계획: 강화 19종 중 쿨러·드론은 1부 샘플을 그대로 쓰고 나머지 17개를 시트 6장으로. 받침에 넣어 본 뒤 반사 코팅 탄(체크 표시처럼 보임)과 편향 실드(안전모처럼 보임)를 1장 더 만들어 교체. 관통탄은 금지 표시처럼 보이지 않게 수직 구도로 바꿈. `icons_sample.png`을 `-i`로 넘김. 후처리는 `tools/make_card_art.py`.

#### `assets/raw/run/icons/icons_a.png`

> 첨부한 픽셀 아트 장비 아이콘(쿨러, 드론)과 똑같은 스타일·같은 색·같은 외곽선으로, 레벨업 카드 아이콘을 3개, 가로 한 줄로 서로 닿지 않게 간격을 넉넉히 두고 크게 그려 줘. 왼쪽부터: 1) 다중 포신: 정면 위쪽을 향한 굵은 포신 3개를 나란히 묶은 포대, 포구마다 청록 빛. 2) 고밀도 탄두: 위를 향한 뚱뚱하고 짧은 탄두 1개, 앞부분은 무거운 회백색 금속, 가운데 주황 띠. 3) 장거리 조준 센서: 둥근 렌즈가 크고 청록빛인 망원 센서를 정면에서 본 모습, 렌즈 아래 굵은 받침. 공통: 각 아이콘은 지름이 같은 원 안에 꽉 차게 들어가는 뭉툭하고 묵직한 실루엣이어야 하고, 얇은 막대·가는 선을 쓰지 말고 굵은 형태로만. 아이콘을 가로지르는 대각선 금지, 원 안에 사선이 있는 금지 표지처럼 보이면 안 됨. 금속은 #3c3544 #5c5164 #917487 #a5b29d #fef8e5 범위, 강조색은 #30e1b9 #99e9e6(청록) #f89419 #f6ce50(주황·금) #f25c76(빨강) #a884f3(보라) 중에서만, 아이콘 하나에 8~10색. 바깥쪽 1픽셀 어두운 외곽선(#2b1925), 빛은 왼쪽 위, 밝은 면 하이라이트 1~2픽셀. 큰 픽셀이 또렷한 픽셀 아트(아이콘 하나가 약 48x48 픽셀 격자를 크게 키운 느낌), 그라데이션·안티에일리어싱·디더링 없음. 배경은 단색 마젠타(#FF00FF)만, 그림자·별·글자·숫자·테두리·원형 받침 없음. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

#### `assets/raw/run/icons/icons_b.png`

> 첨부한 픽셀 아트 장비 아이콘(쿨러, 드론)과 똑같은 스타일·같은 색·같은 외곽선으로, 레벨업 카드 아이콘을 3개, 가로 한 줄로 서로 닿지 않게 간격을 넉넉히 두고 크게 그려 줘. 왼쪽부터: 1) 복합 장갑판: 굵은 방패 모양으로 겹친 장갑판 2겹, 작은 나사, 가운데 청록 표시. 2) 나노 수리봇: 둥근 몸체의 작은 로봇, 굵은 집게 팔 2개, 가운데 초록빛이 도는 청록 십자 표시. 3) 추진기: 뒤쪽에서 본 굵은 원통형 엔진 노즐 1개, 아래로 주황·금색 불꽃이 짧고 두껍게 나옴. 공통: 각 아이콘은 지름이 같은 원 안에 꽉 차게 들어가는 뭉툭하고 묵직한 실루엣이어야 하고, 얇은 막대·가는 선을 쓰지 말고 굵은 형태로만. 아이콘을 가로지르는 대각선 금지, 원 안에 사선이 있는 금지 표지처럼 보이면 안 됨. 금속은 #3c3544 #5c5164 #917487 #a5b29d #fef8e5 범위, 강조색은 #30e1b9 #99e9e6(청록) #f89419 #f6ce50(주황·금) #f25c76(빨강) #a884f3(보라) 중에서만, 아이콘 하나에 8~10색. 바깥쪽 1픽셀 어두운 외곽선(#2b1925), 빛은 왼쪽 위, 밝은 면 하이라이트 1~2픽셀. 큰 픽셀이 또렷한 픽셀 아트(아이콘 하나가 약 48x48 픽셀 격자를 크게 키운 느낌), 그라데이션·안티에일리어싱·디더링 없음. 배경은 단색 마젠타(#FF00FF)만, 그림자·별·글자·숫자·테두리·원형 받침 없음. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

#### `assets/raw/run/icons/icons_c.png`

> 첨부한 픽셀 아트 장비 아이콘(쿨러, 드론)과 똑같은 스타일·같은 색·같은 외곽선으로, 레벨업 카드 아이콘을 3개, 가로 한 줄로 서로 닿지 않게 간격을 넉넉히 두고 크게 그려 줘. 왼쪽부터: 1) 중력 견인 코일: 위가 열린 말굽 자석 모양 코일, 굵은 금속 감김 줄, 양 끝에 청록 빛. 2) 정밀 채굴 레이저: 위에서 아래로 향한 굵은 레이저 헤드, 아래쪽 끝에 빛나는 청록 결정 조각 1개, 빛줄기는 짧고 수직. 3) 편향 실드 발생기: 금색 빛 테두리를 두른 납작한 원반 장치 위에 금색 빛이 위로 솟는 모습. 공통: 각 아이콘은 지름이 같은 원 안에 꽉 차게 들어가는 뭉툭하고 묵직한 실루엣이어야 하고, 얇은 막대·가는 선을 쓰지 말고 굵은 형태로만. 아이콘을 가로지르는 대각선 금지, 원 안에 사선이 있는 금지 표지처럼 보이면 안 됨. 금속은 #3c3544 #5c5164 #917487 #a5b29d #fef8e5 범위, 강조색은 #30e1b9 #99e9e6(청록) #f89419 #f6ce50(주황·금) #f25c76(빨강) #a884f3(보라) 중에서만, 아이콘 하나에 8~10색. 바깥쪽 1픽셀 어두운 외곽선(#2b1925), 빛은 왼쪽 위, 밝은 면 하이라이트 1~2픽셀. 큰 픽셀이 또렷한 픽셀 아트(아이콘 하나가 약 48x48 픽셀 격자를 크게 키운 느낌), 그라데이션·안티에일리어싱·디더링 없음. 배경은 단색 마젠타(#FF00FF)만, 그림자·별·글자·숫자·테두리·원형 받침 없음. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

#### `assets/raw/run/icons/icons_d.png`

> 첨부한 픽셀 아트 장비 아이콘(쿨러, 드론)과 똑같은 스타일·같은 색·같은 외곽선으로, 레벨업 카드 아이콘을 3개, 가로 한 줄로 서로 닿지 않게 간격을 넉넉히 두고 크게 그려 줘. 왼쪽부터: 1) 텅스텐 관통탄: 수직으로 똑바로 위를 향한 아주 굵고 뭉툭한 탄환 1개(아이콘 폭의 40%), 탄두는 회백색, 몸통은 어두운 금속, 꼬리에 청록 띠. 탄환 가운데 높이에 가로로 놓인 부서진 금속판 조각이 좌우에 하나씩 있고 그 구멍을 탄환이 뚫고 올라감, 판과 탄환 사이에 주황 불꽃 조각 몇 개. 탄환은 절대 기울이지 말 것. 2) 반사 코팅 탄: 굵고 둥근 탄 1개가 금속판에 부딪혀 V자로 꺾여 튕기는 모습, 꺾인 궤적은 굵은 청록 띠, V의 꼭짓점은 아래. 3) 고폭 탄두: 굵고 둥근 폭탄형 탄두, 그 둘레로 주황·금색 폭발 조각이 사방으로 튐. 공통: 각 아이콘은 지름이 같은 원 안에 꽉 차게 들어가는 뭉툭하고 묵직한 실루엣이어야 하고, 얇은 막대·가는 선을 쓰지 말고 굵은 형태로만. 아이콘을 가로지르는 대각선 금지, 원 안에 사선이 있는 금지 표지처럼 보이면 안 됨. 금속은 #3c3544 #5c5164 #917487 #a5b29d #fef8e5 범위, 강조색은 #30e1b9 #99e9e6(청록) #f89419 #f6ce50(주황·금) #f25c76(빨강) #a884f3(보라) 중에서만, 아이콘 하나에 8~10색. 바깥쪽 1픽셀 어두운 외곽선(#2b1925), 빛은 왼쪽 위, 밝은 면 하이라이트 1~2픽셀. 큰 픽셀이 또렷한 픽셀 아트(아이콘 하나가 약 48x48 픽셀 격자를 크게 키운 느낌), 그라데이션·안티에일리어싱·디더링 없음. 배경은 단색 마젠타(#FF00FF)만, 그림자·별·글자·숫자·테두리·원형 받침 없음. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

#### `assets/raw/run/icons/icons_e.png`

> 첨부한 픽셀 아트 장비 아이콘(쿨러, 드론)과 똑같은 스타일·같은 색·같은 외곽선으로, 레벨업 카드 아이콘을 2개, 가로 한 줄로 서로 닿지 않게 간격을 넉넉히 두고 크게 그려 줘. 왼쪽부터: 1) 표적 분석 AI: 네모 칩 위에 빛나는 청록 눈 하나, 칩 둘레에 굵은 핀, 눈 안에 빨강 점. 2) 궤도 관통 가속기: 수직으로 위를 향한 굵은 금색 포탄이 빛나는 고리 3개를 겹쳐 통과하는 모습, 고리는 앞에서 납작한 타원으로 보임, 금·청록 색으로 화려하게. 탄은 기울이지 말 것. 공통: 각 아이콘은 지름이 같은 원 안에 꽉 차게 들어가는 뭉툭하고 묵직한 실루엣이어야 하고, 얇은 막대·가는 선을 쓰지 말고 굵은 형태로만. 아이콘을 가로지르는 대각선 금지, 원 안에 사선이 있는 금지 표지처럼 보이면 안 됨. 금속은 #3c3544 #5c5164 #917487 #a5b29d #fef8e5 범위, 강조색은 #30e1b9 #99e9e6(청록) #f89419 #f6ce50(주황·금) #f25c76(빨강) #a884f3(보라) 중에서만, 아이콘 하나에 8~10색. 바깥쪽 1픽셀 어두운 외곽선(#2b1925), 빛은 왼쪽 위, 밝은 면 하이라이트 1~2픽셀. 큰 픽셀이 또렷한 픽셀 아트(아이콘 하나가 약 48x48 픽셀 격자를 크게 키운 느낌), 그라데이션·안티에일리어싱·디더링 없음. 배경은 단색 마젠타(#FF00FF)만, 그림자·별·글자·숫자·테두리·원형 받침 없음. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

#### `assets/raw/run/icons/icons_f.png`

> 첨부한 픽셀 아트 장비 아이콘(쿨러, 드론)과 똑같은 스타일·같은 색·같은 외곽선으로, 레벨업 카드 아이콘을 3개, 가로 한 줄로 서로 닿지 않게 간격을 넉넉히 두고 크게 그려 줘. 왼쪽부터 (모두 가장 희귀한 특별 장비라 금색과 보라색으로 화려하게): 1) 연쇄 반사 매트릭스: 빛나는 정육면체 결정 1개에서 위쪽으로 굵은 번개 줄기 3개가 나뉘어 뻗음, 보라·청록. 2) 과부하 반응로: 둥글고 묵직한 반응로 코어, 붉게 달아오른 가운데, 둘레에 금속 고리, 위로 짧은 불꽃. 3) 전역 견인 비콘: 굵은 받침 위의 둥근 등대 머리, 둘레로 금색 동심 호(위쪽 절반만) 2줄. 공통: 각 아이콘은 지름이 같은 원 안에 꽉 차게 들어가는 뭉툭하고 묵직한 실루엣이어야 하고, 얇은 막대·가는 선을 쓰지 말고 굵은 형태로만. 아이콘을 가로지르는 대각선 금지, 원 안에 사선이 있는 금지 표지처럼 보이면 안 됨. 금속은 #3c3544 #5c5164 #917487 #a5b29d #fef8e5 범위, 강조색은 #30e1b9 #99e9e6(청록) #f89419 #f6ce50(주황·금) #f25c76(빨강) #a884f3(보라) 중에서만, 아이콘 하나에 8~10색. 바깥쪽 1픽셀 어두운 외곽선(#2b1925), 빛은 왼쪽 위, 밝은 면 하이라이트 1~2픽셀. 큰 픽셀이 또렷한 픽셀 아트(아이콘 하나가 약 48x48 픽셀 격자를 크게 키운 느낌), 그라데이션·안티에일리어싱·디더링 없음. 배경은 단색 마젠타(#FF00FF)만, 그림자·별·글자·숫자·테두리·원형 받침 없음. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

#### `assets/raw/run/icons/icons_g.png`

> 첨부한 픽셀 아트 장비 아이콘(쿨러, 드론)과 똑같은 스타일·같은 색·같은 외곽선으로, 레벨업 카드 아이콘을 2개, 가로 한 줄로 서로 닿지 않게 간격을 넉넉히 두고 크게 그려 줘. 왼쪽부터: 1) 반사 코팅 탄: 아래쪽에 가로로 놓인 굵은 금속판 1장, 그 위에서 둥글고 굵은 탄 1개가 공처럼 통통 튀는 모습. 궤적은 판 위로 볼록한 굵은 청록 아치 2개가 왼쪽에서 오른쪽으로 이어지고, 오른쪽 아치 끝에 탄이 있음. 직선이나 V자 궤적 금지, 체크 표시처럼 보이면 안 됨. 2) 편향 실드 발생기: 위에서 내려다본 작은 회색 우주선 1대(날개 달린 뭉툭한 실루엣)를, 우주선 윤곽을 그대로 따라가는 굵은 금색(#f6ce50) 빛 테두리가 간격을 두고 감싸는 모습, 테두리 위쪽에 흰 반짝임 2픽셀, 왼쪽 위에 작은 금빛 별 조각 1개. 둥근 방어막이나 돔이나 안전모처럼 보이면 안 됨. 공통: 각 아이콘은 지름이 같은 원 안에 꽉 차게 들어가는 뭉툭하고 묵직한 실루엣이어야 하고, 얇은 막대·가는 선을 쓰지 말고 굵은 형태로만. 아이콘을 가로지르는 대각선 금지, 원 안에 사선이 있는 금지 표지처럼 보이면 안 됨. 금속은 #3c3544 #5c5164 #917487 #a5b29d #fef8e5 범위, 강조색은 #30e1b9 #99e9e6(청록) #f89419 #f6ce50(주황·금) #f25c76(빨강) #a884f3(보라) 중에서만, 아이콘 하나에 8~10색. 바깥쪽 1픽셀 어두운 외곽선(#2b1925), 빛은 왼쪽 위, 밝은 면 하이라이트 1~2픽셀. 큰 픽셀이 또렷한 픽셀 아트(아이콘 하나가 약 48x48 픽셀 격자를 크게 키운 느낌), 그라데이션·안티에일리어싱·디더링 없음. 배경은 단색 마젠타(#FF00FF)만, 그림자·별·글자·숫자·테두리·원형 받침 없음. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

#### `assets/raw/run/icons/icons_h.png` (v0.7.0 5단계 3부, 반사 코팅 탄 다시 그림, 1장)

> Pixel art game upgrade icon, single icon centered on solid magenta #FF00FF background, square image. Subject: one thick orange energy bullet that visibly BOUNCES: a chunky bullet travelling diagonally down-right hits a small flat metal deflector plate with a spark at the impact point, then flies away up-right along a sharp V-shaped bent trail; the trail is drawn as a bold 2-segment zigzag with a clear corner at the plate, the outgoing bullet head larger and brighter. It must read at 48x48 pixels as a ricochet, not a wavy line, not a check mark. Style: Foozle Void space pack look, top-left light, dark purple-brown outline #2b1925, limited palette of about 8 colors: orange #f89419, yellow #f6ce50, cream #fef8e5, teal #30e1b9, grey-green #a5b29d, mauve #917487, dark #3c3544. Big chunky pixels, no anti-aliasing, no text, no drop shadow, no frame. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

#### `assets/raw/run/gate_ring.png` (v0.7.0 6단계, 워프 게이트 고리, 1장. `ref_pack_x8.png`, `gate_concept_design.png`를 참고로 넘김)

> Pixel art sprite sheet on solid magenta #FF00FF background, for a top-down space shooter. Use the first attached image only as the style reference for the pixel look (Foozle Void pack: chunky pixels, top-left light, dark outline, muted grey-brown hull metal, small saturated accents) and the second image only for the idea of a mechanical warp gate. Draw one WARP GATE seen from directly above, an original design: a heavy round metal ring built from 8 separate armored segments with small gaps between them, each segment with 1-2 rivets and a thin teal-cyan light strip on its inner edge. The ring is wide: inner hole diameter is 65 percent of the outer diameter. Center of the ring is completely empty magenta. Draw exactly one gate, centered, filling about 80 percent of a square image, perfectly circular and symmetric, lights on. Pixel grid about 68 x 68 units enlarged with nearest neighbour; no anti-aliasing, no gradients, no dithering. Palette only: #2b1925 #3c3544 #5c5164 #917487 #a5b29d #fef8e5 metal, #125952 #30e1b9 #99e9e6 teal, #f6ce50 #f89419 accents. No text, no stars, no shadow, no energy swirl inside. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

### 기지 화면 시안 (v0.7.0 D, 게임에 적용 안 함, 3장. `ref_pack_x8.png`을 참고로 넘김)

#### `assets/raw/base_v070/base_buildings.png`

> Pixel art sprite sheet on solid magenta #FF00FF background, 3/4 top-down view for a space mining outpost on an asteroid. Six separate objects in a 3 by 2 grid with wide spacing, each on a pixel grid of about 96 by 96 units enlarged with nearest neighbour: 1 research lab with a teal glass dome, 2 hangar with a big sliding door, 3 mineral storage silo with a glowing crystal heap, 4 exhibition hall with display windows, 5 drone factory with a crane under construction, 6 round octagonal landing pad with gold hazard ring and center mark, empty. Each building has lit windows and small antennas. Style: Foozle Void space pack look as in the attached reference (fine small pixels, one pixel dark outlines, top-left light, muted metal with small saturated accents). Palette only: #2b1925 #3c3544 #5c5164 #917487 #a5b29d #fef8e5 metal, #625565 #966c6c rock, #125952 #30e1b9 #99e9e6 teal, #f6ce50 #f89419 gold, #a884f3 purple. No anti-aliasing, no gradients, no dithering, no text, no drop shadow. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

#### `assets/raw/base_v070/base_ground.png`

> Pixel art on solid magenta #FF00FF background: one big flat asteroid surface plate seen in 3/4 top-down view, wide oval, rugged rocky edge, small craters, dark muted purple-grey rock, faint metal paths are NOT drawn, no buildings. Fine pixel grid about 480 by 240 units enlarged with nearest neighbour, keep the surface dark and low contrast so buildings stand out. Style: Foozle Void space pack look as in the attached reference (fine small pixels, one pixel dark outlines, top-left light, muted metal with small saturated accents). Palette only: #2b1925 #3c3544 #5c5164 #917487 #a5b29d #fef8e5 metal, #625565 #966c6c rock, #125952 #30e1b9 #99e9e6 teal, #f6ce50 #f89419 gold, #a884f3 purple. No anti-aliasing, no gradients, no dithering, no text, no drop shadow. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

#### `assets/raw/base_v070/base_station.png`

> Pixel art on solid magenta #FF00FF background: one orbital mining station seen from directly above (top-down like a space shooter), pixel grid about 320 by 320 units enlarged with nearest neighbour. A central circular docking hub with an empty landing ring in the middle, and five distinct modules connected by short bridges around it: greenhouse-like research dome, hangar bay, mineral silo with a glowing crystal, exhibition module with windows, drone factory arm with a crane. Solar panels and small antennas. Dark metal with thin teal light strips. Style: Foozle Void space pack look as in the attached reference (fine small pixels, one pixel dark outlines, top-left light, muted metal with small saturated accents). Palette only: #2b1925 #3c3544 #5c5164 #917487 #a5b29d #fef8e5 metal, #625565 #966c6c rock, #125952 #30e1b9 #99e9e6 teal, #f6ce50 #f89419 gold, #a884f3 purple. No anti-aliasing, no gradients, no dithering, no text, no drop shadow. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

### 기지 화면 A' 시안 (v0.7.0, 게임에 적용 안 함, 4장. `assets/raw/run/ref_pack_x8.png`을 참고로 넘김, 새 건물은 `assets/raw/base_v070/base_buildings.png`도 함께)

#### `assets/raw/base_v070b/deck_square.png`

> Pixel art sprite sheet on solid magenta #FF00FF background, 3/4 top-down view, parts for a mining space station built on top of an asteroid. Six separate objects in a 3 by 2 grid with wide spacing, all magenta between them, each on a pixel grid of about 128 by 96 units enlarged with nearest neighbour: 1 one rectangular dark metal deck plate with bolted panel seams, rivets, thin teal light strips on two edges and a visible thick front lip below it so it looks like a raised platform; 2 the same rectangular deck plate marked as an empty construction slot: darker, thick gold and dark hazard stripes around its border, four small scaffold posts at the corners, nothing built on it; 3 a short horizontal enclosed walkway bridge with small lit windows and two thin pipes along its side, wider than tall; 4 a short vertical enclosed walkway bridge seen in 3/4 view with a lit stripe and a pipe beside it, taller than wide; 5 the same rectangular deck plate with a recessed octagonal socket and eight small round guide-light recesses around it for a landing pad; 6 a narrow straight metal railing and pipe rack piece for a deck edge. Plates must have straight edges so they can sit next to each other like tiles. Keep the deck surface dark and low contrast so buildings stand out. Style: Foozle Void space pack look as in the attached reference (fine small pixels, one pixel dark outlines, top-left light, muted metal with small saturated accents). Palette only: #2b1925 #3c3544 #5c5164 #917487 #a5b29d #fef8e5 metal, #625565 #966c6c rock, #125952 #30e1b9 #99e9e6 teal, #f6ce50 #f89419 gold, #a884f3 purple. No anti-aliasing, no gradients, no dithering, no text, no drop shadow. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

#### `assets/raw/base_v070b/deck_hex.png`

> Pixel art sprite sheet on solid magenta #FF00FF background, 3/4 top-down view, parts for a mining space station built on top of an asteroid. Six separate objects in a 3 by 2 grid with wide spacing, all magenta between them, each on a pixel grid of about 128 by 96 units enlarged with nearest neighbour: 1 one flat-top hexagonal dark metal deck module, squashed vertically for 3/4 view, with radial panel seams, rivets, thin teal light strips along edges and a visible thick front lip below its lower edges so it looks like a raised platform; 2 the same hexagonal module marked as an empty construction slot: darker, gold and dark hazard stripes around its border, small scaffold posts at the corners, nothing built on it; 3 a short straight enclosed walkway bridge running left to right with small lit windows and a thin pipe; 4 the same short enclosed walkway bridge running diagonally from lower left to upper right; 5 the same hexagonal module with a recessed octagonal socket and eight small round guide-light recesses around it for a landing pad; 6 the same short enclosed walkway bridge running diagonally from upper left to lower right. All hexagons identical in size and regular so they can sit next to each other like honeycomb tiles. Keep the deck surface dark and low contrast so buildings stand out. Style: Foozle Void space pack look as in the attached reference (fine small pixels, one pixel dark outlines, top-left light, muted metal with small saturated accents). Palette only: #2b1925 #3c3544 #5c5164 #917487 #a5b29d #fef8e5 metal, #625565 #966c6c rock, #125952 #30e1b9 #99e9e6 teal, #f6ce50 #f89419 gold, #a884f3 purple. No anti-aliasing, no gradients, no dithering, no text, no drop shadow. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

#### `assets/raw/base_v070b/station_props.png`

> Pixel art sprite sheet on solid magenta #FF00FF background, 3/4 top-down view, small props for a mining space station built on an asteroid. Eight separate objects in a 4 by 2 grid with wide spacing, all magenta between them, each on a pixel grid of about 64 by 64 units enlarged with nearest neighbour: 1 tall thin antenna mast with crossbars and a small lit tip; 2 satellite radar dish on a short base; 3 tilted solar panel array, dark blue-teal cells in a metal frame on a stand; 4 warning beacon: short post with a big orange lamp, lit; 5 the same warning beacon with the lamp dark and off; 6 small landing guide light: low metal stud with a teal lens, lit; 7 the same guide light dark and off; 8 pair of round fuel tanks with connecting pipes and a valve. Style: Foozle Void space pack look as in the attached reference (fine small pixels, one pixel dark outlines, top-left light, muted metal with small saturated accents). Palette only: #2b1925 #3c3544 #5c5164 #917487 #a5b29d #fef8e5 metal, #625565 #966c6c rock, #125952 #30e1b9 #99e9e6 teal, #f6ce50 #f89419 gold, #a884f3 purple. No anti-aliasing, no gradients, no dithering, no text, no drop shadow. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

#### `assets/raw/base_v070b/base_buildings2.png`

> Pixel art sprite sheet on solid magenta #FF00FF background, 3/4 top-down view for a space mining outpost on an asteroid. Exactly the same building style, scale and colours as the second attached image. Three separate buildings in a 3 by 1 row with wide spacing, each on a pixel grid of about 96 by 96 units enlarged with nearest neighbour: 1 sub-weapon research lab with a small test turret on the roof and a gold-striped firing bay; 2 evolution archive laboratory with three tall glass tanks holding glowing purple and teal specimens; 3 planetary control centre with a tall tower, a big radar dish and a lit teal planet display window. Each building has lit windows and small antennas. Style: Foozle Void space pack look as in the attached reference (fine small pixels, one pixel dark outlines, top-left light, muted metal with small saturated accents). Palette only: #2b1925 #3c3544 #5c5164 #917487 #a5b29d #fef8e5 metal, #625565 #966c6c rock, #125952 #30e1b9 #99e9e6 teal, #f6ce50 #f89419 gold, #a884f3 purple. No anti-aliasing, no gradients, no dithering, no text, no drop shadow. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

### 기지 건물 종류 표식 (v0.7.0, 게임에 적용 안 함, 1장. `assets/raw/run/ref_pack_x8.png`을 참고로 넘김)

#### `assets/raw/base_v070c/base_icons.png`

> Pixel art icon sheet on solid magenta #FF00FF background, same colour feel as the attached pack. Nine separate small flat UI icons in an exact 3 by 3 grid with very wide spacing, all magenta between them, each icon drawn on a very coarse pixel grid of only 16 by 16 units enlarged with nearest neighbour, chunky bold silhouette, readable at tiny size, at most 3 flat colours per icon, 1 unit thick dark outline, no text, no letters, no background plate, no gradients, no anti-aliasing. Icons in order: 1 research flask in pale teal (science lab); 2 hangar gate with two doors in pale grey-white; 3 small quadcopter drone in pale orange; 4 crate with a crystal on top in gold (mineral storage); 5 picture frame with a star in pale cream (exhibition hall); 6 small missile pointing up in soft red (sub-weapon lab); 7 double helix DNA in light purple (evolution lab); 8 ringed planet in light blue (planet control); 9 wrench crossed with a plus sign in amber (build site). 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

### 기지 착륙장 (v0.7.0, 1장. `assets/raw/base_v070b/deck_square.png`을 참고로 넘김)

#### `assets/raw/base_v070d/station_pad.png`

> Pixel art game asset sheet in the exact same style, palette, outline and 3/4 top-down view as the attached deck sheet (dark purple-grey riveted metal, black outline, top-left light). Solid flat magenta #FF00FF background, nothing else on the background. Three separate objects side by side with wide magenta gaps, no text, no labels, no shadows on the background: 1) LEFT, the largest: one long portrait rectangular landing deck slab, about 1 wide by 2 tall, same riveted metal plate and same thick front lip as the attached deck plates. In its exact centre the same octagonal landing ring as the attached pad. Between the top edge and the ring, and between the ring and the bottom edge, one straight vertical row of small dark round light sockets. Leave the upper third and lower third of the slab otherwise calm and empty. No fence, no posts, no railings, no corner pillars, no stripes. 2) MIDDLE: a small airport-style control tower, 3/4 view: short metal base, slim mast, wide glass cab on top with teal-lit windows, small antenna. Width about one quarter of the slab. 3) RIGHT: a compact fuel station seen 3/4: two short horizontal grey fuel pipes with an amber valve wheel running into one small round tank. Width about one quarter of the slab. Crisp hard pixels, no anti-aliasing, no gradients, no dithering. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마

### 착륙장 화물 컨테이너 (v0.7.0, 1장. `assets/raw/base_v070b/station_props.png`을 참고로 넘김)

#### `assets/raw/base_v070d/cargo.png`

> Generate one image: a single small sci-fi cargo crate stack for a pixel-art space station landing pad, in exactly the same style as the attached prop sheet (3/4 top-down view, chunky dark outline, muted grey-green metal with one small orange latch accent, no text). Two stacked metal containers, compact, wider than tall. Centered on a solid flat magenta #FF00FF background with no shadow on the background, no other objects. 내장 이미지 생성 도구만 사용하고, 스크립트를 만들거나 API를 호출하지 마
