import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { deployments } from "hardhat";
import chai from "chai";
import { Ship, advanceTimeAndBlock } from "../utils";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import {
  JUSDC,
  JUSDC__factory,
  JurisEscrowFactoryFacet,
  JurisEscrowFactoryFacet__factory,
  JurisPoolFacet,
  JurisPoolFacet__factory,
} from "../types";
import { Contract, ZeroAddress } from "ethers";

const { expect } = chai;

let ship: Ship;
let escrowFactory: JurisEscrowFactoryFacet;
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

describe("JurisEscrow test", function () {
  let key: string;
  let timestamp: bigint;

  before(async () => {
    const scaffold = await setup();

    deployer = scaffold.accounts.deployer;
    alice = scaffold.accounts.alice;

    usdc = await ship.connect(JUSDC__factory);
    const diamond = await ship.connect("JurisFund");
    escrowFactory = JurisEscrowFactoryFacet__factory.connect(
      (diamond as Contract).target as string,
      deployer,
    );
    await usdc.connect(alice).mint(1_000_000_000n);
    // await usdc.connect(alice).approve(pool.target, 1_000_000_000n);
  });
});
