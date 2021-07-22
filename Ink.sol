pragma solidity ^0.6.0;

/**
 * This contract is the one of $INK ERC20 token.
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


import './owner/Operator.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol';

contract INK is ERC20Burnable, Ownable, Operator {
    /**
     * @notice Constructs the INK Bond ERC-20 contract.
     */
    constructor() public ERC20('INK', 'INK') {}

    /**
     * @notice Operator mints INK to a recipient
     * @param recipient_ The address of recipient
     * @param amount_ The amount of INK to mint to
     * @return whether the process has been done
     */
    function mint(address recipient_, uint256 amount_)
        public
        onlyOperator
        returns (bool)
    {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);

        return balanceAfter > balanceBefore;
    }

    function burn(uint256 amount) public override onlyOperator {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount)
        public
        override
        onlyOperator
    {
        super.burnFrom(account, amount);
    }
}
