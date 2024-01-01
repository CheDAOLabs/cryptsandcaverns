import { Contract, RpcProvider, shortString } from "starknet";
import { writeFile } from "fs";
import { JsonRpcProvider, Contract as EthersContract, toBeHex } from "ethers";
import { atob, Base64 } from 'js-base64';
import readline from 'readline';

import abi from "./abi.json" assert { type: 'json' };

const main = async () => {
    //starknet
    let starknetContract = buildStarknetContract();
    // ethereum
    const ethContract = buildEthereumContract();

    let bug = [];
    let exceptions = [];
    const badCC = [7162, 1807, 3032, 6421, 1135, 270, 7730, 5947, 4706];

    for (let i = 1; i <= 9000; i++) {
        if (badCC.includes(i) || (i >= 7786 && i <= 8000)) {
            continue;
        }
        await valid(i, ethContract, starknetContract, exceptions, bug);
    }

    if (bug.length > 0) {
        console.warn("bug: ", bug);
    }

    if (exceptions.length > 0) {
        console.error("exceptions: ", exceptions);
    }

}



async function valid(i, ethContract, starknetContract, exceptions, array) {
    let dungeon_data = {
        id: i,
        // seed: "0x" + BigInt(seed).toString(16),
        name: "",
        affinity: "",
        legendary: 0,
        environment: 0,
        structure: 0,
        size: 0,
        layout: "",
        doors: "",
        points: "",
        svg: "",
    }

    // console.log("id: " + i);

    let dungeon;
    try {

        let token = await ethContract.tokenURI(i);
        let data = JSON.parse(atob(token.split(",")[1]));
        data.attributes.forEach((attribute) => {
            if (attribute.trait_type === "name") {
                dungeon_data.name = attribute.value;
            }
            if (attribute.trait_type === "affinity") {
                dungeon_data.affinity = attribute.value;
            }
            if (attribute.trait_type === "legendary") {
                dungeon_data.legendary = attribute.value === 'No' ? 0 : 1;
            }
            if (attribute.trait_type === "environment") {
                switch (attribute.value) {
                    case "Desert Plateau":
                        dungeon_data.environment = 0;
                        return;
                    case "Forest Ruins":
                        dungeon_data.environment = 2;
                        return;
                    case "Underwater Keep":
                        dungeon_data.environment = 4;
                        return;
                    case "Stone Temple":
                        dungeon_data.environment = 1;
                        return;
                    case "Mountain Deep":
                        dungeon_data.environment = 3;
                        return;
                    case "Ember's Glow":
                        dungeon_data.environment = 5;
                        return;
                }
            }
            if (attribute.trait_type === "structure") {
                dungeon_data.structure = attribute.value === "Cavern" ? 1 : 0;
            }
            if (attribute.trait_type === "size") {
                dungeon_data.size = Number(attribute.value.split("x")[0]);
            }
        })
        dungeon_data.svg = atob(data.image.split(",")[1]);

        let layout = BigInt(await ethContract.getLayout(i)).toString(2);
        dungeon_data.layout = layout.padStart(Math.ceil(layout.length / 256) * 256, "0");

        let entity = await ethContract.getEntities(i);
        dungeon_data.doors = "".padEnd(744, "0");
        dungeon_data.points = "".padEnd(744, "0");
        if (entity.length !== 0) {
            let x = entity[0];
            let y = entity[1];
            let t = entity[2];
            for (let u = 0; u < x.length; u++) {
                let cord = Number(y[u]) * dungeon_data.size + Number(x[u]);
                if (Number(t[u]) === 0) {
                    dungeon_data.doors = dungeon_data.doors.slice(0, cord) + "1" + dungeon_data.doors.slice(cord + 1);
                } else {
                    dungeon_data.points = dungeon_data.doors.slice(0, cord) + "1" + dungeon_data.doors.slice(cord + 1);
                }
            }
        }

        console.info(dungeon_data);

        dungeon = await starknetContract.generate_dungeon(i);
        
        let dungeon_starknet = {
            id: i,
            // seed: "0x" + BigInt(seed).toString(16),
            name: decodeArray(dungeon.dungeon_name),
            affinity: shortString.decodeShortString(dungeon.affinity),
            legendary: Number(dungeon.legendary),
            environment: Number(dungeon.environment),
            structure: Number(dungeon.structure),
            size: Number(dungeon.size),
            layout: decodePack(dungeon.layout),
            doors: decodePack(dungeon.doors),
            points: decodePack(dungeon.points),
            svg: "",
        }
        console.log(dungeon_starknet);

        if (dungeon_data.name != decodeArray(dungeon.dungeon_name)
            || dungeon_data.affinity != shortString.decodeShortString(dungeon.affinity)
            || dungeon_data.legendary != Number(dungeon.legendary)
            || dungeon_data.environment != Number(dungeon.environment)
            || dungeon_data.structure != Number(dungeon.structure)
            || dungeon_data.size != Number(dungeon.size)
            || dungeon_data.layout != decodePack(dungeon.layout)
            || dungeon_data.doors != decodePack(dungeon.doors)
            || dungeon_data.points != decodePack(dungeon.points)) {
            console.warn("wrong data: ", i);
            array.push(i);
        } else {
            console.info("correct data: ", i);
        }

    } catch (e) {

        console.error(e);
        exceptions.push(i);

    }

}


const decodeArray = (svg) => {
    let result = "";
    for (let i = 0; i < svg.length; i++) {
        result += shortString.decodeShortString(svg[i]);
    }
    return result;
};


const decodePack = (pack) => {
    // for starknet <felt252>
    let first = BigInt(pack.first).toString(2).padStart(248, '0');
    let second = BigInt(pack.second).toString(2).padStart(248, '0');
    let three = BigInt(pack.third).toString(2).padStart(248, '0');
    return first + second + three;
}


function buildStarknetContract() {
    return new Contract(
        // abi
        abi,
        // address
        "0x04cc07139853629d99aecb5d21fb0fc928297e2548bdf5cf46e4c92eb4ab1480",
        // rpc
        new RpcProvider({ nodeUrl: "https://rpc-sepolia.staging.nethermind.dev" }));
}

function buildEthereumContract() {
    return new EthersContract(
        // address
        "0x86f7692569914b5060ef39aab99e62ec96a6ed45",
        // abi
        [
            "function getSvg(uint256) public view returns (string)",
            "function tokenURI(uint256) public view returns (string)",
            "function getLayout(uint256) public view returns (bytes)",
            "function getEntities(uint256) public view returns (uint8[], uint8[], uint8[])",
        ],
        // rpc
        // https://chainlist.org/
        // const url = "https://eth.merkle.io";
        new JsonRpcProvider("https://rpc.mevblocker.io"));
}

main().then(r => console.log(r));