import '@typechain/hardhat';
import '@nomiclabs/hardhat-waffle';
import '@nomiclabs/hardhat-etherscan';
import '@nomiclabs/hardhat-ethers';
import 'hardhat-gas-reporter';
import 'dotenv/config';
import 'solidity-coverage';
import 'hardhat-deploy';
import { HardhatUserConfig } from 'hardhat/config';

// const RINKEBY_RPC_URL = process.env.RINKEBY_RPC_URL || '';
// const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || '';
const PRIVATE_KEY = process.env.PRIVATE_KEY || '';
// const COINMARKETCAP_API_KEY = process.env.COINMARKETCAP_API_KEY || '';

const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      chainId: 31337
    },
    localhost: {
      chainId: 31337
    },
    songbird: {
      url: 'https://sgb.ftso.com.au/ext/bc/C/rpc',
      accounts: [`0x${PRIVATE_KEY}`],
      chainId: 19,
    },
  },
  solidity: {
    version: "0.8.9",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  // etherscan: {
  //   apiKey: ETHERSCAN_API_KEY,
  // },
  // gasReporter: {
  //   enabled: true,
  //   currency: 'USD',
  //   outputFile: 'gas-report.txt',
  //   noColors: true,
  //   coinmarketcap: COINMARKETCAP_API_KEY,
  // },
  namedAccounts: {
    deployer: {
      default: 0,
      1: 0,
    },
  },
  mocha: {
    timeout: 200000,
  },
}

export default config;
