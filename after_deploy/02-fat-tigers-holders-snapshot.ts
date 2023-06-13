import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { ethers } from 'hardhat';
import fs from 'fs';
import verify from '../helpers/verify-contract';
import 'dotenv/config';
import { DEVELOPMENT_CHAINS } from '../helpers/constants';

const filePath = './fatTigersAbi.json';
const fileContents = fs.readFileSync(filePath, 'utf8');
const FAT_TIGERS_ABI = JSON.parse(fileContents);

const NAME = process.env.NAME || '';
const SYMBOL = process.env.SYMBOL || '';
const BASE_URI = process.env.BASE_URI || '';
const CONTRACT_NAME = process.env.CONTRACT_NAME || '';

const CONTRACT_ADDRESS = '0xFdD87A263ba929E14Dd0A2D879D9C66d5c8fF3ae';

const getSnapshotFatTigers: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { getNamedAccounts, deployments, network } = hre;
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  // Create new ethers provider with the rpc url 'https://sgb.ftso.com.au/ext/bc/C/rpc'
  const provider = new ethers.providers.JsonRpcProvider('https://sgb.ftso.com.au/ext/bc/C/rpc');

  // Get the contract from the contract address
  const contract = new ethers.Contract(CONTRACT_ADDRESS, FAT_TIGERS_ABI, provider);

  let fatTigerHolders: any = [];
  for(let i = 4049; i <= 6000; i++) {
    fatTigerHolders = [];
    if (i % 5 === 0) {
      console.log(`Checking ${i} of 6000 and sleeping for 5 seconds...`);
        await new Promise(r => setTimeout(r, 5000));
    }
    const owner = await contract.ownerOf(i);
    fatTigerHolders.push(owner);

    // Append the fatTigerHolders to the json file
    let filePath = './fatTigerHolders.json';
    let fileContents = fs.readFileSync(filePath, 'utf8');
    let existingData = JSON.parse(fileContents);
    let newData = existingData.concat(fatTigerHolders);
    fs.writeFileSync(filePath, JSON.stringify(newData));
  }
  
  // Write the fatTigerHolders to a json file
//   fs.appendFileSync('./fatTigerHolders.json', JSON.stringify(fatTigerHolders));

//   const uniqueFatTigerHolders = [...new Set(fatTigerHolders)];
//   fs.writeFileSync('./uniqueFatTigerHolders.json', JSON.stringify(uniqueFatTigerHolders));
}

export default getSnapshotFatTigers;
getSnapshotFatTigers.tags = ['all', 'fatTigers'];