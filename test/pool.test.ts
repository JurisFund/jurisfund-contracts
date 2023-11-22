import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { deployments } from "hardhat";
import chai from "chai";
import { Ship } from "../utils";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { JurisPoolFacet, JurisPoolFacet__factory } from "../types";
import { ZeroAddress } from "ethers";

const { expect } = chai;

let ship: Ship;
let pool: JurisPoolFacet;

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
  beforeEach(async () => {
    const scaffold = await setup();

    deployer = scaffold.accounts.deployer;
    alice = scaffold.accounts.alice;

    const diamond = await ship.connect("JurisFund");
    pool = JurisPoolFacet__factory.connect(diamond.target as string, deployer);
  });

  it("token", async () => {
    expect(await pool.name()).eq("Juris Pool Liquidity");
    expect(await pool.symbol()).eq("JPL");
    expect(await pool.decimals()).eq(18);
  });
});
