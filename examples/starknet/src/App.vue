<template>
  <div id="app">

    <el-card class="box-card" style="width: 1100px;margin-left: auto;margin-right: auto;margin-top: 50px">
      <template #header>
        <div class="card-header">
          <span style="font-size: 30px">C&C Example</span>
          <el-button class="button" plain type="primary" @click="connect">
            {{
              wallet_address == null ? "Connect Wallet" : wallet_address.toString().substr(0, 10) + "..." +
            wallet_address.toString().substr(wallet_address.length - 4, 4)
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
      <el-input-number v-model="token_id" :min="1" :max="1000000" @change="handleChange" />
      <!-- <div style="color: white;font-size: 20px;font-family: VT323;margin-top: 10px">total {{ last_id }}</div> -->
      <div style="color: white;font-size: 24px;font-family: VT323;margin-top: 20px;margin-bottom: 10px;"> {{ name }}</div>
      <div class="container"
        style="float: left;  overflow: hidden;margin-top: 10px;margin-bottom: 30px;background-color: black;color:white;border: 1px;border-color:white;display: flex;align-items: center;    justify-content: center;"
        v-loading="loading">
        <pre style="color: white">{{ dungeon_string }}</pre>
      </div>
      <div class="container" style="float:right;background-color: red;margin-top: 10px; margin-bottom: 30px;" v-loading="loading_svg">
        <div v-html="svg"></div>
      </div>
      <div style="margin-bottom: 10px">
        <el-button type="danger" plain @click="mint">MINT</el-button>
      </div>
    </el-card>

  </div>
</template>

<script>
import { ElMessage } from 'element-plus'
import { Contract, Provider, shortString } from "starknet";
import { connect } from "@argent/get-starknet"
import { useRoute } from 'vue-router';
import abi from "./abi.json";

const address = "0x070017c7a691d60ac06a5905bf782764cbc9c81a97f8f2587a5373ad7bdec886";

export default {
  name: 'App',
  components: {
    // HelloWorld
  },
  mounted() {
    this.provider = new Provider({
      rpc: { nodeUrl: "https://starknet-testnet.public.blastapi.io" }
    });
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
      token_id: 1,
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
      } catch (e) {
        console.error(e);

        ElMessage({
          type: 'error',
          message: 'The map is not minted yet, you could mint one',
        })
        this.token_id = 1;
        this.handleChange();
        return;
      }

      console.log("dungeon_data", dungeon_data);

      // https://testnet.starkscan.co/contract/0x0019965eaf48c49d298a9a60423a6322c0b17443325a59832d65f0ac716364d2#class-code-history
      const name = dungeon_data.dungeon_name;
      const layout = this.decodePack(dungeon_data.layout);
      const points = this.decodePack(dungeon_data.points);
      const doors = this.decodePack(dungeon_data.doors);
      const size = Number(dungeon_data.size);
      this.name = this.decode_string(name);
      console.log("name:", this.name);
      console.log("layout:", layout);
      console.log("size:", size);
      console.log("points:", points);
      console.log("doors:", doors);

      // Store dungeon in 2D array
      let dungeon = [];
      // let grid = []
      let counter = 0;
      for (let y = 0; y < size; y++) {
        let row = []
        // let grid_row = [];
        for (let x = 0; x < size; x++) {
          let bit = 'X';
          if (points[counter] == 1) {
            bit = 'O';
          } else if (doors[counter] == 1) {
            bit = '-';
          } else if (layout[counter] == 1) {
            bit = ' ';
          } else {
            console.warn("point or door not found");
          }
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
    decodePack(layout) {
      // eslint-disable-next-line
      let layoutIntFirst = BigInt(layout.first).toString(2).padStart(248, '0');
      // eslint-disable-next-line
      let layoutIntSecond = BigInt(layout.second).toString(2).padStart(248, '0');
      // eslint-disable-next-line
      let layoutIntThird = BigInt(layout.third).toString(2).padStart(248, '0');

      let bits = layoutIntFirst + layoutIntSecond + layoutIntThird;
      return bits;
    },
    async load_image() {
      this.contract = new Contract(abi, address, this.provider);

      this.loading_svg = true;
      let svg;
      try {
        svg = await this.contract.get_svg(this.token_id);
      } catch (e) {
        console.error(e);
        this.token_id = 1;
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
      if (new_id) {

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
        modalMode: "alwaysAsk",
        modalTheme: "dark",
        chainId: "SN_GOERLI"
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
  width: 500px;
  height: 500px;
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
