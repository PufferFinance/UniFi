import { BigInt, Address } from "@graphprotocol/graph-ts"

import {
  OperatorRegistered,
  OperatorDeregistered
} from "../generated/UniFiAVSManager/UniFiAVSManager";

import {OperatorSharesIncreased, OperatorSharesDecreased} from "../generated/DelegationManager/DelegationManager"
import { Operator, TotalShares, StrategyShares } from "../generated/schema"
import { UniFiAVSManager } from "../generated/UniFiAVSManager/UniFiAVSManager"
import { DelegationManager } from "../generated/DelegationManager/DelegationManager"


const DELEGATION_MANAGER = Address.fromString("0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A")
const UNIFI_AVS_MANAGER = Address.fromString("0x2d86E90ED40a034C753931eE31b1bD5E1970113d")

const EIGEN_STRATEGY = Address.fromString("0xaCB55C530Acdb2849e6d4f36992Cd8c9D50ED8F7")
const RESTAKEABLE_STRATEGIES: Address[] = [
  Address.fromString("0xbeaC0eeEeeeeEEeEeEEEEeeEEeEeeeEeeEEBEaC0"), // BEACON_CHAIN_STRATEGY
  Address.fromString("0x54945180dB7943c0ed0FEE7EdaB2Bd24620256bc"), // cbETH
  Address.fromString("0x93c4b944D05dfe6df7645A86cd2206016c51564D"), // stETH
  Address.fromString("0x1BeE69b7dFFfA4E2d53C2a2Df135C388AD25dCD2"), // rETH
  Address.fromString("0x9d7eD45EE2E8FC5482fa2428f15C971e6369011d"), // ETHx
  Address.fromString("0x13760F50a9d7377e4F20CB8CF9e4c26586c658ff"), // ankrETH
  Address.fromString("0xa4C637e0F704745D182e4D38cAb7E7485321d059"), // OETH
  Address.fromString("0x57ba429517c3473B6d34CA9aCd56c0e735b94c02"), // osETH
  Address.fromString("0x0Fe4F44beE93503346A3Ac9EE5A26b130a5796d6"), // swETH
  Address.fromString("0x7CA911E83dabf90C90dD3De5411a10F1A6112184"), // wBETH
  Address.fromString("0x8CA7A5d6f3acd3A7A8bC468a8CD0FB14B6BD28b6"), // sfrxETH
  Address.fromString("0xAe60d8180437b5C34bB956822ac2710972584473"), // lsETH
  Address.fromString("0x298aFB19A105D59E74658C4C334Ff360BadE6dd2")  // mETH
];

const BLOCK_TO_ENABLE_RESTAKEABLE_STRATEGIES = BigInt.fromI32(21016203); // Mon Oct 21 2024 18:14:15

function getTotalShares(): TotalShares {
  let totalShares = TotalShares.load("1")
  if (totalShares == null) {
    totalShares = new TotalShares("1")
    totalShares.totalShares = BigInt.fromI32(0)
    totalShares.totalEigenShares = BigInt.fromI32(0)
  }
  return totalShares as TotalShares
}

function isRestakeableStrategy(strategy: Address, blockNumber: BigInt): boolean {
  if (blockNumber.lt(BLOCK_TO_ENABLE_RESTAKEABLE_STRATEGIES)) {
    return strategy.equals(EIGEN_STRATEGY) || RESTAKEABLE_STRATEGIES.includes(strategy) as boolean;
  } else {
    let unifiAVSManager = UniFiAVSManager.bind(UNIFI_AVS_MANAGER);
    const strategies = unifiAVSManager.getRestakeableStrategies();
    return strategies.includes(strategy) as boolean;
  }
}

function getOperatorShares(operator: Address, strategy: Address): BigInt {
  let delegationManager = DelegationManager.bind(DELEGATION_MANAGER)
  let shares = delegationManager.getOperatorShares(operator, [strategy])
  return shares[0]
}

function getOrCreateStrategyShares(operator: Address, strategy: Address): StrategyShares {
  let id = operator.toHexString() + '-' + strategy.toHexString()
  let strategyShares = StrategyShares.load(id)
  if (strategyShares == null) {
    strategyShares = new StrategyShares(id)
    strategyShares.operator = operator.toHexString()
    strategyShares.strategy = strategy
    strategyShares.shares = BigInt.fromI32(0)
  }
  return strategyShares as StrategyShares
}

export function handleOperatorRegistered(event: OperatorRegistered): void {
  let operator = new Operator(event.params.operator.toHex())
  operator.address = event.params.operator
  operator.totalEthShares = BigInt.fromI32(0)
  operator.totalEigenShares = BigInt.fromI32(0)
  operator.isRegistered = true

  let totalShares = getTotalShares()

  for (let i = 0; i < RESTAKEABLE_STRATEGIES.length; i++) {
    let strategyShares = getOrCreateStrategyShares(event.params.operator, RESTAKEABLE_STRATEGIES[i])
    let shares = getOperatorShares(event.params.operator, RESTAKEABLE_STRATEGIES[i])
    strategyShares.shares = shares
    strategyShares.save()
    operator.totalEthShares = operator.totalEthShares.plus(shares)
  }

  let eigenStrategyShares = getOrCreateStrategyShares(event.params.operator, EIGEN_STRATEGY)
  let totalEigenShares = getOperatorShares(event.params.operator, EIGEN_STRATEGY)
  eigenStrategyShares.shares = totalEigenShares
  eigenStrategyShares.save()
  operator.totalEigenShares = totalEigenShares

  totalShares.totalShares = totalShares.totalShares.plus(operator.totalEthShares)
  totalShares.totalEigenShares = totalShares.totalEigenShares.plus(operator.totalEigenShares)
  
  totalShares.save()
  operator.save()
}

export function handleOperatorDeregistered(event: OperatorDeregistered): void {
  let operator = Operator.load(event.params.operator.toHex())
  if (operator != null) {
    let totalShares = getTotalShares()
    totalShares.totalShares = totalShares.totalShares.minus(operator.totalEthShares)
    totalShares.totalEigenShares = totalShares.totalEigenShares.minus(operator.totalEigenShares)
    totalShares.save()

    operator.isRegistered = false
    operator.save()
  }
}

export function handleOperatorSharesIncreased(event: OperatorSharesIncreased): void {
  let operator = Operator.load(event.params.operator.toHex())
  if (operator != null && operator.isRegistered) {
    let strategyShares = getOrCreateStrategyShares(event.params.operator, event.params.strategy)
    let oldShares = strategyShares.shares
    let newShares = getOperatorShares(event.params.operator, event.params.strategy)
    let sharesDifference = newShares.minus(oldShares)

    strategyShares.shares = newShares
    strategyShares.save()

    let totalShares = getTotalShares()

    if (event.params.strategy.equals(EIGEN_STRATEGY)) {
      operator.totalEigenShares = operator.totalEigenShares.plus(sharesDifference)
      totalShares.totalEigenShares = totalShares.totalEigenShares.plus(sharesDifference)
    } else if (isRestakeableStrategy(event.params.strategy, event.block.number)) {
      operator.totalEthShares = operator.totalEthShares.plus(sharesDifference)
      totalShares.totalShares = totalShares.totalShares.plus(sharesDifference)
    }

    totalShares.save()
    operator.save()
  }
}

export function handleOperatorSharesDecreased(event: OperatorSharesDecreased): void {
  let operator = Operator.load(event.params.operator.toHex())
  if (operator != null && operator.isRegistered) {
    let strategyShares = getOrCreateStrategyShares(event.params.operator, event.params.strategy)
    let oldShares = strategyShares.shares
    let newShares = getOperatorShares(event.params.operator, event.params.strategy)
    let sharesDifference = oldShares.minus(newShares)

    strategyShares.shares = newShares
    strategyShares.save()

    let totalShares = getTotalShares()

    if (event.params.strategy.equals(EIGEN_STRATEGY)) {
      operator.totalEigenShares = operator.totalEigenShares.minus(sharesDifference)
      totalShares.totalEigenShares = totalShares.totalEigenShares.minus(sharesDifference)
    } else if (isRestakeableStrategy(event.params.strategy, event.block.number)) {
      operator.totalEthShares = operator.totalEthShares.minus(sharesDifference)
      totalShares.totalShares = totalShares.totalShares.minus(sharesDifference)
    }

    totalShares.save()
    operator.save()
  }
}