# 开篇词

Crypts and Caverns（C&C）是一个生成式的、链上的 Lootverse “乐高”。这意味着开发者、设计师和艺术家都可以直接调用合约来集成自己的机制、冒险和地图集。

用 Cairo 重写 C&C，让我们可以在 Starknet 生成同样充满魅力的 C&C 地图。整个开发过程中，也碰到并解决了一些问题，记录后分享出来，希望这些思考与经验，有机会可以对大家有用。

# 地图信息存储结构的选择

地图本身需要存储的信息是二维的点阵，状态只有两种——可通行与不可通行。

C&C 的 solidity 代码中，选择 `uint256[]` 作为载体。是的，一维数组，将地图中不同点的状态映射到单个 bit 的 0/1 中，这样长度不超过3的数组就可以存下 C&C 最大尺寸 25*25 的地图信息。在生成地图的过程中，非顺序地对不同 bit 位做更新。

回到 Cairo ，Cairo 的内存模型不同于 solidity 的内存插槽（256），而是基于 `felt252` 这个类型，且拥有 ZK 可验证特性，因此内存不可变。Cairo中的 `Array<T>` 目前只有 `pop_front()` `append()` 方法，除非新建数组，否则原数组的更新只能是顺序的。

在选择数据结构过程中，我尝试了不同的类型：

### `Felt252Dict<Nullable<Span<u8>>>`

看起来有点吓人，一开始想要实现一个可变二维数组。外层通过 `Dict`可以实现随机更新（`Dict` 底层也是通过 `Array` 实现的喔），因为`Array` 未实现 `Copy` 不方便，又选择了 `Span` 做为内层，最后为了满足`Dict`的默认值（`zero_default`）特性套上了`Nullable` 。这样的设计带来了存取上很多不必要的消耗，很显然并不是好的选择，所以很快也弃用了。

### `Felt252Dict<u256>`

仿照原有思路使用了这个结构，内层通过位运算去压缩信息存储。出于减少 gas 消耗的考虑，这个结构后来也弃用了。

修改过程中的一些实现可以参考[这里](https://github.com/CheDAOLabs/cryptsandcaverns/blob/main/contracts-starknet/src/utils/map.cairo#L8C11-L8C11) 

### `felt252` *3

```rust
#[derive(Copy, Drop, Serde)]
struct Pack {
    first: felt252,
    second: felt252,
    third: felt252
}
```

这里是最后选用的结构，因为本身地图的信息存储所需长度上限可知，所以选择`Felt252Dict`这样的灵活结构并不会方便开发，比如需要额外处理 Felt252Dict 中实际使用的数量，再包装一个`struct` 去做有些不必要，总之写死相对更好。另外，`Cairo` 中的 `felt252` 长度为252个bit，`u256` 本身是由两个 `felt252` 存储的`u128` 组成的，本质是一个`struct` ，分高低位，可以想见相关的计算都会至少加倍消耗gas。最后选择了`felt252`作为成员类型，对内存的利用率也会比`u128`更高（后面也会再聊到 `felt252` ）。

# 地图信息存储的实现

```rust
#[derive(Copy, Drop, Serde)]
struct Pack {
    first: felt252,
    second: felt252,
    third: felt252
}
```

之前提到，我们最后选择使用3个`felt252` 作为地图信息的载体。

接下来就是针对bit的更新能力做实现，找到对应的bit位，将其更新为1或者0，这其中有两个地方值得聊聊。

### 类型转换

实现过程中，首先需要转到`u256`类型，位运算结束后转回`felt252`。在这里，我只使用了每个`felt252`中的`248`个bit。

我们首先看`Cairo` 的`try_into()`在`u256`和`felt252`两种类型转换中的实现源码。

```rust
impl U256TryIntoFelt252 of TryInto<u256, felt252> {
    fn try_into(self: u256) -> Option<felt252> {
        let FELT252_PRIME_HIGH = 0x8000000000000110000000000000000_u128;
        if self.high > FELT252_PRIME_HIGH {
            return Option::None;
        }
        if self.high == FELT252_PRIME_HIGH {
            // since FELT252_PRIME_LOW is 1.
            if self.low != 0 {
                return Option::None;
            }
        }
        Option::Some(
            self.high.into() * 0x100000000000000000000000000000000_felt252 + self.low.into()
        )
    }
}
```

从方法中可以看出，`252`位所能表示的最大值，并不能顺利通过类型转换。另外，为了方便debug，这里直接扔掉表达一个十六进制数所需的`4`个bit，所以最终仅使用每个`felt252`中的`248`个bit位。

### 位运算与掩码

`Cairo`原生支持基本的位运算，但没有位移运算。项目初期，通过算术运算来实现预期的左位移运算，来获取所需要的bit位信息，并且也在这个过程中手动实现应有的“溢出截断”。当然，代价是大量的不必要消耗，也导致了函数的运行缓慢。

```rust
fn left_shift(mut self: u256, mut count: u256) -> u256 {
        loop {
            if count == 0 {
                break;
            }
            // overflow 2^255
            if self >= 0x8000000000000000000000000000000000000000000000000000000000000000 {
                self = (self - 0x8000000000000000000000000000000000000000000000000000000000000000)
                    * 2;
            } else {
                self *= 2;
            }

            count -= 1;
        };

        self
    }
```

讨论后，选择用掩码的形式来实现预期效果，继续保持位运算的低消耗。掩码通过硬编码形式写入代码，这里没有严格求证过`if-else`的消耗，但还是手动实现了某个数对应掩码的二分查找。这里也顺便用Java写了一个简单的函数生成脚本及测试生成脚本，一起放在[项目](https://github.com/CheDAOLabs/cryptsandcaverns/blob/main/contracts-starknet/src/utils/pack.cairo)内。

```rust
fn get_pow(position: u128) -> u256 {
    if position <= 126 {
        if position <= 63 {
            if position <= 31 {
                if position <= 15 {
                    if position <= 7 {
                        if position <= 3 {
                            if position <= 1 {
                                if position == 0 {
                                    POW_0
                                } else {
                                    POW_1
                                } ......
```

# 加速函数访问（复杂数据存储上链）

在C&C中，原有设计仅在链上保存一个随机种子`seed` ，其他地图信息如布局、兴趣点等都通过`seed` + 生成函数来实现，因为`seed`不变，所以生成结果永远一致。

但是，在`Starknet Goerli`部署后，尽管已经做了种种优化，地图生成函数的响应速度还是非常慢。讨论后，我们决定将地图生成后的原始数据存到链上，加速调用获取。

```rust
#[derive(Drop)]
    struct Dungeon {
        size: u8,
        environment: u8,
        structure: u8,
        legendary: u8,
        layout: Pack,
        entities: EntityData,
        affinity: felt252,
        dungeon_name: Array<felt252>
    }

    #[derive(Drop)]
    struct EntityData {
        x: Array<u8>,
        y: Array<u8>,
        entity_data: Array<u8>
    }
```

以上是地图的原始数据信息。`Cairo` 已支持基本类型的数据上链存储，比如`felt252` `u256`等，对于稍复杂一些的类型，比如`Array<T>`，目前还需要开发人员手动实现相关方法，以下是对应的trait。

```rust
trait Store<T> {
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<T>;
    fn write(address_domain: u32, base: StorageBaseAddress, value: T) -> SyscallResult<()>;
    fn read_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8
    ) -> SyscallResult<T>;
    fn write_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8, value: T
    ) -> SyscallResult<()>;
    fn size() -> u8;
}
```

复杂数据的存储上链，本质还是利用其中基本类型的已实现的存储能力。将复杂的数据结构拆分为多个基本类型，分别存储到链上，过程中保持偏移量递增。在读取时，按偏移依次取出并组装结构返回即可。可参考[项目代码](https://github.com/CheDAOLabs/cryptsandcaverns/blob/main/contracts-starknet/src/lib.cairo#L234)。

# 聊聊`felt252`

### 字面量与实际存储值的不同

`Felt252Dict` 的 key 值类型为 `felt252` 

```rust
use debug::PrintTrait;
#[test]
#[available_gas(3000000)]
fn test() {
    let mut dict: Felt252Dict<u128> = Default::default();
    dict.insert(1, 1);

    let value1 = dict.get(1);
    let value2 = dict.get('1');
}
```

这里从字典中取出的两个`value` 不会相等，`value1`是我们之前`insert`的`1`，而`value2`是默认值`0` 。因为两个key的值分别为`0x1` `0x31` 。

还有一个处理场景是在拼接`svg`时。目前`Cairo` 还不支持长字符串或者字节数组（Experimental），因此地图生成的`svg` 我们只能通过`Array<felt252>` 不断`append()` 最后输出。碰到非固定数值的变量时，需要将实际数值加上`0x30`后再拼接，保持整个数组内容均为ASCII标准。如果是多位十进制，那么就依次取余拆分后拼接（因此，最后返回的数组长度惊人）。

```rust
fn append_number_ascii(mut parts: Array<felt252>, mut num: u128) -> Array<felt252> {
        let part: Array<felt252> = append_number(ArrayTrait::<felt252>::new(), num);
        let mut length = part.len();
        loop {
            if length == 0 {
                break;
            }
            parts.append(*part[length - 1]);
            length -= 1;
        };
        parts
    }

    fn append_number(mut part: Array<felt252>, mut num: u128) -> Array<felt252> {
        if num != 0 {
            let temp: u8 = (num % 10).try_into().unwrap();
            part.append((temp + 48).into());
            num /= 10;
            append_number(part, num)
        } else {
            part
        }
    }
```