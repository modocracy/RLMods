# 2026-10-19 구현 및 차단 기록

**아래는 이전 0.1.1 기록입니다.** Bingus와 공존하도록 변경한 최신 0.1.2는
[COEXISTENCE.md](COEXISTENCE.md)를 보세요. 아래 0.1.1 Wwise 패치를 새 버전과
함께 활성화하지 마세요. 이전 파일과 그 해시는 이력으로만 보존합니다.

요청한 전체 로드아웃 모드는 **미완성**입니다. 실제 원본 콜백을 포함하는
독립 실험 패치를 컴파일·패키징했지만, 기능 범위는 스트라타젬 부분 구현입니다.
게임과 모드 코드를 실행하거나 테스트하지 않았습니다.

## 이번에 실제로 수행한 작업

- README, 문서, Lua 소스 8개, 패키징 소스를 읽었습니다. 시작 시점의 파일
  20개가 전달된 SOURCE-MANIFEST.json 해시와 모두 같았습니다. Git 이력은
  없었고, 기존 파일을 보존한 채 로컬 Git 메타데이터만 초기화했습니다.
- Steam 설치 경로 레지스트리, libraryfolders.vdf, 앱 553850 manifest에서
  설치 위치와 빌드 `25480438`을 확인했습니다. 계정 정보·인증 정보는 읽지 않았습니다.
- 설치 원본 PE 두 개의 헤더·섹션·해시·기존 시그니처를 정적으로 조사했습니다.
  재현 도구는 `tools/inspect_native.py`, 결과는
  `research/installed-build-25480438.json`입니다. 원본 바이트는 보고서에 포함하지 않습니다.
- 공식 Filediver v0.7.61로 `core/wwise/lua/wwise_flow_callbacks`를
  vanilla `9ba626afa44a3aa3` 아카이브에서 추출했습니다. 배포된 모드 패치를
  원본으로 사용하지 않습니다. DSAR/NXA 빌드를 `--filediver`로 연결했습니다.
- `--compiler-dll` 컴파일 백엔드를 구현했습니다. 소유한 `bin/lua51.dll`의
  정확한 SHA-256만 허용하고, 별도 Python 프로세스에서 텍스트를 컴파일한 뒤
  native `string.dump`로 직렬화합니다. 입력 함수는 실행하지 않습니다.
- 기존 독립 래퍼의 원본 호출·인자/반환값 보존 구조를 유지해 원본 바이트코드와
  모드 소스를 하나의 리소스로 컴파일했습니다. 해당 보존 동작을 실행 검증하지는 않았습니다.
- `src/platform.lua`의 `condition and false or ...` 버그를 고쳤습니다.
  기존 표현식은 `??`도 숫자로 해석하려다 오류를 내므로 와일드카드 분기를 분리했습니다.
- `src/stratagems.lua`에서 이미 장착했다는 이유만으로 기본 선택 목록의
  제한을 무시하던 경로를 제거했습니다. 모든 후보에 실제 selectable offer와
  소유권 증거를 요구하고, 같은 장비의 여러 offer 중 적격 항목을 찾습니다.
- picker 열기를 오류 처리 범위에 포함하고, 오류가 나도 같은 화면에서만
  picker 닫기와 이전 포커스 복원을 시도하도록 했습니다. 네이티브 접근 위반은
  Lua pcall로 복구된다고 가정하지 않습니다.

## 확보한 설치 입력

설치 루트: `C:\Program Files (x86)\Steam\steamapps\common\Helldivers 2`

| 파일/리소스 | 실제 관측 |
| --- | --- |
| `data/game/game.dll` | 15,522,408 bytes, 파일 버전 1.0.0.19155, PE timestamp 0x6AB3B43F |
| `bin/helldivers2.exe` | 14,957,160 bytes, 파일 버전 1.8.46015.0, PE timestamp 0x6AB382E4 |
| 원본 Wwise `.lua.main` | 10,271 bytes; 8바이트 envelope + 10,263바이트 bytecode; 헤더 `1b 4c 4a 02 02` |
| 원본 callback SHA-256 | `05bbf52978028758b39f5b91a30a695d20069ceabd774d88755f0582a296bec9` |
| `lua51.dll` compiler SHA-256 | `2c8720c9f446c848436ad993b1a88099d76f0b0b09df53689719b797c3039ce7` |
| Filediver CLI SHA-256 | `c661b5d7cc5325eecd4103b3d053e729f92bafdc09f409ab6b0ced33fddd31b4` |

Steam manifest와 두 파일을 같은 설치에서 읽었지만, Steam 무결성 검사나
원본 재다운로드는 하지 않았습니다. 원본은 읽기 전용으로 열었습니다.

## 전체 구현의 정확한 차단 원인

두 PE에는 `.winlice`, `.boot`, `.vm_sec` 섹션이 있고, 첫 코드 섹션의
가상 크기가 디스크 크기보다 훨씬 큽니다. `game.dll`의 해당 섹션은
RVA `0x1000`, virtual size `0x210FA93`, raw size `0x850800`입니다.
기존 네이티브 시그니처 13개의 후보 RVA는 모두 해당 섹션의 raw bytes
범위 밖입니다. 파일 전체에서도 이 13개 패턴은 각각 0건이었습니다.
따라서 디스크 원본을 런타임 메모리 이미지처럼 읽어 디스어셈블할 수 없습니다.
이는 **실행 시 시그니처가 불일치한다는 증거가 아닙니다**. 실행 중 확인은 하지 않았습니다.

Filediver가 나열한 기본 Lua 리소스 10개에도 loadout/equipment/booster/
Hellpod/armory/menu 선택 스크립트는 없었습니다. 리소스 목록만으로 임의의
native equip API나 UI 등록 함수를 만들어낼 수는 없습니다.

| 요구 기능 | 현재 결과와 남은 근거 |
| --- | --- |
| 스트라타젬 4칸 | 기존 외부 ABI 근거 기반 코드 + 위 버그 수정. 실제 native 선택·저장·임무 제한 동작 미검증 |
| 헬멧·방어구·망토 | 이전 문서에 후보 actor setter 정보는 있지만, pre-mission 적용·저장·카드 갱신 전체 경로 미확정 |
| 주무기·보조무기·수류탄 | category/offer 매핑, 임무 가용성 및 실제 선택·저장 ABI 미확정 |
| 부스터 | 본인 소유/임무 가용성, 팀 중복 제한, 선택·동기화 트랜잭션 미확정 |
| 전체 랜덤 | 비활성. 호출하면 false/설명 반환, 일부만 바꾸지 않음 |
| 버튼 | 기존 Stingray 오버레이. 정식 메뉴 widget 등록·native focus·컨트롤러 탐색 미구현 |

다음 구현에는 동일 빌드의 분석 가능한 코드 이미지 또는 확인 가능한 native
선택 경로 소스가 필요합니다. 현재 지시 아래에서는 이를 얻기 위한 게임 실행,
런타임 덤프, 디버거 부착, 보호 우회는 하지 않습니다. 이미 확보한 설치 경로를
다시 받는 것으로 해결되는 문제가 아닙니다. 소유권·해금 상태도 변경하지 않습니다.

현재 picker의 제한을 엄격히 따르면 이미 선택한 장비가 목록에서 제외되거나
차량 제한 때문에 후보가 부족할 수 있습니다. 이 경우 네 칸 변경을 거부합니다.
제한을 해제하거나 비어 있는 슬롯을 억지로 채우지 않습니다. 이 동작도 미실행입니다.

## 실제 생성 파일

- `dist/RLMmods-0.1.1-stratagems-private-untested.zip`: **36,863 bytes**.
  원본 callback을 포함한 설치용 형식의 실험 패치. 설치와 게임 동작은 미검증.
  전체 로드아웃 모드 완성본이 아니며 **공개 배포 금지**.
  SHA-256: `30f76a0b75b60f6a91de643057b8085d5e9970718728ab5192ae57f64e38b7db`.
- ZIP의 실제 patch: `data/9ba626afa44a3aa3.patch_0`, **43,040 bytes**.
  `.stream`, `.gpu_resources`는 각각 0 bytes입니다.
- `RLMmods-build.json`에는 원본/컴파일 결과/소스/컴파일러 해시와
  `runtime_verified=false`, `tests_run=false`, `game_executed=false`,
  `mod_manager_verified=false`, `randomize_all_available=false`가 기록됩니다.
- 분석 중 추출한 private 원본은 `.work/extracted/core/wwise/lua/wwise_flow_callbacks.lua.main`입니다.
  `.work/`는 `.git/info/exclude`에 등록했습니다. 제품 코드와 정식 문서는 제외하지 않습니다.
- `dist/RLMmods-0.1.1-source.zip`은 별도의 소스 배포물입니다. `.work/`, 원본
  리소스, DLL/EXE, `dist/`, patch 파일을 포함하지 않으며 설치 파일이 아닙니다.

## 설치·제거·충돌

1. 게임을 종료하고, 하나의 HD2MM/Arsenal 모드 매니저에서 **private patch ZIP**을
   가져온 뒤 활성화·Deploy합니다. 이 작업에서는 설치하지 않았으며 import도 미검증입니다.
2. 이 패치는 `core/wwise/lua/wwise_flow_callbacks`를 단독으로 소유합니다.
   Bingus Shared Loader나 같은 리소스를 교체하는 다른 standalone/overlay 모드와
   함께 활성화하지 마세요. 파일명이 달라도 같은 리소스라면 충돌하며 자동 병합하지 않습니다.
3. 제거는 게임 종료 → 동일 매니저에서 비활성화 → Purge/Deploy입니다.
   수동 설치와 매니저 배포를 섞거나 원본 아카이브를 덮어쓰지 마세요.
4. 게임 업데이트 후에는 기존 빌드를 비활성화하고 새 버전의 근거부터 다시 조사해야 합니다.

## 수행하지 않은 검증과 Git 상태

게임 실행, 실제 버튼 클릭, 런타임 메모리/ABI 확인, 해금·임무 제한의 실제 동작,
팀 부스터 동기화, 네트워크/멀티플레이, 원본 callback 실행 결과, 설치/제거,
unit/integration tests, CI, 별도 테스트·실행 검증을 수행하지 않았습니다.
컴파일 성공을 이 항목들의 검증 통과로 표현하지 않습니다.

시작 폴더에 `.git`이 없어 변경 전 이력이 없습니다. 원본 파일들은 시작 manifest와
비교했으며 보존했습니다. 테스트를 생략한 이번 결과를 검증 완료 변경으로
커밋하지 않았습니다. GitHub 저장소 생성·원격 쓰기·push도 하지 않았습니다.
