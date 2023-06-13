import { ethers } from "hardhat";
import fs from 'fs';

const CONTRACT_ADDRESS = '0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984';

const filePath = './uniswapABI.json';
const fileContents = fs.readFileSync(filePath, 'utf8');
const ABI = JSON.parse(fileContents);
// console.log(ABI);

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log(deployer.provider);
    // const provider = new ethers.providers.JsonRpcProvider('http://127.0.0.1:8545/');
    
    const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, deployer);
    // console.log(contract);
    // await contract.mint(2, { gasLimit: 1000000 });
    // const balance = await contract.balanceOf(deployer.address);
    // console.log(balance.toString());
    await contract.mint(deployer.address, 1);
    // const balance = await contract.balanceOf(deployer.address);
    console.log(await contract.symbol());

    // console.log(await contract.maxSupply());

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});