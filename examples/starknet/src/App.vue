<template>
  <div id="app">

    <el-card class="box-card" style="width: 400px;margin-left: auto;margin-right: auto;margin-top: 50px">
      <template #header>
        <div class="card-header">
          <span style="font-size: 30px">C&C Example</span>
          <el-button class="button" plain type="primary" @click="connect">
            {{
              wallet_address == null ? "Connect Wallet" : wallet_address.toString().substr(0, 10) + "..." + wallet_address.toString().substr(wallet_address.length - 4, 4)
            }}
          </el-button>
        </div>
      </template>
      <!--      <div style="float: right;margin-top: 10px;margin-right: 10px">-->
      <!--        <el-button type="primary" plain @click="connect">Connect Wallet</el-button>-->
      <!--      </div>-->
      <!--      <div style="clear: both"></div>-->
      <!--      <br/>-->
      <!--      <br/>-->
      <!--    <img alt="Vue logo" src="./assets/logo.png">-->
      <el-input-number v-model="token_id" :min="1" :max="1000000" @change="handleChange"/>

      <div style="color: white;font-size: 24px;font-family: VT323;margin-top: 10px"> {{ name }}</div>
      <div class="container"
           style="  overflow: hidden;margin-top: 10px;background-color: black;color:white;border: 1px;border-color:white;display: flex;align-items: center;    justify-content: center;"
           v-loading="loading">
        <pre style="color: white">{{ dungeon_string }}</pre>
      </div>
      <div class="container" style="background-color: red;margin-top: 10px" v-loading="loading_svg">
        <div v-html="svg"></div>
      </div>
      <div style="margin-top: 10px">
        <el-button type="danger" plain @click="mint">MINT</el-button>
      </div>
    </el-card>


  </div>
</template>

<script>
import {ElMessage} from 'element-plus'
import {Contract,  Provider, shortString} from "starknet";
import {connect} from "@argent/get-starknet"
import {useRoute} from 'vue-router';

const abi = [
  {
    "name": "ERC721Enumerable",
    "type": "impl",
    "interface_name": "cc_starknet::IERC721Enumerable"
  },
  {
    "name": "core::integer::u256",
    "type": "struct",
    "members": [
      {
        "name": "low",
        "type": "core::integer::u128"
      },
      {
        "name": "high",
        "type": "core::integer::u128"
      }
    ]
  },
  {
    "name": "cc_starknet::IERC721Enumerable",
    "type": "interface",
    "items": [
      {
        "name": "total_supply",
        "type": "function",
        "inputs": [],
        "outputs": [
          {
            "type": "core::integer::u256"
          }
        ],
        "state_mutability": "view"
      },
      {
        "name": "token_by_index",
        "type": "function",
        "inputs": [
          {
            "name": "index",
            "type": "core::integer::u256"
          }
        ],
        "outputs": [
          {
            "type": "core::integer::u256"
          }
        ],
        "state_mutability": "view"
      },
      {
        "name": "token_of_owner_by_index",
        "type": "function",
        "inputs": [
          {
            "name": "owner",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "index",
            "type": "core::integer::u256"
          }
        ],
        "outputs": [
          {
            "type": "core::integer::u256"
          }
        ],
        "state_mutability": "view"
      }
    ]
  },
  {
    "name": "ERC721EnumerableCamelOnly",
    "type": "impl",
    "interface_name": "cc_starknet::IERC721EnumerableCamelOnly"
  },
  {
    "name": "cc_starknet::IERC721EnumerableCamelOnly",
    "type": "interface",
    "items": [
      {
        "name": "totalSupply",
        "type": "function",
        "inputs": [],
        "outputs": [
          {
            "type": "core::integer::u256"
          }
        ],
        "state_mutability": "view"
      },
      {
        "name": "tokenByIndex",
        "type": "function",
        "inputs": [
          {
            "name": "index",
            "type": "core::integer::u256"
          }
        ],
        "outputs": [
          {
            "type": "core::integer::u256"
          }
        ],
        "state_mutability": "view"
      },
      {
        "name": "tokenOfOwnerByIndex",
        "type": "function",
        "inputs": [
          {
            "name": "owner",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "index",
            "type": "core::integer::u256"
          }
        ],
        "outputs": [
          {
            "type": "core::integer::u256"
          }
        ],
        "state_mutability": "view"
      }
    ]
  },
  {
    "name": "ERC721Impl",
    "type": "impl",
    "interface_name": "openzeppelin::token::erc721::interface::IERC721"
  },
  {
    "name": "core::array::Span::<core::felt252>",
    "type": "struct",
    "members": [
      {
        "name": "snapshot",
        "type": "@core::array::Array::<core::felt252>"
      }
    ]
  },
  {
    "name": "core::bool",
    "type": "enum",
    "variants": [
      {
        "name": "False",
        "type": "()"
      },
      {
        "name": "True",
        "type": "()"
      }
    ]
  },
  {
    "name": "openzeppelin::token::erc721::interface::IERC721",
    "type": "interface",
    "items": [
      {
        "name": "balance_of",
        "type": "function",
        "inputs": [
          {
            "name": "account",
            "type": "core::starknet::contract_address::ContractAddress"
          }
        ],
        "outputs": [
          {
            "type": "core::integer::u256"
          }
        ],
        "state_mutability": "view"
      },
      {
        "name": "owner_of",
        "type": "function",
        "inputs": [
          {
            "name": "token_id",
            "type": "core::integer::u256"
          }
        ],
        "outputs": [
          {
            "type": "core::starknet::contract_address::ContractAddress"
          }
        ],
        "state_mutability": "view"
      },
      {
        "name": "transfer_from",
        "type": "function",
        "inputs": [
          {
            "name": "from",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "to",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "token_id",
            "type": "core::integer::u256"
          }
        ],
        "outputs": [],
        "state_mutability": "external"
      },
      {
        "name": "safe_transfer_from",
        "type": "function",
        "inputs": [
          {
            "name": "from",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "to",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "token_id",
            "type": "core::integer::u256"
          },
          {
            "name": "data",
            "type": "core::array::Span::<core::felt252>"
          }
        ],
        "outputs": [],
        "state_mutability": "external"
      },
      {
        "name": "approve",
        "type": "function",
        "inputs": [
          {
            "name": "to",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "token_id",
            "type": "core::integer::u256"
          }
        ],
        "outputs": [],
        "state_mutability": "external"
      },
      {
        "name": "set_approval_for_all",
        "type": "function",
        "inputs": [
          {
            "name": "operator",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "approved",
            "type": "core::bool"
          }
        ],
        "outputs": [],
        "state_mutability": "external"
      },
      {
        "name": "get_approved",
        "type": "function",
        "inputs": [
          {
            "name": "token_id",
            "type": "core::integer::u256"
          }
        ],
        "outputs": [
          {
            "type": "core::starknet::contract_address::ContractAddress"
          }
        ],
        "state_mutability": "view"
      },
      {
        "name": "is_approved_for_all",
        "type": "function",
        "inputs": [
          {
            "name": "owner",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "operator",
            "type": "core::starknet::contract_address::ContractAddress"
          }
        ],
        "outputs": [
          {
            "type": "core::bool"
          }
        ],
        "state_mutability": "view"
      }
    ]
  },
  {
    "name": "ERC721MetadataImpl",
    "type": "impl",
    "interface_name": "cc_starknet::IERC721Metadata"
  },
  {
    "name": "cc_starknet::IERC721Metadata",
    "type": "interface",
    "items": [
      {
        "name": "name",
        "type": "function",
        "inputs": [],
        "outputs": [
          {
            "type": "core::felt252"
          }
        ],
        "state_mutability": "view"
      },
      {
        "name": "symbol",
        "type": "function",
        "inputs": [],
        "outputs": [
          {
            "type": "core::felt252"
          }
        ],
        "state_mutability": "view"
      },
      {
        "name": "token_uri",
        "type": "function",
        "inputs": [
          {
            "name": "token_id",
            "type": "core::integer::u256"
          }
        ],
        "outputs": [
          {
            "type": "core::array::Array::<core::felt252>"
          }
        ],
        "state_mutability": "view"
      }
    ]
  },
  {
    "name": "ERC721MetadataCamelOnlyImpl",
    "type": "impl",
    "interface_name": "cc_starknet::IERC721MetadataCamelOnly"
  },
  {
    "name": "cc_starknet::IERC721MetadataCamelOnly",
    "type": "interface",
    "items": [
      {
        "name": "tokenURI",
        "type": "function",
        "inputs": [
          {
            "name": "tokenId",
            "type": "core::integer::u256"
          }
        ],
        "outputs": [
          {
            "type": "core::array::Array::<core::felt252>"
          }
        ],
        "state_mutability": "view"
      }
    ]
  },
  {
    "name": "ERC721CamelOnlyImpl",
    "type": "impl",
    "interface_name": "openzeppelin::token::erc721::interface::IERC721CamelOnly"
  },
  {
    "name": "openzeppelin::token::erc721::interface::IERC721CamelOnly",
    "type": "interface",
    "items": [
      {
        "name": "balanceOf",
        "type": "function",
        "inputs": [
          {
            "name": "account",
            "type": "core::starknet::contract_address::ContractAddress"
          }
        ],
        "outputs": [
          {
            "type": "core::integer::u256"
          }
        ],
        "state_mutability": "view"
      },
      {
        "name": "ownerOf",
        "type": "function",
        "inputs": [
          {
            "name": "tokenId",
            "type": "core::integer::u256"
          }
        ],
        "outputs": [
          {
            "type": "core::starknet::contract_address::ContractAddress"
          }
        ],
        "state_mutability": "view"
      },
      {
        "name": "transferFrom",
        "type": "function",
        "inputs": [
          {
            "name": "from",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "to",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "tokenId",
            "type": "core::integer::u256"
          }
        ],
        "outputs": [],
        "state_mutability": "external"
      },
      {
        "name": "safeTransferFrom",
        "type": "function",
        "inputs": [
          {
            "name": "from",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "to",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "tokenId",
            "type": "core::integer::u256"
          },
          {
            "name": "data",
            "type": "core::array::Span::<core::felt252>"
          }
        ],
        "outputs": [],
        "state_mutability": "external"
      },
      {
        "name": "setApprovalForAll",
        "type": "function",
        "inputs": [
          {
            "name": "operator",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "approved",
            "type": "core::bool"
          }
        ],
        "outputs": [],
        "state_mutability": "external"
      },
      {
        "name": "getApproved",
        "type": "function",
        "inputs": [
          {
            "name": "tokenId",
            "type": "core::integer::u256"
          }
        ],
        "outputs": [
          {
            "type": "core::starknet::contract_address::ContractAddress"
          }
        ],
        "state_mutability": "view"
      },
      {
        "name": "isApprovedForAll",
        "type": "function",
        "inputs": [
          {
            "name": "owner",
            "type": "core::starknet::contract_address::ContractAddress"
          },
          {
            "name": "operator",
            "type": "core::starknet::contract_address::ContractAddress"
          }
        ],
        "outputs": [
          {
            "type": "core::bool"
          }
        ],
        "state_mutability": "view"
      }
    ]
  },
  {
    "name": "mint",
    "type": "function",
    "inputs": [],
    "outputs": [],
    "state_mutability": "external"
  },
  {
    "name": "supports_interface",
    "type": "function",
    "inputs": [
      {
        "name": "interface_id",
        "type": "core::felt252"
      }
    ],
    "outputs": [
      {
        "type": "core::bool"
      }
    ],
    "state_mutability": "view"
  },
  {
    "name": "supportsInterface",
    "type": "function",
    "inputs": [
      {
        "name": "interfaceId",
        "type": "core::felt252"
      }
    ],
    "outputs": [
      {
        "type": "core::bool"
      }
    ],
    "state_mutability": "view"
  },
  {
    "name": "get_seeds",
    "type": "function",
    "inputs": [
      {
        "name": "token_id",
        "type": "core::integer::u256"
      }
    ],
    "outputs": [
      {
        "type": "core::integer::u256"
      }
    ],
    "state_mutability": "view"
  },
  {
    "name": "token_URI",
    "type": "function",
    "inputs": [
      {
        "name": "token_id",
        "type": "core::integer::u256"
      }
    ],
    "outputs": [
      {
        "type": "core::array::Array::<core::felt252>"
      }
    ],
    "state_mutability": "view"
  },
  {
    "name": "get_svg",
    "type": "function",
    "inputs": [
      {
        "name": "token_id",
        "type": "core::integer::u256"
      }
    ],
    "outputs": [
      {
        "type": "core::array::Array::<core::felt252>"
      }
    ],
    "state_mutability": "view"
  },
  {
    "name": "cc_starknet::utils::pack::Pack",
    "type": "struct",
    "members": [
      {
        "name": "first",
        "type": "core::felt252"
      },
      {
        "name": "second",
        "type": "core::felt252"
      },
      {
        "name": "third",
        "type": "core::felt252"
      }
    ]
  },
  {
    "name": "core::array::Span::<core::integer::u8>",
    "type": "struct",
    "members": [
      {
        "name": "snapshot",
        "type": "@core::array::Array::<core::integer::u8>"
      }
    ]
  },
  {
    "name": "cc_starknet::Dungeons::EntityDataSerde",
    "type": "struct",
    "members": [
      {
        "name": "x",
        "type": "core::array::Span::<core::integer::u8>"
      },
      {
        "name": "y",
        "type": "core::array::Span::<core::integer::u8>"
      },
      {
        "name": "entity_data",
        "type": "core::array::Span::<core::integer::u8>"
      }
    ]
  },
  {
    "name": "cc_starknet::Dungeons::DungeonSerde",
    "type": "struct",
    "members": [
      {
        "name": "size",
        "type": "core::integer::u8"
      },
      {
        "name": "environment",
        "type": "core::integer::u8"
      },
      {
        "name": "structure",
        "type": "core::integer::u8"
      },
      {
        "name": "legendary",
        "type": "core::integer::u8"
      },
      {
        "name": "layout",
        "type": "cc_starknet::utils::pack::Pack"
      },
      {
        "name": "entities",
        "type": "cc_starknet::Dungeons::EntityDataSerde"
      },
      {
        "name": "affinity",
        "type": "core::felt252"
      },
      {
        "name": "dungeon_name",
        "type": "core::array::Span::<core::felt252>"
      }
    ]
  },
  {
    "name": "generate_dungeon",
    "type": "function",
    "inputs": [
      {
        "name": "token_id",
        "type": "core::integer::u256"
      }
    ],
    "outputs": [
      {
        "type": "cc_starknet::Dungeons::DungeonSerde"
      }
    ],
    "state_mutability": "view"
  },
  {
    "name": "get_entities",
    "type": "function",
    "inputs": [
      {
        "name": "token_id",
        "type": "core::integer::u256"
      }
    ],
    "outputs": [
      {
        "type": "cc_starknet::Dungeons::EntityDataSerde"
      }
    ],
    "state_mutability": "view"
  },
  {
    "name": "get_layout",
    "type": "function",
    "inputs": [
      {
        "name": "seed",
        "type": "core::integer::u256"
      },
      {
        "name": "size",
        "type": "core::integer::u128"
      }
    ],
    "outputs": [
      {
        "type": "(cc_starknet::utils::pack::Pack, core::integer::u8)"
      }
    ],
    "state_mutability": "view"
  },
  {
    "name": "get_size",
    "type": "function",
    "inputs": [
      {
        "name": "token_id",
        "type": "core::integer::u256"
      }
    ],
    "outputs": [
      {
        "type": "core::integer::u128"
      }
    ],
    "state_mutability": "view"
  },
  {
    "name": "get_environment",
    "type": "function",
    "inputs": [
      {
        "name": "token_id",
        "type": "core::integer::u256"
      }
    ],
    "outputs": [
      {
        "type": "core::integer::u8"
      }
    ],
    "state_mutability": "view"
  },
  {
    "name": "get_name",
    "type": "function",
    "inputs": [
      {
        "name": "token_id",
        "type": "core::integer::u256"
      }
    ],
    "outputs": [
      {
        "type": "(core::array::Array::<core::felt252>, core::felt252, core::integer::u8)"
      }
    ],
    "state_mutability": "view"
  },
  {
    "name": "constructor",
    "type": "constructor",
    "inputs": []
  },
  {
    "kind": "struct",
    "name": "cc_starknet::Dungeons::Minted",
    "type": "event",
    "members": [
      {
        "kind": "key",
        "name": "account",
        "type": "core::starknet::contract_address::ContractAddress"
      },
      {
        "kind": "data",
        "name": "token_id",
        "type": "core::integer::u256"
      }
    ]
  },
  {
    "kind": "struct",
    "name": "cc_starknet::Dungeons::Transfer",
    "type": "event",
    "members": [
      {
        "kind": "key",
        "name": "from",
        "type": "core::starknet::contract_address::ContractAddress"
      },
      {
        "kind": "key",
        "name": "to",
        "type": "core::starknet::contract_address::ContractAddress"
      },
      {
        "kind": "key",
        "name": "token_id",
        "type": "core::integer::u256"
      }
    ]
  },
  {
    "kind": "struct",
    "name": "cc_starknet::Dungeons::Approval",
    "type": "event",
    "members": [
      {
        "kind": "key",
        "name": "owner",
        "type": "core::starknet::contract_address::ContractAddress"
      },
      {
        "kind": "key",
        "name": "approved",
        "type": "core::starknet::contract_address::ContractAddress"
      },
      {
        "kind": "key",
        "name": "token_id",
        "type": "core::integer::u256"
      }
    ]
  },
  {
    "kind": "struct",
    "name": "cc_starknet::Dungeons::ApprovalForAll",
    "type": "event",
    "members": [
      {
        "kind": "key",
        "name": "owner",
        "type": "core::starknet::contract_address::ContractAddress"
      },
      {
        "kind": "key",
        "name": "operator",
        "type": "core::starknet::contract_address::ContractAddress"
      },
      {
        "kind": "data",
        "name": "approved",
        "type": "core::bool"
      }
    ]
  },
  {
    "kind": "enum",
    "name": "cc_starknet::Dungeons::Event",
    "type": "event",
    "variants": [
      {
        "kind": "nested",
        "name": "Minted",
        "type": "cc_starknet::Dungeons::Minted"
      },
      {
        "kind": "nested",
        "name": "Transfer",
        "type": "cc_starknet::Dungeons::Transfer"
      },
      {
        "kind": "nested",
        "name": "Approval",
        "type": "cc_starknet::Dungeons::Approval"
      },
      {
        "kind": "nested",
        "name": "ApprovalForAll",
        "type": "cc_starknet::Dungeons::ApprovalForAll"
      }
    ]
  }
];
const address = "0x000ec1131fe035c235c03e0ad43646d8cbfd59d048b1825b0a36a167c468d5bf";

export default {
  name: 'App',
  components: {
    // HelloWorld
  },
  mounted() {
    this.provider = new Provider({
      rpc: {nodeUrl:"https://rpc-sepolia.staging.nethermind.dev"}});
    console.log("provider", this.provider);

    const route = useRoute();
    console.log("route", route);
    const token_id = route.params.id;
    console.log("token_id", token_id)
    if (token_id) {
      this.token_id = token_id;
    }

    this.init();
    this.load_image();
  },
  data() {
    return {
      contract: null,
      name: "loading...",
      dungeon_string: "",
      svg: null,
      loading: true,
      loading_svg: true,
      wallet_address: null,
      account: null,
      provider: null,
      token_id: 1
    }
  },
  methods: {
    handleChange() {
        this.init();
        this.load_image();
    },
    async init() {

      this.contract = new Contract(abi, address, this.provider);

      this.loading = true;
      let dungeon_data;
      try {
         dungeon_data = await this.contract.generate_dungeon(this.token_id);
      }catch (e) {
        console.error(e);

        ElMessage({
          type: 'error',
          message: 'The map is not minted yet, you could mint one',
        })
        this.token_id =1;
        this.handleChange();
        return;
      }

      console.log("dungeon_data", dungeon_data);

      // https://testnet.starkscan.co/contract/0x0019965eaf48c49d298a9a60423a6322c0b17443325a59832d65f0ac716364d2#class-code-history
      const name = dungeon_data.dungeon_name;
      const layout = dungeon_data.layout;
      const size = Number(dungeon_data.size);
      const entities = dungeon_data.entities;
      this.name = this.decode_string(name);
      console.log("name:", this.name);
      console.log("layout:", layout);
      console.log("size:", size);
      console.log("entities:", entities);

      // eslint-disable-next-line
      let layoutIntFirst = BigInt(layout.first).toString(2).padStart(248, '0');
      // eslint-disable-next-line
      let layoutIntSecond = BigInt(layout.second).toString(2);
      // eslint-disable-next-line
      let layoutIntThird = BigInt(layout.third).toString(2);
      let bits = layoutIntFirst + layoutIntSecond + layoutIntThird;

      // Store dungeon in 2D array
      let dungeon = [];
      // let grid = []
      let counter = 0;
      for (let y = 0; y < size; y++) {
        let row = []
        // let grid_row = [];
        for (let x = 0; x < size; x++) {
          const bit = bits[counter] == 1 ? '   ' : 'X ';
          row.push(bit)
          // grid_row.push(bits[counter] == 1 ? 0 : 1);
          counter++;
        }
        dungeon.push(row)
        // grid.push(grid_row);
      }

      console.log(dungeon);
      this.dungeon_string = this.dungeon_toString(dungeon)
      console.log(this.dungeon_string)
      this.loading = false;
    },
    async load_image() {
      this.contract = new Contract(abi, address, this.provider);

      this.loading_svg = true;
      let svg;
      try {
         svg = await this.contract.get_svg(this.token_id);
      }catch (e) {
        console.error(e);
        this.token_id =1;
        return;
      }
      // console.log("svg",svg);

      const svg_str = this.decode_string(svg);
      console.log("svg_str", svg_str)
      this.svg = svg_str;
      this.loading_svg = false;
    },
    dungeon_toString(dungeon) {
      // Returns a string representing the dungeon
      let rowString = ""

      for (let y = 0; y < dungeon.length; y++) {
        for (let x = 0; x < dungeon.length; x++) {
          const tile = dungeon[y][x]
          rowString += `${tile} `
        }
        rowString += '\n'
      }
      return (rowString)
    },
    decode_string(array) {
      let result = "";
      for (let i = 0; i < array.length; i++) {
        let temp = shortString.decodeShortString(array[i]);
        // console.log("temp:", temp);
        result += temp;
      }
      return result;
    },
    async mint() {
      if (this.wallet_address === null) {

        ElMessage({
          message: 'Please connect your wallet first.',
          type: 'error',
        })

        return;
      }

      const contract = new Contract(abi, address, this.account);
      const tx = await contract.mint();
      console.log("tx", tx);
      const txid = tx.transaction_hash;


      ElMessage({
        message: 'Congrats, mint success.' + txid,
        type: 'success',
      })

      const status = await this.provider.waitForTransaction(txid);
      console.log("status", status);

      const new_id = status.events[0].keys[3];
      console.log("new_id", new_id);
      if (new_id){

        ElMessage({
          message: 'Token ID:' + Number(new_id),
          type: 'success',
        })

        this.token_id = Number(new_id);
        this.handleChange();

      }

    },
    async connect() {
      const a = await connect({
        modalMode:"alwaysAsk",
        modalTheme:"dark",
        chainId:"SN_GOERLI"
      });
      console.log(a.account);
      this.wallet_address = a.account.address;
      console.log(this.wallet_address)
      this.provider = a.provider;
      this.account = a.account;
    }
  }
}
</script>


<style>

body {
  background-color: black;
  margin: 0;
}

#app {
  font-family: VT323, Avenir, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: black;
  /*margin-top: 60px;*/
}

.container {
  /*display: flex;*/
  /*justify-content: center;*/
  /*align-items: center;*/
  width: 300px;
  height: 300px;
  margin-left: auto;
  margin-right: auto;
}

@font-face {
  font-family: 'VT323';
  src: url('./VT323-Regular.ttf');
  font-weight: normal;
  font-style: normal;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

</style>
