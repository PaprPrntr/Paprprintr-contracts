// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/GSN/Context.sol";
import '../utils/DoubleOwnable.sol';

contract DoubleOperator is Context, DoubleOwnable {
    address private _primaryOperator;
    address private _secondaryOperator;

    event PrimaryOperatorTransferred(
        address indexed previousOperator,
        address indexed newOperator
    );
    event SecondaryOperatorTransferred(
        address indexed previousOperator,
        address indexed newOperator
    );

    constructor() internal {
        _primaryOperator = _msgSender();
        emit PrimaryOperatorTransferred(address(0), _primaryOperator);
    }

    function primaryOperator() public view returns (address) {
        return _primaryOperator;
    }

    function operator() public view returns (address) {
        return _secondaryOperator;
    }

    modifier onlyDoubleOperator() {
        require(
            (_primaryOperator == msg.sender || _secondaryOperator == msg.sender),
            'operator: caller is not the operator'
        );
        _;
    }

    modifier onlySecondaryOperator() {
        require(
            _secondaryOperator == msg.sender,
            'operator: caller is not the operator'
        );
        _;
    }

    function isOperator() public view returns (bool) {
        return _msgSender() == _primaryOperator || _msgSender() == _secondaryOperator;
    }

    function transferPrimaryOperator(address newOperator_) public onlyPrimaryOwner {
        _transferPrimaryOperator(newOperator_);
    }

    function _transferPrimaryOperator(address newOperator_) internal {
        require(
            newOperator_ != address(0),
            'operator: zero address given for new operator'
        );
        emit PrimaryOperatorTransferred(address(0), newOperator_);
        _primaryOperator = newOperator_;
    }

    function setSecondaryOperator(address newOperator_) external onlyPrimaryOwner {
        require(
            newOperator_ != address(0),
            'operator: zero address given for new operator'
        );

        emit SecondaryOperatorTransferred(address(0), newOperator_);
        _secondaryOperator = newOperator_;
    }
}