// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {ERC4626} from "../lib/solmate/src/tokens/ERC4626.sol";
import {SafeTransferLib} from "../lib/solmate/src/utils/SafeTransferLib.sol";

import {FixedPointMathLib} from "../lib/solmate/src/utils/FixedPointMathLib.sol";

interface IL1StandardBridge {
    function depositERC20To(
        address _l1Token,
        address _l2Token,
        address _to,
        uint256 _amount,
        uint32 _minGasLimit,
        bytes calldata _extraData
    ) external;
}

contract TokenizedVault is ERC4626 {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    // a mapping that checks if a user has deposited
    mapping(address => uint256) public shareHolder;
    // Address of the L1StandardBridge contract
    IL1StandardBridge public immutable l1StandardBridge;
    // Address of the basedAppChain on L2 to deposit the tokens to
    address public immutable basedAppChain;

    error Disabled();

    constructor(
        ERC20 _underlying,
        string memory _name,
        string memory _symbol,
        address _l1StandardBridge,
        address _basedAppChain
    ) ERC4626(_underlying, _name, _symbol) {
        l1StandardBridge = IL1StandardBridge(_l1StandardBridge);
        basedAppChain = _basedAppChain;
    }

    // DEPOSIT/WITHDRAWAL LOGIC

    // a deposit function that receives assets fron users
    function deposit(
        uint256 assets,
        address receiver
    ) public virtual override returns (uint256) {
        return super.deposit(assets, receiver);
        // mint the unifiETH to this vault, and transfer to the bridge contract??? - handled in afterDeposit
    }

    function mint(
        uint256 shares,
        address receiver
    ) public virtual override returns (uint256) {
        return super.mint(shares, receiver);
    }

    // returns total number of assets
    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    // Disable the redeem and withdraw functions for now since it needs to be withdrawn from L2
    function redeem(
        uint256,
        address,
        address
    ) public virtual override returns (uint256) {
        revert Disabled();
    }

    function withdraw(
        uint256,
        address,
        address
    ) public virtual override returns (uint256) {
        revert Disabled();
    }

    function afterDeposit(uint256, uint256 shares) internal override {
        // Approve the L1StandardBridge to spend the vault tokens
        ERC20(address(this)).approve(address(l1StandardBridge), shares);
        // Deposit the tokens to the L1StandardBridge
        l1StandardBridge.depositERC20To(
            address(this), // L1 token (this contract)
            address(this), // L2 token (assuming same address, can be adjusted)
            basedAppChain, // Recipient address on L2
            shares, // Amount of tokens to deposit
            200000, // Minimum gas limit for the deposit message on L2 (adjust as needed)
            bytes("") // Extra data for L2 to execute something, currently empty
        );
    }
}
