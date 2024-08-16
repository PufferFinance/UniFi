// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { IAVSDirectory } from "eigenlayer/interfaces/IAVSDirectory.sol";

interface IAVSDirectoryExtended is IAVSDirectory {
    function avsOperatorStatus(address avs, address operator) external view returns (OperatorAVSRegistrationStatus);
}
