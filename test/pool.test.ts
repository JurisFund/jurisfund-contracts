import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { deployments } from "hardhat";
import chai from "chai";
import { Ship, advanceTimeAndBlock } from "../utils";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { JUSDC, JUSDC__factory, JurisPoolFacet, JurisPoolFacet__factory } from "../types";
import { Contract, ZeroAddress } from "ethers";

const { expect } = chai;

let ship: Ship;
let pool: JurisPoolFacet;
let usdc: JUSDC;

let deployer: SignerWithAddress;
let alice: SignerWithAddress;

const setup = deployments.createFixture(async (hre) => {
  ship = await Ship.init(hre);
  const { accounts, users } = ship;
  await deployments.fixture(["init"]);

  return {
    ship,
    accounts,
    users,
  };
});

describe("JurisPool test", function () {
  let key: string;
  let timestamp: bigint;

  const getKey = (x: string) => {
    key = x;
    return true;
  };

  const getTimestamp = (x: bigint) => {
    timestamp = x;
    return true;
  };

  before(async () => {
    const scaffold = await setup();

    deployer = scaffold.accounts.deployer;
    alice = scaffold.accounts.alice;

    usdc = await ship.connect(JUSDC__factory);
    const diamond = await ship.connect("JurisFund");
    pool = JurisPoolFacet__factory.connect((diamond as Contract).target as string, deployer);
    await usdc.connect(alice).mint(1_000_000_000n);
    await usdc.connect(alice).approve(pool.target, 1_000_000_000n);
  });

  it("check initialization", async () => {
    const poolState = await pool.getPoolState();
    const poolConfig = await pool.getPoolConfig();

    expect(poolState.stakedAmount).to.eq(0);
    expect(poolState.liquidity).to.eq(0);
    expect(poolConfig.token).to.eq(usdc.target);
    expect(poolConfig.minStakeAmount).to.eq(10_000_000n); // $10
    expect(poolConfig.fullPeriod).to.eq(2 * 365 * 24 * 3600); // 2 years
  });

  it("stake USDC", async () => {
    await expect(pool.connect(alice).stake(true, 1_000_000n)).to.be.revertedWithCustomError(
      pool,
      "InvalidStakeAmount",
    );

    await expect(pool.connect(alice).stake(true, 10_000_000n))
      .to.be.emit(usdc, "Transfer")
      .withArgs(alice.address, pool.target, 10_000_000n)
      .emit(pool, "Staked")
      .withArgs(getKey, alice.address, 10_000_000n, getTimestamp, 10_000_000n)
      .emit(pool, "RateUpdated")
      .withArgs(10_000_000n, 10_000_000n);

    const poolState = await pool.getPoolState();

    expect(poolState.stakedAmount).to.eq(10_000_000n);
    expect(poolState.liquidity).to.eq(10_000_000n);

    const stakeData = await pool.getStake(key);
    expect(stakeData.unlockTime).to.eq(timestamp);
    expect(stakeData.amount).to.eq(10_000_000n);
    expect(stakeData.liquidity).to.eq(10_000_000n);
    expect(stakeData.owner).to.eq(alice.address);
    expect(stakeData.finished).to.eq(false);
  });

  it("unStake USDC", async () => {
    await expect(pool.unStake(key)).to.be.revertedWithCustomError(pool, "Forbidden").withArgs(alice.address);
    await expect(pool.connect(alice).unStake(key))
      .to.be.revertedWithCustomError(pool, "Locked")
      .withArgs(timestamp);

    await advanceTimeAndBlock(2 * 365 * 24 * 3600);
    await expect(pool.connect(alice).unStake(key))
      .to.emit(usdc, "Transfer")
      .withArgs(pool.target, alice.address, 10_000_000n)
      .emit(pool, "Withdrawal")
      .withArgs(key, alice.address, 10_000_000n, 10_000_000n)
      .emit(pool, "RateUpdated")
      .withArgs(0n, 0n);

    const poolState = await pool.getPoolState();

    expect(poolState.stakedAmount).to.eq(0n);
    expect(poolState.liquidity).to.eq(0n);

    const stakeData = await pool.getStake(key);
    expect(stakeData.unlockTime).to.eq(timestamp);
    expect(stakeData.amount).to.eq(10_000_000n);
    expect(stakeData.liquidity).to.eq(10_000_000n);
    expect(stakeData.owner).to.eq(alice.address);
    expect(stakeData.finished).to.eq(true);
  });
});
