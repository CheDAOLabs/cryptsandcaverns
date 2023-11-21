#[starknet::contract]
mod Example {

    use core::array::ArrayTrait;
    use core::array::SpanTrait;
    use starknet::{ContractAddress, contract_address_const};
    // base import
    use cc_starknet::{
        interface::{CryptsAndCavernsTraitDispatcher, CryptsAndCavernsTraitDispatcherTrait},
        Dungeons::{DungeonSerde, DungeonDojo, Name, EntityDataSerde}
    };
    use cc_starknet::utils::pack::{Pack, PackTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn get_points_(self: @ContractState, token_id: u256) -> Pack {
        // you can get the contract address in C&C's README.md
        // this way building ContractAddress just supports literal input
        let dungeon: DungeonDojo = CryptsAndCavernsTraitDispatcher {
            contract_address: contract_address_const::<
                0x056834208d6a7cc06890a80ce523b5776755d68e960273c9ef3659b5f74fa494
            >()
        }.generate_dungeon_dojo(token_id);

        dungeon.points
    }

    #[external(v0)]
    fn get_points(self: @ContractState, token_id: u256) -> (Array<u8>, Array<u8>) {
        // you can get the contract address in C&C's README.md
        // this way building ContractAddress just supports literal input
        let dungeon: DungeonSerde = CryptsAndCavernsTraitDispatcher {
            contract_address: contract_address_const::<
                0x056834208d6a7cc06890a80ce523b5776755d68e960273c9ef3659b5f74fa494
            >()
        }.generate_dungeon(token_id);

        let mut x: Array<u8> = ArrayTrait::new();
        let mut y: Array<u8> = ArrayTrait::new();
        let entity: EntityDataSerde = dungeon.entities;

        let count = entity.entity_data.len();
        let mut i = 0;
        loop {
            if i == count {
                break;
            }

            if *(entity.entity_data)[i] == 1 {
                x.append(*(entity.entity_data)[i]);
                y.append(*(entity.entity_data)[i]);
            }

            i += 1;
        };

        (x, y)
    }

}
