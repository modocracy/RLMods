# RLMmods

**헬다이버즈 2 헬포드 로드아웃 화면에 저장 · 불러오기 · 랜덤 버튼을 추가하는 모드입니다.**

[English](README.md) · [다운로드 (Releases)](https://github.com/modocracy/RLMods/releases)

> Uses research from HD2Runtime by SkyeShade — https://github.com/SkyeShade/HD2Runtime

## 기능

| 버튼 | 동작 |
| --- | --- |
| **저장** | 지금 장착한 스트라타젬 4칸, 부스터, 헬멧·방어구·망토, 주무기·보조무기·수류탄을 저장합니다. |
| **불러오기** | 저장한 구성으로 되돌립니다. 이미 같은 칸은 그대로 두고, 지금 고를 수 없는 장비(임무 제한, 팀원이 쓰는 부스터, 미보유)는 그 칸만 건너뜁니다. |
| **랜덤** | 게임이 선택 가능으로 보여 주는 장비 중에서 무작위로 고릅니다. |

랜덤 규칙:

- 스트라타젬 4칸에 배낭류·차량(엑소수트·FRV·탱크)·지원무기는 **각각 최대 1개**.
- 부스터는 '미선택'과 팀원이 이미 가져온 부스터를 고르지 않습니다.
- 헬멧·방어구·망토·주무기·보조무기·수류탄도 함께 바뀝니다.

모든 동작이 게임 자체의 목록과 장착 과정을 거치므로, 잠긴 장비·임무 제한·팀 규칙이 그대로 지켜집니다.
불러오기에는 랜덤 전용 규칙을 적용하지 않고, 게임 자체 규칙(메크·FRV·탱크 각 1개)만 따릅니다.

## 조작

버튼은 내 플레이어 카드 오른쪽에 있고, **장비구성 탭**이 열릴 때 카드와 함께 나타납니다(드랍 위치를 고를 때는 숨김).

- **마우스:** 버튼 클릭
- **키보드·패드:** **R 장비** 막대까지 올라간 뒤 **↑**를 한 번 더 누르면 랜덤 버튼으로 이동합니다. **↑↓**로 버튼 사이를 이동하고 **선택키**로 실행합니다. 랜덤에서 **↓**를 누르거나 **←·→·뒤로**를 누르면 막대로 돌아갑니다.

## 설치

1. 게임을 종료합니다.
2. **HD2MM** 또는 **Arsenal**에서 예전 RLMmods를 모두 끕니다.
3. [Releases](https://github.com/modocracy/RLMods/releases)에서 `RLMmods-1.0.0.zip`을 받아 가져오고, 활성화한 뒤 **Deploy**합니다.

제거: 게임 종료 → 같은 매니저에서 RLMmods 끄기 → Purge/Deploy.

## 호환성

- **게임 빌드 25480438 전용입니다.** 다른 빌드에서는 아무 기능도 켜지 않고 게임은 정상 실행됩니다. 게임이 업데이트되면 **새 버전이 나올 때까지 RLMmods를 꺼 두세요.**
- 게임의 `boot.lua`를 교체하므로 **`boot.lua`를 교체하는 다른 모드와 함께 쓸 수 없습니다.** Bingus Shared Loader는 함께 써도 됩니다.
- 멀티플레이와 출격 후 동작은 로드아웃 화면보다 덜 확인됐습니다. 문제가 있으면 로그와 함께 알려 주세요.

## PC에 남는 파일

| 경로 | 용도 |
| --- | --- |
| `%LOCALAPPDATA%\RLMmods\loadout-1.txt` | 저장한 로드아웃(1칸, 내 PC에만 저장) |
| `%LOCALAPPDATA%\RLMmods\RLMmods.log` | 동작 기록. 1MiB를 넘으면 `RLMmods.old.log`로 넘깁니다 |

어디로도 데이터를 보내지 않고, 안티치트를 우회하거나 장비를 해금하지 않습니다. 사용에 따른 책임은 사용자에게 있습니다.

## 출처

- **HD2Runtime by SkyeShade** — https://github.com/SkyeShade/HD2Runtime : 스트라타젬 분류·배낭 지원무기 목록, 소유 판정 규칙, 메뉴 입력 구조
- **[Alomare/FlexibleLoadouts](https://github.com/Alomare/FlexibleLoadouts)** (GPL-3.0-or-later): 로드아웃 화면 명령어 시그니처
- **[SHODAN-HORAI/SHODAN-Stat-Editor](https://github.com/SHODAN-HORAI/SHODAN-Stat-Editor)** (GPL-3.0): 게임 GUI·글꼴 사용법
- **[tyrypyrking/HD2-Transmog](https://github.com/tyrypyrking/HD2-Transmog)**: 진행도(소유) 표 구조
- 그 밖의 내용은 이 프로젝트가 직접 분석한 결과이며 [docs](docs/)에 기록되어 있습니다.

## 라이선스와 소스

GPL-3.0-or-later ([LICENSE](LICENSE)). 릴리즈 파일에는 게임 바이트코드나 게임 기계어가 들어 있지 않으며, 게임 코드 확인은 지문으로 합니다.
빌드 방법: [docs/PACKAGING.md](docs/PACKAGING.md) · 변경 기록: [CHANGELOG.md](CHANGELOG.md)

Helldivers 2는 Sony Interactive Entertainment / Arrowhead Game Studios의 상표입니다. RLMmods는 비공식 팬 프로젝트이며 이들과 관련이 없습니다.
