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

const uniqueFatTigerHolders: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    let filePath = './fatTigerHolders.json';
    let fileContents = fs.readFileSync(filePath, 'utf8');
    let fatTigerHolders = JSON.parse(fileContents);

    console.log(`Existing Data: ${fatTigerHolders.length}`);

    const uniqueFatTigerHolders = [...new Set(fatTigerHolders)];
    console.log(`Unique Data: ${uniqueFatTigerHolders.length}`);

    const addressCounts = fatTigerHolders.reduce((acc, val) => {
        if (val in acc) {
          acc[val]++;
        } else {
          acc[val] = 1;
        }
        return acc;
      }, {});
      
      // log keys
    console.log(Object.keys(addressCounts).length);

      // Sum all values in the addressCounts object
    const total = Object.values(addressCounts).reduce((a: any, b) => a + b, 0);

    console.log(`Total: ${total}`);

    // Write uniqueFatTigerHolders to a json file
    fs.writeFileSync('./uniqueFatTigerHolders.json', JSON.stringify(uniqueFatTigerHolders));
}

export default uniqueFatTigerHolders;
uniqueFatTigerHolders.tags = ['all', 'uniqueFatTigerHolders'];