mod dungeons_generator;
mod utils;
mod interface;

// --------------------------------------------- interface -------------------------------------------

use starknet::ContractAddress;

// #[starknet::interface]
// trait IERC721Metadata<TState> {
//     fn name(self: @TState) -> felt252;
//     fn symbol(self: @TState) -> felt252;
//     // fn token_uri(self: @TState, token_id: u256) -> felt252;
//     fn token_uri(self: @TState, token_id: u256) -> Array<felt252>;
// }

// #[starknet::interface]
// trait IERC721MetadataCamelOnly<TState> {
//     // fn tokenURI(self: @TState, tokenId: u256) -> felt252;
//     fn tokenURI(self: @TState, tokenId: u256) -> Array<felt252>;
// }

#[starknet::interface]
trait IERC721Enumerable<TContractState> {
    fn total_supply(self: @TContractState) -> u256;
    fn token_by_index(self: @TContractState, index: u256) -> u256;
    fn token_of_owner_by_index(self: @TContractState, owner: ContractAddress, index: u256) -> u256;
}

#[starknet::interface]
trait IERC721EnumerableCamelOnly<TContractState> {
    fn totalSupply(self: @TContractState) -> u256;
    fn tokenByIndex(self: @TContractState, index: u256) -> u256;
    fn tokenOfOwnerByIndex(self: @TContractState, owner: ContractAddress, index: u256) -> u256;
}

// -------------------------------------------- Contract --------------------------------------------

#[starknet::contract]
mod Dungeons {
    //
    // ------------------------------------------ Imports -------------------------------------------

    use core::array::ArrayTrait;
    use openzeppelin::introspection::interface::ISRC5;
    use openzeppelin::token::erc721::interface::{
        IERC721, IERC721CamelOnly, IERC721Metadata, IERC721MetadataCamelOnly
    };
    use super::{IERC721Enumerable, IERC721EnumerableCamelOnly};
    use core::traits::TryInto;
    use starknet::{
        ContractAddress, SyscallResult, info::get_caller_address,
        storage_access::{Store, StorageAddress, StorageBaseAddress},
        contract_address_try_from_felt252, EthAddress, ClassHash, contract_address_const
    };
    use super::interface::{
        CryptsAndCavernsTrait, CryptsAndCavernsTraitDispatcher,
        CryptsAndCavernsTraitDispatcherTrait, SeedTrait, SeedTraitDispatcher,
        SeedTraitDispatcherTrait
    };

    use super::{
        utils::{random::random, bit_operation::BitOperationTrait, pack::{PackTrait, Pack}},
        dungeons_generator::{generate_layout_and_entities, parse_entities}
    };

    // ------------------------------------------ Components -----------------------------------------

    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::token::erc721::ERC721Component::InternalTrait as erc721Internal;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::OwnableComponent::InternalTrait as ownableInternal;
    use components::upgradeable::upgradeable::UpgradeableComponent;
    use components::upgradeable::upgradeable::UpgradeableComponent::InternalTrait as upgradeableInternal;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // ------------------------------------------- Structs -------------------------------------------

    #[derive(Copy, Drop, Serde)]
    struct Dungeon {
        size: u8,
        environment: u8,
        structure: u8,
        legendary: u8,
        layout: Pack,
        doors: Pack,
        points: Pack,
        affinity: felt252,
        dungeon_name: Span<felt252>,
    }

    /// Helper variables when iterating through and drawing dungeon tiles
    #[derive(Drop)]
    struct RenderHelper {
        pixel: u128,
        start: u128,
        layout: Pack,
        parts: Span<felt252>,
        counter: u128,
        num_rects: u128,
        last_start: u128,
    }

    // ------------------------------------------- Event -------------------------------------------

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Minted: Minted,
        Related: Related,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct Minted {
        #[key]
        account: ContractAddress,
        token_id: u256
    }

    #[derive(Drop, starknet::Event)]
    struct Related {
        from_address: felt252,
        #[key]
        id: u128,
        seed: u256,
        #[key]
        eth_account: felt252,
        starknet_account: ContractAddress
    }

    // ------------------------------------------- Storage -------------------------------------------

    #[storage]
    struct Storage {
        // -------------- dungeons ----------------
        // dungeons: LegacyMap::<u128, Dungeon>,
        // price: u256,
        // loot:ContractAddress,
        seeds: LegacyMap::<u128, u256>,
        last_mint: u128,
        claimed: u128,
        restricted: bool,
        // --------------- seeder ----------------
        PREFIX: LegacyMap::<u128, felt252>,
        LAND: LegacyMap::<u128, felt252>,
        SUFFIXES: LegacyMap::<u128, felt252>,
        UNIQUE: LegacyMap::<u128, felt252>,
        PEOPLE: LegacyMap::<u128, felt252>,
        // --------------- render ----------------
        // Array contains sets of 4 colors:
        // 0 = bg, 1 = wall, 2 = door, 3 = point
        // To calculate, multiply environment (int 0-5) by 4 and add the above numbers.
        colors: LegacyMap::<u8, felt252>,
        // Names mapped to the above colors
        environmentName: LegacyMap::<u8, felt252>,
        // -------------- enumerable -------------
        owned_tokens: LegacyMap::<(ContractAddress, u128), u128>,
        owned_token_index: LegacyMap::<u128, u128>,
        // -------------- cross ------------------
        relater: felt252,
        eth_owner: LegacyMap::<u128, felt252>,
        // -------------- component --------------
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    // ------------------------------------------- Upgrade -------------------------------------------

    #[abi(embed_v0)]
    fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
        self.ownable.assert_only_owner();
        self.upgradeable._upgrade(new_class_hash);
    }

    // ------------------------------------------- Dungeon -------------------------------------------

    // ---- enumerable -----

    #[abi(embed_v0)]
    impl ERC721Enumerable of IERC721Enumerable<ContractState> {
        fn total_supply(self: @ContractState) -> u256 {
            self.last_mint.read().into()
        }

        fn token_of_owner_by_index(
            self: @ContractState, owner: ContractAddress, index: u256
        ) -> u256 {
            self.owned_tokens.read((owner, index.try_into().unwrap())).into()
        }

        fn token_by_index(self: @ContractState, index: u256) -> u256 {
            // we don't have burnable feature
            index
        }
    }

    #[abi(embed_v0)]
    impl ERC721EnumerableCamelOnly of IERC721EnumerableCamelOnly<ContractState> {
        fn totalSupply(self: @ContractState) -> u256 {
            ERC721Enumerable::total_supply(self)
        }

        fn tokenOfOwnerByIndex(self: @ContractState, owner: ContractAddress, index: u256) -> u256 {
            ERC721Enumerable::token_of_owner_by_index(self, owner, index)
        }

        fn tokenByIndex(self: @ContractState, index: u256) -> u256 {
            ERC721Enumerable::token_by_index(self, index)
        }
    }

    // ------ cross chain ------

    #[l1_handler]
    fn relate(
        ref self: ContractState,
        from_address: felt252,
        id: u128,
        seed: u256,
        eth_account: felt252,
        starknet_account: felt252
    ) -> felt252 {
        assert(self.relater.read() == from_address, 'invalid relater');

        let starknet_account: ContractAddress = contract_address_try_from_felt252(starknet_account)
            .expect('invalid starknet address');

        self.emit(Related { from_address, id, seed, eth_account, starknet_account });

        self.seeds.write(id, seed);
        self.eth_owner.write(id, eth_account);

        from_address
    }

    // ------ ERC721 -------

    #[external(v0)]
    fn mint(ref self: ContractState) {
        // assert(self.last_mint.read() < 9000, 'Token sold out');
        // assert(!self.restricted.read(), 'Dungeon is restricted');

        let user = get_caller_address();
        let token_id = self.last_mint.read() + 1;
        let seed = generate_seed(token_id.into());
        self.last_mint.write(token_id);
        self.seeds.write(token_id, seed);

        self.erc721._mint(user, token_id.into());

        let index = self.erc721.balance_of(user);
        self.owned_tokens.write((user, index.try_into().unwrap()), token_id);
        self.owned_token_index.write(token_id, index.try_into().unwrap());

        let token_id: u256 = token_id.into();
        self.emit(Minted { account: user, token_id });
    }

    fn update_owner(
        ref self: ContractState, token_id: u128, from: ContractAddress, to: ContractAddress
    ) {
        let balance: u128 = self.erc721.balance_of(from).try_into().unwrap() + 1;
        let index_origin = self.owned_token_index.read(token_id);

        let mut insert = 0;
        if balance != index_origin + 1 {
            insert = self.owned_tokens.read((from, balance - 1));
            self.owned_tokens.write((from, balance - 1), 0);
            self.owned_token_index.write(insert, index_origin);
        }
        self.owned_tokens.write((from, index_origin), insert);

        let balance_to = self.erc721.balance_of(to).try_into().unwrap() - 1;
        self.owned_tokens.write((to, balance_to), token_id);

        self.owned_token_index.write(token_id, balance_to);
    }

    #[abi(embed_v0)]
    impl ERC721Impl of IERC721<ContractState> {
        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            if token_id <= 9000 {
                return contract_address_const::<0>();
            }
            self.erc721.owner_of(token_id)
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc721.balance_of(account)
        }

        fn safe_transfer_from(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) {
            self.erc721.safe_transfer_from(from, to, token_id, data);
            update_owner(ref self, token_id.try_into().unwrap(), from, to);
        }

        fn transfer_from(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256
        ) {
            self.erc721.transfer_from(from, to, token_id);
            update_owner(ref self, token_id.try_into().unwrap(), from, to);
        }

        fn approve(ref self: ContractState, to: ContractAddress, token_id: u256) {
            self.erc721.approve(to, token_id);
        }

        fn set_approval_for_all(
            ref self: ContractState, operator: ContractAddress, approved: bool
        ) {
            self.erc721.set_approval_for_all(operator, approved);
        }

        fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
            self.erc721.get_approved(token_id)
        }

        fn is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            self.erc721.is_approved_for_all(owner, operator)
        }
    }

    #[abi(embed_v0)]
    impl ERC721MetadataImpl of IERC721Metadata<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            self.erc721.name()
        }

        fn symbol(self: @ContractState) -> felt252 {
            self.erc721.symbol()
        }

        fn token_uri(self: @ContractState, token_id: u256) -> felt252 {
            self.erc721.token_uri(token_id)
        }
    }

    #[abi(embed_v0)]
    impl ERC721MetadataCamelOnlyImpl of IERC721MetadataCamelOnly<ContractState> {
        fn tokenURI(self: @ContractState, tokenId: u256) -> felt252 {
            self.erc721.token_uri(tokenId)
        }
    }

    #[abi(embed_v0)]
    impl ERC721CamelOnlyImpl of IERC721CamelOnly<ContractState> {
        fn ownerOf(self: @ContractState, tokenId: u256) -> ContractAddress {
            self.erc721.owner_of(tokenId)
        }

        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            self.erc721.balance_of(account)
        }

        fn getApproved(self: @ContractState, tokenId: u256) -> ContractAddress {
            self.erc721.get_approved(tokenId)
        }

        fn isApprovedForAll(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            self.erc721.is_approved_for_all(owner, operator)
        }

        fn setApprovalForAll(ref self: ContractState, operator: ContractAddress, approved: bool) {
            self.erc721.set_approval_for_all(operator, approved)
        }

        fn transferFrom(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, tokenId: u256
        ) {
            self.erc721.transfer_from(from, to, tokenId)
        }

        fn safeTransferFrom(
            ref self: ContractState,
            from: ContractAddress,
            to: ContractAddress,
            tokenId: u256,
            data: Span<felt252>
        ) {
            self.erc721.safe_transfer_from(from, to, tokenId, data)
        }
    }

    #[abi(embed_v0)]
    fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
        self.src5.supports_interface(interface_id)
    }

    #[abi(embed_v0)]
    fn supportsInterface(self: @ContractState, interfaceId: felt252) -> bool {
        supports_interface(self, interfaceId)
    }

    // ------ Dungeon -------

    #[abi(embed_v0)]
    impl CryptsAndCavernsTraitImpl of CryptsAndCavernsTrait<ContractState> {
        fn get_seed(self: @ContractState, token_id: u256) -> u256 {
            get_seed_in(self, token_id)
        }

        fn token_URI(self: @ContractState, token_id: u256) -> Array<felt252> {
            render_token_URI(self, token_id, self.generate_dungeon(token_id))
        }

        fn get_svg(self: @ContractState, token_id: u256) -> Array<felt252> {
            draw(self.generate_dungeon(token_id))
        }

        // we recommend to use this function
        fn generate_dungeon(self: @ContractState, token_id: u256) -> Dungeon {
            let seed = get_seed_in(self, token_id);
            let size = get_size_in(seed);
            generate_dungeon_in(seed, size)
        }

        fn get_size(self: @ContractState, token_id: u256) -> u128 {
            get_size_in(get_seed_in(self, token_id))
        }

        fn get_name(self: @ContractState, token_id: u256) -> (Array<felt252>, felt252, u8) {
            get_name_in(get_seed_in(self, token_id))
        }

        fn get_environment(self: @ContractState, token_id: u256) -> u8 {
            get_environment_in(get_seed_in(self, token_id))
        }
    }

    fn get_seed_in(self: @ContractState, token_id: u256) -> u256 {
        if token_id <= 9000 {
            let id: u128 = token_id.try_into().unwrap();
            let seed = if id < 2000 {
                SeedTraitDispatcher {
                    contract_address: contract_address_const::<
                        // goerli
                        // 0x072e8c6ba12603ce17059633bfadcd74882d2b23798e5d32afa1fb18953f4ec6
                        // sepolia
                        0x075ea500c4a2834406d979114a4c1be6fa0970869225b25de1672ecbb6d891ea
                    >()
                }
                    .get_seed(id)
            } else if id < 4000 {
                SeedTraitDispatcher {
                    contract_address: contract_address_const::<
                        // goerli
                        // 0x063540483c4518cb39cbf726c3189970d7dced3d48a3b27ebc15287c49f44b89
                        // sepolia
                        0x06f424fac78d406bd85368ee3fbcf7fd841a01a27466cfd025fa678050077e7f
                    >()
                }
                    .get_seed(id)
            } else if id < 6000 {
                SeedTraitDispatcher {
                    contract_address: contract_address_const::<
                        // goerli
                        // 0x043e183a544e31d5153579ab4c248b9b3e95271ac712f134602764927c44632e
                        // sepolia
                        0x01587c6e9e11ff05105ee6589d75e365f8970867f381098edf36bc3c4a948198
                    >()
                }
                    .get_seed(id)
            } else if id < 8000 {
                SeedTraitDispatcher {
                    contract_address: contract_address_const::<
                        // goerli
                        // 0x06f3d135ef77a047d93d1eeff37b4454d808dc641ef35068dd5fb7309a8e84a9
                        // sepolia
                        0x06847a741fd3a804d84dc41a3a5bfb6d4ffe4e1c620e2d71b80ee40157faeda1
                    >()
                }
                    .get_seed(id)
            } else {
                SeedTraitDispatcher {
                    contract_address: contract_address_const::<
                        // goerli
                        // 0x02801987e7bac5a597da1c573edd1beffe1daf2dc477c923e8d65b856cc29aeb
                        // sepolia
                        0x03facb2063078c16833d0649bf4d9f7079bb5dc7fdc7d19337b5cb5fdc76c637
                    >()
                }
                    .get_seed(id)
            };

            assert(seed != 0, 'invalid token id');
            seed
        } else {
            is_valid(self, token_id);
            self.seeds.read(token_id.try_into().unwrap())
        }
    }

    fn generate_dungeon_in(seed: u256, size: u128) -> Dungeon {
        let (layout, structure, points, doors) = generate_layout_and_entities(seed, size);
        let (mut dungeon_name, mut affinity, legendary) = get_name_in(seed);

        Dungeon {
            size: size.try_into().unwrap(),
            environment: get_environment_in(seed),
            structure: structure,
            legendary: legendary,
            layout: layout,
            doors: doors,
            points: points,
            affinity: affinity,
            dungeon_name: dungeon_name.span(),
        }
    }

    fn is_valid(self: @ContractState, token_id: u256) {
        if token_id > 9000 {
            assert(self.erc721._exists(token_id), 'Valid token');
        }
    }

    // --------------------------------------------- Seeder --------------------------------------------

    // for testnet only
    fn generate_seed(token_id: u256) -> u256 {
        let block_time = starknet::get_block_timestamp();
        let b_u256_time: u256 = block_time.into();
        let input = array![b_u256_time, token_id];
        let seed = keccak::keccak_u256s_be_inputs(input.span());
        seed
    }

    fn get_size_in(seed: u256) -> u128 {
        random(seed.left_shift(4), 8, 25)
    }

    fn get_environment_in(seed: u256) -> u8 {
        let rand = random(seed.left_shift(8), 0, 100);

        if rand >= 70 {
            0
        } else if rand >= 45 {
            1
        } else if rand >= 25 {
            2
        } else if rand >= 13 {
            3
        } else if rand >= 4 {
            4
        } else {
            5
        }
    }

    fn get_name_in(seed: u256) -> (Array<felt252>, felt252, u8) {
        // 'get_name'.print();
        let unique_seed = random(seed.left_shift(15), 0, 10000);

        let mut name_parts = ArrayTrait::<felt252>::new();
        let mut affinity = 'none';
        let mut legendary = 0;

        if (unique_seed < 17) {
            // Unique name
            legendary = 1;
            name_parts.append(get_unique(unique_seed));
        } else {
            let base_seed = random(seed.left_shift(16), 0, 38);

            if unique_seed <= 300 {
                // Person's Name + Base Land
                let people_seed = random(seed.left_shift(23), 0, 12);

                name_parts.append(get_people(people_seed));
                name_parts.append(' ');
                name_parts.append(get_land(base_seed));
            } else if unique_seed <= 1800 {
                // Prefix + Base Land + Suffix
                let suffixs_random = random(seed.left_shift(27), 0, 59);
                affinity = get_suffixes(suffixs_random);
                name_parts.append(get_prefix(random(seed.left_shift(42), 0, 29)));
                name_parts.append(' ');
                name_parts.append(get_land(base_seed));
                name_parts.append(' of ');
                name_parts.append(affinity);
            } else if unique_seed <= 4000 {
                // Base Land + Suffix
                affinity = get_suffixes(random(seed.left_shift(51), 0, 59));
                name_parts.append(get_land(base_seed));
                name_parts.append(' of ');
                name_parts.append(affinity);
            } else if unique_seed <= 6500 {
                // Prefix + Base Land
                name_parts.append(get_prefix(random(seed.left_shift(59), 0, 29)));
                name_parts.append(' ');
                name_parts.append(get_land(base_seed));
            } else {
                // Base Land
                name_parts.append(get_land(base_seed));
            }
        };
        return (name_parts, affinity, legendary);
    }

    fn get_prefix(input: u128) -> felt252 {
        if input == 0 {
            return 'Abyssal';
        } else if input == 1 {
            return 'Ancient';
        } else if input == 2 {
            return 'Bleak';
        } else if input == 3 {
            return 'Bright';
        } else if input == 4 {
            return 'Burning';
        } else if input == 5 {
            return 'Collapsed';
        } else if input == 6 {
            return 'Corrupted';
        } else if input == 7 {
            return 'Dark';
        } else if input == 8 {
            return 'Decrepid';
        } else if input == 9 {
            return 'Desolate';
        } else if input == 10 {
            return 'Dire';
        } else if input == 11 {
            return 'Divine';
        } else if input == 12 {
            return 'Emerald';
        } else if input == 13 {
            return 'Empyrean';
        } else if input == 14 {
            return 'Fallen';
        } else if input == 15 {
            return 'Glowing';
        } else if input == 16 {
            return 'Grim';
        } else if input == 17 {
            return 'Heaven\'s';
        } else if input == 18 {
            return 'Hidden';
        } else if input == 19 {
            return 'Holy';
        } else if input == 20 {
            return 'Howling';
        } else if input == 21 {
            return 'Inner';
        } else if input == 22 {
            return 'Morbid';
        } else if input == 23 {
            return 'Murky';
        } else if input == 24 {
            return 'Outer';
        } else if input == 25 {
            return 'Shimmering';
        } else if input == 26 {
            return 'Siren\'s';
        } else if input == 27 {
            return 'Sunken';
        } else // if input == 28
        {
            return 'Whispering';
        }
    }

    fn get_land(input: u128) -> felt252 {
        if input == 0 {
            return 'Canyon';
        } else if input == 1 {
            return 'Catacombs';
        } else if input == 2 {
            return 'Cavern';
        } else if input == 3 {
            return 'Chamber';
        } else if input == 4 {
            return 'Cloister';
        } else if input == 5 {
            return 'Crypt';
        } else if input == 6 {
            return 'Den';
        } else if input == 7 {
            return 'Dunes';
        } else if input == 8 {
            return 'Field';
        } else if input == 9 {
            return 'Forest';
        } else if input == 10 {
            return 'Glade';
        } else if input == 11 {
            return 'Gorge';
        } else if input == 12 {
            return 'Graveyard';
        } else if input == 13 {
            return 'Grotto';
        } else if input == 14 {
            return 'Grove';
        } else if input == 15 {
            return 'Halls';
        } else if input == 16 {
            return 'Keep';
        } else if input == 17 {
            return 'Lair';
        } else if input == 18 {
            return 'Labyrinth';
        } else if input == 19 {
            return 'Landing';
        } else if input == 20 {
            return 'Maze';
        } else if input == 21 {
            return 'Mountain';
        } else if input == 22 {
            return 'Necropolis';
        } else if input == 23 {
            return 'Oasis';
        } else if input == 24 {
            return 'Passage';
        } else if input == 25 {
            return 'Peak';
        } else if input == 26 {
            return 'Prison';
        } else if input == 27 {
            return 'Scar';
        } else if input == 28 {
            return 'Sewers';
        } else if input == 29 {
            return 'Shrine';
        } else if input == 30 {
            return 'Sound';
        } else if input == 31 {
            return 'Steppes';
        } else if input == 32 {
            return 'Temple';
        } else if input == 33 {
            return 'Tundra';
        } else if input == 34 {
            return 'Tunnel';
        } else if input == 35 {
            return 'Valley';
        } else if input == 36 {
            return 'Waterfall';
        } else // if input ==37
        {
            return 'Woods';
        }
    }

    fn get_suffixes(input: u128) -> felt252 {
        if input == 0 {
            return 'Agony';
        } else if input == 1 {
            return 'Anger';
        } else if input == 2 {
            return 'Blight';
        } else if input == 3 {
            return 'Bone';
        } else if input == 4 {
            return 'Brilliance';
        } else if input == 5 {
            return 'Brimstone';
        } else if input == 6 {
            return 'Corruption';
        } else if input == 7 {
            return 'Despair';
        } else if input == 8 {
            return 'Dread';
        } else if input == 9 {
            return 'Dusk';
        } else if input == 10 {
            return 'Enlightenment';
        } else if input == 11 {
            return 'Fury';
        } else if input == 12 {
            return 'Fire';
        } else if input == 13 {
            return 'Giants';
        } else if input == 14 {
            return 'Gloom';
        } else if input == 15 {
            return 'Hate';
        } else if input == 16 {
            return 'Havoc';
        } else if input == 17 {
            return 'Honour';
        } else if input == 18 {
            return 'Horror';
        } else if input == 19 {
            return 'Loathing';
        } else if input == 20 {
            return 'Mire';
        } else if input == 21 {
            return 'Mist';
        } else if input == 22 {
            return 'Needles';
        } else if input == 23 {
            return 'Pain';
        } else if input == 24 {
            return 'Pandemonium';
        } else if input == 25 {
            return 'Pine';
        } else if input == 26 {
            return 'Rage';
        } else if input == 27 {
            return 'Rapture';
        } else if input == 28 {
            return 'Sand';
        } else if input == 29 {
            return 'Sorrow';
        } else if input == 30 {
            return 'the Apocalypse';
        } else if input == 31 {
            return 'the Beast';
        } else if input == 32 {
            return 'the Behemoth';
        } else if input == 33 {
            return 'the Brood';
        } else if input == 34 {
            return 'the Fox';
        } else if input == 35 {
            return 'the Gale';
        } else if input == 36 {
            return 'the Golem';
        } else if input == 37 {
            return 'the Kraken';
        } else if input == 38 {
            return 'the Leech';
        } else if input == 39 {
            return 'the Moon';
        } else if input == 40 {
            return 'the Phoenix';
        } else if input == 41 {
            return 'the Plague';
        } else if input == 42 {
            return 'the Root';
        } else if input == 43 {
            return 'the Song';
        } else if input == 44 {
            return 'the Stars';
        } else if input == 45 {
            return 'the Storm';
        } else if input == 46 {
            return 'the Sun';
        } else if input == 47 {
            return 'the Tear';
        } else if input == 48 {
            return 'the Titans';
        } else if input == 49 {
            return 'the Twins';
        } else if input == 50 {
            return 'the Willows';
        } else if input == 51 {
            return 'the Wisp';
        } else if input == 52 {
            return 'the Viper';
        } else if input == 53 {
            return 'the Vortex';
        } else if input == 54 {
            return 'Torment';
        } else if input == 55 {
            return 'Vengeance';
        } else if input == 56 {
            return 'Victory';
        } else if input == 57 {
            return 'Woe';
        } else if input == 58 {
            return 'Wisdom';
        } else // if input == 59
        {
            return 'Wrath';
        }
    }

    fn get_unique(input: u128) -> felt252 {
        if input == 0 {
            return '\'Armageddon\'';
        } else if input == 1 {
            return '\'Mind\'s Eye\'';
        } else if input == 2 {
            return '\'Nostromo\'';
        } else if input == 3 {
            return '\'Oblivion\'';
        } else if input == 4 {
            return '\'The Chasm\'';
        } else if input == 5 {
            return '\'The Crypt\'';
        } else if input == 6 {
            return '\'The Depths\'';
        } else if input == 7 {
            return '\'The End\'';
        } else if input == 8 {
            return '\'The Expanse\'';
        } else if input == 9 {
            return '\'The Gale\'';
        } else if input == 10 {
            return '\'The Hook\'';
        } else if input == 11 {
            return '\'The Maelstrom\'';
        } else if input == 12 {
            return '\'The Mouth\'';
        } else if input == 13 {
            return '\'The Muck\'';
        } else if input == 14 {
            return '\'The Shelf\'';
        } else if input == 15 {
            return '\'The Vale\'';
        } else //  if input == 16
        {
            return '\'The Veldt\'';
        }
    }

    fn get_people(input: u128) -> felt252 {
        if input == 0 {
            return 'Fate\'s';
        } else if input == 1 {
            return 'Fohd\'s';
        } else if input == 2 {
            return 'Gremp\'s';
        } else if input == 3 {
            return 'Hate\'s';
        } else if input == 4 {
            return 'Kali\'s';
        } else if input == 5 {
            return 'Kiv\'s';
        } else if input == 6 {
            return 'Light\'s';
        } else if input == 7 {
            return 'Shub\'s';
        } else if input == 8 {
            return 'Sol\'s';
        } else if input == 9 {
            return 'Tish\'s';
        } else if input == 10 {
            return 'Viper\'s';
        } else // if input == 11
        {
            return 'Woe\'s';
        }
    }

    fn get_environment_name(input: u8) -> felt252 {
        if input == 0 {
            return 'Desert Oasis';
        } else if input == 1 {
            return 'Stone Temple';
        } else if input == 2 {
            return 'Forest Ruins';
        } else if input == 3 {
            return 'Mountain Deep';
        } else if input == 4 {
            return 'Underwater Keep';
        } else // if input == 5
        {
            return 'Embers Glow';
        }
    }

    fn get_color(input: u8) -> felt252 {
        if input == 0 {
            return 'F3D899"/>';
        } else if input == 1 {
            return '160F09"/>';
        } else if input == 2 {
            return 'FAAA00"/>';
        } else if input == 3 {
            return '00A29D"/>';
        } else if input == 4 {
            return '967E67"/>';
        } else if input == 5 {
            return 'F3D899"/>';
        } else if input == 6 {
            return '3C2A1A"/>';
        } else if input == 7 {
            return '006669"/>';
        } else if input == 8 {
            return '2F590E"/>';
        } else if input == 9 {
            return 'A98C00"/>';
        } else if input == 10 {
            return '802F1A"/>';
        } else if input == 11 {
            return 'C55300"/>';
        } else if input == 12 {
            return '36230F"/>';
        } else if input == 13 {
            return '744936"/>';
        } else if input == 14 {
            return '802F1A"/>';
        } else if input == 15 {
            return 'FFA800"/>';
        } else if input == 16 {
            return '006669"/>';
        } else if input == 17 {
            return '004238"/>';
        } else if input == 18 {
            return '967E67"/>';
        } else if input == 19 {
            return 'F9B569"/>';
        } else if input == 20 {
            return '340D07"/>';
        } else if input == 21 {
            return '5D0503"/>';
        } else if input == 22 {
            return 'B75700"/>';
        } else //  if input == 23
        {
            return 'FF1800"/>';
        }
    }

    // --------------------------------------------- Render --------------------------------------------

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
            let temp = num % 10;
            part.append((temp + 48).into());
            num /= 10;
            append_number(part, num)
        } else {
            part
        }
    }

    fn draw(dungeon: Dungeon) -> Array<felt252> {
        // Hardcoded to save memory: Width = 100
        // Setup SVG and draw our background
        // We write at 100x100 and scale it 5x to 500x500 to avoid safari small rendering
        let mut parts: Array<felt252> = ArrayTrait::new();
        parts.append('<svg xmlns=');
        parts.append('"http://www.w3.org/2000/svg"');
        parts.append('preserveAspectRatio=');
        parts.append('"xMinYMin meet"');
        parts.append('viewBox="0 0 500 500"');
        parts.append('shape-rendering="crispEdges"');
        parts.append('transform-origin="center">');
        parts.append('<rect width="100%"');
        parts.append('height="100%"fill="#');
        parts.append(get_color(dungeon.environment * 4));

        parts = draw_name_plate(parts, dungeon.dungeon_name);
        let (start, pixel) = get_width(dungeon.size);
        let mut helper: RenderHelper = RenderHelper {
            pixel: pixel,
            start: start,
            layout: dungeon.layout,
            parts: array![].span(),
            counter: 0,
            num_rects: 0,
            last_start: 0
        };

        parts = append(parts, (chunk_dungeon(dungeon, ref helper)).span());
        parts = append(parts, draw_entities(dungeon, helper).span());
        parts.append('</svg>');

        parts
    }

    fn chunk_dungeon(dungeon: Dungeon, ref helper: RenderHelper) -> Array<felt252> {
        let mut layout = dungeon.layout;
        let mut parts: Array<felt252> = ArrayTrait::new();

        let mut y = 0;
        loop {
            if y == dungeon.size {
                break;
            }

            helper.last_start = helper.counter;
            let mut row_parts: Array<felt252> = ArrayTrait::new();

            let mut x = 0;
            loop {
                if x == dungeon.size {
                    break;
                }

                if layout.get_bit(helper.counter)
                    && helper.counter > 0
                    && !layout.get_bit(helper.counter - 1) {
                    helper.num_rects += 1;

                    row_parts =
                        draw_tile(
                            row_parts,
                            helper.start + (helper.last_start % dungeon.size.into()) * helper.pixel,
                            helper.start + (helper.last_start / dungeon.size.into()) * helper.pixel,
                            (helper.counter - helper.last_start) * helper.pixel,
                            helper.pixel,
                            get_color(dungeon.environment * 4 + 1)
                        );
                } else if !layout.get_bit(helper.counter)
                    && helper.counter > 0
                    && layout.get_bit(helper.counter - 1) {
                    helper.last_start = helper.counter;
                }

                helper.counter += 1;
                x += 1;
            };

            if !layout.get_bit(helper.counter - 1) {
                helper.num_rects += 1;
                row_parts =
                    draw_tile(
                        row_parts,
                        helper.start + (helper.last_start % dungeon.size.into()) * helper.pixel,
                        helper.start + (helper.last_start / dungeon.size.into()) * helper.pixel,
                        (helper.counter - helper.last_start) * helper.pixel,
                        helper.pixel,
                        get_color(dungeon.environment * 4 + 1)
                    );
            }

            parts = append(parts, row_parts.span());
            y += 1;
        };

        parts
    }

    fn draw_name_plate(mut parts: Array<felt252>, name: Span<felt252>) -> Array<felt252> {
        let mut name_length = count_length(name);

        let mut font_size = 0;
        let mut multiplier = 0;
        if name_length <= 25 {
            font_size = 5;
            multiplier = 3;
        } else {
            font_size = 4;
            multiplier = 2;
            name_length += 7;
        }

        parts.append('<g transform="scale ');
        parts.append('(5 5)"><rect x="');
        parts = append_number_ascii(parts, (100 - ((name_length + 3) * multiplier)) / 2);
        parts.append('"y="-1"width="');
        parts = append_number_ascii(parts, (name_length + 3) * multiplier);
        parts.append('"height="9"stroke-width="0.3"');
        parts.append('stroke="black"fill="#FFA800"/>');

        parts.append('<text x="50"y="5.5"width="');
        parts = append_number_ascii(parts, name_length * 3);
        parts.append('"font-family="monospace"');
        parts.append('font-size="');
        parts = append_number_ascii(parts, font_size);
        parts.append('"text-anchor="middle">');
        parts = append(parts, name);
        parts.append('</text></g>');

        parts
    }

    // Draw each entity as a pixel on the map
    fn draw_entities(dungeon: Dungeon, helper: RenderHelper) -> Array<felt252> {
        let mut parts: Array<felt252> = ArrayTrait::new();

        let (x, y, entity_type) = parse_entities(
            dungeon.size.into(), dungeon.points, dungeon.doors
        );

        let mut i: usize = 0;
        loop {
            if i == entity_type.len() {
                break;
            }
            let x = helper.start + (*x[i] % dungeon.size).into() * helper.pixel;
            let y = helper.start + (*y[i]).into() * helper.pixel;
            let color_index: u8 = dungeon.environment * 4 + 2 + *entity_type[i];
            let color: felt252 = get_color(color_index);
            parts = draw_tile(parts, x, y, helper.pixel, helper.pixel, color);

            i += 1;
        };
        parts
    }

    fn draw_tile(
        mut tile: Array<felt252>, x: u128, y: u128, width: u128, pixel: u128, color: felt252
    ) -> Array<felt252> {
        tile.append('<rect x="');
        tile = append_number_ascii(tile, x);
        tile.append('"y="');
        tile = append_number_ascii(tile, y);
        tile.append('"width="');
        tile = append_number_ascii(tile, width);
        tile.append('"height="');
        tile = append_number_ascii(tile, pixel);
        tile.append('"fill="#');
        tile.append(color);

        tile
    }

    fn get_width(size: u8) -> (u128, u128) {
        let size = size.into();
        let pixel = 500 / (size + 3 * 2);
        let start = (500 - pixel * size) / 2;
        (start, pixel)
    }

    fn count_length(parts: Span<felt252>) -> u128 {
        let limit = parts.len();
        let mut length = 0;
        let mut count = 0;
        loop {
            if count == limit {
                break;
            }
            let mut part: u256 = (*parts[count]).into();
            loop {
                if part == 0 {
                    break;
                }
                part = part.right_shift(8);
                length += 1;
            };
            count += 1;
        };
        length
    }

    fn append(mut parts: Array<felt252>, mut to_add: Span<felt252>) -> Array<felt252> {
        let pop = to_add.pop_front();

        if (match pop {
            Option::Some(_) => true,
            Option::None => false
        }) {
            parts.append(*pop.unwrap());
            append(parts, to_add)
        } else {
            parts
        }
    }

    fn render_token_URI(self: @ContractState, tokenId: u256, dungeon: Dungeon) -> Array<felt252> {
        let points = dungeon.points.count_bit();
        let doors = dungeon.doors.count_bit();

        // Generate dungeon
        let mut output = draw(dungeon);

        // Base64 Encode svg and output
        let mut json: Array<felt252> = ArrayTrait::new();
        json.append('data:application/json,');
        json.append('{"name": "Crypts and Caverns #');
        json.append(tokenId.try_into().unwrap());
        json.append('", "description": "Crypts and ');
        json.append('Caverns is an onchain map ');
        json.append('generator that produces an ');
        json.append('infinite set of dungeons. ');
        json.append('Enemies, treasure, etc ');
        json.append('intentionally omitted for');
        json.append(' others to interpret. ');
        json.append('Feel free to use Crypts and ');
        json.append('Caverns in any way you want."');
        json.append(', "attributes": [ {');
        json.append('"trait_type": "name", ');
        json.append('"value": "');
        json = append(json, dungeon.dungeon_name);
        json.append('"}, {"trait_type": ');
        json.append('"size", "value": "');
        json.append(dungeon.size.into());
        json.append('"}, {"trait_type": ');
        json.append('"environment", "value": "');
        json.append(get_environment_name(dungeon.environment));
        json.append('"}, {"trait_type": ');
        json.append('"doors", "value": "');
        json.append(doors.into());
        json.append('"}, {"trait_type": ');
        json.append('"points of interest",');
        json.append(' "value": "');
        json.append(points.into());
        json.append('"}, {"trait_type":');
        json.append(' "affinity", "value": "');
        json.append(dungeon.affinity);
        json.append('"}, {"trait_type":');
        json.append(' "legendary", "value": "');
        if (dungeon.legendary == 1) {
            json.append('Yes');
        } else {
            json.append('No');
        }
        if (dungeon.structure == 0) {
            json.append('Crypt');
        } else {
            json.append('Cavern');
        }
        json.append('"}],"image":');
        // json.append(' "data:image/svg+xml;base64,');
        // TODO base64 encode svg

        json = append(json, output.span());
        json.append('}');

        // TODO base64 encode json

        // output.append('data:application/json;base64,');
        // output.append(json);

        json
    }
    // ------------------------------------------ Constructor ------------------------------------------

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc721.initializer('C&C', 'C&C');

        self.restricted.write(false);
        self.last_mint.write(9000);

        self.ownable.initializer(owner);
    }
}

#[cfg(test)]
mod test {
    use super::Dungeons::{generate_layout_and_entities, generate_dungeon_in, draw, get_size_in};

    const seed: u256 = 0xab485c48aba348d1e42c3d22e5ec6a706955dcfeed58a238b94da3e0cfe9ef25;

    #[test]
    fn test() {
        generate_layout_and_entities(seed, get_size_in(seed));
    }

    #[test]
    fn test1() {
        draw(generate_dungeon_in(seed, get_size_in(seed)));
    }
}
