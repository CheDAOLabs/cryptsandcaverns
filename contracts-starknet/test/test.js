import { Contract, RpcProvider, shortString } from "starknet";
import { JsonRpcProvider, Contract as EthersContract } from "ethers";
import { atob } from 'js-base64';

import abi from "./abi.json" assert { type: 'json' };

const main = async () => {
    //starknet
    let starknetContract = buildStarknetContract();
    // ethereum
    const ethContract = buildEthereumContract();

    let bug = [];
    let exceptions = [];
    // 'Panic due to DIVIDE_BY_ZERO(18)'
    const badCC = [270, 685, 1135, 1807, 3032, 4706, 5947, 6421, 7162, 7730, 8232];

    for (let i = 1; i <= 9000; i++) {
        if (// divided by 0 in solidity
            badCC.includes(i)
            // not mint yet
            || (i >= 7786 && i <= 8000)) {
            continue;
        }
        await valid(i, ethContract, starknetContract, exceptions, bug);
    }

    if (exceptions.length === 0 && bug.length === 0) {
        console.log("Congratulation, all tests passed!");
    } else {

        if (bug.length > 0) {
            console.warn("bug: ", bug);
        }

        if (exceptions.length > 0) {
            console.error("exceptions: ", exceptions);
        }

        // double check
        const checkList = bug.concat(exceptions);
        bug = [];
        exceptions = [];
        for (let i of checkList) {
            await valid(i, ethContract, starknetContract, exceptions, bug);
        }

        if (exceptions.length === 0 && bug.length === 0) {
            console.log("Congratulation, all tests passed!");
        } else {
            if (bug.length > 0) {
                console.warn("bug: ", bug);
            }

            if (exceptions.length > 0) {
                console.error("exceptions: ", exceptions);
            }
        }
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

    console.log("id: " + i);

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
                    case "Stone Temple":
                        dungeon_data.environment = 1;
                        return;
                    case "Forest Ruins":
                        dungeon_data.environment = 2;
                        return;
                    case "Mountain Deep":
                        dungeon_data.environment = 3;
                        return;
                    case "Underwater Keep":
                        dungeon_data.environment = 4;
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
        // for example 4434
        let temp = layout.padStart(Math.max(Math.ceil(dungeon_data.size * dungeon_data.size / 256) * 256, Math.ceil(layout.length / 256) * 256), "0");
        dungeon_data.layout = temp.length <= 744 ? temp.padEnd(744, "0") : temp.slice(0, 744);

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
                    dungeon_data.points = dungeon_data.points.slice(0, cord) + "1" + dungeon_data.points.slice(cord + 1);
                }
            }
        }

        // console.info(dungeon_data);

        dungeon = await starknetContract.generate_dungeon(i);

        let flag = false;
        if (dungeon_data.name != decodeArray(dungeon.dungeon_name)) {
            console.warn("wrong name: ", i);
            console.info(dungeon_data.name);
            console.info(decodeArray(dungeon.dungeon_name));
            flag = true;
        }

        if (dungeon_data.affinity != shortString.decodeShortString(dungeon.affinity)) {
            console.warn("wrong affinity: ", i);
            console.info(dungeon_data.affinity);
            console.info(shortString.decodeShortString(dungeon.affinity));
            flag = true;
        }

        if (dungeon_data.legendary != Number(dungeon.legendary)) {
            console.warn("wrong legendary: ", i);
            console.info(dungeon_data.legendary);
            console.info(Number(dungeon.legendary));
            flag = true;
        }

        if (dungeon_data.environment != Number(dungeon.environment)) {
            console.warn("wrong environment: ", i);
            console.info(dungeon_data.environment);
            console.info(Number(dungeon.environment));
            flag = true;
        }

        if (dungeon_data.structure != Number(dungeon.structure)) {
            console.warn("wrong structure: ", i);
            console.info(dungeon_data.structure);
            console.info(Number(dungeon.structure));
            flag = true;
        }

        if (dungeon_data.size != Number(dungeon.size)) {
            console.warn("wrong size: ", i);
            console.info(dungeon_data.size);
            console.info(Number(dungeon.size));
            flag = true;
        }

        if (dungeon_data.layout != decodePack(dungeon.layout)) {
            console.warn("wrong layout: ", i);
            console.info(dungeon_data.layout);
            console.info(decodePack(dungeon.layout));
            flag = true;
        }

        if (dungeon_data.doors != decodePack(dungeon.doors)) {
            console.warn("wrong doors: ", i);
            console.info(dungeon_data.doors);
            console.info(decodePack(dungeon.doors));
            flag = true;
        }

        if (dungeon_data.points != decodePack(dungeon.points)) {
            console.warn("wrong points: ", i);
            console.info(dungeon_data.points);
            console.info(decodePack(dungeon.points));
            flag = true;
        }

        if (flag) {
            array.push(i);
        } else {
            console.info("correct: ", i);
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
        "0x0011c5c9de8359f684891e7fbd761a1a4bc3367bf788e4c8cf320c56d5265354",
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