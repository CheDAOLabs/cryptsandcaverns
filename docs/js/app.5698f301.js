(function(){"use strict";var e={7623:function(e,t,n){var r=n(7195),o=n(5114),a=n.n(o),i=function(){var e=this,t=e._self._c;return t("div",{directives:[{name:"loading",rawName:"v-loading",value:e.loading,expression:"loading"}],attrs:{id:"app"}},[t("p1",[e._v(e._s(e.name))]),t("pre",[e._v(e._s(e.dungeon_string))]),t("div",{domProps:{innerHTML:e._s(e.svg)}})],1)},c=[],u=(n(7658),n(5253)),s={name:"App",components:{},mounted(){const e=new u.zt({sequencer:{network:u._G.NetworkName.SN_GOERLI}});console.log("provider",e);const t=[{name:"mint",type:"function",inputs:[],outputs:[{type:"core::integer::u128"}],state_mutability:"external"},{name:"core::integer::u256",type:"struct",members:[{name:"low",type:"core::integer::u128"},{name:"high",type:"core::integer::u128"}]},{name:"get_seeds",type:"function",inputs:[{name:"token_id",type:"core::integer::u128"}],outputs:[{type:"core::integer::u256"}],state_mutability:"view"},{name:"core::array::Span::<core::felt252>",type:"struct",members:[{name:"snapshot",type:"@core::array::Array::<core::felt252>"}]},{name:"token_URI_not_work_yet",type:"function",inputs:[{name:"token_id",type:"core::integer::u128"}],outputs:[{type:"core::array::Span::<core::felt252>"}],state_mutability:"view"},{name:"get_svg",type:"function",inputs:[{name:"token_id",type:"core::integer::u128"}],outputs:[{type:"core::array::Array::<core::felt252>"}],state_mutability:"view"},{name:"cc_map::utils::pack::Pack",type:"struct",members:[{name:"first",type:"core::felt252"},{name:"second",type:"core::felt252"},{name:"third",type:"core::felt252"}]},{name:"core::array::Span::<core::integer::u8>",type:"struct",members:[{name:"snapshot",type:"@core::array::Array::<core::integer::u8>"}]},{name:"cc_map::Dungeons::EntityData",type:"struct",members:[{name:"x",type:"core::array::Span::<core::integer::u8>"},{name:"y",type:"core::array::Span::<core::integer::u8>"},{name:"entity_data",type:"core::array::Span::<core::integer::u8>"}]},{name:"cc_map::Dungeons::DungeonSerde",type:"struct",members:[{name:"size",type:"core::integer::u8"},{name:"environment",type:"core::integer::u8"},{name:"structure",type:"core::integer::u8"},{name:"legendary",type:"core::integer::u8"},{name:"layout",type:"cc_map::utils::pack::Pack"},{name:"entities",type:"cc_map::Dungeons::EntityData"},{name:"affinity",type:"core::felt252"},{name:"dungeon_name",type:"core::array::Span::<core::felt252>"}]},{name:"generate_dungeon",type:"function",inputs:[{name:"token_id",type:"core::integer::u128"}],outputs:[{type:"cc_map::Dungeons::DungeonSerde"}],state_mutability:"view"},{name:"constructor",type:"constructor",inputs:[]},{kind:"struct",name:"cc_map::Dungeons::Minted",type:"event",members:[{kind:"key",name:"account",type:"core::starknet::contract_address::ContractAddress"},{kind:"data",name:"token_id",type:"core::integer::u128"}]},{kind:"struct",name:"cc_map::Dungeons::Claimed",type:"event",members:[{kind:"key",name:"account",type:"core::starknet::contract_address::ContractAddress"},{kind:"data",name:"token_id",type:"core::integer::u128"}]},{kind:"enum",name:"cc_map::Dungeons::Event",type:"event",variants:[{kind:"nested",name:"Minted",type:"cc_map::Dungeons::Minted"},{kind:"nested",name:"Claimed",type:"cc_map::Dungeons::Claimed"}]}],n="0x0019965eaf48c49d298a9a60423a6322c0b17443325a59832d65f0ac716364d2";this.contract=new u.CH(t,n,e),this.init(),this.load_image()},data(){return{contract:null,name:"",dungeon_string:"",svg:null,loading:!0}},methods:{async init(){const e=1;this.loading=!0;const t=await this.contract.generate_dungeon(e);console.log("dungeon_data",t);const n=t.dungeon_name,r=t.layout,o=Number(t.size),a=t.entities;this.name=this.decode_string(n),console.log("name:",this.name),console.log("layout:",r),console.log("size:",o),console.log("entities:",a);let i=BigInt(r.first).toString(2).padStart(248,"0"),c=BigInt(r.second).toString(2),u=BigInt(r.third).toString(2),s=i+c+u,p=[],d=0;for(let l=0;l<o;l++){let e=[];for(let t=0;t<o;t++){const t=1==s[d]?" ":"X";e.push(t),d++}p.push(e)}console.log(p),this.dungeon_string=this.dungeon_toString(p),console.log(this.dungeon_string),this.loading=!1},async load_image(){const e=await this.contract.get_svg(1),t=this.decode_string(e);this.svg=t},dungeon_toString(e){let t="";for(let n=0;n<e.length;n++){for(let r=0;r<e.length;r++){const o=e[n][r];t+=`${o} `}t+="\n"}return t},decode_string(e){let t="";for(let n=0;n<e.length;n++){let r=u.lC.decodeShortString(e[n]);t+=r}return t}}},p=s,d=n(1001),l=(0,d.Z)(p,i,c,!1,null,null,null),m=l.exports;r["default"].use(a()),new r["default"]({el:"#app",render:e=>e(m)})}},t={};function n(r){var o=t[r];if(void 0!==o)return o.exports;var a=t[r]={id:r,loaded:!1,exports:{}};return e[r].call(a.exports,a,a.exports,n),a.loaded=!0,a.exports}n.m=e,function(){n.amdO={}}(),function(){var e=[];n.O=function(t,r,o,a){if(!r){var i=1/0;for(p=0;p<e.length;p++){r=e[p][0],o=e[p][1],a=e[p][2];for(var c=!0,u=0;u<r.length;u++)(!1&a||i>=a)&&Object.keys(n.O).every((function(e){return n.O[e](r[u])}))?r.splice(u--,1):(c=!1,a<i&&(i=a));if(c){e.splice(p--,1);var s=o();void 0!==s&&(t=s)}}return t}a=a||0;for(var p=e.length;p>0&&e[p-1][2]>a;p--)e[p]=e[p-1];e[p]=[r,o,a]}}(),function(){n.n=function(e){var t=e&&e.__esModule?function(){return e["default"]}:function(){return e};return n.d(t,{a:t}),t}}(),function(){n.d=function(e,t){for(var r in t)n.o(t,r)&&!n.o(e,r)&&Object.defineProperty(e,r,{enumerable:!0,get:t[r]})}}(),function(){n.g=function(){if("object"===typeof globalThis)return globalThis;try{return this||new Function("return this")()}catch(e){if("object"===typeof window)return window}}()}(),function(){n.o=function(e,t){return Object.prototype.hasOwnProperty.call(e,t)}}(),function(){n.r=function(e){"undefined"!==typeof Symbol&&Symbol.toStringTag&&Object.defineProperty(e,Symbol.toStringTag,{value:"Module"}),Object.defineProperty(e,"__esModule",{value:!0})}}(),function(){n.nmd=function(e){return e.paths=[],e.children||(e.children=[]),e}}(),function(){var e={143:0};n.O.j=function(t){return 0===e[t]};var t=function(t,r){var o,a,i=r[0],c=r[1],u=r[2],s=0;if(i.some((function(t){return 0!==e[t]}))){for(o in c)n.o(c,o)&&(n.m[o]=c[o]);if(u)var p=u(n)}for(t&&t(r);s<i.length;s++)a=i[s],n.o(e,a)&&e[a]&&e[a][0](),e[a]=0;return n.O(p)},r=self["webpackChunkcc_interface"]=self["webpackChunkcc_interface"]||[];r.forEach(t.bind(null,0)),r.push=t.bind(null,r.push.bind(r))}();var r=n.O(void 0,[998],(function(){return n(7623)}));r=n.O(r)})();
//# sourceMappingURL=app.5698f301.js.map