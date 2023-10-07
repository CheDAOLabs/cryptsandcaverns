<template>
  <div id="app" v-loading="loading">
    <!--    <img alt="Vue logo" src="./assets/logo.png">-->
    <p1>{{ name }}</p1>
    <pre>{{ dungeon_string }}</pre>
    <div v-html="svg"></div>
  </div>
</template>

<script>
// import HelloWorld from './components/HelloWorld.vue'
import {Contract, constants, Provider, shortString} from "starknet";
// import BigInt from "BigInt";

export default {
  name: 'App',
  components: {
    // HelloWorld
  },
  mounted() {
    const provider = new Provider({sequencer: {network: constants.NetworkName.SN_GOERLI}});
    console.log("provider", provider);
    const abi = [
      {
        "name": "mint",
        "type": "function",
        "inputs": [],
        "outputs": [
          {
            "type": "core::integer::u128"
          }
        ],
        "state_mutability": "external"
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
        "name": "get_seeds",
        "type": "function",
        "inputs": [
          {
            "name": "token_id",
            "type": "core::integer::u128"
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
        "name": "token_URI_not_work_yet",
        "type": "function",
        "inputs": [
          {
            "name": "token_id",
            "type": "core::integer::u128"
          }
        ],
        "outputs": [
          {
            "type": "core::array::Span::<core::felt252>"
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
            "type": "core::integer::u128"
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
        "name": "cc_map::utils::pack::Pack",
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
        "name": "cc_map::Dungeons::EntityData",
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
        "name": "cc_map::Dungeons::DungeonSerde",
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
            "type": "cc_map::utils::pack::Pack"
          },
          {
            "name": "entities",
            "type": "cc_map::Dungeons::EntityData"
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
            "type": "core::integer::u128"
          }
        ],
        "outputs": [
          {
            "type": "cc_map::Dungeons::DungeonSerde"
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
        "name": "cc_map::Dungeons::Minted",
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
            "type": "core::integer::u128"
          }
        ]
      },
      {
        "kind": "struct",
        "name": "cc_map::Dungeons::Claimed",
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
            "type": "core::integer::u128"
          }
        ]
      },
      {
        "kind": "enum",
        "name": "cc_map::Dungeons::Event",
        "type": "event",
        "variants": [
          {
            "kind": "nested",
            "name": "Minted",
            "type": "cc_map::Dungeons::Minted"
          },
          {
            "kind": "nested",
            "name": "Claimed",
            "type": "cc_map::Dungeons::Claimed"
          }
        ]
      }
    ];
    const address = "0x0019965eaf48c49d298a9a60423a6322c0b17443325a59832d65f0ac716364d2";
    this.contract = new Contract(abi, address, provider);

    this.init();
    this.load_image();
  },
  data() {
    return {
      contract: null,
      name: "",
      dungeon_string: "",
      svg: null,
      loading: true
    }
  },
  methods: {
    async init() {

      const tokenId = 1;

      this.loading = true;
      const dungeon_data = await this.contract.generate_dungeon(tokenId);

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
          const bit = bits[counter] == 1 ? ' ' : 'X';
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
      const svg = await this.contract.get_svg(1);
      // console.log("svg",svg);
      const svg_str = this.decode_string(svg);
      // console.log("svg_str",svg_str)
      this.svg = svg_str;
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
  }
}
</script>

<style>
#app {
  font-family: Avenir, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
  margin-top: 60px;
}
</style>
