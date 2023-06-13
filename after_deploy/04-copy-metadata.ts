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

const copyMetadata: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const sourceFilePath = './build/metadata/1.json';
    const destinationFolderPath = './build/metadata/';
    
    for (let i = 2; i <= 100; i++) {
        const destinationFilePath = `${destinationFolderPath}${i}.json`;
        const metadata = JSON.parse(fs.readFileSync(sourceFilePath, 'utf8'));
        metadata.image = `ipfs://QmVZX1SaRZRkMumvCj5zbdupZEufAtMTtP165ozDAZcLbU/${i}.png`;
        fs.writeFileSync(destinationFilePath, JSON.stringify(metadata));
    }
}

export default copyMetadata;
copyMetadata.tags = ['all', 'copyMetadata'];