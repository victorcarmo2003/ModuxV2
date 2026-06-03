# Modux

Modux é um framework para organizar projetos Roblox em Services, Controllers,
Components e Mixins. Ele oferece injeção de dependências, lifecycles previsíveis,
schedulers, cleanup centralizado, Signals, Promise e integração tipada com
Network/Lync.

A extensão **Modux Tooling** analisa o código Luau e mantém dois arquivos:

- `Types.luau`: contratos usados pelo autocomplete e pelo type checker.
- `Manifest.luau`: lista exata dos módulos Modux carregados no `Start()`.

Esses arquivos são gerados automaticamente. Não edite nenhum deles manualmente.

## Sumário

- [Quickstart](#quickstart)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Conceitos principais](#conceitos-principais)
- [Import e Extend](#import-e-extend)
- [Lifecycles e cleanup](#lifecycles-e-cleanup)
- [Components](#components)
- [Modux Doctor](#modux-doctor)
- [Signals](#signals)
- [Promise](#promise)
- [Network e Lync](#network-e-lync)
- [Troubleshooting](#troubleshooting)

## Quickstart

### 1. Inicie o Modux no servidor

Crie um Script em `src/server/ModuxInit.server.luau`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modux = require(ReplicatedStorage.Shared.Modux)

Modux.Start()
```

### 2. Inicie o Modux no cliente

Crie um LocalScript em `src/client/init.client.luau`:

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modux = require(ReplicatedStorage.Shared.Modux)

Modux.Start()
```

### 3. Crie um Service

Crie `src/server/Services/PlayerService.luau`:

```luau
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local PlayerService = Modux.Service("PlayerService")

PlayerService:OnInit(function(self)
	self.Players = {}
end)

PlayerService:OnStart(function(self)
	print("PlayerService iniciado")
end)

return PlayerService
```

### 4. Importe uma dependência

Crie `src/server/Services/InventoryService.luau`:

```luau
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local InventoryService = Modux.Service("InventoryService")

InventoryService:Import("PlayerService")

InventoryService:OnStart(function(self)
	print(self.PlayerService)
end)

return InventoryService
```

`PlayerService` é iniciado antes de `InventoryService`, pois foi declarado como
dependência.

### 5. Gere os tipos

Com a extensão **Modux Tooling** instalada, execute:

```text
Modux: Generate Types
```

Depois disso, `Types.luau` e `Manifest.luau` passam a ser regenerados
automaticamente quando arquivos Luau mudarem.

## Estrutura do projeto

A configuração padrão espera esta organização:

```text
src/
├── client/
│   ├── Controllers/
│   └── init.client.luau
├── server/
│   ├── Services/
│   └── ModuxInit.server.luau
└── shared/
    ├── Components/
    └── Modux/
        ├── init.luau
        ├── Types.luau       # gerado
        ├── Manifest.luau    # gerado
        └── src/
```

O projeto também deve manter um `sourcemap.json` gerado pelo Rojo para que a
extensão publique os caminhos corretos no Manifest.

## Conceitos principais

| Objeto | Responsabilidade | Escopo padrão | Inicia sozinho? |
| --- | --- | --- | --- |
| `Service` | Estado e lógica compartilhada, normalmente no servidor | Singleton | Sim |
| `Controller` | Comportamento do cliente | Singleton | Sim |
| `Component` | Comportamento associado a uma instância com tag | Transient | Por instância |
| `Mixin` | Composição reutilizável de comportamento e defaults | Isolado | Não |

Criação:

```luau
local PlayerService = Modux.Service("PlayerService")
local HudController = Modux.Controller("HudController")
local DoorComponent = Modux.Component("DoorComponent")
local InteractableMixin = Modux.Mixin("InteractableMixin")
```

IDs devem ser únicos em todo o projeto. Um ID duplicado gera erro antes da
inicialização.

## Import e Extend

Use `Import` para dependências compartilhadas:

```luau
InventoryService:Import("PlayerService")

InventoryService:OnStart(function(self)
	self.PlayerService:GetPlayerData()
end)
```

Use `Extend` somente para aplicar Mixins:

```luau
DoorComponent:Extend("InteractableMixin")
```

Também é possível compor múltiplos Mixins:

```luau
DoorComponent
	:Extend("InteractableMixin")
	:Extend("AnimatedMixin")
```

Regras de composição:

- O objeto final sempre vence conflitos com Mixins.
- Entre Mixins, o último `Extend` vence e gera warning em conflitos.
- Lifecycles não sobrescrevem uns aos outros: eles acumulam.
- Lifecycles dos Mixins rodam na ordem de composição e antes dos callbacks do
  objeto final.
- Um Mixin pode usar outros Mixins.
- Ciclos de `Import` e ciclos de Mixins são erros.
- Um Mixin nunca deve ser importado ou resolvido diretamente.

Não use o argumento legado `scopeKey`. Ele ainda é aceito temporariamente, mas
é ignorado e gera warning:

```luau
-- Evite:
Object:Import("PlayerService", "legacy-scope")
```

## Lifecycles e cleanup

### OnInit

Use para preparar estado local antes de o objeto começar a trabalhar:

```luau
RoundService:OnInit(function(self)
	self.ActivePlayers = {}
end)
```

### OnStart

Use para conectar eventos e iniciar o comportamento:

```luau
RoundService:OnStart(function(self)
	print("RoundService pronto")
end)
```

Dependências importadas são inicializadas primeiro. Objetos independentes podem
inicializar em paralelo.

Callbacks de lifecycle são protegidos contra erros. Uma Promise retornada pelo
callback é aguardada por até 30 segundos; rejeições e timeout geram warning sem
deixar o loader pendurado.

### OnTick

Use para gameplay periódico independente de FPS:

```luau
RoundService:OnTick(function(self, deltaTime)
	self:UpdateRound(deltaTime)
end, Modux.TickRate.Hz1)
```

Taxas disponíveis:

```text
Hz1, Hz5, Hz10, Hz15, Hz30, Hz60
```

Uma prioridade menor roda primeiro:

```luau
RoundService:OnTick(function(self, deltaTime)
	self:UpdateRound(deltaTime)
end, Modux.TickRate.Hz10, 100)
```

### OnSimulation

Reserve para simulação física sincronizada:

```luau
PhysicsService:OnSimulation(function(self, deltaTime)
	self:StepPhysics(deltaTime)
end, Enum.StepFrequency.Hz30)
```

`OnSimulation` usa `RunService:BindToSimulation()`. Para relógios, cooldowns e
lógica comum de jogo, prefira `OnTick`.

### OnDestroy e Cleanup

Use `Cleanup` para registrar connections, funções e recursos descartáveis:

```luau
PlayerService:OnStart(function(self)
	self:Cleanup(game.Players.PlayerAdded:Connect(function(player)
		print(player.Name)
	end))
end)
```

Use `OnDestroy` quando precisar executar uma etapa explícita de desmontagem:

```luau
PlayerService:OnDestroy(function(self)
	print("Encerrando PlayerService")
end)
```

`Modux.Stop()` é idempotente e desmonta Components, ticks, simulações, Signals,
Promises canceláveis, connections, cleanups e registries. Isso permite iniciar o
runtime novamente sem duplicar conexões:

```luau
Modux.Stop()
Modux.Start()
```

## Components

Components são templates transientes associados a instâncias por tag do
`CollectionService`.

```luau
local Modux = require(game.ReplicatedStorage.Shared.Modux)
local DoorComponent = Modux.Component("DoorComponent")

DoorComponent
	:Tag("Door")
	:ClassName("BasePart")
	:AttributeDefaults({
		Locked = false,
	})
	:Children({
		"Prompt",
	})

DoorComponent:OnStart(function(self)
	print(self.Instance)
	print(self.Attributes.Locked)
end)

DoorComponent:OnDestroy(function(self)
	print("Door removida")
end)

return DoorComponent
```

O Component só é criado quando:

- A instância possui a tag configurada.
- A instância corresponde ao `ClassName`, quando definido.
- Todos os filhos exigidos por `Children` existem.

`AttributeDefaults` inicializa `self.Attributes` e acompanha mudanças dos
atributos da instância.

Para consultar Components ativos:

```luau
local door = self:GetComponent(instance, "DoorComponent")
local allDoors = self:GetAllComponents("DoorComponent")
```

Quando o ID literal corresponde a um `Modux.Component`, os tipos gerados
especializam automaticamente o retorno:

```luau
local door = self:GetComponent(instance, "DoorComponent") -- DoorComponent?
local allDoors = self:GetAllComponents("DoorComponent") -- { DoorComponent }
```

`GetComponent()` retorna um valor opcional porque a instância pode não possuir
um Component ativo. `GetAllComponents()` sempre retorna um array, mesmo quando
nenhum Component daquele tipo está registrado.

IDs calculados em runtime continuam aceitos por compatibilidade, com fallback
para `any`:

```luau
local component = self:GetComponent(instance, componentId) -- any
```

A extensão sugere apenas IDs de `Modux.Component`. Mixins não aparecem nesses
helpers. Um literal inexistente, como `"DoorComponet"`, gera erro no editor para
facilitar a correção de typos.

Os contratos também especializam a instância e os attributes:

```luau
local VitalComponent = Modux.Component("VitalComponent")
	:Tag("Vital")
	:ClassName("Player")
	:AttributeDefaults({ Health = 100 })

-- Tipos gerados:
-- VitalComponent.Instance: Player
-- VitalComponent.Attributes: { Health: number }
```

Consultas literais preservam esse contrato:

```luau
local vital = self:GetComponent(player, "VitalComponent") -- VitalComponent?
```

## Modux Doctor

O tooling analisa os contratos de Components sem alterar o runtime. Com o
companion opcional instalado no Roblox Studio, ele compara tags, classes,
filhos obrigatórios e tipos de attributes antes do playtest.

O Doctor também sinaliza imports ausentes ou não usados, dependências
inacessíveis entre client/server/shared, connections sem `Cleanup`, packets
Network inexistentes e cópias antigas divergentes fora de `src/`.

Sem Studio conectado, análises estáticas continuam ativas. A ausência de uma
instância observada é warning, pois tags criadas manualmente ou em runtime são
válidas. Para uma exceção intencional, use uma supressão:

```luau
-- modux ignore line
local RegionComponent = Modux.Component("RegionComponent"):Tag("Region")
```

`-- modux ignore line` ignora a próxima linha quando aparece isolado, ou a
própria linha quando usado ao final do código. `-- modux ignore file` vale para
o arquivo inteiro. Um código opcional restringe a supressão a uma regra:

```luau
Players.PlayerAdded:Connect(callback) -- modux ignore line cleanup-untracked-connection
-- modux ignore file component-no-studio-instance
```

O VS Code sugere as diretivas e os códigos depois de `-- modux `. As formas
legadas `modux-ignore-next-line` e `modux-ignore-file` continuam aceitas.

Quando a origem é comprovável, o editor destaca o trecho semanticamente
relacionado ao problema. Por exemplo, ausência de instância observada destaca a
linha de `:Tag()`, classe incompatível destaca `:ClassName()` e filho ausente
destaca a linha correspondente em `:Children()`.

O widget **Modux Companion** no Studio oferece um Inspector somente leitura:

- `Overview` resume a bridge, o snapshot e as quantidades observadas.
- `Components` permite expandir contratos e selecionar instâncias no Explorer.
- `Diagnostics` agrupa erros e warnings por severidade.

As expansões e posições de scroll permanecem estáveis entre sincronizações.

## Signals

Signals públicos devem declarar explicitamente seu payload para preservar
autocomplete e checagem estática.

Signal sem argumentos:

```luau
RoundService.OnReady = RoundService.Signal.new() :: Modux.Signal<>
```

Signal com argumentos:

```luau
RoundService.OnDamage =
	RoundService.Signal.new() :: Modux.Signal<Player, number>
```

O alias público fica no próprio módulo `Modux`, que já foi importado para criar
o objeto. Não é necessário adicionar `require(Modux.Types)` ao arquivo.

O cast legado com `Types.Signal<...>` continua aceito durante a migração.

Uso:

```luau
RoundService.OnDamage:Connect(function(player, amount)
	print(player, amount)
end)

RoundService.OnDamage:Fire(player, 25)
```

Um Signal público criado sem cast continua funcionando, mas gera
`Signal<any>` com warning:

```luau
-- Funciona, mas perde robustez de tipo:
RoundService.OnDamage = RoundService.Signal.new()
```

## Promise

Cada objeto Modux expõe `PromiseAPI` em `self.Promise` e no próprio objeto:

```luau
ProfileService.LoadProfile = function(self, player: Player)
	return self.Promise.new(function(resolve, reject)
		-- trabalho assíncrono
		resolve({ UserId = player.UserId })
	end)
end
```

Métodos estáticos principais:

```text
new, resolve, reject, defer, try, promisify, fromEvent, delay,
all, some, race, any, allSettled, each, fold, retry, retryWithDelay
```

Métodos de instância principais:

```text
andThen, catch, finally, tap, now, timeout, cancel,
getStatus, awaitStatus, expect, await
```

Exemplo:

```luau
return self.Promise.resolve(10)
	:andThen(function(value)
		return value * 2
	end)
	:timeout(5)
```

## Network e Lync

Modux expõe a superfície Lync vendorizada através de `Network`. Declare seus
pacotes em `src/shared/Modux/src/Network/init.luau`.

### Packet

```luau
Network.Packages = {
	Notification = Network.packet(
		"Notification",
		Network.struct({
			Message = Network.string(100),
			Duration = Network.optional(Network.f32),
		})
	),
}
```

Envio e recebimento:

```luau
self.Network.Packages.Notification:send({
	Message = "Olá",
	Duration = 3,
}, player)

self.Network.Packages.Notification:on(function(data)
	print(data.Message)
end)
```

### Query

```luau
Network.Packages = {
	GetCoins = Network.query(
		"GetCoins",
		Network.struct({ UserId = Network.int(0, 4294967295) }),
		Network.struct({ Coins = Network.int(0, 4294967295) })
	),
}
```

### Tagged

`tagged` gera uma união discriminada:

```luau
Network.tagged("kind", {
	Success = Network.struct({ Coins = Network.int(0, 4294967295) }),
	Failure = Network.struct({ Message = Network.string(100) }),
})
```

### Casts explícitos

Codecs opacos precisam de cast:

```luau
type Codec<T> = lync.Codec<T>
type Packet<T> = lync.Packet<T>

local PositionCodec =
	Network.custom(writePosition, readPosition) :: Codec<Vector3>

Network.Packages = {
	Position = Network.packet("Position", PositionCodec) :: Packet<Vector3>,
}
```

Sem cast, a geração usa `any` e emite warning.

### Codecs suportados pelo registry lync@2.3.3

| Família | Codecs | Tipo inferido |
| --- | --- | --- |
| Numéricos | `int`, `zint`, `float`, `deltaInt`, `deltaFloat`, `f16`, `f32`, `f64` | `number` |
| Básicos | `bool`, `string`, `buff` | `boolean`, `string`, `buffer` |
| Vetores e transformações | `vec2`, `vec3`, `deltaVec3`, `cframe`, `deltaCFrame` | `Vector2`, `Vector3`, `CFrame` |
| Datatypes Roblox | `color3`, `inst`, `udim`, `udim2`, `numberRange`, `rect`, `ray`, `region3`, `region3int16`, `vec2int16`, `vec3int16`, `numberSequence`, `colorSequence` | Datatype correspondente |
| Estruturas | `struct`, `deltaStruct` | Tabela com campos inferidos |
| Coleções | `array`, `deltaArray`, `map`, `deltaMap` | Array ou mapa tipado |
| Composição | `optional`, `tuple`, `tagged`, `enum`, `bitfield` | Tipo composto inferido |
| Ausência e desconhecido | `nothing`, `unknown` | `nil`, `any` |
| Opaque | `custom`, `auto` | Exige cast explícito para preservar tipo |

O scanner também reconhece `variant` como compatibilidade legada. Prefira os
codecs publicados pela versão vendorizada atual.

## Troubleshooting

| Mensagem | Causa | Correção |
| --- | --- | --- |
| `Public Signal "X" has no explicit payload` | Signal público criado sem contrato | Adicione cast para `Modux.Signal<...>` |
| `Signal "X" uses a parenthesized factory pack` | Sintaxe antiga como `new<<(Player, number)>>()` | Migre para cast com `Modux.Signal<...>` |
| `Lync codec "custom" is opaque` | Codec customizado sem tipo dedutível | Adicione `:: Codec<MyType>` ou `:: Packet<MyType>` |
| `Lync codec "auto" is opaque` | `auto` não oferece contrato estático suficiente | Adicione cast explícito |
| `Unknown Lync codec` | Codec novo ainda não registrado no tooling | Adicione cast e atualize o registry do tooling |
| `Network packet "X" is missing profile key` | Template e packet não possuem as mesmas chaves | Sincronize o schema do perfil e o packet |
| `Network packet "X" has extra profile key` | Packet possui uma chave não declarada no template | Remova a chave extra ou atualize o template |
| `Duplicate Modux id` | Dois objetos usam o mesmo ID | Renomeie um dos objetos |
| `GetComponent references unknown Component` | Um helper usa ID literal inexistente | Corrija o typo ou use um ID de `Modux.Component` |
| `Cyclic Modux Import` | Dependências formam um ciclo | Reorganize responsabilidades para quebrar o ciclo |
| `Cyclic mixin Extend` | Mixins estendem uns aos outros circularmente | Remova um dos `Extend` |
| `scopeKey is deprecated` | Código legado usa segundo argumento de `Import` | Remova o `scopeKey` |
| `Manifest.luau is missing` | Arquivos gerados não existem ou estão desatualizados | Execute `Modux: Generate Types` |
