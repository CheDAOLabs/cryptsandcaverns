# Introduction

Crypts and Caverns (C&C) is a generative, on-chain Lootverse "LEGO" that allows developers, designers, and artists to directly integrate their own mechanics, adventures, and map collections using smart contracts.

We have rewritten C&C using Cairo to generate equally enchanting C&C maps on Starknet. Throughout the entire development process, we encountered and resolved various challenges, which we have documented and are sharing here. We hope that these insights and experiences can be useful to others in the future.

# Selection of Map Information Storage Structure

The map itself needs to store information in a two-dimensional grid, with only two possible states - passable and impassable.

In the C&C (Crypts and Caverns) Solidity code, `uint256[]` was chosen as the data carrier. Yes, it is a one-dimensional array that maps the states of different points in the map to individual bits (0/1). This way, an array with a length not exceeding 3 can store the map information for C&C with a maximum size of 25*25. During the map generation process, updates to different bit positions are done in a non-sequential manner.

Now, let's switch to Cairo. Cairo's memory model is different from Solidity's memory slots (256). It is based on the felt252 type and has zero-knowledge (ZK) verifiability characteristics, making the memory immutable. In Cairo, the `Array<T>` currently only provides `pop_front()` and `append()` methods, and unless a new array is created, updates to the original array can only be done sequentially.

During the process of selecting a data structure, I experimented with different types:

### `Felt252Dict<Nullable<Span<u8>>>`

It looks a bit intimidating at first. The initial intention was to implement a mutable two-dimensional array. The outer layer uses `Dict` to enable random updates (the underlying implementation of `Dict` is actually based on `Array`). However, since `Array` does not implement `Copy`, it is not convenient. So `Span` was chosen as the inner layer, and finally, to satisfy the default value (`zero_default`) feature of `Dict`, it was wrapped in `Nullable`. This design introduces a lot of unnecessary overhead in terms of storage and access, which is clearly not a good choice, so it was quickly abandoned.

### `Felt252Dict<u256>`

Following the original idea, this structure was used, and bitwise operations were used to compress the information storage in the inner layer. For the purpose of reducing gas consumption, this structure was also eventually deprecated.

You can refer to the implementation of some modifications during the process [here](https://github.com/CheDAOLabs/cryptsandcaverns/blob/main/contracts-starknet/src/utils/map.cairo#L8C11-L8C11):

### `felt252` *3

```rust
#[derive(Copy, Drop, Serde)]
struct Pack {
    first: felt252,
    second: felt252,
    third: felt252
}
```

Here is the structure that was eventually chosen. Since the maximum length required for storing map information is known, using a flexible structure like `Felt252Dict` is not convenient for development. For example, additional processing is required to handle the actual number of elements used in `Felt252Dict`, and wrapping it in another `struct` would be unnecessary. In summary, it is better to hardcode the structure. Additionally, in `Cairo`, `felt252` has a length of 252 bits, and `u256` itself is composed of two `felt252` storing `u128`, which is essentially a `struct` with high and low bits. It can be seen that related calculations would at least double the gas consumption. Therefore, `felt252` was chosen as the member type, which also allows for higher utilization of memory (we will discuss `felt252` further later).

# Implementation of Map Information Storage

```rust
#[derive(Copy, Drop, Serde)]
struct Pack {
    first: felt252,
    second: felt252,
    third: felt252
}
```

As mentioned before, we chose to use 3 `felt252` variables as the containers for map information.

Next, we need to implement the ability to update bits, finding the corresponding bit and setting it to 1 or 0. There are two aspects worth discussing.

### Type Conversion

In the implementation process, we first need to convert to the `u256` type, perform bitwise operations, and then convert back to `felt252`. In this case, I only use the first `248` bits in each `felt252`.

Let's take a look at the implementation source code of `try_into()` in Cairo for the conversion between `u256` and `felt252` types.

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

From the method, we can see that the maximum value representable by `felt252`, which is `252` bits, cannot be smoothly converted. Additionally, for debugging convenience, we directly discard the `4` bits required to represent a hexadecimal number, so in the end, only the first `248` bits in each `felt252` are used.

### Bitwise Operations and Masks

Cairo natively supports basic bitwise operations but does not have bitwise shift operations. In the early stages of the project, we used arithmetic operations to achieve the desired left shift operation to obtain the required bit information, and also manually implemented the necessary "overflow truncation" during this process. However, this resulted in a significant amount of unnecessary overhead and slow function execution.

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

After discussions, we decided to use masks to achieve the desired effect, while maintaining low overhead for bitwise operations. The masks are hard-coded into the code. We haven't rigorously tested the performance of `if-else` statements, but we still manually implemented a binary search for the corresponding mask of a given number. I also wrote a simple function generation script in Java and a script for testing the generated functions, both of which are included in the [project](https://github.com/CheDAOLabs/cryptsandcaverns/blob/main/contracts-starknet/src/utils/pack.cairo).

You can find the complete content [here](https://github.com/CheDAOLabs/cryptsandcaverns/blob/main/contracts-starknet/src/utils/pack.cairo).

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

# Accessing Accelerated Functions (Storing Complex Data On-Chain)

In C&C, the original design only stored a random seed called `seed` on the blockchain. Other map information such as layout and points of interest were generated using the `seed` and a generation function. Since the `seed` remained unchanged, the generated results were always the same.

However, after deploying to `Starknet Goerli`, despite various optimizations, the response time of the map generation function was still very slow. After discussions, we decided to store the raw generated data on the blockchain to accelerate retrieval.

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

The above code represents the raw data structure of the map. `Cairo` already supports storing basic types of data on-chain, such as `felt252` and `u256`. For slightly more complex types like `Array<T>`, developers currently need to manually implement the related methods. The following is the corresponding trait:

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

Storing complex data on-chain essentially relies on the existing storage capabilities of the underlying basic types. The complex data structure is split into multiple basic types, which are stored on the blockchain separately. During the process, the offset is incremented to maintain the correct positions. When reading the data, the values are retrieved based on the offsets and assembled to reconstruct the structure. You can refer to the [project code](https://github.com/CheDAOLabs/cryptsandcaverns/blob/main/contracts-starknet/src/lib.cairo#L234) for more details.

# Let's talk about `felt252`

### Difference between Literal and Actual Stored Value

The key type of `Felt252Dict` is `felt252`.

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

In the code snippet above, the two values retrieved from the dictionary, `value1` and `value2`, will not be equal. `value1` is the value we previously inserted, which is `1`, while `value2` is the default value `0`. This is because the two keys have different values: `0x1` and `0x31`, respectively.

Another scenario where this difference arises is when concatenating SVG strings. Currently, `Cairo` does not support long strings or byte arrays (Experimental). Therefore, when generating the map's SVG, we can only continuously append to an `Array<felt252>` and output it as the final result. When encountering variable values that are not fixed, we need to add `0x30` to the actual value before concatenating it to ensure that the entire array contains ASCII-standard values. If the variable value is a multi-digit decimal number, we need to split it into individual digits and concatenate them (hence, the resulting array can be quite long).

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