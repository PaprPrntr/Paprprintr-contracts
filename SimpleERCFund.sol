pragma solidity ^0.6.0;

/**
 * This contract is the Fund where fees are deposited at each seigniorage of the Treasury.
 * by PaprPrintr
 *
 * _____                     _____        _         _         
 *|  __ \                   |  __ \      (_)       | |        
 *| |__) |__ _  _ __   _ __ | |__) |_ __  _  _ __  | |_  _ __ 
 *|  ___// _  ||  _ \ |  __||  ___/|  __|| ||  _ \ | __||  __|
 *| |   | (_| || |_) || |   | |    | |   | || | | || |_ | |   
 *|_|    \__,_|| .__/ |_|   |_|    |_|   |_||_| |_| \__||_|   
 *             |_|                                         
 */

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

import './owner/Operator.sol';
import './interfaces/ISimpleERCFund.sol';

contract SimpleERCFund is ISimpleERCFund, Operator {
    using SafeERC20 for IERC20;

    function deposit(
        address token,
        uint256 amount,
        string memory reason
    ) public override {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, now, reason);
    }

    function withdraw(
        address token,
        uint256 amount,
        address to,
        string memory reason
    ) public override onlyOperator {
        IERC20(token).safeTransfer(to, amount);
        emit Withdrawal(msg.sender, to, now, reason);
    }

    event Deposit(address indexed from, uint256 indexed at, string reason);
    event Withdrawal(
        address indexed from,
        address indexed to,
        uint256 indexed at,
        string reason
    );
}