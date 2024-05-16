const { ContractType } = require('hardhat/internal/hardhat-network/stack-traces/model');
const { ethers } = require("hardhat");
// Script to deploy our fake loot / testing contract to Rinkeby

console.log("...");

// module.exports = async (hre) => {
//     try {
//         console.log("脚本开始执行");
//         const ownerAddress = '0xbaeFe32bc1636a90425AcBCC8cfAD1b0507eCdE1';

//         const {deployments, getNamedAccounts} = hre;
//         const {deploy} = deployments;
//         const {deployer} = await getNamedAccounts();

//         console.log(`Deploying contract with deployer account: ${deployer}`);

//         const signer = await ethers.getSigner(ownerAddress);
//         console.log("ssssss")

//         const Loot = await ethers.getContractFactory("contracts/fakeloot.sol:Loot", signer);
//         const loot = await Loot.connect(signer).deploy();
//         await loot.deployed();
//         console.log('Deployment from: ', signer.address);
//         console.log(`Loot Contract Address: ${loot.address}`)
//     } catch (error) {
//         console.error("发生错误：", error);
//     }
// } 



async function main(){
    const [deployer]= await ethers.getSigners();
    const Loot = await ethers.getContractFactory("contracts/fakeloot.sol:Loot");
    const loot= await Loot.deploy();
    console.log("loot Address:", loot.address)
}

main()
.then(()=>{
    process.exit(0)})
    .catch((error)=>{
        console.log(error)
        process.exit(1)
    })