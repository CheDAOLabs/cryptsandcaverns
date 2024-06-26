# Crypts And Caverns

## Description

The rewritten version in the Cairo language has achieved the same effects and features as the solidity version.<br>
For more infomation, you can check [README](https://github.com/CheDAOLabs/cryptsandcaverns/blob/main/contract/README.md).

## Sepolia Address

```shell
0x03e82dba083a74fda360b255e8dbe983ca3759299ab20c3ad52f3bd541fa3d59
```

## Goerli Address

```shell
0x070017c7a691d60ac06a5905bf782764cbc9c81a97f8f2587a5373ad7bdec886
```

# Starknet / Cairo

## Introduction

`Starknet` is a Layer-2 network that makes Ethereum transactions faster, cheaper, and more secure using zk-STARKs technology. Think of it as a boosted layer on top of Ethereum, optimized for speed and cost.

`Cairo` is tailor-made for creating STARK-based smart contracts. As Starknet’s native language, it’s central to building scalable and secure decentralized apps. `Cairo` is a programming language designed for a virtual CPU of the same name.

`Scarb` is the Cairo package manager, its configuration file is `Scarb.toml`.

You can check out the [`Starknet Doc`](https://book.starknet.io/title-page.html) and  [`Cairo Book`](https://book.cairo-lang.org/title-page.html) for more information.

## Installation

Cairo can be installed by simply downloading `Scarb`.

1. Scarb requires a Git executable to be available in the PATH environment variable.

```shell
git --version
```

2. run the following command in your terminal

```shell
curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh
```

3. Verify installation by running the following command in new terminal session, it should print both Scarb and Cairo language versions

```shell
$ scarb --version

scarb 2.5.0 (c531a6e50 2024-01-22)
cairo: 2.5.0 (https://crates.io/crates/cairo-lang-compiler/2.5.0)
sierra: 1.4.0
```

## Build / Compile

`Cairo` contract first compiles to Sierra, an intermediate representation of `Cairo` which will compile later down to a safe subset of CASM. The point of Sierra is to ensure your CASM will always be provable, even when the computation fails.

```shell
scarb build
```

## Test

```shell
scarb test
```

## Deploy

We use `Starkli` to __declare__ and __deploy__ our `Cairo` contracts. <br>
you can check out the [`Starkli Book`]([`starli`](https://book.starkli.rs/introduction)) for more information.

_`Remix with Starknet plugin ` is another option._
