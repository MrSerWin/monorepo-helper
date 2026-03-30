#!/usr/bin/env bash
set -euo pipefail
source "$(cd "$(dirname "$0")/../.." && pwd)/lib/utils.sh"

parse_args "my-hardhat-contracts" "$@"
create_project_dir

# --- package.json ---
write_package_json '{
  "name": "'"$PROJECT_NAME"'",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "compile": "hardhat compile",
    "test": "hardhat test",
    "deploy:local": "hardhat ignition deploy ./ignition/modules/Lock.ts --network localhost",
    "deploy:sepolia": "hardhat ignition deploy ./ignition/modules/Lock.ts --network sepolia",
    "node": "hardhat node",
    "coverage": "hardhat coverage",
    "clean": "hardhat clean"
  },
  "devDependencies": {
    "@nomicfoundation/hardhat-toolbox": "^5.0.0",
    "@nomicfoundation/hardhat-ignition-ethers": "^0.15.0",
    "@types/chai": "^5.2.0",
    "@types/mocha": "^10.0.10",
    "@types/node": "^22.14.0",
    "ethers": "^6.13.0",
    "hardhat": "^2.22.0",
    "typescript": "^5.8.3",
    "ts-node": "^10.9.2"
  }
}'

# --- hardhat.config.ts ---
write_file "hardhat.config.ts" 'import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "dotenv/config";

const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x" + "0".repeat(64);
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL || "";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {},
    sepolia: {
      url: SEPOLIA_RPC_URL,
      accounts: [PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
};

export default config;'

# --- tsconfig.json ---
write_tsconfig '{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "outDir": "dist"
  },
  "include": [
    "./scripts",
    "./test",
    "./ignition",
    "./hardhat.config.ts"
  ]
}'

# --- .env.example ---
write_file ".env.example" '# Private key for deploying contracts (DO NOT commit your real key!)
PRIVATE_KEY=0x0000000000000000000000000000000000000000000000000000000000000000

# RPC URLs
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/your-api-key

# Etherscan API key for contract verification
ETHERSCAN_API_KEY=your_etherscan_api_key'

# --- contracts/Lock.sol ---
write_file "contracts/Lock.sol" '// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title Lock
 * @dev A simple time-locked contract that holds funds until the unlock time.
 */
contract Lock {
    uint256 public unlockTime;
    address payable public owner;

    event Withdrawal(uint256 amount, uint256 when);

    constructor(uint256 _unlockTime) payable {
        require(
            block.timestamp < _unlockTime,
            "Unlock time should be in the future"
        );

        unlockTime = _unlockTime;
        owner = payable(msg.sender);
    }

    function withdraw() public {
        require(block.timestamp >= unlockTime, "You cannot withdraw yet");
        require(msg.sender == owner, "You are not the owner");

        emit Withdrawal(address(this).balance, block.timestamp);

        owner.transfer(address(this).balance);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}'

# --- test/Lock.test.ts ---
write_file "test/Lock.test.ts" 'import { expect } from "chai";
import { ethers } from "hardhat";
import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";

describe("Lock", function () {
  async function deployLockFixture() {
    const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
    const ONE_GWEI = 1_000_000_000n;

    const lockedAmount = ONE_GWEI;
    const unlockTime = (await time.latest()) + ONE_YEAR_IN_SECS;

    const [owner, otherAccount] = await ethers.getSigners();
    const Lock = await ethers.getContractFactory("Lock");
    const lock = await Lock.deploy(unlockTime, { value: lockedAmount });

    return { lock, unlockTime, lockedAmount, owner, otherAccount };
  }

  describe("Deployment", function () {
    it("should set the right unlockTime", async function () {
      const { lock, unlockTime } = await loadFixture(deployLockFixture);
      expect(await lock.unlockTime()).to.equal(unlockTime);
    });

    it("should set the right owner", async function () {
      const { lock, owner } = await loadFixture(deployLockFixture);
      expect(await lock.owner()).to.equal(owner.address);
    });

    it("should receive and store the funds to lock", async function () {
      const { lock, lockedAmount } = await loadFixture(deployLockFixture);
      expect(await ethers.provider.getBalance(lock.target)).to.equal(
        lockedAmount
      );
    });

    it("should fail if the unlockTime is not in the future", async function () {
      const latestTime = await time.latest();
      const Lock = await ethers.getContractFactory("Lock");
      await expect(Lock.deploy(latestTime, { value: 1 })).to.be.revertedWith(
        "Unlock time should be in the future"
      );
    });
  });

  describe("Withdrawals", function () {
    describe("Validations", function () {
      it("should revert with the right error if called too soon", async function () {
        const { lock } = await loadFixture(deployLockFixture);
        await expect(lock.withdraw()).to.be.revertedWith(
          "You cannot withdraw yet"
        );
      });

      it("should revert with the right error if called from another account", async function () {
        const { lock, unlockTime, otherAccount } = await loadFixture(
          deployLockFixture
        );
        await time.increaseTo(unlockTime);
        await expect(lock.connect(otherAccount).withdraw()).to.be.revertedWith(
          "You are not the owner"
        );
      });
    });

    describe("Events", function () {
      it("should emit an event on withdrawals", async function () {
        const { lock, unlockTime, lockedAmount } = await loadFixture(
          deployLockFixture
        );
        await time.increaseTo(unlockTime);
        await expect(lock.withdraw())
          .to.emit(lock, "Withdrawal")
          .withArgs(lockedAmount, (v: bigint) => v >= BigInt(unlockTime));
      });
    });

    describe("Transfers", function () {
      it("should transfer the funds to the owner", async function () {
        const { lock, unlockTime, lockedAmount, owner } = await loadFixture(
          deployLockFixture
        );
        await time.increaseTo(unlockTime);
        await expect(lock.withdraw()).to.changeEtherBalances(
          [owner, lock],
          [lockedAmount, -lockedAmount]
        );
      });
    });
  });
});'

# --- scripts/deploy.ts ---
write_file "scripts/deploy.ts" 'import { ethers } from "hardhat";

async function main() {
  const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  const unlockTime = currentTimestampInSeconds + 60 * 60 * 24 * 365; // 1 year
  const lockedAmount = ethers.parseGwei("1");

  console.log(
    `Deploying Lock with unlock time ${unlockTime} and value ${lockedAmount}`
  );

  const Lock = await ethers.getContractFactory("Lock");
  const lock = await Lock.deploy(unlockTime, { value: lockedAmount });

  await lock.waitForDeployment();

  console.log(`Lock deployed to: ${lock.target}`);
  console.log(`Unlock time: ${new Date(unlockTime * 1000).toISOString()}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});'

# --- ignition/modules/Lock.ts ---
write_file "ignition/modules/Lock.ts" 'import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ONE_GWEI = 1_000_000_000n;
const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;

const LockModule = buildModule("LockModule", (m) => {
  const unlockTime = m.getParameter(
    "unlockTime",
    BigInt(Math.floor(Date.now() / 1000) + ONE_YEAR_IN_SECS)
  );
  const lockedAmount = m.getParameter("lockedAmount", ONE_GWEI);

  const lock = m.contract("Lock", [unlockTime], {
    value: lockedAmount,
  });

  return { lock };
});

export default LockModule;'

init_git
write_gitignore "artifacts/" "cache/" "typechain-types/" "ignition/deployments/"
write_editorconfig
write_nvmrc

finish "npm install" "npx hardhat compile"
