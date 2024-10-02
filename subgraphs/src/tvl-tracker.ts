import { BigInt, Address } from "@graphprotocol/graph-ts"

import {
  OperatorRegistered,
  OperatorDeregistered
} from "../generated/UniFiAVSManager/UniFiAVSManager";

import {OperatorSharesIncreased, OperatorSharesDecreased} from "../generated/DelegationManager/DelegationManager"
import { Operator, TotalShares } from "../generated/schema"
import { UniFiAVSManager } from "../generated/UniFiAVSManager/UniFiAVSManager"
import { DelegationManager } from "../generated/DelegationManager/DelegationManager"

function getTotalShares(): TotalShares {
  let totalShares = TotalShares.load("1")
  if (totalShares == null) {
    totalShares = new TotalShares("1")
    totalShares.totalShares = BigInt.fromI32(0)
  }
  return totalShares as TotalShares
}

function isRestakeableStrategy(strategy: Address): boolean {
  // Beacon Chain Strategy
  if (strategy.equals(Address.fromString("0xbeaC0eeEeeeeEEeEeEEEEeeEEeEeeeEeeEEBEaC0"))) {
    return true
  }
  return false;

  // getRestakeableStrategies wasn't available when we first deployed. but we can use it later after we enable new strategies

  // let unifiAVSManager = UniFiAVSManager.bind(Address.fromString("0x2d86E90ED40a034C753931eE31b1bD5E1970113d"))
  // let restakeableStrategies = unifiAVSManager.getRestakeableStrategies()
  // for (let i = 0; i < restakeableStrategies.length; i++) {
  //   if (restakeableStrategies[i].equals(strategy)) {
  //     return true
  //   }
  // }
  // return false
}

function getOperatorShares(operator: Address, strategies: Address): BigInt {
  let delegationManager = DelegationManager.bind(Address.fromString("0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A"))
  let shares = delegationManager.getOperatorShares(operator, [strategies])
  return shares[0]
}

export function handleOperatorRegistered(event: OperatorRegistered): void {
  let operator = new Operator(event.params.operator.toHex())
  operator.address = event.params.operator
  operator.shares = BigInt.fromI32(0)
  operator.isRegistered = true
  operator.save()
}

export function handleOperatorDeregistered(event: OperatorDeregistered): void {
  let operator = Operator.load(event.params.operator.toHex())
  if (operator != null) {
    let totalShares = getTotalShares()
    totalShares.totalShares = totalShares.totalShares.minus(operator.shares)
    totalShares.save()

    operator.isRegistered = false
    operator.save()
  }
}

export function handleOperatorSharesIncreased(event: OperatorSharesIncreased): void {
  if (isRestakeableStrategy(event.params.strategy)) {
    let operator = Operator.load(event.params.operator.toHex())
    if (operator != null && operator.isRegistered) {
      let totalShares = getTotalShares()
      let oldShares = operator.shares
      let newShares = getOperatorShares(event.params.operator, event.params.strategy)
      let sharesDifference = newShares.minus(oldShares)

      totalShares.totalShares = totalShares.totalShares.plus(sharesDifference)
      totalShares.save()

      operator.shares = newShares
      operator.save()
    }
  }
}

export function handleOperatorSharesDecreased(event: OperatorSharesDecreased): void {
  if (isRestakeableStrategy(event.params.strategy)) {
    let operator = Operator.load(event.params.operator.toHex())
    if (operator != null && operator.isRegistered) {
      let totalShares = getTotalShares()
      let oldShares = operator.shares
      let newShares = getOperatorShares(event.params.operator, event.params.strategy)
      let sharesDifference = oldShares.minus(newShares)

      totalShares.totalShares = totalShares.totalShares.minus(sharesDifference)
      totalShares.save()

      operator.shares = newShares
      operator.save()
    }
  }
}