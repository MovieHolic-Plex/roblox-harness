# roblox-harness

[English](README.md) · **한국어**

Roblox용 선언형 생성 하네스입니다 (strict Luau). 스테이지 조각이나 블록형 R15 캐릭터를 테이블(또는 JSON)로
적으면, 검증을 거친 결정적(deterministic) 인스턴스 트리를 만들어 줍니다. Studio, 런타임, 그리고
[Lune](https://lune-org.github.io/docs)(헤드리스: CI, `.rbxm` 내보내기) 어디서든 같은 코드로 돌아갑니다.

![Roblox Studio에서 렌더링한 캐릭터 라인업](docs/img/lineup_front.png)

| 하네스 | 만드는 것 |
| --- | --- |
| `Harness.Object` | 파트, 웨지, 플랫폼(테두리 포함), 트러스 기둥, 오를 수 있는 밧줄, 사다리, 계단, 중첩 모델, 배열, 시드 기반 흩뿌리기, 프리팹. 색, 재질, 고정(Anchored), `WeldConstraint`, 피벗, 속성, 태그 지원 |
| `Harness.Character` | 블록형 R15 리그(파트 15개 + 루트, 표준 `Motor6D` 이름)와 외형: 얼굴, 머리, 옷, 액세서리, 무기, 자유 조각. 전부 해당 부위에 용접 |
| `Harness.Anim` | 키프레임 애니메이션 작성 도구: 검증, 순수 샘플링, 리그 포즈 적용, 좌우 반전, 마커가 들어간 `KeyframeSequence` 생성 |

## 설치

* **Rojo:** 프로젝트 트리에 `src/Harness`를 넣습니다 (예: `ReplicatedStorage.Harness`).
* **모델 파일:** `rojo build default.project.json -o Harness.rbxm` 후 Studio로 끌어다 놓기.

툴 버전은 `aftman.toml`에 고정되어 있습니다 (`aftman install`).

## 오브젝트 하네스

```lua
local Harness = require(game.ReplicatedStorage.Harness)
local tower = Harness.Object.build({
	name = "JumpTower",
	seed = 7, -- 모든 scatter의 시드. 시드가 같으면 배치도 같음
	prefabs = { Ledge = { kind = "platform", size = { 6, 1, 6 }, color = "#7a5c3a", material = "WoodPlanks", trim = 1 } },
	children = {
		{ kind = "part", name = "Base", size = { 24, 2, 24 }, pos = { 0, 1, 0 }, color = "grass", material = "Grass" },
		{ kind = "array", count = 8, offset = { 0, 4.5, 0 }, rotStep = { 0, 45, 0 }, item = { kind = "use", prefab = "Ledge", pos = { 7, 4, 0 } } },
		{ kind = "truss", height = 14, pos = { -4, 2, -6 } },
		{ kind = "rope", length = 12, segments = 6, pos = { 6, 40, 6 } }, -- pos에서 아래로 늘어짐
	},
}, workspace, { origin = CFrame.new(0, 0, 0) })
```

종류(kind): `part`, `wedge`, `cornerwedge`, `platform`(`trim`), `truss`(`height`, 2 단위로 맞춤),
`rope`(`length`, 투명 트러스 + 보이는 원기둥 마디), `ladder`(`height`), `stairs`(`steps`, −Z 방향으로 올라감),
`model`(`children`, `pivot`, `weld = "all"`), `array`(`count`, `offset`, `rotStep`),
`scatter`(`count`, `area`, `seed`, `jitterRot`, `scaleRange`), `use`(`prefab`). 자세한 표는 [영문 README](README.md#object-harness)를 보세요.

공통 필드: `name`, `pos`, `rot`(도), `color`(`#rrggbb`, 팔레트 이름, `{r,g,b}` 0–255), `material`,
`anchored`, `canCollide`, `transparency`, `reflectance`, `castShadow`, `attributes`, `tags`.

**검증:** 문제를 경로와 함께 **전부** 한 번에 알려줍니다. 모르는 kind/필드(오타), 잘못된 enum, NaN/무한대,
0 이하 크기, 빈칸 있는 리스트, 프리팹 순환, 너무 깊은 중첩, 그리고 만들기 전에 파트 개수를 추정해서
`limits`(`maxParts` 20 000, `maxCount` 2 000, `maxDepth` 32)를 넘으면 막습니다.

**결정성:** 결과는 스펙에만 의존합니다. 자식 순서 유지, 0을 채운 이름, `Random` 대신 자체 xorshift RNG를
써서 Studio, 서버, Lune에서 똑같이 나옵니다. scatter 하나를 고쳐도 다른 scatter 배치는 바뀌지 않습니다.

## 캐릭터 하네스

```lua
local hero = Harness.Character.build({
	name = "SwordRonin",
	skin = "#d9a77c",
	outfit = { shirt = "#f2f2ee", pants = "#1d1d22", shoes = "#2a2a2a", sleeves = "short" },
	face = { eyes = "sharp", mouth = "flat", browTilt = 22, scar = true },
	hair = { style = "short", color = "#3f9a52" },
	accessories = { { type = "headband", color = "#1d1d22" }, { type = "belt" } },
	weapons = { { type = "katana", hand = "Right", length = 3.4 } },
	pieces = { { attach = "Head", name = "Horn", size = { 0.2, 0.6, 0.2 }, pos = { 0.3, 0.7, 0 }, color = "red", shape = "Wedge" } },
})
hero.Parent = workspace
```

* 리그: 발이 y = 0, −Z를 바라봄, 표준 R15 관절 이름, `scale` 0.25–4.
* 외형 조각은 **부위 기준 좌표**로 놓입니다(머리는 1.2³, 중심 0, 얼굴 면 z = −0.6). 질량 없음, 충돌 없음,
  `Weld`로 붙어서 애니메이션을 따라갑니다. `Model.Look/<Face|Hair|Acc01_cape|Weapon01_katana|Custom>`으로 묶입니다.
* 머리: bald, short, spiky, long, ponytail, afro. 눈: round, sharp, closed. 입: smile, grin, frown, flat.
  액세서리: strawHat, headband, scarf, cape, belt, shoulderPads, glasses, backpack. 무기: katana, staff, shield, hammer, kunai.

## 애니메이션 도구

`Anim.toKeyframeSequence(spec)`는 R15 Pose 계층, 이징, `KeyframeMarker`가 들어간 `KeyframeSequence`를 만듭니다
(에셋 id는 Animation Editor로 게시해서 받습니다). `Anim.apply(rig, spec, t, "C0")`는 편집 모드 미리보기,
`Anim.sample`은 테스트용 순수 함수, `Anim.mirror`는 좌우를 바꿉니다.

## Lune과 내보내기

```sh
lune run tools/build.luau object examples/objects/JumpTower.lua out/JumpTower.rbxm
lune run tools/export_examples.luau   # 모든 예제 -> out/*.rbxm
lune run tools/preview_place.luau     # 카메라 투어가 들어간 out/harness_preview.rbxlx (Play 누르기)
```

## 검사

`./check.sh`가 CI와 똑같이 selene, `rojo build`, `luau-lsp analyze`(strict), Lune 테스트 88개와 퍼징 3000회, 예제 내보내기를
돌립니다. GitHub Actions가 push와 PR마다 실행합니다.

## 예제

| | |
| --- | --- |
| ![](docs/img/obj_JumpTower.png) JumpTower | ![](docs/img/obj_PirateDock.png) PirateDock |
| ![](docs/img/obj_BambooGrove.png) BambooGrove | ![](docs/img/obj_CheckpointPad.png) CheckpointPad (JSON) |
| ![](docs/img/lineup_back.png) 뒷모습 | ![](docs/img/anim_poses.png) `Anim.apply`로 포즈를 잡은 Slash / JumpClimb / Wave |

예제 캐릭터는 로고나 상표 이름 없이 만든 패러디 원형입니다.

## 한계

* 블록 파트만 지원합니다. MeshPart, SpecialMesh, 텍스처, 데칼은 아직 없습니다.
* 옷은 부위 색칠이며 Shirt/Pants 이미지가 아닙니다.
* `KeyframeSequence`의 에셋 id는 Animation Editor로 게시해야 받을 수 있습니다.
* Lune에는 물리가 없어서 용접과 오르기는 CI가 아니라 Studio에서 확인합니다.

## 라이선스

[MIT](LICENSE)
