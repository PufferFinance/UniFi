import { test, assert } from "matchstick-as/assembly/index"
import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import { OperatorRegistered, OperatorDeregistered } from "../generated/UniFiAVSManager/UniFiAVSManager"
import { OperatorSharesIncreased, OperatorSharesDecreased } from "../generated/DelegationManager/DelegationManager"
import { handleOperatorRegistered, handleOperatorDeregistered, handleOperatorSharesIncreased, handleOperatorSharesDecreased } from "../src/tvl-tracker"
import { Operator, TotalShares } from "../generated/schema"

// Helper function to create a new OperatorRegistered event
function createOperatorRegisteredEvent(operator: Address): OperatorRegistered {
  let newOperatorRegisteredEvent = changetype<OperatorRegistered>(newMockEvent())
  newOperatorRegisteredEvent.parameters = new Array()
  newOperatorRegisteredEvent.parameters.push(new ethereum.EventParam("operator", ethereum.Value.fromAddress(operator)))
  return newOperatorRegisteredEvent
}

// Helper function to create a new OperatorDeregistered event
function createOperatorDeregisteredEvent(operator: Address): OperatorDeregistered {
  let newOperatorDeregisteredEvent = changetype<OperatorDeregistered>(newMockEvent())
  newOperatorDeregisteredEvent.parameters = new Array()
  newOperatorDeregisteredEvent.parameters.push(new ethereum.EventParam("operator", ethereum.Value.fromAddress(operator)))
  return newOperatorDeregisteredEvent
}

// Helper function to create a new OperatorSharesIncreased event
function createOperatorSharesIncreasedEvent(operator: Address, shares: BigInt): OperatorSharesIncreased {
  let newOperatorSharesIncreasedEvent = changetype<OperatorSharesIncreased>(newMockEvent())
  newOperatorSharesIncreasedEvent.parameters = new Array()
  newOperatorSharesIncreasedEvent.parameters.push(new ethereum.EventParam("operator", ethereum.Value.fromAddress(operator)))
  newOperatorSharesIncreasedEvent.parameters.push(new ethereum.EventParam("shares", ethereum.Value.fromUnsignedBigInt(shares)))
  return newOperatorSharesIncreasedEvent
}

// Helper function to create a new OperatorSharesDecreased event
function createOperatorSharesDecreasedEvent(operator: Address, shares: BigInt): OperatorSharesDecreased {
  let newOperatorSharesDecreasedEvent = changetype<OperatorSharesDecreased>(newMockEvent())
  newOperatorSharesDecreasedEvent.parameters = new Array()
  newOperatorSharesDecreasedEvent.parameters.push(new ethereum.EventParam("operator", ethereum.Value.fromAddress(operator)))
  newOperatorSharesDecreasedEvent.parameters.push(new ethereum.EventParam("shares", ethereum.Value.fromUnsignedBigInt(shares)))
  return newOperatorSharesDecreasedEvent
}

test("handleOperatorRegistered creates a new Operator entity", () => {
  let operatorAddress = Address.fromString("0x0000000000000000000000000000000000000001")
  let newOperatorRegisteredEvent = createOperatorRegisteredEvent(operatorAddress)

  handleOperatorRegistered(newOperatorRegisteredEvent)

  assert.fieldEquals("Operator", operatorAddress.toHex(), "address", operatorAddress.toHex())
  assert.fieldEquals("Operator", operatorAddress.toHex(), "shares", "0")
  assert.fieldEquals("Operator", operatorAddress.toHex(), "isRegistered", "true")
})

test("handleOperatorDeregistered updates the Operator entity", () => {
  let operatorAddress = Address.fromString("0x0000000000000000000000000000000000000001")
  let newOperatorRegisteredEvent = createOperatorRegisteredEvent(operatorAddress)
  handleOperatorRegistered(newOperatorRegisteredEvent)

  let newOperatorDeregisteredEvent = createOperatorDeregisteredEvent(operatorAddress)
  handleOperatorDeregistered(newOperatorDeregisteredEvent)

  assert.fieldEquals("Operator", operatorAddress.toHex(), "isRegistered", "false")
})

test("handleOperatorSharesIncreased updates the Operator and TotalShares entities", () => {
  let operatorAddress = Address.fromString("0x0000000000000000000000000000000000000001")
  let newOperatorRegisteredEvent = createOperatorRegisteredEvent(operatorAddress)
  handleOperatorRegistered(newOperatorRegisteredEvent)

  let shares = BigInt.fromI32(100)
  let newOperatorSharesIncreasedEvent = createOperatorSharesIncreasedEvent(operatorAddress, shares)
  handleOperatorSharesIncreased(newOperatorSharesIncreasedEvent)

  assert.fieldEquals("Operator", operatorAddress.toHex(), "shares", shares.toString())
  assert.fieldEquals("TotalShares", "1", "totalShares", shares.toString())
})

test("handleOperatorSharesDecreased updates the Operator and TotalShares entities", () => {
  let operatorAddress = Address.fromString("0x0000000000000000000000000000000000000001")
  let newOperatorRegisteredEvent = createOperatorRegisteredEvent(operatorAddress)
  handleOperatorRegistered(newOperatorRegisteredEvent)

  let shares = BigInt.fromI32(100)
  let newOperatorSharesIncreasedEvent = createOperatorSharesIncreasedEvent(operatorAddress, shares)
  handleOperatorSharesIncreased(newOperatorSharesIncreasedEvent)

  let sharesDecreased = BigInt.fromI32(50)
  let newOperatorSharesDecreasedEvent = createOperatorSharesDecreasedEvent(operatorAddress, sharesDecreased)
  handleOperatorSharesDecreased(newOperatorSharesDecreasedEvent)

  assert.fieldEquals("Operator", operatorAddress.toHex(), "shares", shares.minus(sharesDecreased).toString())
  assert.fieldEquals("TotalShares", "1", "totalShares", shares.minus(sharesDecreased).toString())
})