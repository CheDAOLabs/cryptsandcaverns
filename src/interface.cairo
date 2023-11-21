use starknet::{ContractAddress, contract_address_const};
use super::Dungeons::{DungeonSerde, DungeonDojo, EntityDataSerde, Pack};

#[starknet::interface]
trait CryptsAndCavernsTrait<TContractState> {
    // trait IERC721Metadata<TContractState> 
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn token_uri(self: @TContractState, token_id: u256) -> Array<felt252>;

    // trait IERC721MetadataCamelOnly<TContractState> 
    fn tokenURI(self: @TContractState, tokenId: u256) -> Array<felt252>;

    // trait IERC721Enumerable<TContractState> 
    fn total_supply(self: @TContractState) -> u256;
    fn token_by_index(self: @TContractState, index: u256) -> u256;
    fn token_of_owner_by_index(self: @TContractState, owner: ContractAddress, index: u256) -> u256;

    // trait IERC721EnumerableCamelOnly<TContractState> 
    fn totalSupply(self: @TContractState) -> u256;
    fn tokenByIndex(self: @TContractState, index: u256) -> u256;
    fn tokenOfOwnerByIndex(self: @TContractState, owner: ContractAddress, index: u256) -> u256;

    // trait IERC721<TContractState> 
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256
    );
    fn safe_transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    );
    fn approve(ref self: TContractState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TContractState, owner: ContractAddress, operator: ContractAddress
    ) -> bool;

    // trait IERC721CamelOnly<TContractState> 
    fn balanceOf(self: @TContractState, account: ContractAddress) -> u256;
    fn ownerOf(self: @TContractState, tokenId: u256) -> ContractAddress;
    fn transferFrom(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, tokenId: u256
    );
    fn safeTransferFrom(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        tokenId: u256,
        data: Span<felt252>
    );
    fn setApprovalForAll(ref self: TContractState, operator: ContractAddress, approved: bool);
    fn getApproved(self: @TContractState, tokenId: u256) -> ContractAddress;
    fn isApprovedForAll(
        self: @TContractState, owner: ContractAddress, operator: ContractAddress
    ) -> bool;

    // map trait
    fn get_seeds(self: @TContractState, token_id: u256) -> u256;
    fn token_URI(self: @TContractState, token_id: u256) -> Array<felt252>;
    fn get_svg(self: @TContractState, token_id: u256) -> Array<felt252>;
    fn generate_dungeon(self: @TContractState, token_id: u256) -> DungeonSerde;
    fn generate_dungeon_dojo(self: @TContractState, token_id: u256) -> DungeonDojo;
    fn get_entities(self: @TContractState, token_id: u256) -> EntityDataSerde;
    fn get_layout(self: @TContractState, seed: u256, size: u128) -> (Pack, u8);
    fn get_size(self: @TContractState, token_id: u256) -> u128;
    fn get_name(self: @TContractState, token_id: u256) -> (Array<felt252>, felt252, u8);
}
