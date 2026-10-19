# RLMmods — Randomize Loadouts

**헬다이버즈 2 출격 로드아웃을 버튼 한 번에 랜덤으로 짜 주는 모드입니다.**

[다운로드 (Releases)](https://github.com/modocracy/RLMods/releases) · [English](README.en.md)

> Uses research from HD2Runtime by SkyeShade — https://github.com/SkyeShade/HD2Runtime

## 기능

**랜덤:** 스트라타젬 4칸, 부스터, 헬멧·방어구·망토, 주무기·보조무기·수류탄을 한 번에 무작위로 바꿉니다.

- 지금 고를 수 있는 장비 중에서만 고릅니다(해금·임무 제한 그대로).
- 스트라타젬: 배낭류·차량(엑소수트·FRV·탱크)·지원무기 **각각 최대 1개**.
- 부스터: '미선택'과 팀원이 이미 가져온 부스터는 제외.

**저장 / 불러오기 (보조):** 평소 구성을 1칸 저장해 두고 한 번에 되돌립니다. 지금 고를 수 없는 칸만 건너뜁니다.

## 조작

버튼은 **장비구성 탭**에서 내 카드 오른쪽에 나타납니다.

- **마우스:** 클릭
- **키보드·패드:** **R 장비** 막대에서 **↑** → 버튼 선택, **↑↓** 이동, **선택키** 실행. **↓·←·→·뒤로**로 돌아갑니다.

## 설치

1. 게임 종료
2. **HD2MM** 또는 **Arsenal**에서 예전 RLMmods 끄기
3. [Releases](https://github.com/modocracy/RLMods/releases)의 `RLMmods-1.0.0.zip` 가져오기 → 활성화 → **Deploy**

제거: 게임 종료 → RLMmods 끄기 → Purge/Deploy

## 주의

- **게임 빌드 25480438 전용.** 다른 빌드에서는 스스로 꺼지고 게임은 정상 실행됩니다. 게임 업데이트 후엔 새 버전까지 꺼 두세요.
- `boot.lua`를 교체하는 다른 모드와 함께 쓸 수 없습니다. Bingus Shared Loader는 괜찮습니다.
- 해금·안티치트 우회 없음, 외부 전송 없음. 사용 책임은 본인에게 있습니다.
- 멀티플레이는 덜 테스트됐습니다. 문제가 있으면 `%LOCALAPPDATA%\RLMmods\RLMmods.log`와 함께 알려 주세요.

저장 파일: `%LOCALAPPDATA%\RLMmods\loadout-1.txt` (내 PC에만 저장)

## 출처

- **HD2Runtime by SkyeShade** — https://github.com/SkyeShade/HD2Runtime : 스트라타젬 분류·배낭 지원무기 목록, 소유 판정 규칙, 메뉴 입력 구조
- **[Alomare/FlexibleLoadouts](https://github.com/Alomare/FlexibleLoadouts)** (GPL-3.0-or-later): 로드아웃 화면 명령어 시그니처
- **[SHODAN-HORAI/SHODAN-Stat-Editor](https://github.com/SHODAN-HORAI/SHODAN-Stat-Editor)** (GPL-3.0): 게임 GUI·글꼴 사용법
- **[tyrypyrking/HD2-Transmog](https://github.com/tyrypyrking/HD2-Transmog)**: 진행도(소유) 표 구조
- 그 밖의 내용은 이 프로젝트의 직접 분석이며 [docs](docs/)에 기록되어 있습니다.

## 라이선스

GPL-3.0-or-later ([LICENSE](LICENSE)). 릴리즈 파일에는 게임 바이트코드·기계어가 들어 있지 않습니다.
빌드 방법: [docs/PACKAGING.md](docs/PACKAGING.md) · 변경 기록: [CHANGELOG.md](CHANGELOG.md)

Helldivers 2는 Sony Interactive Entertainment / Arrowhead Game Studios의 상표입니다. RLMmods는 비공식 팬 프로젝트이며 이들과 관련이 없습니다.
