import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { deployments } from "hardhat";
import chai from "chai";
import { Ship, advanceTimeAndBlock, getTime } from "../utils";
import { Lock__factory, Lock } from "../types";
import { anyValue } from '@nomicfoundation/hardhat-chai-matchers/withArgs';

const { expect } = chai;

let ship: Ship;
let lock: Lock;

let deployer: SignerWithAddress
let alice: SignerWithAddress

const setup = deployments.createFixture(async (hre) => {
  ship = await Ship.init(hre);
  const { accounts, users } = ship;
  await deployments.fixture(["lock"]);

  return {
    ship,
    accounts,
    users,
  };
});


describe("Lock", function () {
  beforeEach(async () => {
    const scaffold = await setup();

    deployer = scaffold.accounts.deployer;
    alice = scaffold.accounts.alice;

    lock = await ship.connect(Lock__factory);
  });


  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await lock.owner()).to.equal(deployer.address);
    });

    it("Should receive and store the funds to lock", async function () {
      const ONE_GWEI = 1_000_000_000n;

      expect(await ship.provider.getBalance(lock.target)).to.equal(ONE_GWEI);
    });

    it("Should fail if the unlockTime is not in the future", async function () {
      // We don't use the fixture here because we want a different deployment
      const latestTime = await getTime();
    
      await expect(ship.deploy(Lock__factory, {
        args: [latestTime], value: "1" })).to.be.revertedWith(
        "Unlock time should be in the future",
      );
    });
  });

  describe("Withdrawals", function () {
    describe("Validations", function () {
      it("Should revert with the right error if called too soon", async function () {
        await expect(lock.withdraw()).to.be.revertedWith("You can't withdraw yet");
      });

      it("Should revert with the right error if called from another account", async function () {
        const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
        const unlockTime = (await getTime()) + ONE_YEAR_IN_SECS;

        // We can increase the time in Hardhat Network
        await advanceTimeAndBlock(unlockTime);

        // We use lock.connect() to send a transaction from another account
        await expect(lock.connect(alice).withdraw()).to.be.revertedWith("You aren't the owner");
      });

      it("Shouldn't fail if the unlockTime has arrived and the owner calls it", async function () {
        const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
        const unlockTime = (await getTime()) + ONE_YEAR_IN_SECS;

        // Transactions are sent using the first signer by default
        await advanceTimeAndBlock(unlockTime);

        await expect(lock.withdraw()).not.to.be.reverted;
      });
    });

    describe("Events", function () {
      it("Should emit an event on withdrawals", async function () {
        const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
        const ONE_GWEI = 1_000_000_000n;
      
        const unlockTime = (await getTime()) + ONE_YEAR_IN_SECS;
        await advanceTimeAndBlock(unlockTime);

        await expect(lock.withdraw()).to.emit(lock, "Withdrawal").withArgs(ONE_GWEI, anyValue); // We accept any value as `when` arg
      });
    });

    describe("Transfers", function () {
      it("Should transfer the funds to the owner", async function () {
        const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
        const ONE_GWEI = 1_000_000_000n;
      
        const unlockTime = (await getTime()) + ONE_YEAR_IN_SECS;
        await advanceTimeAndBlock(unlockTime);

        await expect(lock.withdraw()).to.changeEtherBalances([deployer, lock], [ONE_GWEI, -ONE_GWEI]);
      });
    });
  });
});
