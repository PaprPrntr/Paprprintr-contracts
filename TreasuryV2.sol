// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

/**
 * This contract is a fork of Basis Cash Treasury contract, adapted to send a certain percentage
 * of mint tokens of allocateSeigniorage function to an initializable and changeable fund.
 * by PaprPrintr
 *
 * _____                     _____        _         _         
 *|  __ \                   |  __ \      (_)       | |        
 *| |__) |__ _  _ __   _ __ | |__) |_ __  _  _ __  | |_  _ __ 
 *|  ___// _` || '_ \ | '__||  ___/| '__|| || '_ \ | __|| '__|
 *| |   | (_| || |_) || |   | |    | |   | || | | || |_ | |   
 *|_|    \__,_|| .__/ |_|   |_|    |_|   |_||_| |_| \__||_|   
 *             |_|                                         
 */

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import './interfaces/ISimpleERCFund.sol';
import './owner/DoubleOperator.sol';

import "./lib/Babylonian.sol";
import "./owner/Operator.sol";
import "./utils/ContractGuard.sol";
import "./interfaces/IBasisAsset.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IBoardroom.sol";

/**
 * @title paprprintr Treasury contract
 * @notice Monetary policy logic to adjust supplies of the papr ecosystem / including ORIGAMI system
 * @author paprprintr team
 */

contract TreasuryV2 is ContractGuard   {
    using SafeERC20 for IERC20;
    using AddressUpgradeable for address;
    using SafeMath for uint256;

    /* ========= CONSTANT VARIABLES ======== */

    uint256 public constant PERIOD = 6 hours;

    /* ========== STATE VARIABLES ========== */

    // governance
    address public operator;

    // flags
    bool public migrated;
    bool public initialized;

    // epoch
    uint256 public startTime;
    uint256 public epoch;
    uint256 public epochSupplyContractionLeft;

    // core components
    address public fund;
    address public papr; // "Cash"
    address public ink; // "Bond"
    address public printr; //"Share"

    address public boardroom;
    address public paprOracle;

    // price
    uint256 public paprPriceOne;
    uint256 public paprPriceCeiling;
    uint256 public paprPriceOverExpansionCeiling;

    uint256 public seigniorageSaved;

    // protocol parameters
    uint256 public maxSupplyExpansionPercent;
    uint256 public maxSupplyExpansionPercentInDebtPhase;
    uint256 public inkDepletionFloorPercent;
    uint256 public seigniorageExpansionFloorPercent;
    uint256 public maxSupplyContractionPercent;
    uint256 public maxDeptRatioPercent;
    uint256 public BootstrapEpochs;
    uint256 public BootstrapSupplyExpansionPercent;
    uint256 public paprMultiplierStepExpansion;

    // multiplier when the price is above 1.5
    uint256 public printingRatioMultiplier; //%

    // paperprinter fund
    uint256 public fundAllocationRate; // %

    /* =================== Events =================== */
 
    event Initialized(address indexed executor, uint256 at);
    event RedeemedInks(address indexed from, uint256 amount);
    event BoughtInks(address indexed from, uint256 amount);
    event TreasuryFunded(uint256 timestamp, uint256 seigniorage);
    event BoardroomFunded(uint256 timestamp, uint256 seigniorage);
    event RedeemedORIGAMI(address indexed from, uint256 amount);
    event BoughtORIGAMI(address indexed from, uint256 amount);

//==========================================//
    /* =================== Modifier =================== */

    modifier onlyOperator() {
        require(operator == msg.sender, "Caller is not the operator");
        _;
    }

    function checkCondition() private {
        require(now >= startTime, "Not started yet");
    }

    function checkEpoch() private  {
        require(now >= nextEpochPoint(), "Not opened yet");

        epoch = epoch.add(1);
        epochSupplyContractionLeft = IERC20(papr).totalSupply().mul(maxSupplyContractionPercent).div(10000);
    }

    function checkOperator() private {
        require(
            IBasisAsset(papr).operator() == address(this) &&
                IBasisAsset(ink).operator() == address(this) &&
                IBasisAsset(printr).operator() == address(this) &&
                Operator(boardroom).operator() == address(this), 
            "Need more permission"
        );
    }

    /* ========== VIEW FUNCTIONS ========== */


    function isInitialized() public view returns (bool) {
        return initialized;
    }

    // epoch
    function nextEpochPoint() public view returns (uint256) {
        return startTime.add(epoch.mul(PERIOD));
    }

    // oracle
    function getPaprPrice() public view returns (uint256 paprPrice) {
        try IOracle(paprOracle).consult(papr, 1e18) returns (uint256 price) {
            return price;
        } catch {
            revert("Failed to consult papr price from the oracle");
        }
    }

    // budget
    function getReserve() public view returns (uint256) {
        return seigniorageSaved;
    }

    address public ORIGAMI;

    /* ========== GOVERNANCE ========== */

    function initialize(
        address _papr,
        address _ink,
        address _printr,
        uint256 _startTime,
        address _fund
    )  public {
        require(!initialized, "Initialized");
        papr = _papr;
        ink = _ink;
        printr = _printr;
        startTime = _startTime;
        fund = _fund;

        paprMultiplierStepExpansion = 10e16; // 10 cents
        paprPriceOne = 10e17;
        paprPriceOverExpansionCeiling = 15e17;
        paprPriceCeiling = paprPriceOne.mul(101).div(100);

        maxSupplyExpansionPercent = 50;
        maxSupplyExpansionPercentInDebtPhase = 400;
        inkDepletionFloorPercent = 10000;
        seigniorageExpansionFloorPercent = 3500;
        maxSupplyContractionPercent = 400;
        maxDeptRatioPercent = 3500;
        epoch = 0;
        epochSupplyContractionLeft = 0;
        printingRatioMultiplier = 0;
        fundAllocationRate = 500;

        BootstrapEpochs = 0;
        BootstrapSupplyExpansionPercent = 100;

        seigniorageSaved = IERC20(papr).balanceOf(address(this));

        initialized = true;
        operator = msg.sender;
        emit Initialized(msg.sender, block.number);
    }

    function setOperator(address _operator) external onlyOperator {
        operator = _operator;
    }

    function setBoardroom(address _boardroom) external onlyOperator {
        boardroom = _boardroom;
    }

    function setPaprOracle(address _paprOracle) external onlyOperator {
        paprOracle = _paprOracle;
    }

    function setORIGAMI(address _origami) external onlyOperator {
        ORIGAMI = _origami;
    }

    function buyORIGAMI(uint256 amount) external onlyOneBlock {
        checkOperator();
        require(amount > 0, "Cannot purchase ORIGAMI with zero amount");

        IBasisAsset(papr).burnFrom(msg.sender, amount);
        IBasisAsset(ORIGAMI).mint(msg.sender, amount);

        emit BoughtORIGAMI(msg.sender, amount);
    }

    function redeemORIGAMI(uint256 amount) external onlyOneBlock {
        checkOperator();
        require(amount > 0, "Cannot redeem ORIGAMI with zero amount");

        IBasisAsset(ORIGAMI).burnFrom(msg.sender, amount);
        IBasisAsset(papr).mint(msg.sender, amount);

        emit RedeemedORIGAMI(msg.sender, amount);
    }

    function setPaprPriceCeilingAndprintingRatioMultiplier(uint256 _paprPriceCeiling, uint256 _printingRatioMultiplier) external onlyOperator {
        require(_paprPriceCeiling >= paprPriceOne && _paprPriceCeiling <= paprPriceOne.mul(120).div(100), "out of range"); // [$1.0, $1.2]
        paprPriceCeiling = _paprPriceCeiling;
        require(_printingRatioMultiplier >= 0 && _printingRatioMultiplier <= 1000, "out of range"); // [0%, 10%]
        printingRatioMultiplier = _printingRatioMultiplier;
    }

    function setMaxSupplyExpansionPercents(uint256 _maxSupplyExpansionPercent, uint256 _maxSupplyExpansionPercentInDebtPhase) external onlyOperator {
        require(_maxSupplyExpansionPercent >= 10 && _maxSupplyExpansionPercent <= 1000, "_maxSupplyExpansionPercent: out of range"); // [0.1%, 10%]
        require(
            _maxSupplyExpansionPercentInDebtPhase >= 10 && _maxSupplyExpansionPercentInDebtPhase <= 1500,
            "_maxSupplyExpansionPercentInDebtPhase: out of range"
        ); // [0.1%, 15%]
        require(
            _maxSupplyExpansionPercent <= _maxSupplyExpansionPercentInDebtPhase,
            "_maxSupplyExpansionPercent is over _maxSupplyExpansionPercentInDebtPhase"
        );
        maxSupplyExpansionPercent = _maxSupplyExpansionPercent;
        maxSupplyExpansionPercentInDebtPhase = _maxSupplyExpansionPercentInDebtPhase;
    }

    function setInkDepletionFloorPercent(uint256 _inkDepletionFloorPercent) external onlyOperator {
        require(_inkDepletionFloorPercent >= 500 && _inkDepletionFloorPercent <= 10000, "out of range"); // [5%, 100%]
        inkDepletionFloorPercent = _inkDepletionFloorPercent;
    }

    function setMaxSupplyContractionPercent(uint256 _maxSupplyContractionPercent) external onlyOperator {
        require(_maxSupplyContractionPercent >= 100 && _maxSupplyContractionPercent <= 1500, "out of range"); // [0.1%, 15%]
        maxSupplyContractionPercent = _maxSupplyContractionPercent;
    }

    function setMaxDeptRatioPercent(uint256 _maxDeptRatioPercent) external onlyOperator {
        require(_maxDeptRatioPercent >= 1000 && _maxDeptRatioPercent <= 10000, "out of range"); // [10%, 100%]
        maxDeptRatioPercent = _maxDeptRatioPercent;
    }

    // Modifiy PaperPrinter fund address (onlyOperator) :

    function setCoreAddresses(address newFund, uint256 _fundRate, address _papr, address _ink, address _printr) external onlyOperator {
        fund = newFund;
        require(_fundRate <= 2000); // _rate <= 20%
        fundAllocationRate = _fundRate;
        papr = _papr;
        ink = _ink;
        printr = _printr;
    }

    /* ========== MUTABLE FUNCTIONS ========== */

    function _updatePaprPrice() internal {
        try IOracle(paprOracle).update() {} catch {}
    }

    function buyInks(uint256 amount, uint256 targetPrice) external onlyOneBlock {
        checkCondition();
        checkOperator();
        require(amount > 0, "Cannot purchase inks with zero amount");

        uint256 paprPrice = getPaprPrice();
        require(paprPrice == targetPrice, "Papr price moved");
        require(
            paprPrice < paprPriceOne, // price < $1
            "PaprPrice not eligible for ink purchase"
        );

        require(amount <= epochSupplyContractionLeft, "Not enough ink left to purchase");

        uint256 _boughtInk = amount.mul(1e18).div(paprPrice);
        uint256 paprSupply = IERC20(papr).totalSupply();
        uint256 newInkSupply = IERC20(ink).totalSupply().add(_boughtInk);
        require(newInkSupply <= paprSupply.mul(maxDeptRatioPercent).div(10000), "over max debt ratio");

        IBasisAsset(papr).burnFrom(msg.sender, amount);
        IBasisAsset(ink).mint(msg.sender, _boughtInk);

        epochSupplyContractionLeft = epochSupplyContractionLeft.sub(amount);
        _updatePaprPrice();

        emit BoughtInks(msg.sender, amount);
    }

    function redeemInks(uint256 amount, uint256 targetPrice) external onlyOneBlock {
        checkCondition();
        checkOperator();
        require(amount > 0, "Cannot redeem inks with zero amount");

        uint256 paprPrice = getPaprPrice();
        require(paprPrice == targetPrice, "Papr price moved");
        require(
            paprPrice > paprPriceCeiling, // price > $1.01
            "PaprPrice not eligible for ink purchase"
        );
        require(IERC20(papr).balanceOf(address(this)) >= amount, "Treasury has no more budget");

        seigniorageSaved = seigniorageSaved.sub(Math.min(seigniorageSaved, amount));

        IBasisAsset(ink).burnFrom(msg.sender, amount);
        IERC20(papr).safeTransfer(msg.sender, amount);

        _updatePaprPrice();

        emit RedeemedInks(msg.sender, amount);
    }

    // Mint, approve and send PAPR to Boardroom :

    function _sendToBoardRoom(uint256 _amount) internal {
        IBasisAsset(papr).mint(address(this), _amount);
        IERC20(papr).safeApprove(boardroom, _amount);
        IBoardroom(boardroom).allocateSeigniorage(_amount);
        emit BoardroomFunded(now, _amount);
    }

    // Mint, approve and send PAPR to fund :

    function _sendToFund(uint256 _amount) internal {
        IBasisAsset(papr).mint(address(this), _amount);
        IERC20(papr).safeApprove(fund, _amount);
        ISimpleERCFund(fund).deposit(papr,_amount,'Treasury: Seigniorage Allocation');
    }

    // Return number of times over the cents step (paprMultiplierStepExpansion) :

    function _countTimesOverCents() internal returns (uint256) {
        uint256 paprPrice = getPaprPrice();
        uint256 count;
        if (paprPrice > paprPriceOverExpansionCeiling) {
            paprPrice = paprPrice.sub(paprPriceOverExpansionCeiling);
            count = paprPrice.div(paprMultiplierStepExpansion);
            return uint(count);
        } else {
             return 0;
        }
    }

    function allocateSeigniorage() external onlyOneBlock onlyOperator {
        checkCondition();
        checkEpoch();
        checkOperator();
        _updatePaprPrice(); 
        uint256 paprSupply = IERC20(papr).totalSupply().sub(seigniorageSaved);
        if (epoch < BootstrapEpochs) {
            // Bootstrap (early epochs)
            _sendToBoardRoom(paprSupply.mul(BootstrapSupplyExpansionPercent).div(10000));
        } else {
            uint256 paprPrice = getPaprPrice();
            if (paprPrice > paprPriceCeiling) {
                // Expansion ($PAPR Price > 1$): there is some seigniorage to be allocated
                uint256 inkSupply = IERC20(ink).totalSupply();
                uint256 _percentage = paprPrice.sub(paprPriceOne);
                uint256 _savedForInk;
                uint256 _savedForBoardRoom;
                //Allocating to fund when saved enough to pay debt
                uint256 _savedForFund;
                uint256 stepRatio = 10; // base (1) * 10

                if (seigniorageSaved >= inkSupply.mul(inkDepletionFloorPercent).div(10000)) {
                    // saved enough to pay dept, mint as usual rate
                    uint256 _mse = maxSupplyExpansionPercent.mul(1e14);
                    if (_percentage > _mse) {
                        _percentage = _mse;
                    }
                    // computing seigniorage based on cents ratio/current exp %
                    uint256 ratio = printingRatioMultiplier.mul(_countTimesOverCents());
                    uint256 percentCombined = _percentage.mul(stepRatio.add(ratio)).div(10);
                    uint256 _seigniorage = paprSupply.mul(percentCombined).div(1e18);
                    
                    // sending 5% to the PAPR marketing fund
                    _savedForFund = _seigniorage.mul(fundAllocationRate).div(10000);
                    // sending 95% to the printing room
                    _savedForBoardRoom = _seigniorage.sub(_savedForFund); 
                }
                
                else {
                    // have not saved enough to pay dept, mint more
                    uint256 _mse = maxSupplyExpansionPercentInDebtPhase.mul(1e14);
                    if (_percentage > _mse) {
                        _percentage = _mse;
                    }

                    uint256 ratio = printingRatioMultiplier.mul(_countTimesOverCents());
                    uint256 percentCombined = _percentage.mul(stepRatio.add(ratio)).div(10);
                    uint256 _seigniorage = paprSupply.mul(percentCombined).div(1e18);

                    // reducing boardroom allocation, allocating dedicated % only
                    _savedForBoardRoom = _seigniorage.mul(seigniorageExpansionFloorPercent).div(10000);
                    // seignorage allocated to Treasury 
                    _savedForInk = _seigniorage.sub(_savedForBoardRoom);

                }
                if (_savedForBoardRoom > 0) {
                    _sendToBoardRoom(_savedForBoardRoom);
                }
                if (_savedForInk > 0) {
                    seigniorageSaved = seigniorageSaved.add(_savedForInk);
                    IBasisAsset(papr).mint(address(this), _savedForInk);
                    emit TreasuryFunded(now, _savedForInk);
                }
                if (_savedForFund > 0) {
                    _sendToFund(_savedForFund);

                }
            }
        }
    }

    function governanceRecoverUnsupported(
        IERC20 _token,
        uint256 _amount,
        address _to
    ) external onlyOperator {
        // do not allow to drain core tokens
        require(address(_token) != address(papr), "papr");
        require(address(_token) != address(ink), "ink");
        require(address(_token) != address(printr), "printr");
        _token.safeTransfer(_to, _amount);
    }

    /* ========== PRINTING ROOM CONTROLLING FUNCTIONS ========== */

    function boardroomSetOperator(address _operator) external onlyOperator {
        IBoardroom(boardroom).setOperator(_operator);
    }

    function boardroomSetLockUp(uint256 _withdrawLockupEpochs, uint256 _rewardLockupEpochs) external onlyOperator {
        IBoardroom(boardroom).setLockUp(_withdrawLockupEpochs, _rewardLockupEpochs);
    }

    function boardroomAllocateSeigniorage(uint256 amount) external onlyOperator {
        IBoardroom(boardroom).allocateSeigniorage(amount);
    }

    function boardroomGovernanceRecoverUnsupported(
        address _token,
        uint256 _amount,
        address _to
    ) external onlyOperator {
        IBoardroom(boardroom).governanceRecoverUnsupported(_token, _amount, _to);
    }
}