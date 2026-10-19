# Bingus 공존 변경 — RLMmods 0.1.2

기존 Wwise 리소스 충돌을 제거했습니다. **Bingus를 설치하거나 의존하지
않으면서, 설치돼 있으면 원래 초기화 경로를 그대로 실행하는 구조**입니다.
컴파일·패키징과 리소스 테이블 분석은 수행했지만 실제 게임 공존은 미검증입니다.

## 지금 사용할 파일과 교체 순서

`dist/RLMmods-0.1.2-bingus-coexist-private-untested.zip`

1. 게임을 종료합니다.
2. 모드 매니저에서 **기존 RLMmods 0.1.1을 비활성화/제거**하고 Purge/Deploy하여
   기존 Wwise 교체 파일을 제거합니다. 새 파일을 추가하는 것만으로는 해결되지 않습니다.
3. 새 0.1.2 ZIP을 가져와 활성화·배포합니다. 다른 모드에 필요한 Bingus는 유지합니다.
4. `boot.lua`를 교체하는 다른 모드와는 함께 사용하지 않습니다. HUD+도 boot를
   교체하는 버전이면 해당합니다. 모든 모드와의 무조건 호환을 뜻하지 않습니다.

이번 작업에서는 이 설치/제거 과정을 실행하지 않았습니다. 직접 파일을 복사해
동일한 `.patch_0`를 덮어쓰지 말고 매니저가 별도 patch 번호로 배포하도록 하세요.
제거할 때는 게임 종료 후 동일 매니저에서 RLMmods를 끄고 Purge/Deploy합니다.
Bingus 자체는 제거할 필요가 없습니다.

## 실제 바뀐 구조

| 구분 | 기존 0.1.1 | 새 0.1.2 |
| --- | --- | --- |
| 교체 리소스 | `core/wwise/lua/wwise_flow_callbacks` | `boot` |
| Bingus와 리소스 중복 | 있음 | 없음 |
| 시작 시점 | Wwise 원본 실행 직후 | 원본 boot의 `init` 실행 완료 후 |
| Bingus 필수 여부 | 필수 아님 | 필수 아님 |
| 다른 boot 교체 모드 | 별도 문제 | 같은 리소스를 교체하므로 충돌 |
| 실제 공존 실행 검증 | 안 함 | 안 함 |

원본 boot가 만든 init를 보존하고 감쌉니다. 엔진이 init를 호출하면 원래 init를
먼저 호출하며, 이 안의 Wwise require가 평소처럼 동작합니다. Bingus가 있으면
그 로더와 addon들이 먼저 초기화되고, 없으면 원본 Wwise 콜백이 초기화됩니다.
그 다음 RLMmods가 한 번 초기화되며 **그 시점의 update/shutdown 함수들을
보존해서 이어 호출**합니다. Bingus 상태를 사칭하거나 로더 코드를 복사하지 않습니다.

원본 boot와 init의 인자 및 nil을 포함한 반환값 묶음을 그대로 전달합니다.
원본 오류는 재시도 없이 전달하고, RLMmods 초기화만 pcall로 격리합니다.
기존 update/render/shutdown을 빈 함수로 덮어쓰지 않습니다. 코드 수준의 보존
구조를 작성한 것이며 콜백 동작을 실행 검증한 것은 아닙니다.

## 확인한 실제 근거

- 같은 설치 빌드 `25480438`에서 Filediver로 vanilla `boot.lua.main`을 추출했습니다.
  원본 파일은 변경하지 않았고, 추출본은 `.work/coexist-inputs/boot.lua.main`에 있습니다.
- 크기는 334바이트: envelope 8바이트 + LuaJIT bytecode 326바이트입니다.
  SHA-256: `85d7c6a9981e3288286c63bdb75e4256dcf859d6fc5f712cb72e9b329b1712e6`.
- 실행 없이 bytecode prototype/상수/명령을 읽었습니다. 루트의 첫 함수 할당은
  `init` → 첫 prototype이고, 그 함수의 상수는 `require` 및
  `core/wwise/lua/wwise_flow_callbacks`입니다. 명령은 global 읽기 → 문자열
  로드 → 호출 → 반환입니다. 루트는 shutdown/update/render도 별도로 정의합니다.
  따라서 boot chunk 직후가 아니라 **원래 init 호출 이후**에 모드를 시작합니다.
- Bingus의 검토한 revision은 `9471bcb16f3a479efdff3e0520def4573ae0a028`
  (v20)입니다. 그 [시작 계약](https://github.com/CowboyBingus/BingusSharedLoader/blob/9471bcb16f3a479efdff3e0520def4573ae0a028/docs/TECHNICAL.md)과
  [빌드 코드](https://github.com/CowboyBingus/BingusSharedLoader/blob/9471bcb16f3a479efdff3e0520def4573ae0a028/scripts/build.py)는
  Wwise 리소스만 소유하고 boot는 소유하지 않습니다. 기존 출처/라이선스를 유지했습니다.
- 새 아카이브 테이블의 리소스는 **1개**, boot name hash
  `0xF476DF93691895FA`, Lua type hash `0xA14E8DFA2CD117E2`입니다.
  Bingus Wwise hash `0x7251FDD9BB62480A`는 포함하지 않습니다.
  [패키지 메타데이터](../../research/coexist-package-0.1.2.json)에 기록했습니다.
- 빌더는 정확한 원본 boot 해시만 허용합니다. Wwise 원본이나 다른 모드의
  boot를 잘못 입력해 패키징하지 못하도록 제한했습니다.

## 산출물과 확인 범위

- private patch ZIP: 34,329바이트.
  SHA-256: `5925605fad5bbb5e38c34fc484f922752b181bb3b02e78d77d610bd6eb549d3e`.
- 내부 `data/9ba626afa44a3aa3.patch_0`: 33,440바이트. Lua main resource는
  33,233바이트이고 stream/GPU 동반 파일은 비어 있습니다.
- `RLMmods-build.json`의 `startup`에는 boot-only, after-original-init,
  Bingus 리소스 미포함, Bingus 런타임 의존 없음, 공존 실행 미검증을 기록했습니다.
- `dist/RLMmods-0.1.2-source.zip`은 별도의 소스 ZIP이며 설치 파일이 아닙니다.
- 원본 boot를 포함한 private patch는 공개 저장소에 올리지 마세요.

게임 실행, 테스트, 매니저 import/설치/제거, 콜백 실행 검증, Bingus와의 실제
동시 실행, 장비 선택 동작 검증은 모두 건너뛰었습니다. 설치된 Bingus 패키지
버전을 직접 판독한 것도 아닙니다. 검토한 소스의 리소스 경계와 새 패키지의
실제 테이블이 겹치지 않는다는 결과입니다. 후속 모드가 콜백을 전달하지 않고
덮어쓰는 경우나 다른 boot 교체 패키지는 여전히 충돌할 수 있습니다.

스트라타젬 부분 구현과 엔진 오버레이만 유지됩니다. 전체 장비·부스터·정식
메뉴 버튼 구현은 이번 변경에 포함되지 않았으며 전체 랜덤은 여전히 비활성입니다.
Git은 이전과 같이 기준 커밋 없는 상태이고, 테스트/실행 검증을 생략했으므로
이번 변경을 검증 완료 변경으로 커밋하지 않았습니다. 원격 쓰기도 하지 않았습니다.
